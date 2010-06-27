#include <debug.h>
#include <common.h>
#include <symfilter.h>
#include <hash.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <libelf.h>
#include <gelf.h>
#include <ctype.h>

#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

static int match_hash_table_section(Elf *elf, Elf_Scn *sect, void *data);
static int match_dynsym_section(Elf *elf, Elf_Scn *sect, void *data);

void build_symfilter(const char *name, Elf *elf, symfilter_t *filter, 
                     off_t fsize)
{
    char *line = NULL;
    symfilter_list_t *symbol;

    FAILIF(NULL == name,
           "You must provide a list of symbols to filter on!\n");

    filter->num_symbols = 0;
    filter->total_name_length = 0;

    /* Open the file. */
    INFO("Opening symbol-filter file %s...\n", name);
    filter->fd = open(name, O_RDONLY);
    FAILIF(filter->fd < 0, "open(%s): %s (%d)\n",
           name, 
           strerror(errno),
           errno);

    INFO("Symbol-filter file %s is %zd bytes long...\n",
         name,
         (size_t)fsize);
    filter->fsize = fsize;

    /* mmap the symbols file */
    filter->mmap = mmap(NULL, fsize, 
                        PROT_READ | PROT_WRITE, MAP_PRIVATE, 
                        filter->fd, 0);
    FAILIF(MAP_FAILED == filter->mmap, 
           "mmap(NULL, %zd, PROT_READ, MAP_PRIVATE, %d, 0): %s (%d)\n",
           (size_t)fsize,
           filter->fd,
           strerror(errno),
           errno);
    INFO("Memory-mapped symbol-filter file at %p\n", filter->mmap);

    /* Make sure that the ELF file has a hash table.  We will use the hash 
       table to look up symbols quickly.  If the library does not have a hash-
       table section, we can still do a linear scan, but the code for that is
       not written, as practically every shared library has a hash table.
    */

    filter->symtab.sect = NULL;
    map_over_sections(elf, match_dynsym_section, filter);
    FAILIF(NULL == filter->symtab.sect, 
           "There is no dynamic-symbol table in this library.\n");
    filter->hash.sect = NULL;
    map_over_sections(elf, match_hash_table_section, filter);
    FAILIF(NULL == filter->hash.sect, 
           "There is no hash table in this library.\n");
    INFO("Hash table size 0x%lx, data size 0x%lx.\n",
         (unsigned long)filter->hash.hdr->sh_size,
         (unsigned long)filter->hash.data->d_size);

    INFO("Hash table file offset: 0x%x\n", filter->hash.hdr->sh_offset);

    GElf_Ehdr *ehdr, ehdr_mem;
    ehdr = gelf_getehdr(elf, &ehdr_mem);
    size_t symsize = gelf_fsize (elf, ELF_T_SYM, 1, ehdr->e_version);
    ASSERT(symsize);
    filter->num_symbols_to_keep = filter->symtab.data->d_size / symsize;
    filter->symbols_to_keep = (bool *)CALLOC(filter->num_symbols_to_keep, 
                                             sizeof(bool));

    /* Build the symbol-name chain. */
    INFO("Building symbol list...\n");
    
    line = (char *)filter->mmap;

    filter->symbols = NULL;
#define NOT_DONE ((off_t)(line - (char *)filter->mmap) < fsize)
    do {
        char *name = line;

        /* Advance to the next line.  We seek out spaces or new lines.  At the
           first space or newline character we find, we place a '\0', and 
           continue till we've consumed the line.  For new lines, we scan both
           '\r' and '\n'.  For spaces, we look for ' ', '\t', and '\f'
        */

        while (NOT_DONE && !isspace(*line)) line++;
        if (likely(NOT_DONE)) {
            *line++ = '\0';
            if (line - name > 1) {
                /* Add the entry to the symbol-filter list */
                symbol = (symfilter_list_t *)MALLOC(sizeof(symfilter_list_t));
                symbol->next = filter->symbols;
                symbol->name = name;
                filter->symbols = symbol;

#if 0 
                /* SLOW!  For debugging only! */
                {
                    size_t idx;
                    size_t elsize = gelf_fsize(elf, ELF_T_SYM, 1, 
                                               ehdr->e_version);
                    symbol->index = SHN_UNDEF;
                    for (idx = 0; idx < filter->symtab.data->d_size / elsize;
                         idx++) {
                        GElf_Sym sym_mem;
                        GElf_Sym *sym;
                        const char *symname;
                        sym = gelf_getsymshndx (filter->symtab.data, NULL, 
                                                idx, &sym_mem, NULL);
                        ASSERT(sym);

                        symname = elf_strptr(elf, 
                                             filter->symtab.hdr->sh_link,
                                             sym->st_name);
                        if(!strcmp(symname, symbol->name)) {
                            symbol->index = idx;
                            break;
                        }
                    }
                }
#else
                /* Look up the symbol in the ELF file and associate it with the
                   entry in the filter. */
                symbol->index = hash_lookup(elf,
                                            &filter->hash,
                                            &filter->symtab,
                                            symbol->name,
                                            &symbol->symbol);
#endif                                            
                symbol->len = line - name - 1;
                ASSERT(symbol->len == strlen(symbol->name));

                /* If we didn't find the symbol, then it's not in the library. 
                 */

                if(STN_UNDEF == symbol->index) {
                    PRINT("%s: symbol was not found!\n", symbol->name);
                }
                else {
                    /* If we found the symbol but it's an undefined symbol, then
                       it's not in the library as well. */
                    GElf_Sym sym_mem;
                    GElf_Sym *sym;
                    sym = gelf_getsymshndx (filter->symtab.data, NULL, 
                                            symbol->index, &sym_mem, NULL);
                    FAILIF_LIBELF(NULL == sym, gelf_getsymshndx);
                    /* Make sure the hash lookup worked. */
                    ASSERT(!strcmp(elf_strptr(elf, 
                                              filter->symtab.hdr->sh_link,
                                              sym->st_name),
                                   symbol->name));
                    if (sym->st_shndx == SHN_UNDEF) {
                        PRINT("%s: symbol was not found (undefined)!\n", symbol->name);
                    }
                    else {
                        filter->num_symbols++;
                        /* Total count includes null terminators */
                        filter->total_name_length += symbol->len + 1; 

                        /* Set the flag in the symbols_to_keep[] array.  This indicates
                           to function copy_elf() that we want to keep the symbol.
                        */
                        filter->symbols_to_keep[symbol->index] = true;
                        INFO("FILTER-SYMBOL: [%s] [%d bytes]\n", 
                             symbol->name, 
                             symbol->len);
                    }
                }
            }
        }
    } while (NOT_DONE);
#undef NOT_DONE
}

