#include <prelinkmap.h>
#include <debug.h>
#include <errno.h>
#include <string.h>
#include <libgen.h>
#include <ctype.h>

typedef struct mapentry mapentry;

#define MAX_ALIASES 10

struct mapentry
{
    mapentry *next;
    unsigned base;
    char *names[MAX_ALIASES];
    int num_names;
};

static mapentry *maplist = 0;

/* These values limit the address range within which we prelinked libraries
   reside.  The limit is not set in stone, but should be observed in the 
   prelink map, or the prelink step will fail.
*/

#define PRELINK_MIN 0x90000000
#define PRELINK_MAX 0xBFFFFFFF

void pm_init(const char *file)
{
    unsigned line = 0;
    char buf[256];
    char *x;
    FILE *fp;
    mapentry *me;
    unsigned last = -1UL;
    
    fp = fopen(file, "r");
    FAILIF(fp == NULL, "Error opening file %s: %s (%d)\n", 
           file, strerror(errno), errno);

    while(fgets(buf, 256, fp)){
        x = buf;
        line++;
        
        /* eat leading whitespace */
        while(isspace(*x)) x++;

        /* comment or blank line? skip! */
        if(*x == '#') continue;
        if(*x == 0) continue;

        /* skip name */
        while(*x && !isspace(*x)) x++;

        if(*x) {
            *x++ = 0;
            /* skip space before address */
            while(*x && isspace(*x)) x++;
        }

        /* no address? complain. */
        if(*x == 0) {
            fprintf(stderr,"warning: %s:%d no base address specified\n",
                    file, line);
            continue;
        }
        
        if (isalpha(*x)) {
            /* Assume that this is an alias, and look through the list of
               already-installed libraries.
            */
            me = maplist;
            while(me) {
                /* The strlen() call ignores the newline at the end of x */
                if (!strncmp(me->names[0], x, strlen(me->names[0]))) {
                    PRINT("Aliasing library %s to %s at %08x\n",
                          buf, x, me->base);
                    break;
                }
                me = me->next;
            }
            FAILIF(!me, "Nonexistent alias %s -> %s\n", buf, x);
        }
        else {
            unsigned n = strtoul(x, 0, 16);
            /* Note that this is not the only bounds check.  If a library's
               size exceeds its slot as defined in the prelink map, the
               prelinker will exit with an error.  See
               pm_report_library_size_in_memory().
            */
            FAILIF((n < PRELINK_MIN) || (n > PRELINK_MAX),
                   "%s:%d base 0x%08x out of range.\n",
                   file, line, n);

            me = malloc(sizeof(mapentry));
            FAILIF(me == NULL, "Out of memory parsing %s\n", file);

            FAILIF(last <= n, "The prelink map is not in descending order "
                   "at entry %s (%08x)!\n", buf, n);
            last = n;

            me->base = n;
            me->next = maplist;
            me->num_names = 0;
            maplist = me;
        }

        FAILIF(me->num_names >= MAX_ALIASES,
               "Too many aliases for library %s, maximum is %d.\n",
               me->names[0],
               MAX_ALIASES);
        me->names[me->num_names] = strdup(buf);
        me->num_names++;
    }

    fclose(fp);
}

/* apriori() calls this function when it determine the size of a library 
   in memory.  pm_report_library_size_in_memory() makes sure that the library
   fits in the slot provided by the prelink map.
*/
void pm_report_library_size_in_memory(const char *name,
                                      off_t fsize)
{
    char *x;
    mapentry *me;
    int n;
    
    x = strrchr(name,'/');
    if(x) name = x+1;

    for(me = maplist; me; me = me->next){
        for (n = 0; n < me->num_names; n++) {
            if(!strcmp(name, me->names[n])) {
                off_t slot = me->next ? me->next->base : PRELINK_MAX;
                slot -= me->base;
                FAILIF(fsize > slot,
                       "prelink map error: library %s@0x%08x is too big "
                       "at %lld bytes, it runs %lld bytes into "
                       "library %s@0x%08x!\n",
                       me->names[0], me->base, fsize, fsize - slot,
                       me->next->names[0], me->next->base);
                return;
            }
        }
    }
    
    FAILIF(1, "library '%s' not in prelink map\n", name);
}

unsigned pm_get_next_link_address(const char *lookup_name)
{
    char *x;
    mapentry *me;
    int n;
    
    x = strrchr(lookup_name,'/');
    if(x) lookup_name = x+1;
    
    for(me = maplist; me; me = me->next)
        for (n = 0; n < me->num_names; n++)
            if(!strcmp(lookup_name, me->names[n]))
                return me->base;

    FAILIF(1, "library '%s' not in prelink map\n", lookup_name);
    return 0;
}
