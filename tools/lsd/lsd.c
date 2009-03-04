#include <stdio.h>
#include <common.h>
#include <debug.h>
#include <libelf.h>
#include <libebl.h>
#include <elf.h>
#include <gelf.h>
#include <string.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <hash.h>
#include <lsd.h>

extern int verbose_flag;

typedef struct source_t source_t;

typedef struct {
    Elf_Scn *scn;
    GElf_Shdr shdr;
    Elf_Data *data;
} section_info_t;

typedef struct next_export_t { 
    source_t *source;
    int next_idx;
} next_export_t;

struct source_t {
    source_t *next;
    int visited;

    char *name;  /* full path name of this executable file */
    /* ELF-related information: */
    Elf *elf;
    int elf_fd;
    GElf_Ehdr elf_hdr;
    size_t shstrndx;
    int shnum; /* number of sections */

    section_info_t symtab;
    section_info_t strtab;
    section_info_t dynamic;
    section_info_t hash;

    section_info_t *relocations;
    int num_relocations; /* number of relocs (<= relocations_size) */
    int relocations_size; /* sice of array -- NOT number of relocs! */

	/* satisfied_execs: array containing pointers to the libraries or 
	   executables that this executable satisfies symbol references for. */
	source_t **satisfied_execs;
    int num_satisfied_execs;
    int satisfied_execs_size;

    /* satisfied: array is parallel to symbol table; for each undefined symbol 
       in that array, we maintain a flag stating whether that symbol has been 
       satisfied, and if so, by which library.  This applies both to executable
       files and libraries.
    */
    source_t **satisfied;

    /* exports: array is parallel to symbol table; for each global symbol 
       in that array, we maintain a flag stating whether that symbol satisfies 
       a dependency in some other file.  num_syms is the length of the exports
       array, as well as the satisfied array. This applied to libraries only.

       next_exports:  this is a bit tricky.  We use this field to maintain a 
       linked list of source_t for each global symbol of a shared library. 
       For a shared library's global symbol at index N has the property that
       exports[N] is the head of a linked list (threaded through next_export)
       of all source_t that this symbol resolves a reference to.  For example, 
       if symbol printf has index 1000 in libc.so, and an executable A and 
       library L use printf, then the source_t entry corresponding to libc.so
       will have exports[1000] be a linked list that contains the nodes for 
       application A and library L.
    */

    next_export_t *exports;
    /* num_exported is the number of symbols in this file actually used by
       somebody else;  it's not the size of the exports array. */
    int num_exported;
    next_export_t *next_export;
    int num_next_export;
    int next_export_size;

    int num_syms; /* number of symbols in symbol table.  This is the length of
                     both exports[] and satisfied[] arrays. */

    /* This is an array that contains one element for each library dependency
       listed in the executable or shared library. */
    source_t **lib_deps; /* list of library dependencies */
    int num_lib_deps; /* actual number of library dependencies */
    int lib_deps_size; /* size of lib_deps array--NOT actual number of deps! */

};

static source_t *sources = NULL;

static char * find_file(const char *libname, 
                        char **lib_lookup_dirs, 
                        int num_lib_lookup_dirs);

static inline source_t* find_source(const char *name,
                                    char **lib_lookup_dirs, 
                                    int num_lib_lookup_dirs) {
    source_t *trav = sources;
	char *full = find_file(name, lib_lookup_dirs, num_lib_lookup_dirs);
    FAILIF(full == NULL, "Cannot construct full path for file [%s]!\n", name);
    while (trav) {
        if (!strcmp(trav->name, full))
            break;
        trav = trav->next;
    }
	free(full);
    return trav;
}

static inline void add_to_sources(source_t *src) {
    src->next = sources;
    sources = src;
}

