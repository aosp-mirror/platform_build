/* TODO:
   1. check the ARM EABI version--this works for versions 1 and 2.
   2. use a more-intelligent approach to finding the symbol table, symbol-string
      table, and the .dynamic section.
   3. fix the determination of the host and ELF-file endianness
   4. write the help screen
*/

#include <stdio.h>
#include <common.h>
#include <debug.h>
#include <hash.h>
#include <libelf.h>
#include <elf.h>
#include <gelf.h>
#include <cmdline.h>
#include <string.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <soslim.h>
#include <symfilter.h>
#ifdef SUPPORT_ANDROID_PRELINK_TAGS
#include <prelink_info.h>
#endif

/* Flag set by --verbose.  This variable is global as it is accessed by the
   macro INFO() in multiple compilation unites. */
int verbose_flag = 0;
/* Flag set by --quiet.  This variable is global as it is accessed by the
   macro PRINT() in multiple compilation unites. */
int quiet_flag = 0;
static void print_dynamic_symbols(Elf *elf, const char *symtab_name);

int main(int argc, char **argv)
{
    int elf_fd = -1, newelf_fd = -1;
    Elf *elf = NULL, *newelf = NULL;
    char *infile = NULL;
    char *outfile = NULL;
    char *symsfile_name = NULL;
    int print_symtab = 0;
    int shady = 0;
    int dry_run = 0;
    int strip_debug = 0;

    /* Do not issue INFO() statements before you call get_options() to set
       the verbose flag as necessary.
    */

    int first = get_options(argc, argv,
                            &outfile,
                            &symsfile_name,
                            &print_symtab,
                            &verbose_flag,
                            &quiet_flag,
                            &shady,
                            &dry_run,
                            &strip_debug);

    if ((print_symtab && (first == argc)) ||
        (!print_symtab && first + 1 != argc)) {
        print_help();
        FAILIF(1,  "You must specify an input ELF file!\n");
    }
    FAILIF(print_symtab && (outfile || symsfile_name || shady),
           "You cannot provide --print and --outfile, --filter options, or "
           "--shady simultaneously!\n");
    FAILIF(dry_run && outfile,
           "You cannot have a dry run and output a file at the same time.");

    /* Check to see whether the ELF library is current. */
    FAILIF (elf_version(EV_CURRENT) == EV_NONE, "libelf is out of date!\n");

    if (print_symtab) {

        while (first < argc) {
            infile = argv[first++];

            INFO("Opening %s...\n", infile);
            elf_fd = open(infile, O_RDONLY);
            FAILIF(elf_fd < 0, "open(%s): %s (%d)\n",
                   infile,
                   strerror(errno),
                   errno);
            INFO("Calling elf_begin(%s)...\n", infile);
            elf = elf_begin(elf_fd, ELF_C_READ, NULL);
            FAILIF_LIBELF(elf == NULL, elf_begin);

            /* libelf can recognize COFF and A.OUT formats, but we handle only
               ELF. */
            FAILIF(elf_kind(elf) != ELF_K_ELF,
                   "Input file %s is not in ELF format!\n",
                   infile);

            /* Make sure this is a shared library or an executable. */
            {
                GElf_Ehdr elf_hdr;
                INFO("Making sure %s is a shared library or an executable.\n",
                     infile);
                FAILIF_LIBELF(0 == gelf_getehdr(elf, &elf_hdr), gelf_getehdr);
                FAILIF(elf_hdr.e_type != ET_DYN &&
                       elf_hdr.e_type != ET_EXEC,
                       "%s must be a shared library or an executable "
                       "(elf type is %d).\n",
                       infile,
                       elf_hdr.e_type);
            }

            print_dynamic_symbols(elf, infile);

            FAILIF_LIBELF(elf_end(elf), elf_end);
            FAILIF(close(elf_fd) < 0, "Could not close file %s: %s (%d)!\n",
                   infile, strerror(errno), errno);
        }
    }
    else {
        int elf_fd = -1;
        Elf *elf = NULL;
        infile = argv[first];

        INFO("Opening %s...\n", infile);
        elf_fd = open(infile, ((outfile == NULL && dry_run == 0) ? O_RDWR : O_RDONLY));
        FAILIF(elf_fd < 0, "open(%s): %s (%d)\n",
               infile,
               strerror(errno),
               errno);
        INFO("Calling elf_begin(%s)...\n", infile);
        elf = elf_begin(elf_fd,
                        ((outfile == NULL && dry_run == 0) ? ELF_C_RDWR : ELF_C_READ),
                        NULL);
        FAILIF_LIBELF(elf == NULL, elf_begin);

        /* libelf can recognize COFF and A.OUT formats, but we handle only ELF. */
        FAILIF(elf_kind(elf) != ELF_K_ELF,
               "Input file %s is not in ELF format!\n",
               infile);

        /* We run a better check in adjust_elf() itself.  It is permissible to call adjust_elf()
           on an executable if we are only stripping sections from the executable, not rearranging
           or moving sections.
        */
        if (0) {
            /* Make sure this is a shared library. */
            GElf_Ehdr elf_hdr;
            INFO("Making sure %s is a shared library...\n", infile);
            FAILIF_LIBELF(0 == gelf_getehdr(elf, &elf_hdr), gelf_getehdr);
            FAILIF(elf_hdr.e_type != ET_DYN,
                   "%s must be a shared library (elf type is %d, expecting %d).\n",
                   infile,
                   elf_hdr.e_type,
                   ET_DYN);
        }

        if (outfile != NULL) {
            ASSERT(!dry_run);
            struct stat st;
            FAILIF(fstat (elf_fd, &st) != 0,
                   "Cannot stat input file %s: %s (%d)!\n",
                   infile, strerror(errno), errno);
            newelf_fd = open (outfile, O_RDWR | O_CREAT | O_TRUNC,
                    st.st_mode & ACCESSPERMS);
            FAILIF(newelf_fd < 0, "Cannot create file %s: %s (%d)!\n",
                   outfile, strerror(errno), errno);
            INFO("Output file is [%s].\n", outfile);
            newelf = elf_begin(newelf_fd, ELF_C_WRITE_MMAP, NULL);
        } else {
            INFO("Modifying [%s] in-place.\n", infile);
            newelf = elf_clone(elf, ELF_C_EMPTY);
        }

        symfilter_t symfilter;

        symfilter.symbols_to_keep = NULL;
        symfilter.num_symbols_to_keep = 0;
        if (symsfile_name) {
            /* Make sure that the file is not empty. */
            struct stat s;
            FAILIF(stat(symsfile_name, &s) < 0,
                   "Cannot stat file %s.\n", symsfile_name);
            if (s.st_size) {
                INFO("Building symbol filter.\n");
                build_symfilter(symsfile_name, elf, &symfilter, s.st_size);
            }
            else INFO("Not building symbol filter, filter file is empty.\n");
        }
#ifdef SUPPORT_ANDROID_PRELINK_TAGS
        int prelinked = 0, retouched = 0;
        int elf_little; /* valid if prelinked != 0 */
        long prelink_addr; /* valid if prelinked != 0 */
#define RETOUCH_MAX_SIZE 600000
        /* _cnt valid if retouched != 0 */
        unsigned int retouch_byte_cnt = RETOUCH_MAX_SIZE;
        char retouch_buf[RETOUCH_MAX_SIZE]; /* valid if retouched != 0 */
#endif
        clone_elf(elf, newelf,
                  infile, outfile,
                  symfilter.symbols_to_keep,
                  symfilter.num_symbols_to_keep,
                  shady
#ifdef SUPPORT_ANDROID_PRELINK_TAGS
                  , &prelinked,
                  &elf_little,
                  &prelink_addr,
                  &retouched,
                  &retouch_byte_cnt,
                  retouch_buf
#endif
                  ,
                  true, /* rebuild the section-header-strings table */
                  strip_debug,
                  dry_run);

        if (symsfile_name && symfilter.symbols_to_keep != NULL) {
            destroy_symfilter(&symfilter);
        }

        if (outfile != NULL) INFO("Closing %s...\n", outfile);
        FAILIF_LIBELF(elf_end (newelf) != 0, elf_end);
        FAILIF(newelf_fd >= 0 && close(newelf_fd) < 0,
               "Could not close file %s: %s (%d)!\n",
               outfile, strerror(errno), errno);

        INFO("Closing %s...\n", infile);
        FAILIF_LIBELF(elf_end(elf), elf_end);
        FAILIF(close(elf_fd) < 0, "Could not close file %s: %s (%d)!\n",
               infile, strerror(errno), errno);

#ifdef SUPPORT_ANDROID_PRELINK_TAGS
        if (retouched) {
            INFO("File has retouch data, putting it back in place.\n");
            retouch_dump(outfile != NULL ? outfile : infile,
                         elf_little,
                         retouch_byte_cnt,
                         retouch_buf);
        }
        if (prelinked) {
            INFO("File is prelinked, putting prelink TAG back in place.\n");
            setup_prelink_info(outfile != NULL ? outfile : infile,
                               elf_little,
                               prelink_addr);
        }
#endif
    }

    FREEIF(outfile);
    return 0;
}

