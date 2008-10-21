#ifndef HASH_H
#define HASH_H

#include <common.h>
#include <libelf.h>
#include <gelf.h>

int hash_lookup(Elf *elf, 
                Elf_Data *hash,
                Elf_Data *symtab,
                Elf_Data *symstr,
                const char *symname);

#endif/*HASH_H*/