static source_t* init_source(char *full_path) {
    source_t *source = (source_t *)CALLOC(1, sizeof(source_t));

    ASSERT(full_path);
    source->name = full_path;
    source->elf_fd = -1;

    INFO("Opening %s...\n", full_path);
    source->elf_fd = open(full_path, O_RDONLY);
    FAILIF(source->elf_fd < 0, "open(%s): %s (%d)\n", 
           full_path, 
           strerror(errno), 
           errno);
    INFO("Calling elf_begin(%s)...\n", full_path);
    source->elf = elf_begin(source->elf_fd, ELF_C_READ, NULL);
    FAILIF_LIBELF(source->elf == NULL, elf_begin);

    /* libelf can recognize COFF and A.OUT formats, but we handle only ELF. */
    if (elf_kind(source->elf) != ELF_K_ELF) {
        ERROR("Input file %s is not in ELF format!\n", full_path);
        return NULL;
    }

    /* Make sure this is a shared library or an executable. */
    {
        INFO("Making sure %s is a shared library or an executable...\n", 
             full_path);
        FAILIF_LIBELF(0 == gelf_getehdr(source->elf, &source->elf_hdr), gelf_getehdr);
        FAILIF(source->elf_hdr.e_type != ET_DYN && 
               source->elf_hdr.e_type != ET_EXEC,
               "%s must be a shared library (elf type is %d, expecting %d).\n", 
               full_path,
               source->elf_hdr.e_type, 
               ET_DYN);
    }

    /* Get the index of the section-header-strings-table section. */
    FAILIF_LIBELF(elf_getshstrndx (source->elf, &source->shstrndx) < 0, 
                  elf_getshstrndx);

    FAILIF_LIBELF(elf_getshnum (source->elf, &source->shnum) < 0, elf_getshnum);

    /* Find various sections. */
    size_t scnidx;
    Elf_Scn *scn;
    GElf_Shdr *shdr, shdr_mem;
    INFO("Locating %d sections in %s...\n", source->shnum, full_path);
    for (scnidx = 1; scnidx < source->shnum; scnidx++) {
        scn = elf_getscn(source->elf, scnidx);
        FAILIF_LIBELF(NULL == scn, elf_getscn);
        shdr = gelf_getshdr(scn, &shdr_mem);
        FAILIF_LIBELF(NULL == shdr, gelf_getshdr);
        INFO("\tfound section [%s]...\n", elf_strptr(source->elf, source->shstrndx, shdr->sh_name));
        if (shdr->sh_type == SHT_DYNSYM) {
            source->symtab.scn = scn;
            source->symtab.data = elf_getdata(scn, NULL);
            FAILIF_LIBELF(NULL == source->symtab.data, elf_getdata);
            memcpy(&source->symtab.shdr, shdr, sizeof(GElf_Shdr));

            /* The sh_link field of the section header of the symbol table
               contains the index of the associated strings table. */
            source->strtab.scn = elf_getscn(source->elf, 
                                            source->symtab.shdr.sh_link);
            FAILIF_LIBELF(NULL == source->strtab.scn, elf_getscn);
            FAILIF_LIBELF(NULL == gelf_getshdr(scn, &source->strtab.shdr),
                          gelf_getshdr);
            source->strtab.data = elf_getdata(source->strtab.scn, NULL);
            FAILIF_LIBELF(NULL == source->strtab.data, elf_getdata);
        }
        else if (shdr->sh_type == SHT_DYNAMIC) {
            source->dynamic.scn = scn;
            source->dynamic.data = elf_getdata(scn, NULL);
            FAILIF_LIBELF(NULL == source->symtab.data, elf_getdata);
            memcpy(&source->dynamic.shdr, shdr, sizeof(GElf_Shdr));
        }
        else if (shdr->sh_type == SHT_HASH) {
            source->hash.scn = scn;
            source->hash.data = elf_getdata(scn, NULL);
            FAILIF_LIBELF(NULL == source->hash.data, elf_getdata);
            memcpy(&source->hash.shdr, shdr, sizeof(GElf_Shdr));
        }
        else if (shdr->sh_type == SHT_REL || shdr->sh_type == SHT_RELA) {
            if (source->num_relocations == source->relocations_size) {
                source->relocations_size += 5;
                source->relocations = 
                    (section_info_t *)REALLOC(source->relocations,
                                              source->relocations_size *
                                              sizeof(section_info_t));
            }
            section_info_t *reloc = 
                source->relocations + source->num_relocations;
            reloc->scn = scn;
            reloc->data = elf_getdata(scn, NULL);
            FAILIF_LIBELF(NULL == reloc->data, elf_getdata);
            memcpy(&reloc->shdr, shdr, sizeof(GElf_Shdr));
            source->num_relocations++;
        }
    }

    if (source->dynamic.scn == NULL) {
        INFO("File [%s] does not have a dynamic section!\n", full_path);
        return 0;
    }

    FAILIF(source->symtab.scn == NULL, 
           "File [%s] does not have a dynamic symbol table!\n",
           full_path);

    FAILIF(source->hash.scn == NULL, 
           "File [%s] does not have a hash table!\n",
           full_path);
    FAILIF(source->hash.shdr.sh_link != elf_ndxscn(source->symtab.scn),
           "Hash points to section %d, not to %d as expected!\n",
           source->hash.shdr.sh_link,
           elf_ndxscn(scn));

    /* Now, find out how many symbols we have and allocate the array of 
       satisfied symbols.

       NOTE: We don't count the number of undefined symbols here; we will 
       iterate over the symbol table later, and count them then, when it is 
       more convenient. 
    */
    size_t symsize = gelf_fsize (source->elf, 
                                 ELF_T_SYM, 
                                 1, source->elf_hdr.e_version);
    ASSERT(symsize);

    source->num_syms = source->symtab.data->d_size / symsize;
    source->satisfied = (source_t **)CALLOC(source->num_syms, 
                                            sizeof(source_t *));
    source->exports = (source_t **)CALLOC(source->num_syms, 
                                          sizeof(next_export_t));

    source->num_exported = 0;
    source->satisfied_execs = NULL;
    source->num_satisfied_execs = 0;
    source->satisfied_execs_size = 0;

    add_to_sources(source);
    return source;
}

