#include <debug.h>
#include <unistd.h>

#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>

int
main(int argc, char **argv)
{
	char *fname;
	int fd;
	char magic[4];

	argc--, argv++;
	FAILIF(argc != 1, "Expecting a file name!\n");
	fname = *argv;

	fd = open(fname, O_RDONLY);
	FAILIF(fd < 0, "Error opening %s for reading: %s (%d)!\n",
           fname, strerror(errno), errno);

	FAILIF(4 != read(fd, magic, 4),
           "Could not read first 4 bytes from %s: %s (%d)!\n",
           fname, strerror(errno), errno);

    if (magic[0] != 0x7f) return 1;
    if (magic[1] != 'E')  return 1;
    if (magic[2] != 'L')  return 1;
    if (magic[3] != 'F')  return 1;

    return 0;
}