void destroy_symfilter(symfilter_t *filter)
{
    symfilter_list_t *old;
    INFO("Destroying symbol list...\n");
    while ((old = filter->symbols)) {
        filter->symbols = old->next;
        FREE(old);
    }
    munmap(filter->mmap, filter->fsize);
    close(filter->fd);
}

static int match_hash_table_section(Elf *elf, Elf_Scn *sect, void *data)
{
    (void)elf; // unused argument

    symfilter_t *filter = (symfilter_t *)data;
    Elf32_Shdr *shdr;

    ASSERT(filter);
    ASSERT(sect);
    shdr = elf32_getshdr(sect);

    /* The section must be marked both as a SHT_HASH, and it's sh_link field 
       must contain the index of our symbol table (per ELF-file spec).
    */
    if (shdr->sh_type == SHT_HASH)
    {
        FAILIF(filter->hash.sect != NULL, 
               "There is more than one hash table!\n");
        get_section_info(sect, &filter->hash);
    }

    return 0; /* keep looking */
}

static int match_dynsym_section(Elf *elf, Elf_Scn *sect, void *data)
{
    (void)elf; // unused argument

    symfilter_t *filter = (symfilter_t *)data;
    Elf32_Shdr *shdr;

    ASSERT(filter);
    ASSERT(sect);
    shdr = elf32_getshdr(sect);

    if (shdr->sh_type == SHT_DYNSYM)
    {
        FAILIF(filter->symtab.sect != NULL, 
               "There is more than one dynamic symbol table!\n");
        get_section_info(sect, &filter->symtab);
    }

    return 0; /* keep looking */
}
