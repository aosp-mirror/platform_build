#ifndef ELFCOPY_H
#define ELFCOPY_H

#include <libelf.h>
#include <libebl.h>
#include <elf.h>
#include <gelf.h>

/*
symbol_filter:
	On input: symbol_filter[i] indicates whether to keep a symbol (1) or to
	          remove it from the symbol table.
    On output: symbol_filter[i] indicates whether a symbol was removed (0) or
	           kept (1) in the symbol table.
*/

void clone_elf(Elf *elf, Elf *newelf,
			   const char *elf_name,
			   const char *newelf_name,
			   bool *symbol_filter,
			   int num_symbols,
               int shady
#ifdef SUPPORT_ANDROID_PRELINK_TAGS
			   , int *prelinked,
			   int *elf_little,
			   long *prelink_addr,
                           int *retouched,
                           unsigned int *retouch_byte_cnt,
                           char *retouch_buf
#endif
               , bool rebuild_shstrtab,
               bool strip_debug,
               bool dry_run);

#endif/*ELFCOPY_H*/
