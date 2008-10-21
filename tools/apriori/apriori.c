#include <stdio.h>
#include <common.h>
#include <debug.h>
#include <libelf.h>
#include <libebl.h>
#ifdef ARM_SPECIFIC_HACKS
    #include <libebl_arm.h>
#endif/*ARM_SPECIFIC_HACKS*/
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
#include <apriori.h>
#include <source.h>
#include <tweak.h>
#include <rangesort.h>
#include <prelink_info.h>
#include <prelinkmap.h>
#include <libgen.h>

#ifndef ADJUST_ELF
#error "ADJUST_ELF must be defined!"
#endif

/* When this macro is defined, apriori sets to ZERO those relocation values for
   which it canot find the appropriate referent.
*/
#define PERMISSIVE
#define COPY_SECTION_DATA_BUFFER (0)
/* When this macro is set to a nonzero value, we replace calls to elf_strptr()
   on the target ELF handle with code that extracts the strings directly from
   the data buffers of that ELF handle.  In this case, elf_strptr() does not
   work as expected, as it tries to read the data buffer of the associated
   string section directly from the file, and that buffer does not exist yet
   in the file, since we haven't committed our changes yet.
*/
#define ELF_STRPTR_IS_BROKEN     (1)

/* When the macro below is defined, apriori does not mark for removal those
   relocation sections that it fully handles.  Instead, apriori just sets their
   sizes to zero.  This is more for debugging than of any actual use.

   This macro is meaningful only when ADJUST_ELF!=0
*/
#define REMOVE_HANDLED_SECTIONS

extern int verbose_flag;

static source_t *sources = NULL;

#if defined(DEBUG) && 0

static void print_shdr(source_t *source, Elf_Scn *scn)
{
    GElf_Shdr shdr_mem, *shdr;
    shdr = gelf_getshdr(scn, &shdr_mem);
    Elf_Data *data = elf_getdata(scn, NULL);
    INFO("\t%02d: data = %p, hdr = { offset = %8lld, size = %lld }, "
         "data->d_buf = %p data->d_off = %lld, data->d_size = %d\n",
         elf_ndxscn(scn),
         data,
         shdr->sh_offset, shdr->sh_size,
         data->d_buf, data->d_off, data->d_size);
}

static void print_shdr_idx(source_t *source, Elf *elf, int idx)
{
    print_shdr(source, elf_getscn(elf, idx));
}

static void print_shdrs(source_t *source) {
  Elf_Scn *scn = NULL;
  INFO("section offset dump for new ELF\n");
  while ((scn = elf_nextscn (source->elf, scn)) != NULL)
    print_shdr(source, scn);

  INFO("\nsection offset dump for original ELF\n");
  while ((scn = elf_nextscn (source->oldelf, scn)) != NULL)
    print_shdr(source, scn);

#if 0
  {
    INFO("section offset dump for new ELF\n");
    int i = 0;
    for (i = 0; i < source->shnum; i++) {
      scn = elf_getscn(source->elf, i);
      print_shdr(source, scn);
    }
  }
#endif
}

#endif /* DEBUG */

static char * find_file(const char *libname,
                        char **lib_lookup_dirs,
                        int num_lib_lookup_dirs);

static inline source_t* find_source(const char *name,
                                    char **lib_lookup_dirs,
                                    int num_lib_lookup_dirs) {
    char *full = find_file(name, lib_lookup_dirs, num_lib_lookup_dirs);
    if (full) {
        source_t *trav = sources;
        while (trav) {
            if (!strcmp(trav->name, full))
                break;
            trav = trav->next;
        }
        free(full);
        return trav;
    }
    return NULL;
}

static inline void add_to_sources(source_t *src) {
    src->next = sources;
    sources = src;
}

static void handle_range_error(range_error_t err,
                               range_t *left, range_t *right) {
    switch (err) {
    case ERROR_CONTAINS:
        ERROR("ERROR: section (%lld, %lld bytes) contains "
              "section (%lld, %lld bytes)\n",
              left->start, left->length,
              right->start, right->length);
        break;
    case ERROR_OVERLAPS:
        ERROR("ERROR: Section (%lld, %lld bytes) intersects "
              "section (%lld, %lld bytes)\n",
              left->start, left->length,
              right->start, right->length);
        break;
    default:
        ASSERT(!"Unknown range error code!");
    }

    FAILIF(1, "Range error.\n");
}

static void create_elf_sections(source_t *source, Elf *elf)
{
    INFO("Creating new ELF sections.\n");
    ASSERT(elf == NULL || source->elf == NULL || source->elf == elf);
    if (elf == NULL) {
        ASSERT(source->elf != NULL);
        elf = source->elf;
    }

    int cnt = 1;
    Elf_Scn *oldscn = NULL, *scn;
    while ((oldscn = elf_nextscn (source->oldelf, oldscn)) != NULL) {
        GElf_Shdr *oldshdr, oldshdr_mem;

        scn = elf_newscn(elf);
        FAILIF_LIBELF(NULL == scn, elf_newscn);

        oldshdr = gelf_getshdr(oldscn, &oldshdr_mem);
        FAILIF_LIBELF(NULL == oldshdr, gelf_getshdr);
        /* Set the section header of the new section to be the same as the
           headset of the old section by default. */
        gelf_update_shdr(scn, oldshdr);

        /* Copy the section data */
        Elf_Data *olddata = elf_getdata(oldscn, NULL);
        FAILIF_LIBELF(NULL == olddata, elf_getdata);

        Elf_Data *data = elf_newdata(scn);
        FAILIF_LIBELF(NULL == data, elf_newdata);
        *data = *olddata;
#if COPY_SECTION_DATA_BUFFER
        if (olddata->d_buf != NULL) {
            data->d_buf = MALLOC(data->d_size);
            memcpy(data->d_buf, olddata->d_buf, olddata->d_size);
        }
#endif

        INFO("\tsection %02d: [%-30s] created\n",
             cnt,
             elf_strptr(source->oldelf,
                        source->shstrndx,
                        oldshdr->sh_name));

        if (ADJUST_ELF) {
            ASSERT(source->shdr_info != NULL);
            /* Create a new section. */
            source->shdr_info[cnt].idx = cnt;
            source->shdr_info[cnt].newscn = scn;
            source->shdr_info[cnt].data = data;
            source->shdr_info[cnt].
                use_old_shdr_for_relocation_calculations = 1;
            INFO("\tsection [%s]  (old offset %lld, old size %lld) "
                 "will have index %d (was %d).\n",
                 source->shdr_info[cnt].name,
                 source->shdr_info[cnt].old_shdr.sh_offset,
                 source->shdr_info[cnt].old_shdr.sh_size,
                 source->shdr_info[cnt].idx,
                 elf_ndxscn(source->shdr_info[cnt].scn));
            /* Same as the next assert */
            ASSERT(elf_ndxscn (source->shdr_info[cnt].newscn) ==
                   source->shdr_info[cnt].idx);
        }

        ASSERT(elf_ndxscn(scn) == (size_t)cnt);
        cnt++;
    }
}

/* This function sets up the shdr_info[] array of a source_t.  We call it only
   when ADJUST_ELF is non-zero (i.e., support for adjusting an ELF file for
   changes in sizes and numbers of relocation sections is compiled in.  Note
   that setup_shdr_info() depends only on the information in source->oldelf,
   not on source->elf.
*/

static void setup_shdr_info(source_t *source)
{
    if (ADJUST_ELF)
    {
        /* Allocate the section-header-info buffer. */
        INFO("Allocating section-header info structure (%d) bytes...\n",
             source->shnum * sizeof (shdr_info_t));

        source->shdr_info = (shdr_info_t *)CALLOC(source->shnum,
                                                  sizeof (shdr_info_t));

        /* Mark the SHT_NULL section as handled. */
        source->shdr_info[0].idx = 2;

        int cnt = 1;
        Elf_Scn *oldscn = NULL;
        while ((oldscn = elf_nextscn (source->oldelf, oldscn)) != NULL) {
            /* Copy the section header */
            ASSERT(elf_ndxscn(oldscn) == (size_t)cnt);

            /* Initialized the corresponding shdr_info entry */
            {
                /* Mark the section with a non-zero index.  Later, when we
                   decide to drop a section, we will set its idx to zero, and
                   assign section numbers to the remaining sections.
                */
                source->shdr_info[cnt].idx = 1;

                source->shdr_info[cnt].scn = oldscn;

                /* NOTE: Here we pupulate the section-headset struct with the
                         same values as the original section's.  After the
                         first run of prelink(), we will update the sh_size
                         fields of those sections that need resizing.
                */
                FAILIF_LIBELF(NULL == 
                              gelf_getshdr(oldscn,
                                           &source->shdr_info[cnt].shdr),
                              gelf_getshdr);
                
                /* Get the name of the section. */
                source->shdr_info[cnt].name =
                    elf_strptr (source->oldelf, source->shstrndx,
                                source->shdr_info[cnt].shdr.sh_name);

                INFO("\tname: %s\n", source->shdr_info[cnt].name);
                FAILIF(source->shdr_info[cnt].name == NULL,
                       "Malformed file: section %d name is null\n",
                       cnt);

                /* Remember the shdr.sh_link value.  We need to remember this
                   value for those sections that refer to other sections.  For
                   example, we need to remember it for relocation-entry
                   sections, because if we modify the symbol table that a
                   relocation-entry section is relative to, then we need to
                   patch the relocation section.  By the time we get to
                   deciding whether we need to patch the relocation section, we
                   will have overwritten its header's sh_link field with a new
                   value.
                */
                source->shdr_info[cnt].old_shdr = source->shdr_info[cnt].shdr;
                INFO("\t\toriginal sh_link: %08d\n",
                     source->shdr_info[cnt].old_shdr.sh_link);
                INFO("\t\toriginal sh_addr: %lld\n",
                     source->shdr_info[cnt].old_shdr.sh_addr);
                INFO("\t\toriginal sh_offset: %lld\n",
                     source->shdr_info[cnt].old_shdr.sh_offset);
                INFO("\t\toriginal sh_size: %lld\n",
                     source->shdr_info[cnt].old_shdr.sh_size);

                FAILIF(source->shdr_info[cnt].shdr.sh_type == SHT_SYMTAB_SHNDX,
                       "Cannot handle sh_type SHT_SYMTAB_SHNDX!\n");
                FAILIF(source->shdr_info[cnt].shdr.sh_type == SHT_GROUP,
                       "Cannot handle sh_type SHT_GROUP!\n");
                FAILIF(source->shdr_info[cnt].shdr.sh_type == SHT_GNU_versym,
                       "Cannot handle sh_type SHT_GNU_versym!\n");
            }

            cnt++;
        } /* for each section */
    } /* if (ADJUST_ELF) */
}

