#ifndef CMDLINE_H
#define CMDLINE_H

void print_help(const char *executable_name);

int get_options(int argc, char **argv,
                int *start_addr,
                int *addr_increment,
                int *locals_only,
                int *quiet,
                int *dry_run,
                char ***dirs,
                int *num_dirs,
                char ***defaults,
                int *num_defaults,
                int *verbose,
				char **mapfile,
                char **output,
                char **prelinkmap);

#endif/*CMDLINE_H*/
