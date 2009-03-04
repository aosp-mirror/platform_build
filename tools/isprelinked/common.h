#ifndef COMMON_H
#define COMMON_H

#include <libelf.h>
#include <elf.h>

#define unlikely(expr) __builtin_expect (expr, 0)
#define likely(expr)   __builtin_expect (expr, 1)

#define MIN(a,b) ((a)<(b)?(a):(b)) /* no side effects in arguments allowed! */

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