static Elf * init_elf(source_t *source, bool create_new_sections)
{
    Elf *elf;
    if (source->output != NULL) {
        if (source->output_is_dir) {
            source->output_is_dir++;
            char *dir = source->output;
            int dirlen = strlen(dir);
            /* The main() function maintains a pointer to source->output; it
               frees the buffer after apriori() returns.
            */
            source->output = MALLOC(dirlen +
                                    1 + /* slash */
                                    strlen(source->name) +
                                    1); /* null terminator */
            strcpy(source->output, dir);
            source->output[dirlen] = '/';
            strcpy(source->output + dirlen + 1,
                   basename(source->name));
        }

        source->newelf_fd = open(source->output,
                                 O_RDWR | O_CREAT,
                                 0666);
        FAILIF(source->newelf_fd < 0, "open(%s): %s (%d)\n",
               source->output,
               strerror(errno),
               errno);
        elf = elf_begin(source->newelf_fd, ELF_C_WRITE, NULL);
        FAILIF_LIBELF(elf == NULL, elf_begin);
    } else {
        elf = elf_clone(source->oldelf, ELF_C_EMPTY);
        FAILIF_LIBELF(elf == NULL, elf_clone);
    }

    GElf_Ehdr *oldehdr = gelf_getehdr(source->oldelf, &source->old_ehdr_mem);
    FAILIF_LIBELF(NULL == oldehdr, gelf_getehdr);

    /* Create new ELF and program headers for the elf file */
    INFO("Creating empty ELF and program headers...\n");
    FAILIF_LIBELF(gelf_newehdr (elf, gelf_getclass (source->oldelf)) == 0,
                  gelf_newehdr);
    FAILIF_LIBELF(oldehdr->e_type != ET_REL
                  && gelf_newphdr (elf,
                                   oldehdr->e_phnum) == 0,
                  gelf_newphdr);

    /* Copy the elf header */
    INFO("Copying ELF header...\n");
    GElf_Ehdr *ehdr = gelf_getehdr(elf, &source->ehdr_mem);
    FAILIF_LIBELF(NULL == ehdr, gelf_getehdr);
    memcpy(ehdr, oldehdr, sizeof(GElf_Ehdr));
    FAILIF_LIBELF(!gelf_update_ehdr(elf, ehdr), gelf_update_ehdr);

    /* Copy out the old program header: notice that if the ELF file does not
       have a program header, this loop won't execute.
    */
    INFO("Copying ELF program header...\n");
    {
        int cnt;
        source->phdr_info = (GElf_Phdr *)CALLOC(ehdr->e_phnum,
                                                sizeof(GElf_Phdr));
        for (cnt = 0; cnt < ehdr->e_phnum; ++cnt) {
            INFO("\tRetrieving entry %d\n", cnt);
            FAILIF_LIBELF(NULL ==
                          gelf_getphdr(source->oldelf, cnt,
                                       source->phdr_info + cnt),
                          gelf_getphdr);
            FAILIF_LIBELF(gelf_update_phdr (elf, cnt, 
                                            source->phdr_info + cnt) == 0,
                          gelf_update_phdr);
        }
    }

    /* Copy the sections and the section headers. */
    if (create_new_sections)
    {
        create_elf_sections(source, elf);
    }

    /* The ELF library better follows our layout when this is not a
       relocatable object file. */
    elf_flagelf (elf, ELF_C_SET, (ehdr->e_type != ET_REL ? ELF_F_LAYOUT : 0));

    return elf;
}

static shdr_info_t *lookup_shdr_info_by_new_section(
    source_t *source,
    const char *sname,
    Elf_Scn *newscn)
{
    if (source->shdr_info == NULL) return NULL;
    int cnt;
    for (cnt = 0; cnt < source->shnum; cnt++) {
        if (source->shdr_info[cnt].newscn == newscn) {
            INFO("\t\tnew section at %p matches shdr_info[%d], "
                 "section [%s]!\n",
                 newscn,
                 cnt,
                 source->shdr_info[cnt].name);
            FAILIF(strcmp(sname, source->shdr_info[cnt].name),
                   "Matched section's name [%s] does not match "
                   "looked-up section's name [%s]!\n",
                   source->shdr_info[cnt].name,
                   sname);
            return source->shdr_info + cnt;
        }
    }
    return NULL;
}

static bool do_init_source(source_t *source, unsigned base)
{
    /* Find various sections. */
    size_t scnidx;
    Elf_Scn *scn;
    GElf_Shdr *shdr, shdr_mem;
    source->sorted_sections = init_range_list();
    INFO("Processing [%s]'s sections...\n", source->name);
    for (scnidx = 1; scnidx < (size_t)source->shnum; scnidx++) {
        INFO("\tGetting section index %d...\n", scnidx);
        scn = elf_getscn(source->elf, scnidx);
        if (NULL == scn) {
            /* If we get an error from elf_getscn(), it means that a section
               at the requested index does not exist.  This may happen when
               we remove sections.  Since we do not update source->shnum
               (we can't, since we need to know the original number of sections
               to know source->shdr_info[]'s length), we will attempt to
               retrieve a section for an index that no longer exists in the
               new ELF file. */
            INFO("\tThere is no section at index %d anymore, continuing.\n",
                 scnidx);
            continue;
        }
        shdr = gelf_getshdr(scn, &shdr_mem);
        FAILIF_LIBELF(NULL == shdr, gelf_getshdr);

        /* We haven't modified the shstrtab section, and so shdr->sh_name
           has the same value as before.  Thus we look up the name based
           on the old ELF handle.  We cannot use shstrndx on the new ELF
           handle because the index of the shstrtab section may have
           changed (and calling elf_getshstrndx() returns the same section
           index, so libelf can't handle thise ither).
        */
        const char *sname =
          elf_strptr(source->oldelf, source->shstrndx, shdr->sh_name);
        ASSERT(sname);

        INFO("\tAdding [%s] (%lld, %lld)...\n",
             sname,
             shdr->sh_addr,
             shdr->sh_addr + shdr->sh_size);
        if ((shdr->sh_flags & SHF_ALLOC) == SHF_ALLOC) {
            add_unique_range_nosort(source->sorted_sections,
                                    shdr->sh_addr,
                                    shdr->sh_size,
                                    scn,
                                    handle_range_error,
                                    NULL); /* no user-data destructor */
        }

        if (shdr->sh_type == SHT_DYNSYM) {
            source->symtab.scn = scn;
            source->symtab.data = elf_getdata(scn, NULL);
            FAILIF_LIBELF(NULL == source->symtab.data, elf_getdata);
            memcpy(&source->symtab.shdr, shdr, sizeof(GElf_Shdr));
            source->symtab.info = lookup_shdr_info_by_new_section(
                source, sname, scn);
            ASSERT(source->shdr_info == NULL || source->symtab.info != NULL);

            /* The sh_link field of the section header of the symbol table
               contains the index of the associated strings table. */
            source->strtab.scn = elf_getscn(source->elf,
                                            source->symtab.shdr.sh_link);
            FAILIF_LIBELF(NULL == source->strtab.scn, elf_getscn);
            FAILIF_LIBELF(NULL == gelf_getshdr(source->strtab.scn,
                                               &source->strtab.shdr),
                          gelf_getshdr);
            source->strtab.data = elf_getdata(source->strtab.scn, NULL);
            FAILIF_LIBELF(NULL == source->strtab.data, elf_getdata);
            source->strtab.info = lookup_shdr_info_by_new_section(
                source,
                elf_strptr(source->oldelf, source->shstrndx,
                           source->strtab.shdr.sh_name),
                source->strtab.scn);
            ASSERT(source->shdr_info == NULL || source->strtab.info != NULL);
        } else if (shdr->sh_type == SHT_DYNAMIC) {
            source->dynamic.scn = scn;
            source->dynamic.data = elf_getdata(scn, NULL);
            FAILIF_LIBELF(NULL == source->dynamic.data, elf_getdata);
            memcpy(&source->dynamic.shdr, shdr, sizeof(GElf_Shdr));
            source->dynamic.info = lookup_shdr_info_by_new_section(
                source, sname, scn);
            ASSERT(source->shdr_info == NULL || source->dynamic.info != NULL);
        } else if (shdr->sh_type == SHT_HASH) {
            source->hash.scn = scn;
            source->hash.data = elf_getdata(scn, NULL);
            FAILIF_LIBELF(NULL == source->hash.data, elf_getdata);
            memcpy(&source->hash.shdr, shdr, sizeof(GElf_Shdr));
            source->hash.info = lookup_shdr_info_by_new_section(
                source, sname, scn);
            ASSERT(source->shdr_info == NULL || source->hash.info != NULL);
        } else if (shdr->sh_type == SHT_REL || shdr->sh_type == SHT_RELA) {
            if (source->num_relocation_sections ==
                    source->relocation_sections_size) {
                source->relocation_sections_size += 5;
                source->relocation_sections =
                (section_info_t *)REALLOC(source->relocation_sections,
                                          source->relocation_sections_size *
                                          sizeof(section_info_t));
            }
            section_info_t *reloc =
            source->relocation_sections + source->num_relocation_sections;
            reloc->scn = scn;
            reloc->info = lookup_shdr_info_by_new_section(source, sname, scn);
            ASSERT(source->shdr_info == NULL || reloc->info != NULL);
            reloc->data = elf_getdata(scn, NULL);
            FAILIF_LIBELF(NULL == reloc->data, elf_getdata);
            memcpy(&reloc->shdr, shdr, sizeof(GElf_Shdr));
            source->num_relocation_sections++;
        } else if (!strcmp(sname, ".bss")) {
            source->bss.scn = scn;
            source->bss.data = elf_getdata(scn, NULL);
            source->bss.info = lookup_shdr_info_by_new_section(
                source, sname, scn);
            ASSERT(source->shdr_info == NULL || source->bss.info != NULL);
            /* The BSS section occupies no space in the ELF file. */
            FAILIF_LIBELF(NULL == source->bss.data, elf_getdata)
            FAILIF(NULL != source->bss.data->d_buf,
                   "Enexpected: section [%s] has data!",
                   sname);
            memcpy(&source->bss.shdr, shdr, sizeof(GElf_Shdr));
        }
    }
    sort_ranges(source->sorted_sections);

    source->unfinished =
        (unfinished_relocation_t *)CALLOC(source->num_relocation_sections,
                                          sizeof(unfinished_relocation_t));

    if (source->dynamic.scn == NULL) {
        INFO("File [%s] does not have a dynamic section!\n", source->name);
        /* If this is a static executable, we won't update anything. */
        source->dry_run = 1;
        return false;
    }

    FAILIF(source->symtab.scn == NULL,
           "File [%s] does not have a dynamic symbol table!\n",
           source->name);
    FAILIF(source->hash.scn == NULL,
           "File [%s] does not have a hash table!\n",
           source->name);
    FAILIF(source->hash.shdr.sh_link != elf_ndxscn(source->symtab.scn),
           "Hash points to section %d, not to %d as expected!\n",
           source->hash.shdr.sh_link,
           elf_ndxscn(source->symtab.scn));

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
    source->base = (source->oldelf_hdr.e_type == ET_DYN) ? base : 0;
    INFO("Relink base for [%s]: 0x%lx\n", source->name, source->base);
    FAILIF(source->base == -1,
           "Can't prelink [%s]: it's a shared library and you did not "
           "provide a prelink address!\n",
           source->name);
#ifdef SUPPORT_ANDROID_PRELINK_TAGS
    FAILIF(source->prelinked && source->base != source->prelink_base,
           "ERROR: file [%s] has already been prelinked for 0x%08lx.  "
           "Cannot change to 0x%08lx!\n",
           source->name,
           source->prelink_base,
           source->base);
#endif/*SUPPORT_ANDROID_PRELINK_TAGS*/

    return true;
}