static void destroy_source(source_t *source) {
    FREE(source->satisfied_execs);
    FREE(source->satisfied);
    FREE(source->exports);
    FREE(source->next_export);    
    FREE(source->lib_deps); /* list of library dependencies */
    FAILIF_LIBELF(elf_end(source->elf), elf_end);
    FAILIF(close(source->elf_fd) < 0, "Could not close file %s: %s (%d)!\n", 
           source->name, strerror(errno), errno);
    FREE(source->name);
    FREE(source);
}

static void print_needed_libs(source_t *source)
{
	size_t idx;
	for (idx = 0; idx < source->num_lib_deps; idx++) {
		PRINT("%s:%s\n", 
			  source->name, 
			  source->lib_deps[idx]->name);
	}
}

static int is_symbol_imported(source_t *source,
                              GElf_Sym *sym, 
                              size_t symidx)
{
    const char *symname = elf_strptr(source->elf,
                                     elf_ndxscn(source->strtab.scn),
                                     sym->st_name);

    /* A symbol is imported by an executable or a library if it is undefined
       and is either global or weak. There is an additional case for 
       executables that we will check below. */
    if (sym->st_shndx == SHN_UNDEF &&
        (GELF_ST_BIND(sym->st_info) == STB_GLOBAL ||
         GELF_ST_BIND(sym->st_info) == STB_WEAK)) {
        INFO("*** symbol [%s:%s] is imported (UNDEFIEND).\n",
             source->name,
             symname);
        return 1;
    }

#ifdef ARM_SPECIFIC_HACKS
    /* A symbol is imported by an executable if is marked as an undefined 
       symbol--this is standard to all ELF formats.  Alternatively, according 
       to the ARM specifications, a symbol in a BSS section that is also marked
       by an R_ARM_COPY relocation is also imported. */

    if (source->elf_hdr.e_type != ET_EXEC) {
        INFO("is_symbol_imported(): [%s] is a library, "
             "no further checks.\n", source->name);
        return 0;
    }

    /* Is the symbol in the BSS section, and is there a COPY relocation on 
       that symbol? */
    INFO("*** [%s:%s] checking further to see if symbol is imported.\n",
         source->name, symname);
    if (sym->st_shndx < source->shnum) {
        /* Is it the .bss section? */
        Elf_Scn *scn = elf_getscn(source->elf, sym->st_shndx);
        FAILIF_LIBELF(NULL == scn, elf_getscn);
        GElf_Shdr *shdr, shdr_mem;
        shdr = gelf_getshdr(scn, &shdr_mem);
        FAILIF_LIBELF(NULL == shdr, gelf_getshdr);
        if (!strcmp(".bss", elf_strptr(source->elf,
                                       source->shstrndx,
                                       shdr->sh_name)))
        {
            /* Is there an R_ARM_COPY relocation on this symbol?  Iterate 
               over the list of relocation sections and scan each section for
               an entry that matches the symbol. */
            size_t idx;
            for (idx = 0; idx < source->num_relocations; idx++) {
                section_info_t *reloc = source->relocations + idx;
                /* Does the relocation section refer to the symbol table in
                   which this symbol resides, and does it relocate the .bss
                   section? */
                if (reloc->shdr.sh_link == elf_ndxscn(source->symtab.scn) &&
                    reloc->shdr.sh_info == sym->st_shndx)
                {
                    /* Go over the relocations and see if any of them matches
                       our symbol. */
                    size_t nrels = reloc->shdr.sh_size / reloc->shdr.sh_entsize;
                    size_t relidx, newidx;
                    if (reloc->shdr.sh_type == SHT_REL) {
                        for (newidx = relidx = 0; relidx < nrels; ++relidx) {
                            GElf_Rel rel_mem;
                            FAILIF_LIBELF(gelf_getrel (reloc->data, 
                                                       relidx, 
                                                       &rel_mem) == NULL,
                                          gelf_getrel);
                            if (GELF_R_TYPE(rel_mem.r_info) == R_ARM_COPY &&
                                GELF_R_SYM (rel_mem.r_info) == symidx)
                            {
                                INFO("*** symbol [%s:%s] is imported "
                                     "(DEFINED, REL-COPY-RELOCATED).\n",
                                     source->name,
                                     symname);
                                return 1;
                            }
                        } /* for each rel entry... */
                    } else {
                        for (newidx = relidx = 0; relidx < nrels; ++relidx) {
                            GElf_Rela rel_mem;
                            FAILIF_LIBELF(gelf_getrela (reloc->data, 
                                                        relidx, 
                                                        &rel_mem) == NULL,
                                          gelf_getrela);
                            if (GELF_R_TYPE(rel_mem.r_info) == R_ARM_COPY &&
                                GELF_R_SYM (rel_mem.r_info) == symidx)
                            {
                                INFO("*** symbol [%s:%s] is imported "
                                     "(DEFINED, RELA-COPY-RELOCATED).\n",
                                     source->name,
                                     symname);
                                return 1;
                            }
                        } /* for each rela entry... */
                    } /* if rel else rela */
                }
            }
        }
    }
#endif/*ARM_SPECIFIC_HACKS*/

    return 0;
}

