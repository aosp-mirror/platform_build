#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <private/android_filesystem_config.h>

#define DO_DEBUG 1

#define ERROR(fmt,args...) \
	do { \
		fprintf(stderr, "%s:%d: ERROR: " fmt,  \
		        __FILE__, __LINE__, ##args);    \
	} while (0)

#if DO_DEBUG
#define DEBUG(fmt,args...) \
	do { fprintf(stderr, "DEBUG: " fmt, ##args); } while(0)
#else
#define DEBUG(x...)               do {} while(0)
#endif

void
print_help(void)
{
	fprintf(stderr, "fs_get_stats: retrieve the target file stats "
	        "for the specified file\n");
	fprintf(stderr, "usage: fs_get_stats cur_perms is_dir filename targetout\n");
	fprintf(stderr, "\tcur_perms - The current permissions of "
	        "the file\n");
	fprintf(stderr, "\tis_dir    - Is filename is a dir, 1. Otherwise, 0.\n");
	fprintf(stderr, "\tfilename  - The filename to lookup\n");
	fprintf(stderr, "\ttargetout - The target out path to query device specific FS configs\n");
	fprintf(stderr, "\n");
}

int
main(int argc, const char *argv[])
{
	char *endptr;
	char is_dir = 0;
	unsigned perms = 0;
	unsigned uid = (unsigned)-1;
	unsigned gid = (unsigned)-1;

	if (argc < 5) {
		ERROR("Invalid arguments\n");
		print_help();
		exit(-1);
	}

	perms = (unsigned)strtoul(argv[1], &endptr, 0);
	if (!endptr || (endptr == argv[1]) || (*endptr != '\0')) {
		ERROR("current permissions must be a number. Got '%s'.\n", argv[1]);
		exit(-1);
	}

	if (!strcmp(argv[2], "1"))
		is_dir = 1;

	uint64_t capabilities;
	fs_config(argv[3], is_dir, argv[4], &uid, &gid, &perms, &capabilities);
	fprintf(stdout, "%d %d 0%o\n", uid, gid, perms);

	return 0;
}