static source_t* init_source(const char *full_path,
                             const char *output, int is_file,
                             int base, int dry_run)
{
    source_t *source = (source_t *)CALLOC(1, sizeof(source_t));

    ASSERT(full_path);
    source->name = full_path;
    source->output = output;
    source->output_is_dir = !is_file;

    source->newelf_fd = -1;
    source->elf_fd = -1;
    INFO("Opening %s...\n", full_path);
    source->elf_fd =
        open(full_path, ((dry_run || output != NULL) ? O_RDONLY : O_RDWR));
    FAILIF(source->elf_fd < 0, "open(%s): %s (%d)\n",
           full_path,
           strerror(errno),
           errno);

	FAILIF(fstat(source->elf_fd, &source->elf_file_info) < 0,
		   "fstat(%s(fd %d)): %s (%d)\n",
		   source->name,
		   source->elf_fd,
		   strerror(errno),
		   errno);
	INFO("File [%s]'s size is %lld bytes!\n",
		 source->name,
		 source->elf_file_info.st_size);

    INFO("Calling elf_begin(%s)...\n", full_path);

    source->oldelf =
        elf_begin(source->elf_fd,
                  (dry_run || output != NULL) ? ELF_C_READ : ELF_C_RDWR,
                  NULL);
    FAILIF_LIBELF(source->oldelf == NULL, elf_begin);

    /* libelf can recognize COFF and A.OUT formats, but we handle only ELF. */
    if(elf_kind(source->oldelf) != ELF_K_ELF) {
        ERROR("Input file %s is not in ELF format!\n", full_path);
        return NULL;
    }

    /* Make sure this is a shared library or an executable. */
    {
        INFO("Making sure %s is a shared library or an executable...\n",
             full_path);
        FAILIF_LIBELF(0 == gelf_getehdr(source->oldelf, &source->oldelf_hdr),
                      gelf_getehdr);
        FAILIF(source->oldelf_hdr.e_type != ET_DYN &&
               source->oldelf_hdr.e_type != ET_EXEC,
               "%s must be a shared library (elf type is %d, expecting %d).\n",
               full_path,
               source->oldelf_hdr.e_type,
               ET_DYN);
    }

#ifdef SUPPORT_ANDROID_PRELINK_TAGS
    /* First, check to see if the file has been prelinked. */
    source->prelinked =
        check_prelinked(source->name,
                        source->oldelf_hdr.e_ident[EI_DATA] == ELFDATA2LSB,
                        &source->prelink_base);
    /* Note that in the INFO() below we need to use oldelf_hdr because we
       haven't cloned the ELF file yet, and source->elf_hdr is not defined. */
    if (source->prelinked) {
        PRINT("%s [%s] is already prelinked at 0x%08lx!\n",
              (source->oldelf_hdr.e_type == ET_EXEC ?
               "Executable" : "Shared library"),
              source->name,
              source->prelink_base);
        /* Force a dry run when the file has already been prelinked */
        source->dry_run = dry_run = 1;
    }
    else {
        INFO("%s [%s] is not prelinked!\n",
             (source->oldelf_hdr.e_type == ET_EXEC ?
              "Executable" : "Shared library"),
             source->name);
        source->dry_run = dry_run;
    }
#endif/*SUPPORT_ANDROID_PRELINK_TAGS*/

    /* Get the index of the section-header-strings-table section. */
    FAILIF_LIBELF(elf_getshstrndx (source->oldelf, &source->shstrndx) < 0,
                  elf_getshstrndx);

    FAILIF_LIBELF(elf_getshnum (source->oldelf, (size_t *)&source->shnum) < 0,
                  elf_getshnum);

    /* When we have a dry run, or when ADJUST_ELF is enabled, we use
       source->oldelf for source->elf, because the former is mmapped privately,
       so changes to it have no effect.  With ADJUST_ELF, the first run of
       prelink() is a dry run.  We will reopen the elf file for write access
       after that dry run, before we call adjust_elf. */

    source->elf = (ADJUST_ELF || source->dry_run) ?
        source->oldelf : init_elf(source, ADJUST_ELF == 0);

    FAILIF_LIBELF(0 == gelf_getehdr(source->elf, &source->elf_hdr),
                  gelf_getehdr);
#ifdef DEBUG
    ASSERT(!memcmp(&source->oldelf_hdr,
                   &source->elf_hdr,
                   sizeof(source->elf_hdr)));
#endif

    /* Get the EBL handling.  The -g option is currently the only reason
       we need EBL so dont open the backend unless necessary.  */
    source->ebl = ebl_openbackend (source->elf);
    FAILIF_LIBELF(NULL == source->ebl, ebl_openbackend);
#ifdef ARM_SPECIFIC_HACKS
    FAILIF_LIBELF(0 != arm_init(source->elf, source->elf_hdr.e_machine,
                                source->ebl, sizeof(Ebl)),
                  arm_init);
#endif/*ARM_SPECIFIC_HACKS*/

    add_to_sources(source);
    if (do_init_source(source, base) == false) return NULL;
    return source;
}

/* complements do_init_source() */
static void do_destroy_source(source_t *source)
{
    int cnt;
    destroy_range_list(source->sorted_sections);
    source->sorted_sections = NULL;
    for (cnt = 0; cnt < source->num_relocation_sections; cnt++) {
        FREEIF(source->unfinished[cnt].rels);
        source->unfinished[cnt].rels = NULL;
        source->unfinished[cnt].num_rels = 0;
        source->unfinished[cnt].rels_size = 0;
    }
    if (source->jmprel.sections != NULL) {
        destroy_range_list(source->jmprel.sections);
        source->jmprel.sections = NULL;
    }
    if (source->rel.sections != NULL) {
        destroy_range_list(source->rel.sections);
        source->rel.sections = NULL;
    }
    FREE(source->unfinished); /* do_init_source() */
    source->unfinished = NULL;
    FREE(source->relocation_sections); /* do_init_source() */
    source->relocation_sections = NULL;
    source->num_relocation_sections = source->relocation_sections_size = 0;
}

static void destroy_source(source_t *source)
{
    /* Is this a little-endian ELF file? */
    if (source->oldelf != source->elf) {
        /* If it's a dynamic executable, this must not be a dry run. */
        if (!source->dry_run && source->dynamic.scn != NULL)
        {
            FAILIF_LIBELF(elf_update(source->elf, ELF_C_WRITE) == -1,
                          elf_update);
        }
        FAILIF_LIBELF(elf_end(source->oldelf), elf_end);
    }
    ebl_closebackend(source->ebl);
    FAILIF_LIBELF(elf_end(source->elf), elf_end);
    FAILIF(close(source->elf_fd) < 0, "Could not close file %s: %s (%d)!\n",
           source->name, strerror(errno), errno);
    FAILIF((source->newelf_fd >= 0) && (close(source->newelf_fd) < 0),
           "Could not close output file: %s (%d)!\n", strerror(errno), errno);

#ifdef SUPPORT_ANDROID_PRELINK_TAGS
    if (!source->dry_run) {
        if (source->dynamic.scn != NULL &&
            source->elf_hdr.e_type != ET_EXEC)
        {
            /* For some reason, trying to write directly to source->elf_fd
               causes a "bad file descriptor" error because of something libelf
               does.  We just close the file descriptor and open a new one in
               function setup_prelink_info() below. */
            INFO("%s: setting up prelink tag at end of file.\n",
                 source->output ? source->output : source->name);
            setup_prelink_info(source->output ? source->output : source->name,
                               source->elf_hdr.e_ident[EI_DATA] == ELFDATA2LSB,
                               source->base);
        }
        else INFO("%s: executable, NOT setting up prelink tag.\n",
                  source->name);
    }
#endif/*SUPPORT_ANDROID_PRELINK_TAGS*/

    do_destroy_source(source);

    if (source->shstrtab_data != NULL)
        FREEIF(source->shstrtab_data->d_buf); /* adjust_elf */

    FREE(source->lib_deps); /* list of library dependencies (process_file()) */
    FREEIF(source->shdr_info); /* setup_shdr_info() */
    FREEIF(source->phdr_info); /* init_elf() */
    FREE(source->name); /* assigned to by init_source() */
    /* If the output is a directory, in init_elf() we allocate a buffer where
       we copy the directory, a slash, and the file name.  Here we free that
       buffer.
    */
    if (source->output_is_dir > 1) {
        FREE(source->output);
    }
    FREE(source); /* init_source() */
}

static void reinit_source(source_t *source)
{
    do_destroy_source(source);
    do_init_source(source, source->base);

    {
        /* We've gathered all the DT_DYNAMIC entries; now we need to figure
           out which relocation sections fit in which range as described by
           the entries.  Before we do so, however, we will populate the
           jmprel and rel members of source, as well as their sizes.
        */

        size_t dynidx, numdyn;
        GElf_Dyn *dyn, dyn_mem;

        numdyn = source->dynamic.shdr.sh_size /
            source->dynamic.shdr.sh_entsize;

        source->rel.idx = source->rel.sz_idx = -1;
        source->jmprel.idx = source->jmprel.sz_idx = -1;
        for (dynidx = 0; dynidx < numdyn; dynidx++) {
            dyn = gelf_getdyn (source->dynamic.data,
                               dynidx,
                               &dyn_mem);
            FAILIF_LIBELF(NULL == dyn, gelf_getdyn);
            switch (dyn->d_tag)
            {
            case DT_NEEDED:
                break;
            case DT_JMPREL:
                INFO("reinit_source: DT_JMPREL is at index %d, 0x%08llx.\n",
                     dynidx, dyn->d_un.d_ptr);
                source->jmprel.idx = dynidx;
                source->jmprel.addr = dyn->d_un.d_ptr;
                break;
            case DT_PLTRELSZ:
                INFO("reinit_source: DT_PLTRELSZ is at index %d, 0x%08llx.\n",
                     dynidx, dyn->d_un.d_val);
                source->jmprel.sz_idx = dynidx;
                source->jmprel.size = dyn->d_un.d_val;
                break;
            case DT_REL:
                INFO("reinit_source: DT_REL is at index %d, 0x%08llx.\n",
                     dynidx, dyn->d_un.d_ptr);
                source->rel.idx = dynidx;
                source->rel.addr = dyn->d_un.d_ptr;
                break;
            case DT_RELSZ:
                INFO("reinit_source: DT_RELSZ is at index %d, 0x%08llx.\n",
                     dynidx, dyn->d_un.d_val);
                source->rel.sz_idx = dynidx;
                source->rel.size = dyn->d_un.d_val;
                break;
            case DT_RELA:
            case DT_RELASZ:
                FAILIF(1, "Can't handle DT_RELA and DT_RELASZ entries!\n");
                break;
            } /* switch */
        } /* for each dynamic entry... */
    }
}

static GElf_Sym *hash_lookup_global_or_weak_symbol(source_t *lib,
                                                   const char *symname,
                                                   GElf_Sym *lib_sym_mem)
{
    int lib_symidx = hash_lookup(lib->elf,
                                 lib->hash.data,
                                 lib->symtab.data,
                                 lib->strtab.data,
                                 symname);

    GElf_Sym sym_mem;
    if (SHN_UNDEF != lib_symidx) {
        /* We found the symbol--now check to see if it is global
           or weak.  If this is the case, then the symbol satisfies
           the dependency. */
        GElf_Sym *lib_sym = gelf_getsymshndx(lib->symtab.data,
                                             NULL,
                                             lib_symidx,
                                             &sym_mem,
                                             NULL);
        FAILIF_LIBELF(NULL == lib_sym, gelf_getsymshndx);
#if ELF_STRPTR_IS_BROKEN
        ASSERT(!strcmp(
                   symname,
                   ((char *)elf_getdata(elf_getscn(lib->elf,
                                                   lib->symtab.shdr.sh_link),
                                        NULL)->d_buf) +
                   lib_sym->st_name));
#else
        ASSERT(!strcmp(
                   symname,
                   elf_strptr(lib->elf, lib->symtab.shdr.sh_link,
                              lib_sym->st_name)));
#endif
        if (lib_sym->st_shndx != SHN_UNDEF &&
            (GELF_ST_BIND(lib_sym->st_info) == STB_GLOBAL ||
             GELF_ST_BIND(lib_sym->st_info) == STB_WEAK)) {
            memcpy(lib_sym_mem, &sym_mem, sizeof(GElf_Sym));
            return lib_sym;
        }
    }

    return NULL;
}

