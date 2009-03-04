#ifndef COMMON_H
#define COMMON_H

#include <libelf.h>
#include <elf.h>

#define unlikely(expr) __builtin_expect (expr, 0)
#define likely(expr)   __builtin_expect (expr, 1)

#define MIN(a,b) ((a)<(b)?(a):(b)) /* no side effects in arguments allowed! */

typedef int (*section_match_fn_t)(Elf *, Elf_Scn *, void *);
void map_over_sections(Elf *, section_match_fn_t, void *);

typedef int (*segment_match_fn_t)(Elf *, Elf32_Phdr *, void *);
void map_over_segments(Elf *, segment_match_fn_t, void *);

typedef struct {
    Elf_Scn *sect;
    Elf32_Shdr *hdr;
    Elf_Data *data;
    size_t index;
} section_info_t;

static inline void get_section_info(Elf_Scn *sect, section_info_t *info)
{
    info->sect = sect;
    info->data = elf_getdata(sect, 0);
    info->hdr = elf32_getshdr(sect);
    info->index = elf_ndxscn(sect);
}

static inline int is_host_little(void)
{
    short val = 0x10;
    return ((char *)&val)[0] != 0;
}

static inline long switch_endianness(long val)
{
	long newval;
	((char *)&newval)[3] = ((char *)&val)[0];
	((char *)&newval)[2] = ((char *)&val)[1];
	((char *)&newval)[1] = ((char *)&val)[2];
	((char *)&newval)[0] = ((char *)&val)[3];
	return newval;
}

#endif/*COMMON_H*/
