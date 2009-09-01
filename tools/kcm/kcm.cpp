#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <ui/KeycodeLabels.h>
#include <stdlib.h>
#include <ctype.h>
#include <map>
#include <string>
#include <utils/ByteOrder.h>

using namespace std;

enum {
    LENDIAN,
    BENDIAN
};

/*
 * 1: KeyEvent name
 * 2: display_label
 * 3: number
 * 4..7: base, shift, alt, shift-alt
 */
#define COLUMNS (3+4)

struct KeyRecord
{
    int lineno;
    int values[COLUMNS];
};

struct PropValue
{
    PropValue() { lineno = -1; }
    PropValue(const PropValue& that) { lineno=that.lineno; value=that.value; }
    PropValue(int l, const string& v) { lineno = l; value = v; }

    int lineno;
    string value;
};

static int usage();

//  0 -- ok
// >0 -- error
static int parse_key_line(const char* filename, int lineno, char* line,
        KeyRecord* out);
static int write_kr(int fd, const KeyRecord& kr);

int g_endian;

int
main(int argc, char** argv)
{
    int err;
    if (argc != 3) {
        return usage();
    }

    const char* filename = argv[1];
    const char* outfilename = argv[2];

    int in = open(filename, O_RDONLY);
    if (in == -1) {
        fprintf(stderr, "kcm: error opening file for read: %s\n", filename);
        return 1;
    }

    off_t size = lseek(in, 0, SEEK_END);
    lseek(in, 0, SEEK_SET);

    char* input = (char*)malloc(size+1);
    read(in, input, size);
    input[size] = '\0';

    close(in);
    in = -1;

    map<string,PropValue> properties;
    map<int,KeyRecord> keys;
    int errorcount = 0;
    int lineno = 1;
    char *thisline = input;
    while (*thisline) {
        KeyRecord kr;
        char *nextline = thisline;
        
        while (*nextline != '\0' && *nextline != '\n' && *nextline != '\r') {
            nextline++;
        }

        // eat whitespace, but not newlines
        while (*thisline != '\0' && (*thisline == ' ' || *thisline == '\t')) {
            thisline++;
        }

        // find the end of the line
        char lineend = *nextline;
        *nextline = '\0';
        if (lineend == '\r' && nextline[1] == '\n') {
            nextline++;
        }

        if (*thisline == '\0' || *thisline == '\r' || *thisline == '\n'
                 || *thisline == '#') {
            // comment or blank line
        }
        else if (*thisline == '[') {
            // property - syntax [name=value]
            // look for =
            char* prop = thisline+1;
            char* end = prop;
            while (*end != '\0' && *end != '=') {
                end++;
            }
            if (*end != '=') {
                fprintf(stderr, "%s:%d: invalid property line: %s\n",
                        filename, lineno, thisline);
                errorcount++;
            } else {
                *end = '\0';
                char* value = end+1;
                end = nextline;
                while (end > prop && *end != ']') {
                    end--;
                }
                if (*end != ']') {
                    fprintf(stderr, "%s:%d: property missing closing ]: %s\n",
                            filename, lineno, thisline);
                    errorcount++;
                } else {
                    *end = '\0';
                    properties[prop] = PropValue(lineno, value);
                }
            }
        }
        else {
            // key
            err = parse_key_line(filename, lineno, thisline, &kr);
            if (err == 0) {
                kr.lineno = lineno;

                map<int,KeyRecord>::iterator old = keys.find(kr.values[0]);
                if (old != keys.end()) {
                    fprintf(stderr, "%s:%d: keycode %d already defined\n",
                            filename, lineno, kr.values[0]);
                    fprintf(stderr, "%s:%d: previously defined here\n",
                            filename, old->second.lineno);
                    errorcount++;
                }

                keys[kr.values[0]] = kr;
            }
            else if (err > 0) {
                errorcount += err;
            }
        }
        lineno++;

        nextline++;
        thisline = nextline;

        if (errorcount > 20) {
            fprintf(stderr, "%s:%d: too many errors.  stopping.\n", filename,
                    lineno);
            return 1;
        }
    }

    free(input);

    map<string,PropValue>::iterator sit = properties.find("type");
    if (sit == properties.end()) {
        fprintf(stderr, "%s: key character map must contain type property.\n",
		argv[0]);
        errorcount++;
    }
    PropValue pv = sit->second;
    unsigned char kbdtype = 0;
    if (pv.value == "NUMERIC") {
        kbdtype = 1;
    }
    else if (pv.value == "Q14") {
        kbdtype = 2;
    }
    else if (pv.value == "QWERTY") {
        kbdtype = 3;
    }
    else {
        fprintf(stderr, "%s:%d: keyboard type must be one of NUMERIC, Q14 "
                " or QWERTY, not %s\n", filename, pv.lineno, pv.value.c_str());
    }

    if (errorcount != 0) {
        return 1;
    }

    int out = open(outfilename, O_RDWR|O_CREAT|O_TRUNC, 0664);
    if (out == -1) {
        fprintf(stderr, "kcm: error opening file for write: %s\n", outfilename);
        return 1;
    }

    int count = keys.size();
    
    map<int,KeyRecord>::iterator it;
    int n;

    /**
     * File Format:
     *    Offset    Description     Value
     *    0         magic string    "keychar"
     *    8         endian marker   0x12345678
     *    12        version         0x00000002
     *    16        key count       number of key entries
     *    20        keyboard type   NUMERIC, Q14, QWERTY, etc.
     *    21        padding         0
     *    32        the keys
     */
    err = write(out, "keychar", 8);
    if (err == -1) goto bad_write;

    n = htodl(0x12345678);
    err = write(out, &n, 4);
    if (err == -1) goto bad_write;

    n = htodl(0x00000002);
    err = write(out, &n, 4);
    if (err == -1) goto bad_write;

    n = htodl(count);
    err = write(out, &n, 4);
    if (err == -1) goto bad_write;

    err = write(out, &kbdtype, 1);
    if (err == -1) goto bad_write;

    char zero[11];
    memset(zero, 0, 11);
    err = write(out, zero, 11);
    if (err == -1) goto bad_write;

    for (it = keys.begin(); it != keys.end(); it++) {
        const KeyRecord& kr = it->second;
        /*
        printf("%2d/ [%d] [%d] [%d] [%d] [%d] [%d] [%d]\n", kr.lineno,
                kr.values[0], kr.values[1], kr.values[2], kr.values[3],
                kr.values[4], kr.values[5], kr.values[6]);
        */
        err = write_kr(out, kr);
        if (err == -1) goto bad_write;
    }

    close(out);
    return 0;

bad_write:
    fprintf(stderr, "kcm: fatal error writing to file: %s\n", outfilename);
    close(out);
    unlink(outfilename);
    return 1;
}