static source_t *lookup_symbol_in_dependencies(source_t *source,
                                               const char *symname,
                                               GElf_Sym *found_sym)
{
    source_t *sym_source = NULL; /* return value */

    /* This is an undefined symbol.  Go over the list of libraries
       and look it up. */
    size_t libidx;
    int found = 0;
    source_t *last_found = NULL;
    for (libidx = 0; libidx < (size_t)source->num_lib_deps; libidx++) {
        source_t *lib = source->lib_deps[libidx];
        if (hash_lookup_global_or_weak_symbol(lib, symname, found_sym) != NULL)
        {
            sym_source = lib;
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

#if ELF_STRPTR_IS_BROKEN
    ASSERT(!sym_source ||
           !strcmp(symname,
                   (char *)(elf_getdata(elf_getscn(
                                            sym_source->elf,
                                            sym_source->symtab.shdr.sh_link),
                                        NULL)->d_buf) +
                   found_sym->st_name));
#else
    ASSERT(!sym_source ||
           !strcmp(symname,
                   elf_strptr(sym_source->elf,
                              sym_source->symtab.shdr.sh_link,
                              found_sym->st_name)));
#endif

    return sym_source;
}

static int do_prelink(source_t *source,
                      Elf_Data *reloc_scn_data,
                      int reloc_scn_entry_size,
                      unfinished_relocation_t *unfinished,
                      int locals_only,
                      bool dry_run,
                      char **lib_lookup_dirs, int num_lib_lookup_dirs,
                      char **default_libs, int num_default_libs,
                      int *num_unfinished_relocs)
{
    int num_relocations = 0;

    size_t num_rels;
    num_rels = reloc_scn_data->d_size / reloc_scn_entry_size;

    INFO("\tThere are %d relocations.\n", num_rels);

    int rel_idx;
    for (rel_idx = 0; rel_idx < (size_t)num_rels; rel_idx++) {
        GElf_Rel *rel, rel_mem;

        //INFO("\tHandling relocation %d/%d\n", rel_idx, num_rels);

        rel = gelf_getrel(reloc_scn_data, rel_idx, &rel_mem);
        FAILIF_LIBELF(rel == NULL, gelf_getrel);
        GElf_Sym *sym = NULL, sym_mem;
        unsigned sym_idx = GELF_R_SYM(rel->r_info);
        source_t *sym_source = NULL;
        /* found_sym points to found_sym_mem, when sym_source != NULL, and
           to sym, when the sybmol is locally defined.  If the symbol is
           not locally defined and sym_source == NULL, then sym is not
           defined either. */
        GElf_Sym *found_sym = NULL, found_sym_mem;
        const char *symname = NULL;
        int sym_is_local = 1;
        if (sym_idx) {
          sym = gelf_getsymshndx(source->symtab.data,
                                 NULL,
                                 sym_idx,
                                 &sym_mem,
                                 NULL);
          FAILIF_LIBELF(NULL == sym, gelf_getsymshndx);
#if ELF_STRPTR_IS_BROKEN
          symname =
              ((char *)source->strtab.data->d_buf) +
              sym->st_name;
#else
          symname = elf_strptr(source->elf,
                               elf_ndxscn(source->strtab.scn),
                               sym->st_name);
#endif

          /* If the symbol is defined and is either not in the BSS
             section, or if it is in the BSS then the relocation is
             not a copy relocation, then the symbol's source is this
             library (i.e., it is locally-defined).  Otherwise, the
             symbol is imported.
          */

          sym_is_local = 0;
          if (sym->st_shndx != SHN_UNDEF &&
              (source->bss.scn == NULL ||
               sym->st_shndx != elf_ndxscn(source->bss.scn) ||
#ifdef ARM_SPECIFIC_HACKS
               GELF_R_TYPE(rel->r_info) != R_ARM_COPY
#else
               1
#endif
               ))
            {
              sym_is_local = 1;
            }

          if (sym_is_local) {
            INFO("\t\tSymbol [%s:%s] is defined locally.\n",
                 source->name,
                 symname);
            sym_source = source;
            found_sym = sym;
          }
          else if (!locals_only) {
            sym_source = lookup_symbol_in_dependencies(source,
                                                       symname,
                                                       &found_sym_mem);

            /* The symbol was not in the list of dependencies, which by
               itself is an error:  it means either that the symbol does
               not exist anywhere, or that the library which has the symbol
               has not been listed as a dependency in this library or
               executable. It could also mean (for a library) that the
               symbol is defined in the executable that links agsinst it,
               which is obviously not a good thing.  These are bad things,
               but they do happen, which is why we have the ability to
               provide a list of default dependencies, including
               executables. Here we check to see if the symbol has been
               defined in any of them.
            */
            if (NULL == sym_source) {
              INFO("\t\tChecking default dependencies...\n");
              int i;
              source_t *lib, *old_sym_source = NULL;
              int printed_initial_error = 0;
              for (i = 0; i < num_default_libs; i++) {
                INFO("\tChecking in [%s].\n", default_libs[i]);
                lib = find_source(default_libs[i],
                                  lib_lookup_dirs,
                                  num_lib_lookup_dirs);
                FAILIF(NULL == lib,
                       "Can't find default library [%s]!\n",
                       default_libs[i]);
                if (hash_lookup_global_or_weak_symbol(lib,
                                                      symname,
                                                      &found_sym_mem)) {
                  found_sym = &found_sym_mem;
                  sym_source = lib;
#if ELF_STRPTR_IS_BROKEN
                  ASSERT(!strcmp(symname,
                                 (char *)(elf_getdata(
                                              elf_getscn(
                                                  sym_source->elf,
                                                  sym_source->symtab.
                                                      shdr.sh_link),
                                              NULL)->d_buf) +
                                 found_sym->st_name));
#else
                  ASSERT(!strcmp(symname,
                                 elf_strptr(sym_source->elf,
                                            sym_source->symtab.shdr.sh_link,
                                            found_sym->st_name)));

#endif
                  INFO("\tFound symbol [%s] in [%s]!\n",
                       symname, lib->name);
                  if (old_sym_source) {
                    if (printed_initial_error == 0) {
                      printed_initial_error = 1;
                      ERROR("Multiple definition of [%s]:\n"
                            "\t[%s]\n",
                            symname,
                            old_sym_source->name);
                    }
                    ERROR("\t[%s]\n", sym_source->name);
                  }
                  old_sym_source = sym_source;
                } else {
                  INFO("\tCould not find symbol [%s] in default "
                       "lib [%s]!\n", symname, lib->name);
                }
              }
              if (sym_source) {
                ERROR("ERROR: Could not find [%s:%s] in dependent "
                      "libraries (but found in default [%s])!\n",
                      source->name,
                      symname,
                      sym_source->name);
              }
            } else {
              found_sym = &found_sym_mem;
              /* We found the symbol in a dependency library. */
              INFO("\t\tSymbol [%s:%s, value %lld] is imported from [%s]\n",
                   source->name,
                   symname,
                   found_sym->st_value,
                   sym_source->name);
            }
          } /* if symbol is defined in this library... */

          if (!locals_only) {
            /* If a symbol is weak and we haven't found it, then report
               an error.  We really need to find a way to set its value
               to zero.  The problem is that it needs to refer to some
               section. */

            FAILIF(NULL == sym_source &&
                   GELF_ST_BIND(sym->st_info) == STB_WEAK,
                   "Cannot handle weak symbols yet (%s:%s <- %s).\n",
                   source->name,
                   symname,
                   sym_source->name);
#ifdef PERMISSIVE
            if (GELF_ST_BIND(sym->st_info) != STB_WEAK &&
                NULL == sym_source) {
              ERROR("ERROR: Can't find symbol [%s:%s] in dependent or "
                    "default libraries!\n", source->name, symname);
            }
#else
            FAILIF(GELF_ST_BIND(sym->st_info) != STB_WEAK &&
                   NULL == sym_source,
                   "Can't find symbol [%s:%s] in dependent or default "
                   "libraries!\n",
                   source->name,
                   symname);
#endif
          } /* if (!locals_only) */
        }
#if 0 // too chatty
        else
          INFO("\t\tno symbol is associated with this relocation\n");
#endif


        // We prelink only local symbols when locals_only == 1.

        bool can_relocate = true;
        if (!sym_is_local &&
            (symname[0] == 'd' && symname[1] == 'l' && symname[2] != '\0' &&
             (!strcmp(symname + 2, "open") ||
              !strcmp(symname + 2, "close") ||
              !strcmp(symname + 2, "sym") ||
              !strcmp(symname + 2, "error")))) {
            INFO("********* NOT RELOCATING LIBDL SYMBOL [%s]\n", symname);
            can_relocate = false;
        }

        if (can_relocate && (sym_is_local || !locals_only))
        {
            GElf_Shdr shdr_mem; Elf_Scn *scn; Elf_Data *data;
            find_section(source, rel->r_offset, &scn, &shdr_mem, &data);
            unsigned *dest =
              (unsigned*)(((char *)data->d_buf) +
                          (rel->r_offset - shdr_mem.sh_addr));
            unsigned rel_type = GELF_R_TYPE(rel->r_info);
            char buf[64];
            INFO("\t\t%-15s ",
                 ebl_reloc_type_name(source->ebl,
                                     GELF_R_TYPE(rel->r_info),
                                     buf,
                                     sizeof(buf)));

            /* Section-name offsets do not change, so we use oldelf to get the
               strings.  This makes a difference in the second pass of the
               perlinker, after the call to adjust_elf, because
               source->shstrndx no longer contains the index of the
               section-header-strings table.
            */
            const char *sname = elf_strptr(
                source->oldelf, source->shstrndx, shdr_mem.sh_name);

            switch (rel_type) {
            case R_ARM_JUMP_SLOT:
            case R_ARM_GLOB_DAT:
            case R_ARM_ABS32:
              ASSERT(data->d_buf != NULL);
              ASSERT(data->d_size >= rel->r_offset - shdr_mem.sh_addr);
#ifdef PERMISSIVE
              if (sym_source == NULL) {
                ERROR("ERROR: Permissive relocation "
                      "[%-15s] [%s:%s]: [0x%llx] = ZERO\n",
                      ebl_reloc_type_name(source->ebl,
                                          GELF_R_TYPE(rel->r_info),
                                          buf,
                                          sizeof(buf)),
                      sname,
                      symname,
                      rel->r_offset);
                if (!dry_run)
                  *dest = 0;
              } else
#endif
                {
                  ASSERT(sym_source);
                  INFO("[%s:%s]: [0x%llx] = 0x%llx + 0x%lx\n",
                       sname,
                       symname,
                       rel->r_offset,
                       found_sym->st_value,
                       sym_source->base);
                  if (!dry_run)
                    *dest = found_sym->st_value + sym_source->base;
                }
              num_relocations++;
              break;
            case R_ARM_RELATIVE:
              ASSERT(data->d_buf != NULL);
              ASSERT(data->d_size >= rel->r_offset - shdr_mem.sh_addr);
              FAILIF(sym != NULL,
                     "Unsupported RELATIVE form (symbol != 0)...\n");
              INFO("[%s:%s]: [0x%llx] = 0x%x + 0x%lx\n",
                   sname,
                   symname ?: "(symbol has no name)",
                   rel->r_offset, *dest, source->base);
              if (!dry_run)
                *dest += source->base;
              num_relocations++;
              break;
            case R_ARM_COPY:
#ifdef PERMISSIVE
              if (sym_source == NULL) {
                ERROR("ERROR: Permissive relocation "
                      "[%-15s] [%s:%s]: NOT PERFORMING\n",
                      ebl_reloc_type_name(source->ebl,
                                          GELF_R_TYPE(rel->r_info),
                                          buf,
                                          sizeof(buf)),
                      sname,
                      symname);
              } else
#endif
                {
                  ASSERT(sym);
                  ASSERT(sym_source);
                  GElf_Shdr src_shdr_mem;
                  Elf_Scn *src_scn;
                  Elf_Data *src_data;
                  find_section(sym_source, found_sym->st_value,
                               &src_scn,
                               &src_shdr_mem,
                               &src_data);
                  INFO("Found [%s:%s (%lld)] in section [%s] .\n",
                       sym_source->name,
                       symname,
                       found_sym->st_value,
#if ELF_STRPTR_IS_BROKEN
                       (((char *)elf_getdata(
                             elf_getscn(sym_source->elf,
                                        sym_source->shstrndx),
                             NULL)->d_buf) + src_shdr_mem.sh_name)
#else
                       elf_strptr(sym_source->elf,
                                  sym_source->shstrndx,
                                  src_shdr_mem.sh_name)
#endif
                      );

                  unsigned *src = NULL;
                  if (src_data->d_buf == NULL)
                    {
#ifdef PERMISSIVE
                      if (sym_source->bss.scn == NULL ||
                          elf_ndxscn(src_scn) !=
                          elf_ndxscn(sym_source->bss.scn)) {
                        ERROR("ERROR: Permissive relocation (NULL source "
                              "not from .bss) [%-15s] [%s:%s]: "
                              "NOT PERFORMING\n",
                              ebl_reloc_type_name(source->ebl,
                                                  GELF_R_TYPE(rel->r_info),
                                                  buf,
                                                  sizeof(buf)),
                              sname,
                              symname);
                      }
#endif
                    }
                  else {
                    ASSERT(src_data->d_size >=
                           found_sym->st_value - src_shdr_mem.sh_addr);
                    src = (unsigned*)(((char *)src_data->d_buf) +
                                      (found_sym->st_value -
                                       src_shdr_mem.sh_addr));
                  }
                  ASSERT(symname);
                  INFO("[%s:%s]: [0x%llx] <- [0x%llx] size %lld\n",
                       sname,
                       symname, rel->r_offset,
                       found_sym->st_value,
                       found_sym->st_size);

#ifdef PERMISSIVE
                  if (src_data->d_buf != NULL ||
                      (sym_source->bss.scn != NULL &&
                       elf_ndxscn(src_scn) ==
                       elf_ndxscn(sym_source->bss.scn)))
#endif/*PERMISSIVE*/
                    {
                      if (data->d_buf == NULL) {
                        INFO("Incomplete relocation [%-15s] of [%s:%s].\n",
                             ebl_reloc_type_name(source->ebl,
                                                 GELF_R_TYPE(rel->r_info),
                                                 buf,
                                                 sizeof(buf)),
                             sname,
                             symname);
                        FAILIF(unfinished == NULL,
                               "You passed unfinished as NULL expecting "
                               "to handle all relocations, "
                               "but at least one cannot be handled!\n");
                        if (unfinished->num_rels == unfinished->rels_size) {
                          unfinished->rels_size += 10;
                          unfinished->rels = (GElf_Rel *)REALLOC(
                              unfinished->rels,
                              unfinished->rels_size *
                              sizeof(GElf_Rel));
                        }
                        unfinished->rels[unfinished->num_rels++] = *rel;
                        num_relocations--;
                        (*num_unfinished_relocs)++;
                      }
                      else {
                        if (src_data->d_buf != NULL)
                          {
                            ASSERT(data->d_buf != NULL);
                            ASSERT(data->d_size >= rel->r_offset -
                                   shdr_mem.sh_addr);
                            if (!dry_run)
                              memcpy(dest, src, found_sym->st_size);
                          }
                        else {
                          ASSERT(src == NULL);
                          ASSERT(elf_ndxscn(src_scn) ==
                                 elf_ndxscn(sym_source->bss.scn));
                          if (!dry_run)
                            memset(dest, 0, found_sym->st_size);
                        }
                      }
                    }
                  num_relocations++;
                }
              break;
            default:
              FAILIF(1, "Unknown relocation type %d!\n", rel_type);
            } // switch
        } // relocate
        else {
          INFO("\t\tNot relocating symbol [%s]%s\n",
               symname,
               (can_relocate ? ", relocating only locals" : 
                ", which is a libdl symbol"));
          FAILIF(unfinished == NULL,
                 "You passed unfinished as NULL expecting to handle all "
                 "relocations, but at least one cannot be handled!\n");
          if (unfinished->num_rels == unfinished->rels_size) {
              unfinished->rels_size += 10;
              unfinished->rels = (GElf_Rel *)REALLOC(
                  unfinished->rels,
                  unfinished->rels_size *
                  sizeof(GElf_Rel));
          }
          unfinished->rels[unfinished->num_rels++] = *rel;
          (*num_unfinished_relocs)++;
        }
    } // for each relocation entry

    return num_relocations;
}

static int prelink(source_t *source,
                   int locals_only,
                   bool dry_run,
                   char **lib_lookup_dirs, int num_lib_lookup_dirs,
                   char **default_libs, int num_default_libs,
                   int *num_unfinished_relocs)
{
    INFO("Prelinking [%s] (number of relocation sections: %d)%s...\n",
         source->name, source->num_relocation_sections,
         (dry_run ? " (dry run)" : ""));
    int num_relocations = 0;
    int rel_scn_idx;
    for (rel_scn_idx = 0; rel_scn_idx < source->num_relocation_sections;
         rel_scn_idx++)
    {
        section_info_t *reloc_scn = source->relocation_sections + rel_scn_idx;
        unfinished_relocation_t *unfinished = source->unfinished + rel_scn_idx;

        /* We haven't modified the shstrtab section, and so shdr->sh_name has
           the same value as before.  Thus we look up the name based on the old
           ELF handle.  We cannot use shstrndx on the new ELF handle because
           the index of the shstrtab section may have changed (and calling
           elf_getshstrndx() returns the same section index, so libelf can't
           handle thise ither).

           If reloc_scn->info is available, we can assert that the
           section-name has not changed.  If this assertion fails,
           then we cannot use the elf_strptr() trick below to get
           the section name.  One solution would be to save it in
           the section_info_t structure.
        */
        ASSERT(reloc_scn->info == NULL ||
               reloc_scn->shdr.sh_name == reloc_scn->info->old_shdr.sh_name);
        const char *sname =
          elf_strptr(source->oldelf,
                     source->shstrndx,
                     reloc_scn->shdr.sh_name);
        ASSERT(sname != NULL);

        INFO("\n\tIterating relocation section [%s]...\n", sname);

        /* In general, the new size of the section differs from the original
           size of the section, because we can handle some of the relocations.
           This was communicated to adjust_elf, which modified the ELF file
           according to the new section sizes.  Now, when prelink() does the
           actual work of prelinking, it needs to know the original size of the
           relocation section so that it can see all of the original relocation
           entries!
        */
        size_t d_size = reloc_scn->data->d_size;
        if (reloc_scn->info != NULL &&
            reloc_scn->data->d_size != reloc_scn->info->old_shdr.sh_size)
        {
            INFO("Setting size of section [%s] to from new size %d to old "
                 "size %lld temporarily (so prelinker can see all "
                 "relocations).\n",
                 reloc_scn->info->name,
                 d_size,
                 reloc_scn->info->old_shdr.sh_size);
            reloc_scn->data->d_size = reloc_scn->info->old_shdr.sh_size;
        }

        num_relocations +=
          do_prelink(source,
                     reloc_scn->data, reloc_scn->shdr.sh_entsize,
                     unfinished,
                     locals_only, dry_run,
                     lib_lookup_dirs, num_lib_lookup_dirs,
                     default_libs, num_default_libs,
                     num_unfinished_relocs);

        if (reloc_scn->data->d_size != d_size)
        {
            ASSERT(reloc_scn->info != NULL);
            INFO("Resetting size of section [%s] to %d\n",
                 reloc_scn->info->name,
                 d_size);
            reloc_scn->data->d_size = d_size;
        }
    }

    /* Now prelink those relocation sections which were fully handled, and
       therefore removed.  They are not a part of the
       source->relocation_sections[] array anymore, but we can find them by
       scanning source->shdr_info[] and looking for sections with idx == 0.
    */

    if (ADJUST_ELF && source->shdr_info != NULL) {
        /* Walk over the shdr_info[] array to see if we've removed any
           relocation sections.  prelink() those sections as well.
        */
        int i;
        for (i = 0; i < source->shnum; i++) {
            shdr_info_t *info = source->shdr_info + i;
            if (info->idx == 0 &&
                (info->shdr.sh_type == SHT_REL ||
                 info->shdr.sh_type == SHT_RELA)) {

              Elf_Data *data = elf_getdata(info->scn, NULL);
              ASSERT(data->d_size == 0);
              data->d_size = info->old_shdr.sh_size;

              INFO("\n\tIterating relocation section [%s], which was "
                   "discarded (size %d, entry size %lld).\n",
                   info->name,
                   data->d_size,
                   info->old_shdr.sh_entsize);

              num_relocations +=
                do_prelink(source,
                           data, info->old_shdr.sh_entsize,
                           NULL, /* the section was fully handled */
                           locals_only, dry_run,
                           lib_lookup_dirs, num_lib_lookup_dirs,
                           default_libs, num_default_libs,
                           num_unfinished_relocs);

              data->d_size = 0;
            }
        }
    }
    return num_relocations;
}

static char * find_file(const char *libname,
                        char **lib_lookup_dirs,
                        int num_lib_lookup_dirs) {
    if (libname[0] == '/') {
        /* This is an absolute path name--just return it. */
        /* INFO("ABSOLUTE PATH: [%s].\n", libname); */
        return strdup(libname);
    } else {
        /* First try the working directory. */
        int fd;
        if ((fd = open(libname, O_RDONLY)) > 0) {
            close(fd);
            /* INFO("FOUND IN CURRENT DIR: [%s].\n", libname); */
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
                    /* INFO("FOUND: [%s] in [%s].\n", libname, name); */
                    return name;
                }
                INFO("NOT FOUND: [%s] in [%s].\n", libname, name);
                free(name);
            }
        }
    }
    return NULL;
}