static void resolve(source_t *source) {
    /* Iterate the symbol table.  For each undefined symbol, scan the 
       list of dependencies till we find a global symbol in one of them that 
       satisfies the undefined reference.  At this point, we update both the 
       satisfied[] array of the sources entry, as well as the exports array of 
       the dependency where we found the match.
    */

    GElf_Sym *sym, sym_mem;
    size_t symidx;
    for (symidx = 0; symidx < source->num_syms; symidx++) {
        sym = gelf_getsymshndx(source->symtab.data, 
                               NULL,
                               symidx,
                               &sym_mem,
                               NULL);
        FAILIF_LIBELF(NULL == sym, gelf_getsymshndx);
        if (is_symbol_imported(source, sym, symidx)) 
		{
            /* This is an undefined symbol.  Go over the list of libraries 
               and look it up. */
            size_t libidx;
			int found = 0;
			source_t *last_found = NULL;
			const char *symname = elf_strptr(source->elf,
											 elf_ndxscn(source->strtab.scn),
											 sym->st_name);
            for (libidx = 0; libidx < source->num_lib_deps; libidx++) {
                source_t *lib = source->lib_deps[libidx];
                int lib_symidx = hash_lookup(lib->elf,
                                             lib->hash.data,
                                             lib->symtab.data,
                                             lib->strtab.data,
                                             symname);
                if (STN_UNDEF != lib_symidx)
                {
					/* We found the symbol--now check to see if it is global 
					   or weak.  If this is the case, then the symbol satisfies
					   the dependency. */
					GElf_Sym *lib_sym, lib_sym_mem;
					lib_sym = gelf_getsymshndx(lib->symtab.data, 
											   NULL,
											   lib_symidx,
											   &lib_sym_mem,
											   NULL);
					FAILIF_LIBELF(NULL == lib_sym, gelf_getsymshndx);

					if(lib_sym->st_shndx != STN_UNDEF &&
					   (GELF_ST_BIND(lib_sym->st_info) == STB_GLOBAL ||
						GELF_ST_BIND(lib_sym->st_info) == STB_WEAK))
					{
						/* We found the symbol! Update the satisfied array at this
						   index location. */
						source->satisfied[symidx] = lib;
						/* Now, link this structure into the linked list 
						   corresponding to the found symbol in the library's 
						   global array. */
                        if (source->num_next_export == source->next_export_size) {
                            source->next_export_size += 30;
                            source->next_export = 
                                (source_t **)REALLOC(source->next_export,
                                                     source->next_export_size *
                                                     sizeof(struct next_export_t));
                        }
                        source->next_export[source->num_next_export] = lib->exports[lib_symidx];
                        lib->exports[lib_symidx].source = source;
                        lib->exports[lib_symidx].next_idx = source->num_next_export;

                        source->num_next_export++;
                        lib->num_exported++;

                        INFO("[%s:%s (index %d)] satisfied by [%s] (index %d)\n",
							 source->name,
							 symname,
							 symidx,
							 lib->name,
							 lib_symidx);
						if (found) {
							if (found == 1) {
								found++;
								ERROR("ERROR: multiple definitions found for [%s:%s]!\n",
									  source->name, symname);
								ERROR("\tthis definition     [%s]\n", lib->name);
							}
							ERROR("\tprevious definition [%s]\n", last_found->name);
						}

						last_found = lib;
						if (!found) found = 1;
					}
                }
            }
			if(found == 0) {
				ERROR("ERROR: could not find match for %s:%s.\n", 
					  source->name, 
					  symname);
			}
        } /* if we found the symbol... */
    } /* for each symbol... */
} /* resolve() */

