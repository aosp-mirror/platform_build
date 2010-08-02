#ifndef PRELINK_INFO_H
#define PRELINK_INFO_H
#ifdef SUPPORT_ANDROID_PRELINK_TAGS

int check_prelinked(const char *fname, int elf_little, long *prelink_addr);
int check_retouched(const char *fname, int elf_little,
                    unsigned int *retouch_byte_cnt, char *retouch_buf);
void retouch_dump(const char *fname, int elf_little,
                  unsigned int retouch_byte_cnt, char *retouch_buf);
void setup_prelink_info(const char *fname, int elf_little, long base);

#endif
#endif/*PRELINK_INFO_H*/
