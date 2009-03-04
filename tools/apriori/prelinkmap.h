#ifndef PRELINKMAP_H
#define PRELINKMAP_H

#include <sys/types.h>

extern void pm_init(const char *file);
extern void pm_report_library_size_in_memory(const char *name, off_t fsize);
extern unsigned pm_get_next_link_address(const char *name);

#endif/*PRELINKMAP_H*/
