#include "fs.h"
#include "files.h"
#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <dirent.h>
#include <string>
#include <vector>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <host/CopyFile.h>

using namespace std;

static bool
is_dir(const string& path)
{
    int err;
    struct stat st;
    err = stat(path.c_str(), &st);
    return err != 0 || S_ISDIR(st.st_mode);
}

static int
remove_file(const string& path)
{
    int err = unlink(path.c_str());
    if (err != 0) {
        fprintf(stderr, "error deleting file %s (%s)\n", path.c_str(),
                strerror(errno));
        return errno;
    }
    return 0;
}

int
remove_recursively(const string& path)
{
    int err;

    if (is_dir(path)) {
        DIR *d = opendir(path.c_str());
        if (d == NULL) {
            fprintf(stderr, "error getting directory contents %s (%s)\n",
                    path.c_str(), strerror(errno));
            return errno;
        }

        vector<string> files;
        vector<string> dirs;

        struct dirent *ent;
        while (NULL != (ent = readdir(d))) {
            if (0 == strcmp(".", ent->d_name)
                    || 0 == strcmp("..", ent->d_name)) {
                continue;
            }
            string full = path;
            full += '/';
            full += ent->d_name;
#ifdef HAVE_DIRENT_D_TYPE
            bool is_directory = (ent->d_type == DT_DIR);
#else
            // If dirent.d_type is missing, then use stat instead
            struct stat stat_buf;
            stat(full.c_str(), &stat_buf);
            bool is_directory = S_ISDIR(stat_buf.st_mode);
#endif
            if (is_directory) {
                dirs.push_back(full);
            } else {
                files.push_back(full);
            }
        }
        closedir(d);

        for (vector<string>::iterator it=files.begin(); it!=files.end(); it++) {
            err = remove_file(*it);
            if (err != 0) {
                return err;
            }
        }

        for (vector<string>::iterator it=dirs.begin(); it!=dirs.end(); it++) {
            err = remove_recursively(*it);
            if (err != 0) {
                return err;
            }
        }

        err = rmdir(path.c_str());
        if (err != 0) {
            fprintf(stderr, "error deleting directory %s (%s)\n", path.c_str(),
                    strerror(errno));
            return errno;
        }
        return 0;
    } else {
        return remove_file(path);
    }
}

int
mkdir_recursively(const string& path)
{
    int err;
    size_t pos = 0;
    // For absolute pathnames, that starts with leading '/'
    // use appropriate initial value.
    if (path.length() != 0 and path[0] == '/') pos++;

    while (true) {
        pos = path.find('/', pos);
        string p = path.substr(0, pos);
        struct stat st;
        err = stat(p.c_str(), &st);
        if (err != 0) {
            err = mkdir(p.c_str(), 0770);
            if (err != 0) {
                fprintf(stderr, "can't create directory %s (%s)\n",
                        path.c_str(), strerror(errno));
                return errno;
            }
        }
        else if (!S_ISDIR(st.st_mode)) {
            fprintf(stderr, "can't create directory %s because %s is a file.\n",
                        path.c_str(), p.c_str());
            return 1;
        }
        pos++;
        if (p == path) {
            return 0;
        }
    }
}

int
copy_file(const string& src, const string& dst)
{
    int err;

    err = copyFile(src.c_str(), dst.c_str(),
                    COPY_NO_DEREFERENCE | COPY_FORCE | COPY_PERMISSIONS);
    return err;
}

int
strip_file(const string& path)
{
    // Default strip command to run is "strip" unless overridden by the ATREE_STRIP env var.
    const char* strip_cmd = getenv("ATREE_STRIP");
    if (!strip_cmd || !strip_cmd[0]) {
        strip_cmd = "strip";
    }
    pid_t pid = fork();
    if (pid == -1) {
        // Fork failed. errno should be set.
        return -1;
    } else if (pid == 0) {
        // Exec in the child. Only returns if execve failed.

        int num_args = 0;
        const char *s = strip_cmd;
        while (*s) {
            while (*s == ' ') ++s;
            if (*s && *s != ' ') {
                ++num_args;
                while (*s && *s != ' ') ++s;
            }
        }

        if (num_args <= 0) {
            fprintf(stderr, "Invalid ATREE_STRIP command '%s'\n", strip_cmd);
            return 1;

        } else if (num_args == 1) {
            return execlp(strip_cmd, strip_cmd, path.c_str(), (char *)NULL);

        } else {
            // Split the arguments if more than 1
            char* cmd = strdup(strip_cmd);
            const char** args = (const char**) malloc(sizeof(const char*) * (num_args + 2));

            const char** curr = args;
            char* s = cmd;
            while (*s) {
                while (*s == ' ') ++s;
                if (*s && *s != ' ') {
                    *curr = s;
                    ++curr;
                    while (*s && *s != ' ') ++s;
                    if (*s) {
                        *s = '\0';
                        ++s;
                    }
                }
            }

            args[num_args] = path.c_str();
            args[num_args + 1] = NULL;

            int ret = execvp(args[0], (char* const*)args);
            free(args);
            free(cmd);
            return ret;
        }
    } else {
        // Wait for child pid and return its exit code.
        int status;
        waitpid(pid, &status, 0);
        return status;
    }
}

