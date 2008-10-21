#ifndef FS_H
#define FS_H

#include <string>

using namespace std;

int remove_recursively(const string& path);
int mkdir_recursively(const string& path);
int copy_file(const string& src, const string& dst);

#endif // FS_H
