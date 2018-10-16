#include "files.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <fnmatch.h>
#include <string.h>
#include <stdlib.h>

static bool
is_comment_line(const char* p)
{
    while (*p && isspace(*p)) {
        p++;
    }
    return *p == '#';
}

static string
path_append(const string& base, const string& leaf)
{
    string full = base;
    if (base.length() > 0 && leaf.length() > 0) {
        full += '/';
    }
    full += leaf;
    return full;
}

static bool
is_whitespace_line(const char* p)
{
    while (*p) {
        if (!isspace(*p)) {
            return false;
        }
        p++;
    }
    return true;
}

static bool
is_exclude_line(const char* p) {
    while (*p) {
        if (*p == '-') {
            return true;
        }
        else if (isspace(*p)) {
            p++;
        }
        else {
            return false;
        }
    }
    return false;
}

void
split_line(const char* p, vector<string>* out)
{
    const char* q = p;
    enum { WHITE, TEXT, IN_QUOTE } state = WHITE;
    while (*p) {
        if (*p == '#') {
            break;
        }

        switch (state)
        {
            case WHITE:
                if (!isspace(*p)) {
                    q = p;
                    state = (*p == '"') ? IN_QUOTE : TEXT;
                }
                break;
            case IN_QUOTE:
                if (*p == '"') {
                    state = TEXT;
                    break;
                }
                [[fallthrough]];
            case TEXT:
                if (state != IN_QUOTE && isspace(*p)) {
                    if (q != p) {
                        const char* start = q;
                        size_t len = p-q;
                        if (len > 2 && *start == '"' && start[len - 1] == '"') {
                            start++;
                            len -= 2;
                        }
                        out->push_back(string(start, len));
                    }
                    state = WHITE;
                }
                break;
        }
        p++;
    }
    if (state == TEXT) {
        const char* start = q;
        size_t len = p-q;
        if (len > 2 && *start == '"' && start[len - 1] == '"') {
            start++;
            len -= 2;
        }
        out->push_back(string(start, len));
    }
}

static void
add_file(vector<FileRecord>* files, const FileOpType fileOp,
            const string& listFile, int listLine,
            const string& sourceName, const string& outName)
{
    FileRecord rec;
    rec.listFile = listFile;
    rec.listLine = listLine;
    rec.fileOp = fileOp;
    rec.sourceName = sourceName;
    rec.outName = outName;
    files->push_back(rec);
}

static string
replace_variables(const string& input,
                  const map<string, string>& variables,
                  bool* error) {
    if (variables.empty()) {
        return input;
    }

    // Abort if the variable prefix is not found
    if (input.find("${") == string::npos) {
        return input;
    }

    string result = input;

    // Note: rather than be fancy to detect recursive replacements,
    // we simply iterate till a given threshold is met.

    int retries = 1000;
    bool did_replace;

    do {
        did_replace = false;
        for (map<string, string>::const_iterator it = variables.begin();
             it != variables.end(); ++it) {
            string::size_type pos = 0;
            while((pos = result.find(it->first, pos)) != string::npos) {
                result = result.replace(pos, it->first.length(), it->second);
                pos += it->second.length();
                did_replace = true;
            }
        }
        if (did_replace && --retries == 0) {
            *error = true;
            fprintf(stderr, "Recursive replacement detected during variables "
                    "substitution. Full list of variables is: ");

            for (map<string, string>::const_iterator it = variables.begin();
                 it != variables.end(); ++it) {
                fprintf(stderr, "  %s=%s\n",
                        it->first.c_str(), it->second.c_str());
            }

            return result;
        }
    } while (did_replace);

    return result;
}

int
read_list_file(const string& filename,
               const map<string, string>& variables,
               vector<FileRecord>* files,
               vector<string>* excludes)
{
    int err = 0;
    FILE* f = NULL;
    long size;
    char* buf = NULL;
    char *p, *q;
    int i, lineCount;

    f = fopen(filename.c_str(), "r");
    if (f == NULL) {
        fprintf(stderr, "Could not open list file (%s): %s\n",
                    filename.c_str(), strerror(errno));
        err = errno;
        goto cleanup;
    }

    err = fseek(f, 0, SEEK_END);
    if (err != 0) {
        fprintf(stderr, "Could not seek to the end of file %s. (%s)\n",
                    filename.c_str(), strerror(errno));
        err = errno;
        goto cleanup;
    }

    size = ftell(f);

    err = fseek(f, 0, SEEK_SET);
    if (err != 0) {
        fprintf(stderr, "Could not seek to the beginning of file %s. (%s)\n",
                    filename.c_str(), strerror(errno));
        err = errno;
        goto cleanup;
    }

    buf = (char*)malloc(size+1);
    if (buf == NULL) {
        // (potentially large)
        fprintf(stderr, "out of memory (%ld)\n", size);
        err = ENOMEM;
        goto cleanup;
    }

    if (1 != fread(buf, size, 1, f)) {
        fprintf(stderr, "error reading file %s. (%s)\n",
                    filename.c_str(), strerror(errno));
        err = errno;
        goto cleanup;
    }

    // split on lines
    p = buf;
    q = buf+size;
    lineCount = 0;
    while (p<q) {
        if (*p == '\r' || *p == '\n') {
            *p = '\0';
            lineCount++;
        }
        p++;
    }

    // read lines
    p = buf;
    for (i=0; i<lineCount; i++) {
        int len = strlen(p);
        q = p + len + 1;
        if (is_whitespace_line(p) || is_comment_line(p)) {
            ;
        }
        else if (is_exclude_line(p)) {
            while (*p != '-') p++;
            p++;
            excludes->push_back(string(p));
        }
        else {
            vector<string> words;

            split_line(p, &words);

#if 0
            printf("[ ");
            for (size_t k=0; k<words.size(); k++) {
                printf("'%s' ", words[k].c_str());
            }
            printf("]\n");
#endif
            FileOpType op = FILE_OP_COPY;
            string paths[2];
            int pcount = 0;
            string errstr;
            for (vector<string>::iterator it = words.begin(); it != words.end(); ++it) {
                const string& word = *it;
                if (word == "rm") {
                    if (op != FILE_OP_COPY) {
                        errstr = "Error: you can only specifiy 'rm' or 'strip' once per line.";
                        break;
                    }
                    op = FILE_OP_REMOVE;
                } else if (word == "strip") {
                    if (op != FILE_OP_COPY) {
                        errstr = "Error: you can only specifiy 'rm' or 'strip' once per line.";
                        break;
                    }
                    op = FILE_OP_STRIP;
                } else if (pcount < 2) {
                    bool error = false;
                    paths[pcount++] = replace_variables(word, variables, &error);
                    if (error) {
                        err = 1;
                        goto cleanup;
                    }
                } else {
                    errstr = "Error: More than 2 paths per line.";
                    break;
                }
            }

            if (pcount == 0 && !errstr.empty()) {
                errstr = "Error: No path found on line.";
            }

            if (!errstr.empty()) {
                fprintf(stderr, "%s:%d: bad format: %s\n%s\nExpected: [SRC] [rm|strip] DEST\n",
                        filename.c_str(), i+1, p, errstr.c_str());
                err = 1;
            } else {
                if (pcount == 1) {
                    // pattern: [rm|strip] DEST
                    paths[1] = paths[0];
                }

                add_file(files, op, filename, i+1, paths[0], paths[1]);
            }
        }
        p = q;
    }

cleanup:
    if (buf != NULL) {
        free(buf);
    }
    if (f != NULL) {
        fclose(f);
    }
    return err;
}


