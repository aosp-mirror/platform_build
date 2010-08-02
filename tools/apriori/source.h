#ifndef SOURCE_H
#define SOURCE_H

#include <sys/types.h>
#include <sys/stat.h>
#include <libelf.h>
#include <libebl.h>
#ifdef ARM_SPECIFIC_HACKS
    #include <libebl_arm.h>
#endif/*ARM_SPECIFIC_HACKS*/
#include <elf.h>
#include <gelf.h>
#include <rangesort.h>
#include <elfcopy.h>

typedef struct source_t source_t;

typedef struct {
    Elf_Scn *scn;
    GElf_Shdr shdr;
    Elf_Data *data;
    shdr_info_t *info;
} section_info_t;

typedef struct {
    GElf_Rel *rels;
    int num_rels; /* number of relocations that were not finished */
    int rels_size; /* this is the size of rels[], NOT the number of rels! */
} unfinished_relocation_t;

typedef struct {
    int processed;
    size_t idx; /* index of DT entry in the .dynamic section, if entry has a ptr value */
    Elf64_Addr addr; /* if DT entry's value is an address, we save it here */
    size_t sz_idx; /* index of DT entry in the .dynamic section, if entry has a size value */
    Elf64_Xword size; /* if DT entry's value is a size, we save it here */

    range_list_t *sections; /* list of sections corresponding to this entry */
    int num_unfinished_relocs; /* this variables is populated by adjust_dynamic_segment_for()
                                  during the second pass of the prelinker */
} dt_rel_info_t;

struct source_t {
    source_t *next;

    char *name;  /* full path name of this executable file */
    char *output; /* name of the output file or directory */
    int output_is_dir; /* nonzero if output is a directory, 0 if output is a file */
    /* ELF-related information: */
    Elf *oldelf;
    Elf *elf;
    /* info[] is an array of structures describing the sections of the new ELF
       file.  We populate the info[] array in clone_elf(), and use it to
       adjust the size of the ELF file when we modify the relocation-entry
       section.
    */
    shdr_info_t *shdr_info;
    GElf_Ehdr old_ehdr_mem; /* store ELF header of original library */
    GElf_Ehdr ehdr_mem; /* store ELF header of new library */
    GElf_Phdr *phdr_info;
    Ebl *ebl;
    Elf_Data *shstrtab_data;
    int elf_fd;
    int newelf_fd; /* fd of output file, -1 if output == NULL */
    int newelf_relo_fd; /* fd of relocaion output file */
    struct stat elf_file_info;
    GElf_Ehdr elf_hdr, oldelf_hdr;
    size_t shstrndx;
    int shnum; /* number of sections */
    int dry_run; /* 0 if we do not update the files, 1 (default) otherwise */

    section_info_t symtab;
    section_info_t strtab;
    section_info_t dynamic;
    section_info_t hash;
    section_info_t bss;

    range_list_t *sorted_sections;

    section_info_t *relocation_sections; /* relocation sections in file */
    int num_relocation_sections; /* number of relocation sections (<= relocation_sections_size) */
    int relocation_sections_size; /* sice of array -- NOT number of relocs! */

    /* relocation sections that contain relocations that could not be handled.
       This array is parallel to relocation_sections, and for each entry
       in that array, it contains a list of relocations that could not be
       handled.
    */
    unfinished_relocation_t *unfinished;

    /* The sections field of these two structuer contains a list of elements
       of the member variable relocations. */
    dt_rel_info_t rel;
    dt_rel_info_t jmprel;

    int num_syms; /* number of symbols in symbol table.  This is the length of
                     both exports[] and satisfied[] arrays. */

    /* This is an array that contains one element for each library dependency
       listed in the executable or shared library. */
    source_t **lib_deps; /* list of library dependencies */
    int num_lib_deps; /* actual number of library dependencies */
    int lib_deps_size; /* size of lib_deps array--NOT actual number of deps! */

    /* This is zero for executables.  For shared libraries, it is the address
	   at which the library was prelinked. */
    unsigned base;
#ifdef SUPPORT_ANDROID_PRELINK_TAGS
	/* When we read in a file, if it has the prelinked tag, we set prelinked
	   to 1 and the prelink address in the tag to prelink_base.  This address
	   must match the value of base that we choose. */
	int prelinked;
	long prelink_base; /* valid if prelinked != 0 */
#endif/*SUPPORT_ANDROID_PRELINK_TAGS*/
};

extern void find_section(source_t *source, Elf64_Addr address,
                         Elf_Scn **scn,
                         GElf_Shdr *shdr,
                         Elf_Data **data);

#endif/*SOURCE_H*/
