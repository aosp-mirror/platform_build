#ifndef TWEAK_H
#define TWEAK_H

#include <source.h>

/* This function will break up the .bss section into multiple subsegments, 
   depending on whether the .bss segment contains copy-relocated symbols.  This
   will produce a nonstandard ELF file (with multiple .bss sections), tht the
   linker will need to know how to handle.  The return value is the number of
   segments that the .bss segment was broken into (zero if the .bss segment was
   not modified. */

int tweak_bss_if_necessary(source_t *source);

#endif/*TWEAK_H*/
