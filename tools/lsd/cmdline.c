#include <debug.h>
#include <cmdline.h>
#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <string.h>
#include <ctype.h>

extern char *optarg;
extern int optind, opterr, optopt;

static struct option long_options[] = {
	{"verbose", no_argument, 0, 'V'},
	{"help", no_argument, 0, 'h'},
	{"print-info", no_argument, 0, 'p'},
	{"list-needed-libs", no_argument, 0, 'n'},
	{"lookup",     required_argument, 0, 'L'},
	{0, 0, 0, 0},
};

/* This array must parallel long_options[] */
static const char *descriptions[] = {
	"print verbose output",
	"print help screen",
	"for each file, generate a listing of all dependencies that each symbol "
	     "satisfies",
	"print out a list of needed libraries",
	"provide a directory for library lookup"
};

void print_help(void)
{
    fprintf(stdout, 
			"invokation:\n"
			"\tlsd file1 [file2 file3 ... fileN] [-Ldir1 -Ldir2 ... -LdirN] "
			"[-Vpn]\n"
			"or\n"
			"\tlsd -h\n\n");
	fprintf(stdout, "options:\n");
	struct option *opt = long_options;
	const char **desc = descriptions;
	while (opt->name) {
		fprintf(stdout, "\t-%c\n"
						"\t--%-15s: %s\n",
				opt->val,
				opt->name,
				*desc);
		opt++;
		desc++;
	}
}

int get_options(int argc, char **argv,
				int *list_needed_libs,
				int *info,
                char ***dirs,
                int *num_dirs,
                int *verbose)
{
    int c;

	ASSERT(list_needed_libs);
	*list_needed_libs = 0;
	ASSERT(info);
	*info = 0;
    ASSERT(verbose);
    *verbose = 0;
    ASSERT(dirs);
	*dirs = NULL;
    ASSERT(num_dirs);
    int size = 0;
    *num_dirs = 0;

    while (1) {
        /* getopt_long stores the option index here. */
        int option_index = 0;

        c = getopt_long (argc, argv, 
                         "VhpnL:",
                         long_options, 
                         &option_index);
        /* Detect the end of the options. */
        if (c == -1) break;

        if (isgraph(c)) {
            INFO ("option -%c with value `%s'\n", c, (optarg ?: "(null)"));
        }

#define SET_STRING_OPTION(name) do { \
    ASSERT(optarg);                  \
    (*name) = strdup(optarg);        \
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
        case 'h': print_help(); exit(1); break;
		case 'V': *verbose = 1; break;
		case 'p': *info = 1; break;
		case 'n': *list_needed_libs = 1; break;
        case 'L': 
            {
                if (*num_dirs == size) {
                    size += 10;
                    *dirs = (char **)REALLOC(*dirs, size * sizeof(char *));
                }
                SET_STRING_OPTION(((*dirs) + *num_dirs));
                (*num_dirs)++;
            }
			break;
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