static void print_used_symbols(source_t *source) {

    int name_len = strlen(source->name);
    static const char ext[] = ".syms";
    char *filter = (char *)MALLOC(name_len + sizeof(ext));
    strcpy(filter, source->name);
    strcpy(filter + name_len, ext);

    FILE *fp = fopen(filter, "w+");
    FAILIF(NULL == fp, 
           "Can't open %s: %s (%d)\n", 
           filter, 
           strerror(errno), errno);
    
    /* Is anybody using the symbols defined in source? */

    if (source->num_exported > 0) {
        INFO("[%s] exports %d symbols to %d libraries and executables.\n",
             source->name,
             source->num_exported,
             source->num_satisfied_execs);
        size_t symidx;
        for (symidx = 0; symidx < source->num_syms; symidx++) {
            if (source->exports[symidx].source != NULL) {
                GElf_Sym *sym, sym_mem;
                sym = gelf_getsymshndx(source->symtab.data, 
                                       NULL,
                                       symidx,
                                       &sym_mem,
                                       NULL);
                FAILIF_LIBELF(NULL == sym, gelf_getsymshndx);
                fprintf(fp, "%s\n", elf_strptr(source->elf,
                                               elf_ndxscn(source->strtab.scn),
                                               sym->st_name));
            }
        }
    }
    else if (source->num_satisfied_execs > 0) {

        /*  Is the source listed as a depenency on anyone?  If so, then the source exports no symbols
            to anyone, but someone lists it as a dependency, which is unnecessary, so we print a warning.
         */

        ERROR("WARNING: [%s] is listed as a dependency in: ", source->name);
        int i;
        for (i = 0; i < source->num_satisfied_execs; i++) {
            ERROR(" [%s],", source->satisfied_execs[i]->name);
        }
        ERROR(" but none of its symbols are used!.\n");
    }
#if 0 /* This is not really an error--a library's symbols may not be used anyone as specified in the ELF file,
         but someone may still open a library via dlopen(). 
      */
    else {
        ERROR("WARNING: None of [%s]'s symbols are used by any library or executable!\n", source->name);
    }
#endif

	fclose(fp);
    FREE(filter);
}

