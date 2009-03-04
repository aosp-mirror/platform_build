#ifndef SYMFILTER_H
#define SYMFILTER_H

/* This file describes the interface for parsing the list of symbols. Currently,
   this is just a text file with each symbol on a separate line.  We build an
   in-memory linked list of symbols out of this image.
*/

#include <stdio.h>
#include <libelf.h>
#include <gelf.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <libebl.h> /* defines bool */

typedef struct symfilter_list_t symfilter_list_t;
struct symfilter_list_t {
    symfilter_list_t *next;
    const char *name;
    unsigned int len; /* strlen(name) */
    Elf32_Word index;
    GElf_Sym symbol;
};

typedef struct symfilter_t {

    int fd; /* symbol-filter-file descriptor */
    off_t fsize; /* size of file */
    void *mmap; /* symbol-fiter-file memory mapping */

    section_info_t symtab;
    section_info_t hash;
    symfilter_list_t *symbols;

    /* The total number of symbols in the symfilter. */
    unsigned int num_symbols;
    /* The total number of bytes occupied by the names of the symbols, including
       the terminating null characters.
    */
    unsigned int total_name_length;

    bool *symbols_to_keep;
    /* must be the same as the number of symbols in the dynamic table! */
    int num_symbols_to_keep;
} symfilter_t;

void build_symfilter(const char *name, Elf *elf, symfilter_t *filter, off_t);
void destroy_symfilter(symfilter_t *);

#endif/*SYMFILTER_H*/
