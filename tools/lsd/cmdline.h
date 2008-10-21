#ifndef CMDLINE_H
#define CMDLINE_H

void print_help(void);

int get_options(int argc, char **argv,
				int *list_needed_libs,
				int *info,
                char ***dirs,
                int *num_dirs,
                int *verbose);

#endif/*CMDLINE_H*/
