#!/usr/bin/env python
#
# Copyright (C) 2023 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from typing import List
from glob import glob
from pathlib import Path
from os.path import join, relpath
from itertools import chain
import argparse

class FileLister:
    def __init__(self, args) -> None:
        self.out_file = args.out_file

        self.folder_dir = args.dir
        self.extensions = [e if e.startswith(".") else "." + e for e in args.extensions]
        self.root = args.root
        self.files_list : List[str] = list()
        self.classes = args.classes

    def get_files(self) -> None:
        """Get all files directory in the input directory including the files in the subdirectories

        Recursively finds all files in the input directory.
        Set file_list as a list of file directory strings,
        which do not include directories but only files.
        List is sorted in alphabetical order of the file directories.

        Args:
            dir: Directory to get the files. String.

        Raises:
            FileNotFoundError: An error occurred accessing the non-existing directory
        """

        if not dir_exists(self.folder_dir):
            raise FileNotFoundError(f"Directory {self.folder_dir} does not exist")

        if self.folder_dir[:-2] != "**":
            self.folder_dir = join(self.folder_dir, "**")

        self.files_list = list()
        for file in sorted(glob(self.folder_dir, recursive=True)):
            if Path(file).is_file():
                if self.root:
                    file = join(self.root, relpath(file, self.folder_dir[:-2]))
                self.files_list.append(file)


    def list(self) -> None:
        self.get_files()
        self.files_list = [f for f in self.files_list if not self.extensions or Path(f).suffix in self.extensions]

        # If files_list is as below:
        # A/B/C.java
        # A/B/D.java
        # A/B/E.txt
        # --classes flag converts files_list in the following format:
        # A/B/C.class
        # A/B/C$*.class
        # A/B/D.class
        # A/B/D$*.class
        # Additional `$*`-suffixed line is appended after each line
        # to take multiple top level classes in a single java file into account.
        # Note that non-java files in files_list are filtered out.
        if self.classes:
            self.files_list = list(chain.from_iterable([
                (class_files := str(Path(ff).with_suffix(".class")),
                 class_files.replace(".class", "$*.class"))
                 for ff in self.files_list if ff.endswith(".java")
            ]))

        self.write()

    def write(self) -> None:
        if self.out_file == "":
            pprint(self.files_list)
        else:
            write_lines(self.out_file, self.files_list)

###
# Helper functions
###
def pprint(l: List[str]) -> None:
    for line in l:
        print(line)

def dir_exists(dir: str) -> bool:
    return Path(dir).exists()

def write_lines(out_file: str, lines: List[str]) -> None:
    with open(out_file, "w+") as f:
        f.writelines(line + '\n' for line in lines)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('dir', action='store', type=str,
                        help="directory to list all subdirectory files")
    parser.add_argument('--out', dest='out_file',
                        action='store', default="", type=str,
                        help="optional directory to write subdirectory files. If not set, will print to console")
    parser.add_argument('--root', dest='root',
                        action='store', default="", type=str,
                        help="optional directory to replace the root directories of output.")
    parser.add_argument('--extensions', nargs='*', default=list(), dest='extensions',
                        help="Extensions to include in the output. If not set, all files are included")
    parser.add_argument('--classes', dest='classes', action=argparse.BooleanOptionalAction,
                        help="Optional flag. If passed, outputs a list of pattern of class files \
                                that will be produced by compiling java files in the input dir. \
                                Non-java files in the input directory will be ignored.")

    args = parser.parse_args()

    file_lister = FileLister(args)
    file_lister.list()