static void print_dynamic_symbols(Elf *elf, const char *file)
{
    Elf_Scn *scn = NULL;
    GElf_Shdr shdr;

    GElf_Ehdr ehdr;
    FAILIF_LIBELF(0 == gelf_getehdr(elf, &ehdr), gelf_getehdr);
    while ((scn = elf_nextscn (elf, scn)) != NULL) {
        FAILIF_LIBELF(NULL == gelf_getshdr(scn, &shdr), gelf_getshdr);
        if (SHT_DYNSYM == shdr.sh_type) {
            /* This failure is too restrictive.  There is no reason why
               the symbol table couldn't be called something else, but
               there is a standard name, and chances are that if we don't
               see it, there's something wrong.
            */
            size_t shstrndx;
            FAILIF_LIBELF(elf_getshstrndx(elf, &shstrndx) < 0,
                          elf_getshstrndx);
            /* Now print the symbols. */
            {
                Elf_Data *symdata;
                size_t elsize;
                symdata = elf_getdata (scn, NULL); /* get the symbol data */
                FAILIF_LIBELF(NULL == symdata, elf_getdata);
                /* Get the number of section.  We need to compare agains this
                   value for symbols that have special info in their section
                   references */
                size_t shnum;
                FAILIF_LIBELF(elf_getshnum (elf, &shnum) < 0, elf_getshnum);
                /* Retrieve the size of a symbol entry */
                elsize = gelf_fsize(elf, ELF_T_SYM, 1, ehdr.e_version);

                size_t index;
                for (index = 0; index < symdata->d_size / elsize; index++) {
                    GElf_Sym sym_mem;
                    GElf_Sym *sym;
                    /* Get the symbol. */
                    sym = gelf_getsymshndx (symdata, NULL,
                                            index, &sym_mem, NULL);
                    FAILIF_LIBELF(sym == NULL, gelf_getsymshndx);
                    /* Print the symbol. */
                    char bind = '?';
                    switch(ELF32_ST_BIND(sym->st_info))
                    {
                    case STB_LOCAL: bind = 'l'; break;
                    case STB_GLOBAL: bind = 'g'; break;
                    case STB_WEAK: bind = 'w'; break;
                    default: break;
                    }
                    char type = '?';
                    switch(ELF32_ST_TYPE(sym->st_info))
                    {
                    case STT_NOTYPE: /* Symbol type is unspecified */
                        type = '?';
                        break;
                    case STT_OBJECT: /* Symbol is a data object */
                        type = 'o';
                        break;
                    case STT_FUNC: /* Symbol is a code object */
                        type = 'f';
                        break;
                    case STT_SECTION:/* Symbol associated with a section */
                        type = 's';
                        break;
                    case STT_FILE: /* Symbol's name is file name */
                        type = 'f';
                        break;
                    case STT_COMMON: /* Symbol is a common data object */
                        type = 'c';
                        break;
                    case STT_TLS: /* Symbol is thread-local data object*/
                        type = 't';
                        break;
                    }
                    {
                        int till_lineno;
                        int lineno;
                        const char *section_name = "(unknown)";
                        FAILIF(sym->st_shndx == SHN_XINDEX,
                               "Can't handle symbol's st_shndx == SHN_XINDEX!\n");
                        if (sym->st_shndx != SHN_UNDEF &&
                            sym->st_shndx < shnum) {
                            Elf_Scn *symscn = elf_getscn(elf, sym->st_shndx);
                            FAILIF_LIBELF(NULL == symscn, elf_getscn);
                            GElf_Shdr symscn_shdr;
                            FAILIF_LIBELF(NULL == gelf_getshdr(symscn,
                                                               &symscn_shdr),
                                          gelf_getshdr);
                            section_name = elf_strptr(elf, shstrndx,
                                                      symscn_shdr.sh_name);
                        }
                        else if (sym->st_shndx == SHN_ABS) {
                            section_name = "SHN_ABS";
                        }
                        else if (sym->st_shndx == SHN_COMMON) {
                            section_name = "SHN_COMMON";
                        }
                        else if (sym->st_shndx == SHN_UNDEF) {
                            section_name = "(undefined)";
                        }
                        /* value size binding type section symname */
                        PRINT("%-15s %8zd: %08llx %08llx %c%c %5d %n%s%n",
                              file,
                              index,
                              sym->st_value, sym->st_size, bind, type,
                              sym->st_shndx,
                              &till_lineno,
                              section_name,
                              &lineno);
                        lineno -= till_lineno;
                        /* Create padding for section names of 15 chars.
                           This limit is somewhat arbitratry. */
                        while (lineno++ < 15) PRINT(" ");
                        PRINT("(%d) %s\n",
                              sym->st_name,
                              elf_strptr(elf, shdr.sh_link, sym->st_name));
                    }
                }
            }
        } /* if (shdr.sh_type = SHT_DYNSYM) */
    } /* while ((scn = elf_nextscn (elf, scn)) != NULL) */
}
