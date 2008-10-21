#ifndef COMMON_H
#define COMMON_H

#include <libelf.h>
#include <elf.h>

#define unlikely(expr) __builtin_expect (expr, 0)
#define likely(expr)   __builtin_expect (expr, 1)

#define MIN(a,b) ((a)<(b)?(a):(b)) /* no side effects in arguments allowed! */

#endif/*COMMON_H*/
