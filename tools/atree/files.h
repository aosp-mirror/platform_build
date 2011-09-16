#ifndef FILES_H
#define FILES_H

#include <map>
#include <string>
#include <vector>
#include <sys/types.h>

using namespace std;

enum FileOpType {
    FILE_OP_COPY = 0,
    FILE_OP_REMOVE,
    FILE_OP_STRIP
};

struct FileRecord
{
    FileRecord();

    string listFile;
    int listLine;

    string sourceBase;
    string sourceName;
    string sourcePath;
    bool sourceIsDir;
    time_t sourceMod;
    off_t  sourceSize;
    FileOpType fileOp;

    string outName;
    string outPath;
    off_t  outSize;
    time_t outMod;
    bool outIsDir;
    unsigned int mode;
};

int read_list_file(const string& filename,
                   const map<string, string>& variables,
                   vector<FileRecord>* files,
                   vector<string>* excludes);
int locate(FileRecord* rec, const vector<string>& search);
void stat_out(const string& base, FileRecord* rec);
string dir_part(const string& filename);
int list_dir(const FileRecord& rec, const vector<string>& excludes,
                    vector<FileRecord>* files);

#endif // FILES_H