static void adjust_dynamic_segment_entry_size(source_t *source,
                                              dt_rel_info_t *dyn)
{
    /* Update the size entry in the DT_DYNAMIC segment. */
    GElf_Dyn *dyn_entry, dyn_entry_mem;
    dyn_entry = gelf_getdyn(source->dynamic.data,
                            dyn->sz_idx,
                            &dyn_entry_mem);
    FAILIF_LIBELF(NULL == dyn_entry, gelf_getdyn);
    /* If we are calling this function to adjust the size of the dynamic entry,
       then there should be some unfinished relocations remaining.  If there
       are none, then we should remove the entry from the dynamic section
       altogether.
    */
    ASSERT(dyn->num_unfinished_relocs);

    size_t relsize = gelf_fsize(source->elf,
                                ELF_T_REL,
                                1,
                                source->elf_hdr.e_version);

    if (unlikely(verbose_flag)) {
        char buf[64];
        INFO("Updating entry %d: [%-10s], %08llx --> %08x\n",
             dyn->sz_idx,
             ebl_dynamic_tag_name (source->ebl, dyn_entry->d_tag,
                                   buf, sizeof (buf)),
             dyn_entry->d_un.d_val,
             dyn->num_unfinished_relocs * relsize);
    }

    dyn_entry->d_un.d_val = dyn->num_unfinished_relocs * relsize;

    FAILIF_LIBELF(!gelf_update_dyn(source->dynamic.data,
                                   dyn->sz_idx,
                                   dyn_entry),
                  gelf_update_dyn);
}

