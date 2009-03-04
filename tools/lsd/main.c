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
#include <lsd.h>

/* Flag set by --verbose.  This variable is global as it is accessed by the
   macro INFO() in multiple compilation unites. */
int verbose_flag = 0;
/* Flag set by --quiet.  This variable is global as it is accessed by the
   macro PRINT() in multiple compilation unites. */
int quiet_flag = 0;

int main(int argc, char **argv)
{
    char **lookup_dirs = NULL;
    int num_lookup_dirs;
	int print_info;
	int list_needed_libs;

    /* Do not issue INFO() statements before you call get_options() to set 
       the verbose flag as necessary.
    */

    int first = get_options(argc, argv,
							&list_needed_libs,
							&print_info,
                            &lookup_dirs,
                            &num_lookup_dirs,
                            &verbose_flag);

    if (first == argc) {
        print_help();
        FAILIF(1,  "You must specify at least one input ELF file!\n");
    }

    /* Check to see whether the ELF library is current. */
    FAILIF (elf_version(EV_CURRENT) == EV_NONE, "libelf is out of date!\n");

    /* List symbol dependencies... */
    lsd(&argv[first], argc - first, 
		list_needed_libs, print_info, 
		lookup_dirs, num_lookup_dirs);

    FREE(lookup_dirs);

    return 0;
} 