static void print_symbol_references(source_t *source) {

    int name_len = strlen(source->name);
    static const char ext[] = ".info";
    char *filter = (char *)MALLOC(name_len + sizeof(ext));
    strcpy(filter, source->name);
    strcpy(filter + name_len, ext);

    FILE *fp = fopen(filter, "w+");
    FAILIF(NULL == fp, 
           "Can't open %s: %s (%d)\n", 
           filter, 
           strerror(errno), errno);

    if (source->num_exported > 0) {
        size_t symidx;
        for (symidx = 0; symidx < source->num_syms; symidx++) {
            if (source->exports[symidx].source != NULL) {
                const char *symname;
                GElf_Sym *sym, sym_mem;
                sym = gelf_getsymshndx(source->symtab.data, 
                                       NULL,
                                       symidx,
                                       &sym_mem,
                                       NULL);
                FAILIF_LIBELF(NULL == sym, gelf_getsymshndx);
                symname = elf_strptr(source->elf, 
                                     elf_ndxscn(source->strtab.scn),
                                     sym->st_name);
                fprintf(fp, "%s\n", symname);
                next_export_t *export = &source->exports[symidx];
                while (export->source != NULL) {
                    //fprintf(stderr, "%s:%s\n", symname, export->source->name);
                    fprintf(fp, "\t%s\n", export->source->name);
                    export = &export->source->next_export[export->next_idx];
                }
            }
        }
    }

	fclose(fp);
    FREE(filter);
}

static char * find_file(const char *libname, 
                        char **lib_lookup_dirs, 
                        int num_lib_lookup_dirs) {
    if (libname[0] == '/') {
        /* This is an absolute path name--just return it. */
        INFO("ABSOLUTE PATH: [%s].\n", libname);
        return strdup(libname);
    } else {
        /* First try the working directory. */
        int fd;
        if ((fd = open(libname, O_RDONLY)) > 0) {
            close(fd);
            INFO("FOUND IN CURRENT DIR: [%s].\n", libname);
            return strdup(libname);
        } else {
            /* Iterate over all library paths.  For each path, append the file
               name and see if there is a file at that place. If that fails, 
               bail out. */

            char *name;
            while (num_lib_lookup_dirs--) {
                size_t lib_len = strlen(*lib_lookup_dirs);
                /* one extra character for the slash, and another for the 
                   terminating NULL. */
                name = (char *)MALLOC(lib_len + strlen(libname) + 2);
                strcpy(name, *lib_lookup_dirs);
                name[lib_len] = '/';
                strcpy(name + lib_len + 1, libname);
                if ((fd = open(name, O_RDONLY)) > 0) {
                    close(fd);
                    INFO("FOUND: [%s] in [%s].\n", libname, name);
                    return name;
                }
                INFO("NOT FOUND: [%s] in [%s].\n", libname, name);
                free(name);
            }
        }
    }
    return NULL;
}