static void adjust_dynamic_segment_entries(source_t *source)
{
    /* This function many remove entries from the dynamic segment, but it won't
       resize the relevant section.  It'll just fill the remainted with empty
       DT entries.

       FIXME: This is not guaranteed right now.  If a dynamic segment does not
       end with null DT entries, I think this will break.
    */
    FAILIF(source->rel.processed,
           "More than one section matches DT_REL entry in dynamic segment!\n");
    FAILIF(source->jmprel.processed,
           "More than one section matches DT_JMPREL entry in "
           "dynamic segment!\n");
    source->rel.processed =
      source->jmprel.processed = 1;

    if (source->rel.num_unfinished_relocs > 0)
        adjust_dynamic_segment_entry_size(source, &source->rel);

    if (source->jmprel.num_unfinished_relocs > 0)
        adjust_dynamic_segment_entry_size(source, &source->jmprel);

    /* If at least one of the entries is empty, then we need to remove it.  We
       have already adjusted the size of the other.
    */
    if (source->rel.num_unfinished_relocs == 0 ||
        source->jmprel.num_unfinished_relocs == 0)
    {
        /* We need to delete the DT_REL/DT_RELSZ and DT_PLTREL/DT_PLTRELSZ
           entries from the dynamic segment. */

        GElf_Dyn *dyn_entry, dyn_entry_mem;
        size_t dynidx, updateidx;

        size_t numdyn =
            source->dynamic.shdr.sh_size /
            source->dynamic.shdr.sh_entsize;

        for (updateidx = dynidx = 0; dynidx < numdyn; dynidx++)
        {
            dyn_entry = gelf_getdyn(source->dynamic.data,
                                    dynidx,
                                    &dyn_entry_mem);
            FAILIF_LIBELF(NULL == dyn_entry, gelf_getdyn);
            if ((source->rel.num_unfinished_relocs == 0 &&
                 (dynidx == source->rel.idx ||
                  dynidx == source->rel.sz_idx)) ||
                (source->jmprel.num_unfinished_relocs == 0 &&
                 (dynidx == source->jmprel.idx ||
                  dynidx == source->jmprel.sz_idx)))
            {
                if (unlikely(verbose_flag)) {
                    char buf[64];
                    INFO("\t(!)\tRemoving entry %02d: [%-10s], %08llx\n",
                         dynidx,
                         ebl_dynamic_tag_name (source->ebl, dyn_entry->d_tag,
                                               buf, sizeof (buf)),
                         dyn_entry->d_un.d_val);
                }
                continue;
            }

            if (unlikely(verbose_flag)) {
                char buf[64];
                INFO("\t\tKeeping  entry %02d: [%-10s], %08llx\n",
                     dynidx,
                     ebl_dynamic_tag_name (source->ebl, dyn_entry->d_tag,
                                           buf, sizeof (buf)),
                     dyn_entry->d_un.d_val);
            }

            gelf_update_dyn(source->dynamic.data,
                            updateidx,
                            &dyn_entry_mem);
            updateidx++;
        }
    }
} /* adjust_dynamic_segment_entries */

static bool adjust_dynamic_segment_for(source_t *source,
                                       dt_rel_info_t *dyn,
                                       bool adjust_section_size_only)
{
    bool dropped_sections = false;

    /* Go over the sections that belong to this dynamic range. */
    dyn->num_unfinished_relocs = 0;
    if (dyn->sections) {
        int num_scns, idx;
        range_t *scns = get_sorted_ranges(dyn->sections, &num_scns);

        INFO("\tdynamic range %s:[%lld, %lld) contains %d sections.\n",
             source->name,
             dyn->addr,
             dyn->addr + dyn->size,
             num_scns);

        ASSERT(scns);
        int next_idx = 0, next_rel_off = 0;
        /* The total number of unfinished relocations for this dynamic
         * entry. */
        section_info_t *next = (section_info_t *)scns[next_idx].user;
        section_info_t *first = next;
        ASSERT(first);
        for (idx = 0; idx < num_scns; idx++) {
            section_info_t *reloc_scn = (section_info_t *)scns[idx].user;
            size_t rel_scn_idx = reloc_scn - source->relocation_sections;
            ASSERT(rel_scn_idx < (size_t)source->num_relocation_sections);
            unfinished_relocation_t *unfinished =
                &source->unfinished[rel_scn_idx];
            int unf_idx;

            ASSERT(reloc_scn->info == NULL ||
                   reloc_scn->shdr.sh_name ==
                   reloc_scn->info->old_shdr.sh_name);
            const char *sname =
              elf_strptr(source->oldelf,
                         source->shstrndx,
                         reloc_scn->shdr.sh_name);

            INFO("\tsection [%s] contains %d unfinished relocs.\n",
                 sname,
                 unfinished->num_rels);

            for (unf_idx = 0; unf_idx < unfinished->num_rels; unf_idx++)
            {
                /* There are unfinished relocations.  Copy them forward to the
                   lowest section we can. */

                while (next_rel_off == 
                       (int)(next->shdr.sh_size/next->shdr.sh_entsize))
                {
                    INFO("\tsection [%s] has filled up with %d unfinished "
                         "relocs.\n",
                         sname,
                         next_rel_off);

                    next_idx++;
                    ASSERT(next_idx <= idx);
                    next = (section_info_t *)scns[next_idx].user;
                    next_rel_off = 0;
                }

                if (!adjust_section_size_only) {
                    INFO("\t\tmoving unfinished relocation %2d to [%s:%d]\n",
                         unf_idx,
                         sname,
                         next_rel_off);
                    FAILIF_LIBELF(0 ==
                                  gelf_update_rel(next->data,
                                                  next_rel_off,
                                                  &unfinished->rels[unf_idx]),
                                  gelf_update_rel);
                }

                next_rel_off++;
                dyn->num_unfinished_relocs++;
            }
        } /* for */

        /* Set the size of the last section, and mark all subsequent
           sections for removal.  At this point, next is the section
           to which we last wrote data, next_rel_off is the offset before
           which we wrote the last relocation, and so next_rel_off *
           relsize is the new size of the section.
        */

        bool adjust_file = ADJUST_ELF && source->elf_hdr.e_type != ET_EXEC;
        if (adjust_file && !source->dry_run)
        {
            size_t relsize = gelf_fsize(source->elf,
                                        ELF_T_REL,
                                        1,
                                        source->elf_hdr.e_version);

            ASSERT(next->info == NULL ||
                   next->shdr.sh_name == next->info->old_shdr.sh_name);
            const char *sname =
              elf_strptr(source->oldelf,
                         source->shstrndx,
                         next->shdr.sh_name);

            INFO("\tsection [%s] (index %d) has %d unfinished relocs, "
                 "changing its size to %ld bytes (from %ld bytes).\n",
                 sname,
                 elf_ndxscn(next->scn),
                 next_rel_off,
                 (long)(next_rel_off * relsize),
                 (long)(next->shdr.sh_size));

            /* source->shdr_info[] must be allocated prior to calling this
               function.  This is in fact done in process_file(), by calling
               setup_shdr_info() just before we call adjust_dynamic_segment().
            */
            ASSERT(source->shdr_info != NULL);

            /* We do not update the data field of shdr_info[], because it does
               not exist yet (with ADJUST_ELF != 0).  We create the new section
               and section data after the first call to prelink().  For now, we
               save the results of our analysis by modifying the sh_size field
               of the section header.  When we create the new sections' data,
               we set the size of the data from the sh_size fields of the
               section headers.

               NOTE: The assertion applies only to the first call of
                     adjust_dynamic_segment (which calls this function).  By
                     the second call, we've already created the data for the
                     new sections.  The only sections for which we haven't
                     created data are the relocation sections we are removing.
            */
#ifdef DEBUG
            ASSERT((!adjust_section_size_only &&
                    (source->shdr_info[elf_ndxscn(next->scn)].idx > 0)) ||
                   source->shdr_info[elf_ndxscn(next->scn)].data == NULL);
#endif

            //FIXME: what else do we need to do here?  Do we need to update
            //       another copy of the shdr so that it's picked up when we
            //       commit the file?
            next->shdr.sh_size = next_rel_off * relsize;
            source->shdr_info[elf_ndxscn(next->scn)].shdr.sh_size =
                next->shdr.sh_size;
            if (next_rel_off * relsize == 0) {
#ifdef REMOVE_HANDLED_SECTIONS
                INFO("\tsection [%s] (index %d) is now empty, marking for "
                     "removal.\n",
                     sname,
                     elf_ndxscn(next->scn));
                source->shdr_info[elf_ndxscn(next->scn)].idx = 0;
                dropped_sections = true;
#endif
            }

            while (++next_idx < num_scns) {
                next = (section_info_t *)scns[next_idx].user;
#ifdef REMOVE_HANDLED_SECTIONS
                ASSERT(next->info == NULL ||
                       next->shdr.sh_name == next->info->old_shdr.sh_name);
                const char *sname =
                  elf_strptr(source->oldelf,
                             source->shstrndx,
                             next->shdr.sh_name);
                INFO("\tsection [%s] (index %d) is now empty, marking for "
                     "removal.\n",
                     sname,
                     elf_ndxscn(next->scn));
                /* mark for removal */
                source->shdr_info[elf_ndxscn(next->scn)].idx = 0;
                dropped_sections = true;
#endif
            }
        }

    } /* if (dyn->sections) */
    else {
        /* The dynamic entry won't have any sections when it itself doesn't
           exist.  This could happen when we remove all relocation sections
           from a dynamic entry because we have managed to handle all
           relocations in them.
        */
        INFO("\tNo section for dynamic entry!\n");
    }

    return dropped_sections;
}

static bool adjust_dynamic_segment(source_t *source,
                                   bool adjust_section_size_only)
{
    bool dropped_section;
    INFO("Adjusting dynamic segment%s.\n",
         (adjust_section_size_only ? " (section sizes only)" : ""));
    INFO("\tadjusting dynamic segment REL.\n");
    dropped_section =
        adjust_dynamic_segment_for(source, &source->rel,
                                   adjust_section_size_only);
    INFO("\tadjusting dynamic segment JMPREL.\n");
    dropped_section =
        adjust_dynamic_segment_for(source, &source->jmprel,
                                   adjust_section_size_only) ||
        dropped_section;
    if (!adjust_section_size_only)
        adjust_dynamic_segment_entries(source);
    return dropped_section;
}

static void match_relocation_sections_to_dynamic_ranges(source_t *source)
{
    /* We've gathered all the DT_DYNAMIC entries; now we need to figure out
       which relocation sections fit in which range as described by the
       entries.
    */

    int relidx;
    for (relidx = 0; relidx < source->num_relocation_sections; relidx++) {
        section_info_t *reloc_scn = &source->relocation_sections[relidx];

        int index = elf_ndxscn(reloc_scn->scn);

        ASSERT(reloc_scn->info == NULL ||
               reloc_scn->shdr.sh_name == reloc_scn->info->old_shdr.sh_name);
        const char *sname =
          elf_strptr(source->oldelf,
                     source->shstrndx,
                     reloc_scn->shdr.sh_name);

        INFO("Checking section [%s], index %d, for match to dynamic ranges\n",
             sname, index);
        if (source->shdr_info == NULL || reloc_scn->info->idx > 0) {
            if (source->rel.addr &&
                source->rel.addr <= reloc_scn->shdr.sh_addr &&
                reloc_scn->shdr.sh_addr < source->rel.addr + source->rel.size)
                {
                    /* The entire section must fit in the dynamic range. */
                    if((reloc_scn->shdr.sh_addr + reloc_scn->shdr.sh_size) >
                       (source->rel.addr + source->rel.size))
                        {
                            PRINT("WARNING: In [%s], section %s:[%lld,%lld) "
                                  "is not fully contained in dynamic range "
                                  "[%lld,%lld)!\n",
                                  source->name,
                                  sname,
                                  reloc_scn->shdr.sh_addr,
                                  reloc_scn->shdr.sh_addr +
                                      reloc_scn->shdr.sh_size,
                                  source->rel.addr,
                                  source->rel.addr + source->rel.size);
                        }

                    if (NULL == source->rel.sections) {
                        source->rel.sections = init_range_list();
                        ASSERT(source->rel.sections);
                    }
                    add_unique_range_nosort(source->rel.sections,
                                            reloc_scn->shdr.sh_addr,
                                            reloc_scn->shdr.sh_size,
                                            reloc_scn,
                                            NULL,
                                            NULL);
                    INFO("\tSection [%s] matches dynamic range REL.\n",
                         sname);
                }
            else if (source->jmprel.addr &&
                     source->jmprel.addr <= reloc_scn->shdr.sh_addr &&
                     reloc_scn->shdr.sh_addr <= source->jmprel.addr +
                     source->jmprel.size)
                {
                    if((reloc_scn->shdr.sh_addr + reloc_scn->shdr.sh_size) >
                       (source->jmprel.addr + source->jmprel.size))
                        {
                            PRINT("WARNING: In [%s], section %s:[%lld,%lld) "
                                  "is not fully "
                                  "contained in dynamic range [%lld,%lld)!\n",
                                  source->name,
                                  sname,
                                  reloc_scn->shdr.sh_addr,
                                  reloc_scn->shdr.sh_addr +
                                      reloc_scn->shdr.sh_size,
                                  source->jmprel.addr,
                                  source->jmprel.addr + source->jmprel.size);
                        }

                    if (NULL == source->jmprel.sections) {
                        source->jmprel.sections = init_range_list();
                        ASSERT(source->jmprel.sections);
                    }
                    add_unique_range_nosort(source->jmprel.sections,
                                            reloc_scn->shdr.sh_addr,
                                            reloc_scn->shdr.sh_size,
                                            reloc_scn,
                                            NULL,
                                            NULL);
                    INFO("\tSection [%s] matches dynamic range JMPREL.\n",
                         sname);
                }
            else
                PRINT("WARNING: Relocation section [%s:%s] does not match "
                      "any DT_ entry.\n",
                      source->name,
                      sname);
        }
        else {
            INFO("Section [%s] was removed, not matching it to dynamic "
                 "ranges.\n",
                 sname);
        }
    } /* for ... */

    if (source->rel.sections) sort_ranges(source->rel.sections);
    if (source->jmprel.sections) sort_ranges(source->jmprel.sections);
}

