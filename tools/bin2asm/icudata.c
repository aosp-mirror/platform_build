/*
 * Convert a data file into a .S file suitable for assembly.
 * This reads from stdin and writes to stdout and takes a single
 * argument for the name of the symbol in the assembly file.
 */

#include <stdio.h>

int main(int argc, char *argv[]) {
    unsigned char buf[4096];
    size_t amt;
    size_t i;
    int col = 0;
    char *name;

    if (argc != 2) {
        fprintf(stderr, "usage: %s NAME < DAT_FILE > ASM_FILE\n", argv[0]);
        for (i=0; i<argc; i++) {
            fprintf(stderr, " '%s'", argv[i]);
        }
        fprintf(stderr, "\n");
        return 1;
    }
    
    name = argv[1];

    printf("\
#ifdef __APPLE_CC__\n\
/*\n\
 * The mid-2007 version of gcc that ships with Macs requires a\n\
 * comma on the .section line, but the rest of the world thinks\n\
 * that's a syntax error. It also wants globals to be explicitly\n\
 * prefixed with \"_\" as opposed to modern gccs that do the\n\
 * prefixing for you.\n\
 */\n\
.globl _%s\n\
	.section .rodata,\n\
	.align 8\n\
_%s:\n\
#else\n\
.globl %s\n\
	.section .rodata\n\
	.align 8\n\
%s:\n\
#endif\n\
", name, name, name, name);
    
    while (! feof(stdin)) {
        amt = fread(buf, 1, sizeof(buf), stdin);
        for (i = 0; i < amt; i++) {
            if (col == 0) {
                printf(".byte ");
            }
            printf("0x%02x", buf[i]);
            col++;
            if (col == 16) {
                printf("\n");
                col = 0;
            } else if (col % 4 == 0) {
                printf(", ");
            } else {
                printf(",");
            }
        }
    }

    if (col != 0) {
        printf("\n");
    }

    return 0;
}
