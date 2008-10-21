#include <common.h>
#include <debug.h>
#include <libelf.h>
#include <hash.h>
#include <string.h>

int hash_lookup(Elf *elf, 
                Elf_Data *hash,
                Elf_Data *symtab,
                Elf_Data *symstr,
                const char *symname) {
    Elf32_Word *hash_data = (Elf32_Word *)hash->d_buf;
    Elf32_Word index;
    Elf32_Word nbuckets = *hash_data++;
    Elf32_Word *buckets = ++hash_data;
    Elf32_Word *chains  = hash_data + nbuckets;

    index = buckets[elf_hash(symname) % nbuckets];
    while (index != STN_UNDEF &&
           strcmp((char *)symstr->d_buf + 
                  ((Elf32_Sym *)symtab->d_buf)[index].st_name,
                  symname)) {
        index = chains[index];
    }

    return index;
}