static void drop_sections(source_t *source)
{
    INFO("We are dropping some sections from [%s]--creating section entries "
         "only for remaining sections.\n",
         source->name);
    /* Renumber the sections.  The numbers for the sections after those we are
       dropping will be shifted back by the number of dropped sections. */
    int cnt, idx;
    for (cnt = idx = 1; cnt < source->shnum; ++cnt) {
        if (source->shdr_info[cnt].idx > 0) {
            source->shdr_info[cnt].idx = idx++;
            
            /* Create a new section. */
            FAILIF_LIBELF((source->shdr_info[cnt].newscn =
                           elf_newscn(source->elf)) == NULL, elf_newscn);
            ASSERT(elf_ndxscn (source->shdr_info[cnt].newscn) ==
                   source->shdr_info[cnt].idx);
            
            /* Copy the section data */
            Elf_Data *olddata =
                elf_getdata(source->shdr_info[cnt].scn, // old section
                            NULL);
            FAILIF_LIBELF(NULL == olddata, elf_getdata);
            Elf_Data *data = 
                elf_newdata(source->shdr_info[cnt].newscn);
            FAILIF_LIBELF(NULL == data, elf_newdata);
            *data = *olddata;
#if COPY_SECTION_DATA_BUFFER
            if (olddata->d_buf != NULL) {
                data->d_buf = MALLOC(data->d_size);
                memcpy(data->d_buf, olddata->d_buf, olddata->d_size);
            }
#endif
            source->shdr_info[cnt].data = data;
            
            if (data->d_size !=
                source->shdr_info[cnt].shdr.sh_size) {
                INFO("Trimming new-section data from %d to %lld bytes "
                     "(as calculated by adjust_dynamic_segment()).\n",
                     data->d_size,
                     source->shdr_info[cnt].shdr.sh_size);
                data->d_size =
                    source->shdr_info[cnt].shdr.sh_size;
            }
            
            INFO("\tsection [%s] (old offset %lld, old size %lld) "
                 "will have index %d (was %d), new size %d\n",
                 source->shdr_info[cnt].name,
                 source->shdr_info[cnt].old_shdr.sh_offset,
                 source->shdr_info[cnt].old_shdr.sh_size,
                 source->shdr_info[cnt].idx,
                 elf_ndxscn(source->shdr_info[cnt].scn),
                 data->d_size);
        } else {
            INFO("\tIgnoring section [%s] (offset %lld, size %lld, index %d), "
                 "it will be discarded.\n",
                 source->shdr_info[cnt].name,
                 source->shdr_info[cnt].shdr.sh_offset,
                 source->shdr_info[cnt].shdr.sh_size,
                 elf_ndxscn(source->shdr_info[cnt].scn));
        }

        /* NOTE: We mark use_old_shdr_for_relocation_calculations even for the
           sections we are removing.  adjust_elf has an assertion that makes
           sure that if the values for the size of a section according to its
           header and its data structure differ, then we are using explicitly
           the old section header for calculations, and that the section in
           question is a relocation section.
        */
        source->shdr_info[cnt].use_old_shdr_for_relocation_calculations = true;
    } /* for */
}

