#include <stdlib.h>
#include <common.h>
#include <debug.h>

void map_over_sections(Elf *elf, 
                       section_match_fn_t match,
                       void *user_data)
{
    Elf_Scn* section = NULL;
    while ((section = elf_nextscn(elf, section)) != NULL) {
        if (match(elf, section, user_data))
            return;
    }
}   

void map_over_segments(Elf *elf, 
                       segment_match_fn_t match, 
                       void *user_data)
{
    Elf32_Ehdr *ehdr; 
    Elf32_Phdr *phdr; 
    int index;

    ehdr = elf32_getehdr(elf);
    phdr = elf32_getphdr(elf);

    INFO("Scanning over %d program segments...\n", 
         ehdr->e_phnum);

    for (index = ehdr->e_phnum; index; index--) {
        if (match(elf, phdr++, user_data))
            return;
    }
}

