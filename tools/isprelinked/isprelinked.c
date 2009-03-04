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
#include <rangesort.h>
#include <prelink_info.h>
#include <libgen.h>


/* Flag set by --verbose.  This variable is global as it is accessed by the
   macro INFO() in multiple compilation unites. */
int verbose_flag = 0;
/* Flag set by --quiet.  This variable is global as it is accessed by the
   macro PRINT() in multiple compilation unites. */
int quiet_flag = 0;

int main(int argc, char **argv) {

    argc--, argv++;
    if (!argc)
        return 0;

    /* Check to see whether the ELF library is current. */
    FAILIF (elf_version(EV_CURRENT) == EV_NONE, "libelf is out of date!\n");

    const char *filename;
    for (; argc; argc--) {
        filename = *argv++;

        Elf *elf;
        GElf_Ehdr elf_hdr;
        int fd; 
        int prelinked;
        long prelink_addr = 0;

        INFO("Processing file [%s]\n", filename);

        fd = open(filename, O_RDONLY);
        FAILIF(fd < 0, "open(%d): %s (%d).\n", 
               filename,
               strerror(errno),
               errno);

        elf = elf_begin(fd, ELF_C_READ_MMAP_PRIVATE, NULL);
        FAILIF_LIBELF(elf == NULL, elf_begin);

        FAILIF_LIBELF(0 == gelf_getehdr(elf, &elf_hdr), 
                      gelf_getehdr);

#ifdef SUPPORT_ANDROID_PRELINK_TAGS
        prelinked = check_prelinked(filename, elf_hdr.e_ident[EI_DATA] == ELFDATA2LSB, 
                                    &prelink_addr);
#else
        #error 'SUPPORT_ANDROID_PRELINK_TAGS is not defined!'
#endif

        if (prelinked)
            PRINT("%s: 0x%08x\n", filename, prelink_addr);
        else
            PRINT("%s: not prelinked\n", filename);

        FAILIF_LIBELF(elf_end(elf), elf_end);
        close(fd);
    }
    
    return 0;
} 

