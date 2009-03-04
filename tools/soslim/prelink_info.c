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

typedef struct {
	uint32_t mmap_addr;
	char tag[4]; /* 'P', 'R', 'E', ' ' */
} prelink_info_t __attribute__((packed));

static inline void set_prelink(long *prelink_addr, 
							   int elf_little,
							   prelink_info_t *info)
{
    FAILIF(sizeof(prelink_info_t) != 8, "Unexpected sizeof(prelink_info_t) == %d!\n", sizeof(prelink_info_t));
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
    FAILIF(sizeof(prelink_info_t) != 8, "Unexpected sizeof(prelink_info_t) == %d!\n", sizeof(prelink_info_t));
	int fd = open(fname, O_RDONLY);
	FAILIF(fd < 0, "open(%s, O_RDONLY): %s (%d)!\n",
		   fname, strerror(errno), errno);
	off_t end = lseek(fd, 0, SEEK_END);

    int nr = sizeof(prelink_info_t);

    off_t sz = lseek(fd, -nr, SEEK_CUR);
	ASSERT((long)(end - sz) == (long)nr);
	FAILIF(sz == (off_t)-1, 
		   "lseek(%d, 0, SEEK_END): %s (%d)!\n", 
		   fd, strerror(errno), errno);

	prelink_info_t info;
	int num_read = read(fd, &info, nr);
	FAILIF(num_read < 0, 
		   "read(%d, &info, sizeof(prelink_info_t)): %s (%d)!\n",
		   fd, strerror(errno), errno);
	FAILIF(num_read != sizeof(info),
		   "read(%d, &info, sizeof(prelink_info_t)): did not read %d bytes as "
		   "expected (read %d)!\n",
		   fd, sizeof(info), num_read);

	int prelinked = 0;
	if (!strncmp(info.tag, "PRE ", 4)) {
		set_prelink(prelink_addr, elf_little, &info);
		prelinked = 1;
	}
	FAILIF(close(fd) < 0, "close(%d): %s (%d)!\n", fd, strerror(errno), errno);
	return prelinked;
}

void setup_prelink_info(const char *fname, int elf_little, long base)
{
    FAILIF(sizeof(prelink_info_t) != 8, "Unexpected sizeof(prelink_info_t) == %d!\n", sizeof(prelink_info_t));
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

    int num_written = write(fd, &info, sizeof(info));
    FAILIF(num_written < 0, 
           "write(%d, &info, sizeof(info)): %s (%d)\n",
           fd, strerror(errno), errno);
    FAILIF(sizeof(info) != num_written, 
           "Could not write %d bytes (wrote only %d bytes) as expected!\n",
           sizeof(info), num_written);
    FAILIF(close(fd) < 0, "close(%d): %s (%d)!\n", fd, strerror(errno), errno);
}

#endif /*SUPPORT_ANDROID_PRELINK_TAGS*/
