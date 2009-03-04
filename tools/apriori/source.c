#include <source.h>

void find_section(source_t *source, Elf64_Addr address,
                  Elf_Scn **scn, 
                  GElf_Shdr *shdr, 
                  Elf_Data **data)
{
    range_t *range = find_range(source->sorted_sections, address);
    FAILIF(NULL == range, 
           "Cannot match address %lld to any range in [%s]!\n",
           address,
           source->name);
    *scn = (Elf_Scn *)range->user;
    ASSERT(*scn);
    FAILIF_LIBELF(NULL == gelf_getshdr(*scn, shdr), gelf_getshdr);
    *data = elf_getdata(*scn, NULL);
    FAILIF_LIBELF(NULL == *data, elf_getdata);
}