static source_t* process_file(const char *filename,
                              const char *output, int is_file,
                              void (*report_library_size_in_memory)(
                                  const char *name, off_t fsize),
                              unsigned (*get_next_link_address)(
                                  const char *name),
                              int locals_only,
                              char **lib_lookup_dirs,
                              int num_lib_lookup_dirs,
                              char **default_libs,
                              int num_default_libs,
                              int dry_run,
                              int *total_num_handled_relocs,
                              int *total_num_unhandled_relocs)
{
    /* Look up the file in the list of already-handles files, which are
       represented by source_t structs.  If we do not find the file, then we
       haven't prelinked it yet.  If we find it, then we have, so we do
       nothing.  Keep in mind that apriori operates on an entire collection
       of files, and if application A used library L, and so does application
       B, if we process A first, then by the time we get to B we will have
       prelinked L already; that's why we check first to see if a library has
       been prelinked.
    */
    source_t *source =
        find_source(filename, lib_lookup_dirs, num_lib_lookup_dirs);
    if (NULL == source) {
        /* If we could not find the source, then it hasn't been processed yet,
           so we go ahead and process it! */
        INFO("Processing [%s].\n", filename);
        char *full = find_file(filename, lib_lookup_dirs, num_lib_lookup_dirs);
        FAILIF(NULL == full,
               "Could not find [%s] in the current directory or in any of "
               "the search paths!\n", filename);

        unsigned base = get_next_link_address(full);

        source = init_source(full, output, is_file, base, dry_run);

        if (source == NULL) {
            INFO("File [%s] is a static executable.\n", filename);
            return NULL;
        }
		ASSERT(source->dynamic.scn != NULL);

        /* We need to increment the next prelink address only when the file we
           are currently handing is a shared library.  Executables do not need
           to be prelinked at a different address, they are always at address
           zero.

           Also, if we are prelinking locals only, then we are handling a
           single file per invokation of apriori, so there is no need to
           increment the prelink address unless there is a global prelink map,
           in which case we do need to check to see if the library isn't
           running into its neighbouts in the prelink map.
        */
        if (source->oldelf_hdr.e_type != ET_EXEC && 
            (!locals_only ||
             report_library_size_in_memory == 
             pm_report_library_size_in_memory)) {
            /* This sets the next link address only if an increment was not
               specified by the user.  If an address increment was specified,
               then we just check to make sure that the file size is less than
               the increment.

               NOTE: The file size is the absolute highest number of bytes that
               the file may occupy in memory, if the entire file is loaded, but
               this is almost next the case.  A file will often have sections
               which are not loaded, which could add a lot of size.  That's why
               we start off with the file size and then subtract the size of
               the biggest sections that will not get loaded, which are the
               varios DWARF sections, all of which of which are named starting
               with ".debug_".

               We could do better than this (by caculating exactly how many
               bytes from that file will be loaded), but that's an overkill.
               Unless the prelink-address increment becomes too small, the file
               size after subtracting the sizes of the DWARF section will be a
               good-enough upper bound.
            */

            unsigned long fsize = source->elf_file_info.st_size;
            INFO("Calculating loadable file size for next link address.  "
                 "Starting with %ld.\n", fsize);
            if (true) {
                Elf_Scn *scn = NULL;
                GElf_Shdr shdr_mem, *shdr;
                const char *scn_name;
                while ((scn = elf_nextscn (source->oldelf, scn)) != NULL) {
                    shdr = gelf_getshdr(scn, &shdr_mem);
                    FAILIF_LIBELF(NULL == shdr, gelf_getshdr);
                    scn_name = elf_strptr (source->oldelf,
                                           source->shstrndx, shdr->sh_name);
                    ASSERT(scn_name != NULL);

                    if (!(shdr->sh_flags & SHF_ALLOC)) {
                        INFO("\tDecrementing by %lld on account of section "
                             "[%s].\n",
                             shdr->sh_size,
                             scn_name);
                        fsize -= shdr->sh_size;
                    }                    
                }
            }
            INFO("Done calculating loadable file size for next link address: "
                 "Final value is %ld.\n", fsize);
            report_library_size_in_memory(source->name, fsize);
        }

        /* Identify the dynamic segment and process it.  Specifically, we find
           out what dependencies, if any, this file has.  Whenever we encounter
           such a dependency, we process it recursively; we find out where the
           various relocation information sections are stored. */

        size_t dynidx;
        GElf_Dyn *dyn, dyn_mem;
        size_t numdyn =
            source->dynamic.shdr.sh_size /
            source->dynamic.shdr.sh_entsize;
        ASSERT(source->dynamic.shdr.sh_size == source->dynamic.data->d_size);

        source->rel.idx = source->rel.sz_idx = -1;
        source->jmprel.idx = source->jmprel.sz_idx = -1;

        for (dynidx = 0; dynidx < numdyn; dynidx++) {
            dyn = gelf_getdyn (source->dynamic.data,
                               dynidx,
                               &dyn_mem);
            FAILIF_LIBELF(NULL == dyn, gelf_getdyn);
            /* When we are processing only the local relocations in a file,
               we don't need to handle any of the dependencies.  It won't
               hurt if we do, but we will be doing unnecessary work.
            */
            switch (dyn->d_tag)
            {
            case DT_NEEDED:
                if (!locals_only) {
                    /* Process the needed library recursively.
                     */
                    const char *dep_lib =
#if ELF_STRPTR_IS_BROKEN
                        (((char *)elf_getdata(
                            elf_getscn(source->elf,
                                       source->dynamic.shdr.sh_link),
                            NULL)->d_buf) + dyn->d_un.d_val);
#else
                    elf_strptr (source->elf,
                                source->dynamic.shdr.sh_link,
                                dyn->d_un.d_val);
#endif
                    ASSERT(dep_lib != NULL);
                    INFO("[%s] depends on [%s].\n", filename, dep_lib);
                    ASSERT(output == NULL || is_file == 0);
                    source_t *dep = process_file(dep_lib,
                                                 output, is_file,
                                                 report_library_size_in_memory,
                                                 get_next_link_address,
                                                 locals_only,
                                                 lib_lookup_dirs,
                                                 num_lib_lookup_dirs,
                                                 default_libs,
                                                 num_default_libs,
                                                 dry_run,
                                                 total_num_handled_relocs,
                                                 total_num_unhandled_relocs);

                    /* Add the library to the dependency list. */
                    if (source->num_lib_deps == source->lib_deps_size) {
                        source->lib_deps_size += 10;
                        source->lib_deps = REALLOC(source->lib_deps,
                                                   source->lib_deps_size *
                                                   sizeof(source_t *));
                    }
                    source->lib_deps[source->num_lib_deps++] = dep;
                }
                break;
            case DT_JMPREL:
                source->jmprel.idx = dynidx;
                source->jmprel.addr = dyn->d_un.d_ptr;
                break;
            case DT_PLTRELSZ:
                source->jmprel.sz_idx = dynidx;
                source->jmprel.size = dyn->d_un.d_val;
                break;
            case DT_REL:
                source->rel.idx = dynidx;
                source->rel.addr = dyn->d_un.d_ptr;
                break;
            case DT_RELSZ:
                source->rel.sz_idx = dynidx;
                source->rel.size = dyn->d_un.d_val;
                break;
            case DT_RELA:
            case DT_RELASZ:
                FAILIF(1, "Can't handle DT_RELA and DT_RELASZ entries!\n");
                break;
            } /* switch */
        } /* for each dynamic entry... */

        INFO("Handling [%s].\n", filename);

#ifdef SUPPORT_ANDROID_PRELINK_TAGS
        if (!source->prelinked)
#endif
		{
            /* When ADJUST_ELF is defined, this call to prelink is a dry run
               intended to calculate the number of relocations that could not
               be handled.  This, in turn, allows us to calculate the amount by
               which we can shrink the various relocation sections before we
               call adjust_elf.  After we've adjusted the sections, we will
               call prelink() one more time to do the actual work.

               NOTE: Even when ADJUST_ELF != 0, we cannot adjust an ELF file
               that is an executabe, because an executable is not PIC.
            */

            int num_unfinished_relocs = 0;
            bool adjust_file = ADJUST_ELF && source->elf_hdr.e_type != ET_EXEC;
            INFO("\n\n\tPRELINKING %s\n\n",
                 adjust_file ?
                 "(CALCULATE NUMBER OF HANDLED RELOCATIONS)" :
                 "(ACTUAL)");
            int num_relocs = prelink(source, locals_only,
                                     adjust_file || dry_run,
                                     lib_lookup_dirs, num_lib_lookup_dirs,
                                     default_libs, num_default_libs,
                                     &num_unfinished_relocs);
            INFO("[%s]: (calculate changes) handled %d, could not handle %d "
                 "relocations.\n",
                 source->name,
                 num_relocs,
                 num_unfinished_relocs);

            if (adjust_file && !dry_run)
            {
                /* Find out the new section sizes of the relocation sections,
                   but do not move any relocations around, because adjust_elf
                   needs to know about all relocations in order to adjust the
                   file correctly.
                */
                match_relocation_sections_to_dynamic_ranges(source);

                /* We haven't set up source->shdr_info[] yet, so we do it now.

                   NOTE: setup_shdr_info() depends only on source->oldelf, not
                   on source->elf!  source->elf is not even defined yet.  We
                   initialize source->shdr_info[] based on the section
                   information of the unmodified ELF file, and then make our
                   modifications in the call to adjust_dynamic_segment() based
                   on this information.  adjust_dynamic_segment() will
                   rearrange the unhandled relocations in the beginning of
                   their relocation sections, and adjust the size of those
                   relocation sections.  In the case when a relocation section
                   is completely handled, adjust_dynamic_segment() will mark it
                   for removal by function adjust_elf.
                 */

                ASSERT(source->elf == source->oldelf);
                ASSERT(source->shdr_info == NULL);
                setup_shdr_info(source);
                ASSERT(source->shdr_info != NULL);

                INFO("\n\n\tADJUSTING DYNAMIC SEGMENT "
                     "(CALCULATE CHANGES)\n\n");
                bool drop_some_sections = adjust_dynamic_segment(source, true);

                /* Reopen the elf file!  Note that we are not doing a dry run
                   (the if statement above makes sure of that.)

                   NOTE: We call init_elf() after we called
                         adjust_dynamic_segment() in order to have
                         adjust_dynamic_segment() refer to source->oldelf when
                         it refers to source->elf.  Since
                         adjust_dynamic_segment doesn't actually write to the
                         ELF file, this is OK.  adjust_dynamic_segment()
                         updates the sh_size fields of saved section headers
                         and optionally marks sections for removal.

                         Having adjust_dynamic_segment() refer to
                         source->oldelf means that we'll have access to
                         section-name strings so we can print them out in our
                         logging and debug output.
                */
                source->elf = init_elf(source, false);

                /* This is the same code as in init_source() after the call to
                 * init_elf(). */
                ASSERT(source->elf != source->oldelf);
                ebl_closebackend(source->ebl);
                source->ebl = ebl_openbackend (source->elf);
                FAILIF_LIBELF(NULL == source->ebl, ebl_openbackend);
#ifdef ARM_SPECIFIC_HACKS
                FAILIF_LIBELF(0 != arm_init(source->elf,
                                            source->elf_hdr.e_machine,
                                            source->ebl, sizeof(Ebl)),
                              arm_init);
#endif/*ARM_SPECIFIC_HACKS*/

                if (drop_some_sections)
                    drop_sections(source);
                else {
                  INFO("All sections remain in [%s]--we are changing at "
                       "most section sizes.\n", source->name);
                    create_elf_sections(source, NULL);
                    int cnt, idx;
                    for (cnt = idx = 1; cnt < source->shnum; ++cnt) {
                        Elf_Data *data = elf_getdata(
                            source->shdr_info[cnt].newscn, // new section
                            NULL);
                        if (data->d_size !=
                            source->shdr_info[cnt].shdr.sh_size) {
                            INFO("Trimming new-section data from %d to %lld "
                                 "bytes (as calculated by "
                                 "adjust_dynamic_segment()).\n",
                                 data->d_size,
                                 source->shdr_info[cnt].shdr.sh_size);
                            data->d_size = source->shdr_info[cnt].shdr.sh_size;
                        }
                    }
                }

                /* Shrink it! */
                INFO("\n\n\tADJUSTING ELF\n\n");
                adjust_elf(
                    source->oldelf, source->name,
                    source->elf, source->name,
                    source->ebl,
                    &source->old_ehdr_mem,
                    NULL, 0, // no symbol filter
                    source->shdr_info, // information on how to adjust the ELF
                    source->shnum, // length of source->shdr_info[]
                    source->phdr_info, // program-header info
                    source->shnum, // irrelevant--we're not rebuilding shstrtab
                    source->shnum, // number of sections in file
                    source->shstrndx, // index of shstrtab (both in 
                                      // shdr_info[] and as a section index)
                    NULL, // irrelevant, since we are not rebuilding shstrtab
                    drop_some_sections, // some sections are being dropped
                    elf_ndxscn(source->dynamic.scn), // index of .dynamic
                    elf_ndxscn(source->symtab.scn), // index of .dynsym
                    1, // allow shady business
                    &source->shstrtab_data,
                    true,
                    false); // do not rebuild shstrtab

                INFO("\n\n\tREINITIALIZING STRUCTURES "
                     "(TO CONTAIN ADJUSTMENTS)\n\n");
                reinit_source(source);

                INFO("\n\n\tPRELINKING (ACTUAL)\n\n");
#ifdef DEBUG
                int old_num_unfinished_relocs = num_unfinished_relocs;
#endif
                num_unfinished_relocs = 0;
#ifdef DEBUG
                int num_relocs_take_two =
#endif
                prelink(source, locals_only,
                        false, /* not a dry run */
                        lib_lookup_dirs, num_lib_lookup_dirs,
                        default_libs, num_default_libs,
                        &num_unfinished_relocs);

                /* The numbers for the total number of relocations and the
                   number of unhandled relocations between the first and second
                   invokationof prelink() must be the same!  The first time we
                   ran prelink() just to calculate the numbers so that we could
                   calculate the adjustments to pass to adjust_elf, and the
                   second time we actually carry out the prelinking; the
                   numbers must stay the same!
                */
                ASSERT(num_relocs == num_relocs_take_two);
                ASSERT(old_num_unfinished_relocs == num_unfinished_relocs);

                INFO("[%s]: (actual prelink) handled %d, could not "
                     "handle %d relocations.\n",
                     source->name,
                     num_relocs,
                     num_unfinished_relocs);
            } /* if (adjust_elf && !dry_run) */

            *total_num_handled_relocs += num_relocs;
            *total_num_unhandled_relocs += num_unfinished_relocs;

            if(num_unfinished_relocs != 0 &&
               source->elf_hdr.e_type != ET_EXEC &&
               !locals_only)
            {
                /* One reason you could have unfinished relocations in an
                   executable file is if this file used dlopen() and friends.
                   We do not adjust relocation entries to those symbols,
                   because libdl is a dummy only--the real functions are
                   provided for by the dynamic linker itsef.

                   NOTE FIXME HACK:  This is specific to the Android dynamic
                   linker, and may not be true in other cases.
                */
                PRINT("WARNING: Expecting to have unhandled relocations only "
                      "for executables (%s is not an executable)!\n",
                      source->name);
            }

            match_relocation_sections_to_dynamic_ranges(source);

            /* Now, for each relocation section, check to see if its address
               matches one of the DT_DYNAMIC relocation pointers.  If so, then
               if the section has no unhandled relocations, simply set the
               associated DT_DYNAMIC entry's size to zero.  If the section does
               have unhandled entries, then lump them all together at the front
               of the respective section and update the size of the respective
               DT_DYNAMIC entry to the new size of the section.  A better
               approach would be do delete a relocation section if it has been
               fully relocated and to remove its entry from the DT_DYNAMIC
               array, and for relocation entries that still have some
               relocations in them, we should shrink the section if that won't
               violate relative offsets.  This is more work, however, and for
               the speed improvement we expect from a prelinker, just patching
               up DT_DYNAMIC will suffice.

               Note: adjust_dynamic_segment() will modify source->shdr_info[]
                     to denote any change in a relocation section's size.  This
                     will be picked up by adjust_elf, which will rearrange the
                     file to eliminate the gap created by the decrease in size
                     of the relocation section.  We do not need to do this, but
                     the relocation section could be large, and reduced
                     drastically by the prelinking process, so it pays to
                     adjust the file.
            */

            INFO("\n\n\tADJUSTING DYNAMIC SEGMENT (ACTUAL)\n\n");
            adjust_dynamic_segment(source, false);
        }
#ifdef SUPPORT_ANDROID_PRELINK_TAGS
        else INFO("[%s] is already prelinked at 0x%08lx.\n",
                  filename,
                  source->prelink_base);
#endif
    } else INFO("[%s] has been processed already.\n", filename);

    return source;
}

void apriori(char **execs, int num_execs,
             char *output,
             void (*report_library_size_in_memory)(
                 const char *name, off_t fsize),
             int (*get_next_link_address)(const char *name),
             int locals_only,
             int dry_run,
             char **lib_lookup_dirs, int num_lib_lookup_dirs,
             char **default_libs, int num_default_libs,
			 char *mapfile)
{
    source_t *source; /* for general usage */
    int input_idx;

    ASSERT(report_library_size_in_memory != NULL);
    ASSERT(get_next_link_address != NULL);

    /* Process and prelink each executable and object file.  Function
       process_file() is called for each executable in the loop below.
       It calls itself recursively for each library.   We prelink each library
       after prelinking its dependencies. */
    int total_num_handled_relocs = 0, total_num_unhandled_relocs = 0;
    for (input_idx = 0; input_idx < num_execs; input_idx++) {
        INFO("executable: [%s]\n", execs[input_idx]);
        /* Here process_file() is actually processing the top-level
           executable files. */
        process_file(execs[input_idx], output, num_execs == 1,
                     report_library_size_in_memory,
                     get_next_link_address, /* executables get a link address
                                               of zero, regardless of this 
                                               value */
                     locals_only,
                     lib_lookup_dirs, num_lib_lookup_dirs,
                     default_libs, num_default_libs,
                     dry_run,
                     &total_num_handled_relocs,
                     &total_num_unhandled_relocs);
        /* if source is NULL, then the respective executable is static */
        /* Mark the source as an executable */
    } /* for each input executable... */

    PRINT("Handled %d relocations.\n", total_num_handled_relocs);
    PRINT("Could not handle %d relocations.\n", total_num_unhandled_relocs);

    /* We are done!  Since the end result of our calculations is a set of
       symbols for each library that other libraries or executables link
       against, we iterate over the set of libraries one last time, and for
       each symbol that is marked as satisfying some dependence, we emit
       a line with the symbol's name to a text file derived from the library's
       name by appending the suffix .syms to it. */

    if (mapfile != NULL) {
        const char *mapfile_name = mapfile;
		FILE *fp;
        if (*mapfile == '+') {
            mapfile_name = mapfile + 1;
            INFO("Opening map file %s for append/write.\n",
                 mapfile_name);
            fp = fopen(mapfile_name, "a");
        }
        else fp = fopen(mapfile_name, "w");

		FAILIF(fp == NULL, "Cannot open file [%s]: %s (%d)!\n",
			   mapfile_name,
			   strerror(errno),
			   errno);
        source = sources;
        while (source) {
            /* If it's a library, print the results. */
            if (source->elf_hdr.e_type == ET_DYN) {
                /* Add to the memory map file. */
				fprintf(fp, "%s 0x%08lx %lld\n",
						basename(source->name),
						source->base,
						source->elf_file_info.st_size);
            }
            source = source->next;
        }
		fclose(fp);
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
