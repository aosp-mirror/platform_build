#ifndef FILES_H
#define FILES_H

#include <string>
#include <vector>
#include <sys/types.h>

using namespace std;

struct FileRecord
{
    string listFile;
    int listLine;

    string sourceBase;
    string sourceName;
    string sourcePath;
    bool sourceIsDir;
    time_t sourceMod;

    string outName;
    string outPath;
    time_t outMod;
    bool outIsDir;
    unsigned int mode;
};

int read_list_file(const string& filename, vector<FileRecord>* files,
                    vector<string>* excludes);
int locate(FileRecord* rec, const vector<string>& search);
void stat_out(const string& base, FileRecord* rec);
string dir_part(const string& filename);
int list_dir(const FileRecord& rec, const vector<string>& excludes,
                    vector<FileRecord>* files);

#endif // FILES_H
