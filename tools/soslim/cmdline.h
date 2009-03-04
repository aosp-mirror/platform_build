#ifndef CMDLINE_H
#define CMDLINE_H

void print_help(void);

int get_options(int argc, char **argv,
                char **outfile,
                char **symsfile,
                int *print_symtab,
                int *verbose,
                int *quiet,
                int *shady,
                int *dry_run,
                int *strip_debug);

#endif/*CMDLINE_H*/
