/* TODO:
   1. check the ARM EABI version--this works for versions 1 and 2.
   2. use a more-intelligent approach to finding the symbol table,
      symbol-string table, and the .dynamic section.
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
#include <apriori.h>
#include <prelinkmap.h>

/* Flag set by --verbose.  This variable is global as it is accessed by the
   macro INFO() in multiple compilation unites. */
int verbose_flag = 0;
/* Flag set by --quiet.  This variable is global as it is accessed by the
   macro PRINT() in multiple compilation unites. */
int quiet_flag = 0;
static void print_dynamic_symbols(Elf *elf, const char *symtab_name);

static unsigned s_next_link_addr;
static off_t s_addr_increment;

static void report_library_size_in_memory(const char *name, off_t fsize)
{
    ASSERT(s_next_link_addr != -1UL);
	INFO("Setting next link address (current is at 0x%08x):\n",
         s_next_link_addr);
	if (s_addr_increment) {
		FAILIF(s_addr_increment < fsize,
			   "Command-line-specified address increment of 0x%08llx (%lld) "
               "less than file [%s]'s size of %lld bytes!\n",
			   s_addr_increment, s_addr_increment, name, fsize);
		FAILIF(s_next_link_addr % 4096,
			   "User-provided address increment 0x%08lx "
               "is not page-aligned!\n",
			   s_addr_increment);
		INFO("\tignoring file size, adjusting by address increment.\n");
		s_next_link_addr += s_addr_increment;
	}
	else {
		INFO("\tuser address increment is zero, adjusting by file size.\n");
		s_next_link_addr += fsize;
		s_next_link_addr &= ~(4096 - 1);
	}
	INFO("\t[%s] file size 0x%08lx\n",
		 name,
		 fsize);
	INFO("\tnext prelink address: 0x%08x\n", s_next_link_addr);
	ASSERT(!(s_next_link_addr % 4096)); /* New address must be page-aligned */
}

static unsigned get_next_link_address(const char *name) {
    return s_next_link_addr;
}

int main(int argc, char **argv) {
    /* Do not issue INFO() statements before you call get_options() to set
       the verbose flag as necessary.
    */

    char **lookup_dirs, **default_libs;
	char *mapfile, *output, *prelinkmap;
    int start_addr, inc_addr, locals_only, num_lookup_dirs, 
        num_default_libs, dry_run;
    int first = get_options(argc, argv,
                            &start_addr, &inc_addr, &locals_only,
                            &quiet_flag,
                            &dry_run,
                            &lookup_dirs, &num_lookup_dirs,
                            &default_libs, &num_default_libs,
                            &verbose_flag,
							&mapfile,
                            &output,
                            &prelinkmap);

    /* Perform some command-line-parameter checks. */
    int cmdline_err = 0;
    if (first == argc) {
        ERROR("You must specify at least one input ELF file!\n");
        cmdline_err++;
    }
    /* We complain when the user does not specify a start address for
       prelinking when the user does not pass the locals_only switch.  The
       reason is that we will have a collection of executables, which we always
       prelink to zero, and shared libraries, which we prelink at the specified
       prelink address.  When the user passes the locals_only switch, we do not
       fail if the user does not specify start_addr, because the file to
       prelink may be an executable, and not a shared library.  At this moment,
       we do not know what the case is.  We find that out when we call function
       init_source().
    */
    if (!locals_only && start_addr == -1) {
        ERROR("You must specify --start-addr!\n");
        cmdline_err++;
    }
    if (start_addr == -1 && inc_addr != -1) {
        ERROR("You must provide a start address if you provide an "
              "address increment!\n");
        cmdline_err++;
    }
    if (prelinkmap != NULL && start_addr != -1) {
        ERROR("You may not provide a prelink-map file (-p) and use -s/-i "
              "at the same time!\n");
        cmdline_err++;
    }
    if (inc_addr == 0) {
        ERROR("You may not specify a link-address increment of zero!\n");
        cmdline_err++;
    }
    if (locals_only) {
        if (argc - first == 1) {
            if (inc_addr != -1) {
                ERROR("You are prelinking a single file; there is no point in "
                      "specifying a prelink-address increment!\n");
                /* This is nonfatal error, but paranoia is healthy. */
                cmdline_err++;
            }
        }
        if (lookup_dirs != NULL || default_libs != NULL) {
            ERROR("You are prelinking local relocations only; there is "
                  "no point in specifying lookup directories!\n");
            /* This is nonfatal error, but paranoia is healthy. */
            cmdline_err++;
        }
    }

    /* If there is an output option, then that must specify a file, if there is
       a single input file, or a directory, if there are multiple input
       files. */
    if (output != NULL) {
        struct stat output_st;
        FAILIF(stat(output, &output_st) < 0 && errno != ENOENT,
               "stat(%s): %s (%d)\n",
               output,
               strerror(errno),
               errno);

        if (argc - first == 1) {
            FAILIF(!errno && !S_ISREG(output_st.st_mode),
                   "you have a single input file: -o must specify a "
                   "file name!\n");
        }
        else {
            FAILIF(errno == ENOENT,
                   "you have multiple input files: -o must specify a "
                   "directory name, but %s does not exist!\n",
                   output);
            FAILIF(!S_ISDIR(output_st.st_mode),
                   "you have multiple input files: -o must specify a "
                   "directory name, but %s is not a directory!\n",
                   output);
        }
    }

    if (cmdline_err) {
        print_help(argv[0]);
        FAILIF(1, "There are command-line-option errors.\n");
    }

    /* Check to see whether the ELF library is current. */
    FAILIF (elf_version(EV_CURRENT) == EV_NONE, "libelf is out of date!\n");

	if (inc_addr < 0) {
        if (!locals_only)
            PRINT("User has not provided an increment address, "
                  "will use library size to calculate successive "
                  "prelink addresses.\n");
        inc_addr = 0;
	}

    void (*func_report_library_size_in_memory)(const char *name, off_t fsize);
    unsigned (*func_get_next_link_address)(const char *name);

    if (prelinkmap != NULL) {
        INFO("Reading prelink addresses from prelink-map file [%s].\n",
             prelinkmap);
        pm_init(prelinkmap);
        func_report_library_size_in_memory = pm_report_library_size_in_memory;
        func_get_next_link_address = pm_get_next_link_address;
    }
    else {
        INFO("Start address: 0x%x\n", start_addr);
        INFO("Increment address: 0x%x\n", inc_addr);
        s_next_link_addr = start_addr;
        s_addr_increment = inc_addr;
        func_report_library_size_in_memory = report_library_size_in_memory;
        func_get_next_link_address = get_next_link_address;
    }

    /* Prelink... */
    apriori(&argv[first], argc - first, output,
            func_report_library_size_in_memory, func_get_next_link_address,
            locals_only,
            dry_run,
            lookup_dirs, num_lookup_dirs,
            default_libs, num_default_libs,
			mapfile);

	FREEIF(mapfile);
    FREEIF(output);
	if (lookup_dirs) {
		ASSERT(num_lookup_dirs);
		while (num_lookup_dirs--)
			FREE(lookup_dirs[num_lookup_dirs]);
		FREE(lookup_dirs);
	}
	if (default_libs) {
		ASSERT(num_default_libs);
		while (num_default_libs--)
			FREE(default_libs[num_default_libs]);
		FREE(default_libs);
	}

    return 0;
}
