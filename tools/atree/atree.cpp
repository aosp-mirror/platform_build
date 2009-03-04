#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "options.h"
#include "files.h"
#include "fs.h"
#include <set>
#include <iostream>
#include <sstream>

using namespace std;

bool g_debug = false;
vector<string> g_listFiles;
vector<string> g_inputBases;
map<string, string> g_variables;
string g_outputBase;
string g_dependency;
bool g_useHardLinks = false;

const char* USAGE =
"\n"
"Usage: atree OPTIONS\n"
"\n"
"Options:\n"
"  -f FILELIST    Specify one or more files containing the\n"
"                 list of files to copy.\n"
"  -I INPUTDIR    Specify one or more base directories in\n"
"                 which to look for the files\n"
"  -o OUTPUTDIR   Specify the directory to copy all of the\n"
"                 output files to.\n"
"  -l             Use hard links instead of copying the files.\n"
"  -m DEPENDENCY  Output a make-formatted file containing the list.\n"
"                 of files included.  It sets the variable ATREE_FILES.\n"
"  -v VAR=VAL     Replaces ${VAR} by VAL when reading input files.\n"
"\n"
"FILELIST file format:\n"
"  The FILELIST files contain the list of files that will end up\n"
"  in the final OUTPUTDIR.  Atree will look for files in the INPUTDIR\n"
"  directories in the order they are specified.\n"
"\n"
"  In a FILELIST file, comment lines start with a #.  Other lines\n"
"  are of the format:\n"
"\n"
"    DEST\n"
"    SRC DEST\n"
"    -SRCPATTERN\n"
"\n"
"  DEST should be path relative to the output directory.\n"
"  If SRC is supplied, the file names can be different.\n"
"  SRCPATTERN is a pattern for the filenames.\n"
"\n";

int usage()
{
    fwrite(USAGE, strlen(USAGE), 1, stderr);
    return 1;
}

static bool
add_variable(const char* arg) {
    const char* p = arg;
    while (*p && *p != '=') p++;

    if (*p == 0 || p == arg || p[1] == 0) {
        return false;
    }

    ostringstream var;
    var << "${" << string(arg, p-arg) << "}";
    g_variables[var.str()] = string(p+1);
    return true;
}

