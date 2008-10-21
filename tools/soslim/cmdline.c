#include <debug.h>
#include <cmdline.h>
#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <string.h>
#include <ctype.h>

extern char *optarg;
extern int optind, opterr, optopt;

static struct option long_options[] =
{
    {"verbose",  no_argument,       0, 'V'},
    {"quiet",    no_argument,       0, 'Q'},
    {"shady",    no_argument,       0, 'S'},
    {"print",    no_argument,       0, 'p'},
    {"help",     no_argument,       0, 'h'},
    {"outfile",  required_argument, 0, 'o'},
    {"filter",   required_argument, 0, 'f'},
    {"dry",      no_argument,       0, 'n'},
    {"strip",    no_argument,       0, 's'},
    {0, 0, 0, 0},
};

/* This array must parallel long_options[] */
static
const char *descriptions[sizeof(long_options)/sizeof(long_options[0])] = {
	"print verbose output",
    "suppress errors and warnings",
    "patch ABS symbols whose values coincide with section starts and ends",
    "print the symbol table (if specified, only -V is allowed)",
    "this help screen",
    "specify an output file (if not provided, input file is modified)",
    "specify a symbol-filter file",
    "dry run (perform all calculations but do not modify the ELF file)",
    "strip debug sections, if they are present"
};

void print_help(void)
{
    fprintf(stdout,
			"invokation:\n"
			"\tsoslim file1 [file2 file3 ... fileN] [-Ldir1 -Ldir2 ... -LdirN] "
			"[-Vpn]\n"
			"or\n"
			"\tsoslim -h\n\n");
	fprintf(stdout, "options:\n");
	struct option *opt = long_options;
	const char **desc = descriptions;
	while (opt->name) {
		fprintf(stdout, "\t-%c/--%-15s %s\n",
				opt->val,
				opt->name,
				*desc);
		opt++;
		desc++;
	}
}

int get_options(int argc, char **argv,
                char **outfile,
                char **symsfile,
                int *print_symtab,
                int *verbose,
                int *quiet,
                int *shady,
                int *dry_run,
                int *strip_debug)
{
    int c;

    ASSERT(outfile);
    *outfile = NULL;
    ASSERT(symsfile);
    *symsfile = NULL;
    ASSERT(print_symtab);
    *print_symtab = 0;
    ASSERT(verbose);
    *verbose = 0;
    ASSERT(quiet);
    *quiet = 0;
    ASSERT(shady);
    *shady = 0;
    ASSERT(dry_run);
    *dry_run = 0;
    ASSERT(strip_debug);
    *strip_debug = 0;

    while (1) {
        /* getopt_long stores the option index here. */
        int option_index = 0;

        c = getopt_long (argc, argv,
                         "QVSphi:o:y:Y:f:ns",
                         long_options,
                         &option_index);
        /* Detect the end of the options. */
        if (c == -1) break;

        if (isgraph(c)) {
            INFO ("option -%c with value `%s'\n", c, (optarg ?: "(null)"));
        }

#define SET_STRING_OPTION(name) do { \
    ASSERT(optarg);                  \
    *name = strdup(optarg);          \
} while(0)

        switch (c) {
        case 0:
            /* If this option set a flag, do nothing else now. */
            if (long_options[option_index].flag != 0)
                break;
            INFO ("option %s", long_options[option_index].name);
            if (optarg)
                INFO (" with arg %s", optarg);
            INFO ("\n");
            break;
        case 'p': *print_symtab = 1; break;
        case 'h': print_help(); exit(1); break;
        case 'V': *verbose = 1; break;
        case 'Q': *quiet = 1; break;
        case 'S': *shady = 1; break;
        case 'n': *dry_run = 1; break;
        case 's': *strip_debug = 1; break;
        case 'o': SET_STRING_OPTION(outfile); break;
        case 'f': SET_STRING_OPTION(symsfile); break;
        case '?':
            /* getopt_long already printed an error message. */
            break;

#undef SET_STRING_OPTION

        default:
            FAILIF(1, "Unknown option");
        }
    }

    return optind;
}
