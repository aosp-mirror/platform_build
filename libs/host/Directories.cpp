#include <host/Directories.h>
#include <utils/String8.h>
#include <sys/types.h>
#include <sys/stat.h>

#ifdef HAVE_MS_C_RUNTIME
#include <direct.h>
#endif                    

using namespace android;
using namespace std;

string
parent_dir(const string& path)
{
    return string(String8(path.c_str()).getPathDir().string());
}

int
mkdirs(const char* last)
{
    String8 dest;
    const char* s = last-1;
    int err;
    do {
        s++;
        if (s > last && (*s == '.' || *s == 0)) {
            String8 part(last, s-last);
            dest.appendPath(part);
#ifdef HAVE_MS_C_RUNTIME
            err = _mkdir(dest.string());
#else                    
            err = mkdir(dest.string(), S_IRUSR|S_IWUSR|S_IXUSR|S_IRGRP|S_IXGRP);
#endif                    
            if (err != 0) {
                return err;
            }
            last = s+1;
        }
    } while (*s);
    return 0;
}
