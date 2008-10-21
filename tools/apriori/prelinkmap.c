#include <prelinkmap.h>
#include <debug.h>
#include <errno.h>
#include <string.h>
#include <libgen.h>
#include <ctype.h>

typedef struct mapentry mapentry;

struct mapentry
{
    mapentry *next;
    unsigned base;
    char name[0];
};

static mapentry *maplist = 0;

/* These values limit the address range within which we prelinked libraries
   reside.  The limit is not set in stone, but should be observed in the 
   prelink map, or the prelink step will fail.
*/

#define PRELINK_MIN 0x90000000
#define PRELINK_MAX 0xB0000000

void pm_init(const char *file)
{
    unsigned line = 0;
    char buf[256];
    char *x;
    unsigned n;
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
        
        n = strtoul(x, 0, 16);
        /* Note that this is not the only bounds check.  If a library's size
           exceeds its slot as defined in the prelink map, the prelinker will
           exit with an error.  See pm_report_library_size_in_memory().
        */
        FAILIF((n < PRELINK_MIN) || (n > PRELINK_MAX),
               "%s:%d base 0x%08x out of range.\n",
               file, line, n);
        
        me = malloc(sizeof(mapentry) + strlen(buf) + 1);
        FAILIF(me == NULL, "Out of memory parsing %s\n", file);

        FAILIF(last <= n, "The prelink map is not in descending order "
               "at entry %s (%08x)!\n", buf, n);
        last = n;
        
        me->base = n;
        strcpy(me->name, buf);
        me->next = maplist;
        maplist = me;        
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
    
    x = strrchr(name,'/');
    if(x) name = x+1;

    for(me = maplist; me; me = me->next){
        if(!strcmp(name, me->name)) {
            off_t slot = me->next ? me->next->base : PRELINK_MAX;
            slot -= me->base;
            FAILIF(fsize > slot,
                   "prelink map error: library %s@0x%08x is too big "
                   "at %lld bytes, it runs %lld bytes into "
                   "library %s@0x%08x!\n",
                   me->name, me->base, fsize, fsize - slot,
                   me->next->name, me->next->base);
            break;
        }
    }
    
    FAILIF(!me,"library '%s' not in prelink map\n", name);
}

unsigned pm_get_next_link_address(const char *lookup_name)
{
    char *x;
    mapentry *me;
    
    x = strrchr(lookup_name,'/');
    if(x) lookup_name = x+1;
    
    for(me = maplist; me; me = me->next){
        if(!strcmp(lookup_name, me->name)) {
            return me->base;
        }
    }
    
    FAILIF(1==1,"library '%s' not in prelink map\n", lookup_name);
    return 0;
}
