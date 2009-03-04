#ifndef LSD_H
#define LSD_H

void apriori(char **execs, int num_execs,
             char *output,
             void (*set_next_link_address)(const char *name, off_t fsize),
             int (*get_next_link_address)(const char *name),
             int locals_only,
             int dry_run,
             char **lib_lookup_dirs, int num_lib_lookup_dirs,
             char **default_libs, int num_default_libs,
			 char *mapfile);

#endif
