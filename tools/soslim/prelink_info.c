#ifdef SUPPORT_ANDROID_PRELINK_TAGS

#include <sys/types.h>
#include <fcntl.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

#include <prelink_info.h>
#include <debug.h>
#include <common.h>

#define RETOUCH_SUFFIX_SIZE 12
typedef struct {
	uint32_t mmap_addr;
	char tag[4]; /* 'P', 'R', 'E', ' ' */
} __attribute__((packed)) prelink_info_t;

static inline void set_prelink(long *prelink_addr, 
							   int elf_little,
							   prelink_info_t *info)
{
    FAILIF(sizeof(prelink_info_t) != 8, "Unexpected sizeof(prelink_info_t) == %zd!\n", sizeof(prelink_info_t));
	if (prelink_addr) {
		if (!(elf_little ^ is_host_little())) {
			/* Same endianness */
			*prelink_addr = info->mmap_addr;
		}
		else {
			/* Different endianness */
                        *prelink_addr = switch_endianness(info->mmap_addr);
		}
	}
}

int check_prelinked(const char *fname, int elf_little, long *prelink_addr)
{
    FAILIF(sizeof(prelink_info_t) != 8, "Unexpected sizeof(prelink_info_t) == %zd!\n", sizeof(prelink_info_t));
	int fd = open(fname, O_RDONLY);
	FAILIF(fd < 0, "open(%s, O_RDONLY): %s (%d)!\n",
		   fname, strerror(errno), errno);
	off_t end = lseek(fd, 0, SEEK_END);
#ifndef DEBUG
	(void)end;
#endif

    int nr = sizeof(prelink_info_t);

    off_t sz = lseek(fd, -nr, SEEK_CUR);
	ASSERT((long)(end - sz) == (long)nr);
	FAILIF(sz == (off_t)-1, 
		   "lseek(%d, 0, SEEK_END): %s (%d)!\n", 
		   fd, strerror(errno), errno);

	prelink_info_t info;
	ssize_t num_read = read(fd, &info, nr);
	FAILIF(num_read < 0, 
		   "read(%d, &info, sizeof(prelink_info_t)): %s (%d)!\n",
		   fd, strerror(errno), errno);
	FAILIF((size_t)num_read != sizeof(info),
		   "read(%d, &info, sizeof(prelink_info_t)): did not read %zd bytes as "
		   "expected (read %zd)!\n",
		   fd, sizeof(info), (size_t)num_read);

	int prelinked = 0;
	if (!strncmp(info.tag, "PRE ", 4)) {
		set_prelink(prelink_addr, elf_little, &info);
		prelinked = 1;
	}
	FAILIF(close(fd) < 0,
               "close(%d): %s (%d)!\n", fd, strerror(errno), errno);
	return prelinked;
}

int check_retouched(const char *fname, int elf_little,
                    unsigned int *retouch_byte_cnt, char *retouch_buf) {
    FAILIF(sizeof(prelink_info_t) != 8,
           "Unexpected sizeof(prelink_info_t) == %d!\n",
           sizeof(prelink_info_t));
    int fd = open(fname, O_RDONLY);
    FAILIF(fd < 0, "open(%s, O_RDONLY): %s (%d)!\n",
           fname, strerror(errno), errno);
    off_t end = lseek(fd, 0, SEEK_END);
    int nr = sizeof(prelink_info_t);
    off_t sz = lseek(fd, -nr-RETOUCH_SUFFIX_SIZE, SEEK_CUR);
    ASSERT((long)(end - sz) == (long)(nr+RETOUCH_SUFFIX_SIZE));
    FAILIF(sz == (off_t)-1,
           "lseek(%d, 0, SEEK_END): %s (%d)!\n",
           fd, strerror(errno), errno);

    char retouch_meta[RETOUCH_SUFFIX_SIZE];
    int num_read = read(fd, &retouch_meta, RETOUCH_SUFFIX_SIZE);
    FAILIF(num_read < 0,
           "read(%d, &info, sizeof(prelink_info_t)): %s (%d)!\n",
           fd, strerror(errno), errno);
    FAILIF(num_read != RETOUCH_SUFFIX_SIZE,
           "read(%d, &info, sizeof(prelink_info_t)): did not read %d bytes as "
           "expected (read %d)!\n",
           fd, RETOUCH_SUFFIX_SIZE, num_read);

    int retouched = 0;
    if (!strncmp(retouch_meta, "RETOUCH ", 8)) {
        unsigned int retouch_byte_cnt_meta;
        if (!(elf_little ^ is_host_little()))
            retouch_byte_cnt_meta = *(unsigned int *)(retouch_meta+8);
        else
            retouch_byte_cnt_meta =
              switch_endianness(*(unsigned int *)(retouch_meta+8));
        FAILIF(*retouch_byte_cnt < retouch_byte_cnt_meta,
               "Retouch buffer too small at %d bytes (%d needed).",
               *retouch_byte_cnt, retouch_byte_cnt_meta);
        *retouch_byte_cnt = retouch_byte_cnt_meta;
        off_t sz = lseek(fd,
                         -((long)*retouch_byte_cnt)-RETOUCH_SUFFIX_SIZE-nr,
                         SEEK_END);
        ASSERT((long)(end - sz) ==
               (long)(*retouch_byte_cnt+RETOUCH_SUFFIX_SIZE+nr));
        FAILIF(sz == (off_t)-1,
               "lseek(%d, 0, SEEK_END): %s (%d)!\n",
               fd, strerror(errno), errno);
        num_read = read(fd, retouch_buf, *retouch_byte_cnt);
        FAILIF(num_read < 0,
               "read(%d, &info, sizeof(prelink_info_t)): %s (%d)!\n",
               fd, strerror(errno), errno);
        FAILIF(num_read != *retouch_byte_cnt,
               "read(%d, retouch_buf, %u): did not read %d bytes as "
               "expected (read %d)!\n",
               fd, *retouch_byte_cnt, *retouch_byte_cnt, num_read);

        retouched = 1;
    }
    FAILIF(close(fd) < 0, "close(%d): %s (%d)!\n", fd, strerror(errno), errno);
    return retouched;
}