static int usage()
{
    fprintf(stderr,
            "usage: kcm INPUT OUTPUT\n"
            "\n"
            "INPUT   keycharmap file\n"
            "OUTPUT  compiled keycharmap file\n"
        );
    return 1;
}

static int
is_whitespace(const char* p)
{
    while (*p) {
        if (!isspace(*p)) {
            return 0;
        }
        p++;
    }
    return 1;
}


static int
parse_keycode(const char* filename, int lineno, char* str, int* value)
{
    const KeycodeLabel *list = KEYCODES;
    while (list->literal) {
        if (0 == strcmp(str, list->literal)) {
            *value = list->value;
            return 0;
        }
        list++;
    }

    char* endptr;
    *value = strtol(str, &endptr, 0);
    if (*endptr != '\0') {
        fprintf(stderr, "%s:%d: expected keycode label or number near: "
                "%s\n", filename, lineno, str);
        return 1;
    }

    if (*value == 0) {
        fprintf(stderr, "%s:%d: 0 is not a valid keycode.\n",
                filename, lineno);
        return 1;
    }

    return 0;
}

static int
parse_number(const char* filename, int lineno, char* str, int* value)
{
    int len = strlen(str);

    if (len == 3 && str[0] == '\'' && str[2] == '\'') {
        if (str[1] > 0 && str[1] < 127) {
            *value = (int)str[1];
            return 0;
        } else {
            fprintf(stderr, "%s:%d: only low ascii characters are allowed in"
                    " quotes near: %s\n", filename, lineno, str);
            return 1;
        }
    }

    char* endptr;
    *value = strtol(str, &endptr, 0);
    if (*endptr != '\0') {
        fprintf(stderr, "%s:%d: expected number or quoted ascii but got: %s\n",
                filename, lineno, str);
        return 1;
    }

    if (*value >= 0xfffe || *value < 0) {
        fprintf(stderr, "%s:%d: unicode char out of range (no negatives, "
                "nothing larger than 0xfffe): %s\n", filename, lineno, str);
        return 1;
    }

    return 0;
}

static int
parse_key_line(const char* filename, int lineno, char* line, KeyRecord* out)
{
    char* p = line;

    int len = strlen(line);
    char* s[COLUMNS];
    for (int i=0; i<COLUMNS; i++) {
        s[i] = (char*)malloc(len+1);
    }

    for (int i = 0; i < COLUMNS; i++) {
        while (*p != '\0' && isspace(*p)) {
            p++;
        }

        if (*p == '\0') {
            fprintf(stderr, "%s:%d: not enough on this line: %s\n", filename,
                    lineno, line);
            return 1;
        }

        char *p1 = p;
        while (*p != '\0' && !isspace(*p)) {
            p++;
        }

        memcpy(s[i], p1, p - p1);
        s[i][p - p1] = '\0';
    }

    while (*p != '\0' && isspace(*p)) {
        *p++;
    }
    if (*p != '\0') {
        fprintf(stderr, "%s:%d: too much on one line near: %s\n", filename,
                lineno, p);
        fprintf(stderr, "%s:%d: -->%s<--\n", filename, lineno, line);
        return 1;
    }

    int errorcount = parse_keycode(filename, lineno, s[0], &out->values[0]);
    for (int i=1; i<COLUMNS && errorcount == 0; i++) {
        errorcount += parse_number(filename, lineno, s[i], &out->values[i]);
    }

    return errorcount;
}

struct WrittenRecord
{
    unsigned int keycode;       // 4 bytes
    unsigned short values[COLUMNS - 1];   // 6*2 bytes = 12
                                // 16 bytes total 
};

static int
write_kr(int fd, const KeyRecord& kr)
{
    WrittenRecord wr;

    wr.keycode = htodl(kr.values[0]);
    for (int i=0; i<COLUMNS - 1; i++) {
        wr.values[i] = htods(kr.values[i+1]);
    }

    return write(fd, &wr, sizeof(WrittenRecord));
}