static source_t* process_library(const char *libname,
                                 char **lib_lookup_dirs, 
                                 int num_lib_lookup_dirs) {
    source_t *source = find_source(libname, lib_lookup_dirs, num_lib_lookup_dirs);
    if (NULL == source) {
        INFO("Processing [%s].\n", libname);
        char *full = find_file(libname, lib_lookup_dirs, num_lib_lookup_dirs);
        FAILIF(NULL == full, 
               "Could not find [%s] in the current directory or in any of "
               "the search paths!\n", libname);
        source = init_source(full);
        if (source) {
            GElf_Dyn *dyn, dyn_mem;
            size_t dynidx;
            size_t numdyn =
            source->dynamic.shdr.sh_size / 
            source->dynamic.shdr.sh_entsize;

            for (dynidx = 0; dynidx < numdyn; dynidx++) {
                dyn = gelf_getdyn (source->dynamic.data, 
                                   dynidx, 
                                   &dyn_mem);
                FAILIF_LIBELF(NULL == dyn, gelf_getdyn);
                if (dyn->d_tag == DT_NEEDED) {
                    /* Process the needed library recursively. */
                    const char *dep_lib =
                    elf_strptr (source->elf, 
                                source->dynamic.shdr.sh_link, 
                                dyn->d_un.d_val);
                    INFO("[%s] depends on [%s].\n", libname, dep_lib);
                    source_t *dep = process_library(dep_lib, 
                                                    lib_lookup_dirs,
                                                    num_lib_lookup_dirs);

                    /* Tell dep that source depends on it. */
                    if (dep->num_satisfied_execs == dep->satisfied_execs_size) {
                        dep->satisfied_execs_size += 10;
                        dep->satisfied_execs = 
                            REALLOC(dep->satisfied_execs,
                                    dep->satisfied_execs_size *
                                    sizeof(source_t *));
                    }
                    dep->satisfied_execs[dep->num_satisfied_execs++] = source;

                    /* Add the library to the dependency list. */
                    if (source->num_lib_deps == source->lib_deps_size) {
                        source->lib_deps_size += 10;
                        source->lib_deps = REALLOC(source->lib_deps, 
                                                   source->lib_deps_size *
                                                   sizeof(source_t *));
                    }
                    source->lib_deps[source->num_lib_deps++] = dep;
                }
            } /* for each dynamic entry... */
        }
    } else INFO("[%s] has been processed already.\n", libname);

    return source;
}

void lsd(char **execs, int num_execs,
		 int list_needed_libs,
		 int print_info,
         char **lib_lookup_dirs, int num_lib_lookup_dirs) {

    source_t *source; /* for general usage */
    int input_idx;

    for (input_idx = 0; input_idx < num_execs; input_idx++) {
        INFO("executable: [%s]\n", execs[input_idx]);
        /* Here process library is actually processing the top-level executable
           files. */
        process_library(execs[input_idx], lib_lookup_dirs, num_lib_lookup_dirs);
        /* if source is NULL, then the respective executable is static */
        /* Mark the source as an executable */
    } /* for each input executable... */

	if (list_needed_libs) {
		source = sources;
		while (source) {
			print_needed_libs(source);
			source = source->next;
		}
	}

    /* Now, for each entry in the sources array, iterate its symbol table.  For
       each undefined symbol, scan the list of dependencies till we find a 
       global symbol in one of them that satisfies the undefined reference.  
       At this point, we update both the satisfied[] array of the sources entry, 
       as well as the exports array of the dependency where we found the match.
    */

    source = sources;
    while (source) {
        resolve(source);
        source = source->next;
    }

    /* We are done!  Since the end result of our calculations is a set of 
       symbols for each library that other libraries or executables link 
       against, we iterate over the set of libraries one last time, and for
       each symbol that is marked as satisfying some dependence, we emit 
       a line with the symbol's name to a text file derived from the library's
       name by appending the suffix .syms to it. */

    source = sources;
    while (source) {
        /* If it's a library, print the results. */
        if (source->elf_hdr.e_type == ET_DYN) {
			print_used_symbols(source);
			if (print_info) 
				print_symbol_references(source);
		}
        source = source->next;
    }

	/* Free the resources--you can't do it in the loop above because function 
	   print_symbol_references() accesses nodes other than the one being 
	   iterated over.
	 */
	source = sources;
	while (source) {
		source_t *old = source;
		source = source->next;
		/* Destroy the evidence. */
		destroy_source(old);
	}
}