void retouch_dump(const char *fname, int elf_little,
                  unsigned int retouch_byte_cnt, char *retouch_buf) {
    int fd = open(fname, O_WRONLY);
    FAILIF(fd < 0,
           "open(%s, O_WRONLY): %s (%d)\n",
           fname, strerror(errno), errno);
    off_t sz = lseek(fd, 0, SEEK_END);
    FAILIF(sz == (off_t)-1,
           "lseek(%d, 0, SEEK_END): %s (%d)!\n",
           fd, strerror(errno), errno);

    // The retouch blob ends with "RETOUCH XXXX", where XXXX is the 4-byte
    // size of the retouch blob, in target endianness.
    strncpy(retouch_buf+retouch_byte_cnt, "RETOUCH ", 8);
    if (elf_little ^ is_host_little()) {
        *(unsigned int *)(retouch_buf+retouch_byte_cnt+8) =
          switch_endianness(retouch_byte_cnt);
    } else {
        *(unsigned int *)(retouch_buf+retouch_byte_cnt+8) =
          retouch_byte_cnt;
    }

    int num_written = write(fd, retouch_buf, retouch_byte_cnt+12);
    FAILIF(num_written < 0,
           "write(%d, &info, sizeof(info)): %s (%d)\n",
           fd, strerror(errno), errno);
    FAILIF((retouch_byte_cnt+12) != num_written,
           "Could not write %d bytes as expected (wrote %d bytes instead)!\n",
           retouch_byte_cnt, num_written);
    FAILIF(close(fd) < 0, "close(%d): %s (%d)!\n", fd, strerror(errno), errno);
}

void setup_prelink_info(const char *fname, int elf_little, long base)
{
    FAILIF(sizeof(prelink_info_t) != 8, "Unexpected sizeof(prelink_info_t) == %zd!\n", sizeof(prelink_info_t));
    int fd = open(fname, O_WRONLY);
    FAILIF(fd < 0, 
           "open(%s, O_WRONLY): %s (%d)\n" ,
           fname, strerror(errno), errno);
    prelink_info_t info;
    off_t sz = lseek(fd, 0, SEEK_END);
    FAILIF(sz == (off_t)-1, 
           "lseek(%d, 0, SEEK_END): %s (%d)!\n", 
           fd, strerror(errno), errno);

    if (!(elf_little ^ is_host_little())) {
        /* Same endianness */
        INFO("Host and ELF file [%s] have same endianness.\n", fname);
        info.mmap_addr = base;
    }
    else {
        /* Different endianness */
        INFO("Host and ELF file [%s] have different endianness.\n", fname);
        info.mmap_addr = switch_endianness(base);
    }
    strncpy(info.tag, "PRE ", 4);

    ssize_t num_written = write(fd, &info, sizeof(info));
    FAILIF(num_written < 0, 
           "write(%d, &info, sizeof(info)): %s (%d)\n",
           fd, strerror(errno), errno);
    FAILIF(sizeof(info) != (size_t)num_written,
           "Could not write %zd bytes (wrote only %zd bytes) as expected!\n",
           sizeof(info), (size_t)num_written);
    FAILIF(close(fd) < 0, "close(%d): %s (%d)!\n", fd, strerror(errno), errno);
}

#endif /*SUPPORT_ANDROID_PRELINK_TAGS*/