int
main(int argc, char* const* argv)
{
    int err;
    bool done = false;
    while (!done) {
        int opt = getopt(argc, argv, "f:I:o:hlm:v:");
        switch (opt)
        {
            case -1:
                done = true;
                break;
            case 'f':
                g_listFiles.push_back(string(optarg));
                break;
            case 'I':
                g_inputBases.push_back(string(optarg));
                break;
            case 'o':
                if (g_outputBase.length() != 0) {
                    fprintf(stderr, "%s: -o may only be supplied once -- "
                                "-o %s\n", argv[0], optarg);
                    return usage();
                }
                g_outputBase = optarg;
                break;
            case 'l':
                g_useHardLinks = true;
                break;
            case 'm':
                if (g_dependency.length() != 0) {
                    fprintf(stderr, "%s: -m may only be supplied once -- "
                                "-m %s\n", argv[0], optarg);
                    return usage();
                }
                g_dependency = optarg;
                break;
            case 'v':
                if (!add_variable(optarg)) {
                    fprintf(stderr, "%s Invalid expression in '-v %s': "
                            "expected format is '-v VAR=VALUE'.\n",
                            argv[0], optarg);
                    return usage();
                }
                break;
            default:
            case '?':
            case 'h':
                return usage();
        }
    }
    if (optind != argc) {
        fprintf(stderr, "%s: invalid argument -- %s\n", argv[0], argv[optind]);
        return usage();
    }

    if (g_listFiles.size() == 0) {
        fprintf(stderr, "%s: At least one -f option must be supplied.\n",
                 argv[0]);
        return usage();
    }

    if (g_inputBases.size() == 0) {
        fprintf(stderr, "%s: At least one -I option must be supplied.\n",
                 argv[0]);
        return usage();
    }

    if (g_outputBase.length() == 0) {
        fprintf(stderr, "%s: -o option must be supplied.\n", argv[0]);
        return usage();
    }


#if 0
    for (vector<string>::iterator it=g_listFiles.begin();
                                it!=g_listFiles.end(); it++) {
        printf("-f \"%s\"\n", it->c_str());
    }
    for (vector<string>::iterator it=g_inputBases.begin();
                                it!=g_inputBases.end(); it++) {
        printf("-I \"%s\"\n", it->c_str());
    }
    printf("-o \"%s\"\n", g_outputBase.c_str());
    if (g_useHardLinks) {
        printf("-l\n");
    }
#endif

    vector<FileRecord> files;
    vector<FileRecord> more;
    vector<string> excludes;
    set<string> directories;
    set<string> deleted;

    // read file lists
    for (vector<string>::iterator it=g_listFiles.begin();
                                it!=g_listFiles.end(); it++) {
        err = read_list_file(*it, g_variables, &files, &excludes);
        if (err != 0) {
            return err;
        }
    }

    // look for input files
    err = 0;
    for (vector<FileRecord>::iterator it=files.begin();
                                it!=files.end(); it++) {
        err |= locate(&(*it), g_inputBases);

    }
    
    // expand the directories that we should copy into a list of files
    for (vector<FileRecord>::iterator it=files.begin();
                                it!=files.end(); it++) {
        if (it->sourceIsDir) {
            err |= list_dir(*it, excludes, &more);
        }
    }
    for (vector<FileRecord>::iterator it=more.begin();
                                it!=more.end(); it++) {
        files.push_back(*it);
    }

    // get the name and modtime of the output files
    for (vector<FileRecord>::iterator it=files.begin();
                                it!=files.end(); it++) {
        stat_out(g_outputBase, &(*it));
    }

    if (err != 0) {
        return 1;
    }

    // gather directories
    for (vector<FileRecord>::iterator it=files.begin();
                                it!=files.end(); it++) {
        if (it->sourceIsDir) {
            directories.insert(it->outPath);
        } else {
            string s = dir_part(it->outPath);
            if (s != ".") {
                directories.insert(s);
            }
        }
    }

    // gather files that should become directores and directories that should
    // become files
    for (vector<FileRecord>::iterator it=files.begin();
                                it!=files.end(); it++) {
        if (it->outMod != 0 && it->sourceIsDir != it->outIsDir) {
            deleted.insert(it->outPath);
        }
    }

    // delete files
    for (set<string>::iterator it=deleted.begin();
                                it!=deleted.end(); it++) {
        if (g_debug) {
            printf("deleting %s\n", it->c_str());
        }
        err = remove_recursively(*it);
        if (err != 0) {
            return err;
        }
    }

    // make directories
    for (set<string>::iterator it=directories.begin();
                                it!=directories.end(); it++) {
        if (g_debug) {
            printf("mkdir %s\n", it->c_str());
        }
        err = mkdir_recursively(*it);
        if (err != 0) {
            return err;
        }
    }

    // copy (or link) files
    for (vector<FileRecord>::iterator it=files.begin();
                                it!=files.end(); it++) {
        if (!it->sourceIsDir) {
            if (g_debug) {
                printf("copy %s(%ld) ==> %s(%ld)", it->sourcePath.c_str(),
                    it->sourceMod, it->outPath.c_str(), it->outMod);
                fflush(stdout);
            }

            if (it->outMod < it->sourceMod) {
                err = copy_file(it->sourcePath, it->outPath);
                if (g_debug) {
                    printf(" done.\n");
                }
                if (err != 0) {
                    return err;
                }
            } else {
                if (g_debug) {
                    printf(" skipping.\n");
                }
            }
        }
    }

    // output the dependency file
    if (g_dependency.length() != 0) {
        FILE *f = fopen(g_dependency.c_str(), "w");
        if (f != NULL) {
            fprintf(f, "ATREE_FILES := $(ATREE_FILES) \\\n");
            for (vector<FileRecord>::iterator it=files.begin();
                                it!=files.end(); it++) {
                if (!it->sourceIsDir) {
                    fprintf(f, "%s \\\n", it->sourcePath.c_str());
                }
            }
            fprintf(f, "\n");
            fclose(f);
        } else {
            fprintf(stderr, "error opening manifest file for write: %s\n",
                    g_dependency.c_str());
        }
    }

    return 0;
}