int
locate(FileRecord* rec, const vector<string>& search)
{
    if (rec->fileOp == FILE_OP_REMOVE) {
        // Don't touch source files when removing a destination.
        rec->sourceMod = 0;
        rec->sourceSize = 0;
        rec->sourceIsDir = false;
        return 0;
    }

    int err;

    for (vector<string>::const_iterator it=search.begin();
                it!=search.end(); it++) {
        string full = path_append(*it, rec->sourceName);
        struct stat st;
        err = stat(full.c_str(), &st);
        if (err == 0) {
            rec->sourceBase = *it;
            rec->sourcePath = full;
            rec->sourceMod = st.st_mtime;
            rec->sourceSize = st.st_size;
            rec->sourceIsDir = S_ISDIR(st.st_mode);
            return 0;
        }
    }

    fprintf(stderr, "%s:%d: couldn't locate source file: %s\n",
                rec->listFile.c_str(), rec->listLine, rec->sourceName.c_str());
    return 1;
}

void
stat_out(const string& base, FileRecord* rec)
{
    rec->outPath = path_append(base, rec->outName);

    int err;
    struct stat st;
    err = stat(rec->outPath.c_str(), &st);
    if (err == 0) {
        rec->outMod = st.st_mtime;
        rec->outSize = st.st_size;
        rec->outIsDir = S_ISDIR(st.st_mode);
    } else {
        rec->outMod = 0;
        rec->outSize = 0;
        rec->outIsDir = false;
    }
}

string
dir_part(const string& filename)
{
    int pos = filename.rfind('/');
    if (pos <= 0) {
        return ".";
    }
    return filename.substr(0, pos);
}

static void
add_more(const string& entry, bool isDir,
         const FileRecord& rec, vector<FileRecord>*more)
{
    FileRecord r;
    r.listFile = rec.listFile;
    r.listLine = rec.listLine;
    r.sourceName = path_append(rec.sourceName, entry);
    r.sourcePath = path_append(rec.sourceBase, r.sourceName);
    struct stat st;
    int err = stat(r.sourcePath.c_str(), &st);
    if (err == 0) {
        r.sourceMod = st.st_mtime;
    }
    r.sourceIsDir = isDir;
    r.outName = path_append(rec.outName, entry);
    more->push_back(r);
}

static bool
matches_excludes(const char* file, const vector<string>& excludes)
{
    for (vector<string>::const_iterator it=excludes.begin();
            it!=excludes.end(); it++) {
        if (0 == fnmatch(it->c_str(), file, FNM_PERIOD)) {
            return true;
        }
    }
    return false;
}

static int
list_dir(const string& path, const FileRecord& rec,
                const vector<string>& excludes,
                vector<FileRecord>* more)
{
    string full = path_append(rec.sourceBase, rec.sourceName);
    full = path_append(full, path);

    DIR *d = opendir(full.c_str());
    if (d == NULL) {
        return errno;
    }

    vector<string> dirs;

    struct dirent *ent;
    while (NULL != (ent = readdir(d))) {
        if (0 == strcmp(".", ent->d_name)
                || 0 == strcmp("..", ent->d_name)) {
            continue;
        }
        if (matches_excludes(ent->d_name, excludes)) {
            continue;
        }
        string entry = path_append(path, ent->d_name);
        bool is_directory = (ent->d_type == DT_DIR);
        add_more(entry, is_directory, rec, more);
        if (is_directory) {
            dirs.push_back(entry);
        }
    }
    closedir(d);

    for (vector<string>::iterator it=dirs.begin(); it!=dirs.end(); it++) {
        list_dir(*it, rec, excludes, more);
    }

    return 0;
}

int
list_dir(const FileRecord& rec, const vector<string>& excludes,
            vector<FileRecord>* files)
{
    return list_dir("", rec, excludes, files);
}

FileRecord::FileRecord() {
    fileOp = FILE_OP_COPY;
}

