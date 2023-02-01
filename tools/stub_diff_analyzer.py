#!/usr/bin/env python
#
# Copyright (C) 2022 The Android Open Source Project
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

from sys import exit
from typing import List
from glob import glob
from pathlib import Path
from collections import defaultdict
from difflib import Differ
from re import split
from tqdm import tqdm
import argparse


DIFFER_CODE_LEN = 2

class DifferCodes:
    COMMON = '  '
    UNIQUE_FIRST = '- '
    UNIQUE_SECOND = '+ '
    DIFF_IDENT = '? '

class FilesDiffAnalyzer:
    def __init__(self, args) -> None:
        self.out_dir = args.out_dir
        self.show_diff = args.show_diff
        self.skip_words = args.skip_words
        self.first_dir = args.first_dir
        self.second_dir = args.second_dir
        self.include_common = args.include_common

        self.first_dir_files = self.get_files(self.first_dir)
        self.second_dir_files = self.get_files(self.second_dir)
        self.common_file_map = defaultdict(set)

        self.map_common_files(self.first_dir_files, self.first_dir)
        self.map_common_files(self.second_dir_files, self.second_dir)

    def get_files(self, dir: str) -> List[str]:
        """Get all files directory in the input directory including the files in the subdirectories

        Recursively finds all files in the input directory.
        Returns a list of file directory strings, which do not include directories but only files.
        List is sorted in alphabetical order of the file directories.

        Args:
            dir: Directory to get the files. String.

        Returns:
            A list of file directory strings within the input directory.
            Sorted in Alphabetical order.

        Raises:
            FileNotFoundError: An error occurred accessing the non-existing directory
        """

        if not dir_exists(dir):
            raise FileNotFoundError("Directory does not exist")

        if dir[:-2] != "**":
            if dir[:-1] != "/":
                dir += "/"
            dir += "**"

        return [file for file in sorted(glob(dir, recursive=True)) if Path(file).is_file()]

    def map_common_files(self, files: List[str], dir: str) -> None:
        for file in files:
            file_name = file.split(dir, 1)[-1]
            self.common_file_map[file_name].add(dir)
        return

    def compare_file_contents(self, first_file: str, second_file: str) -> List[str]:
        """Compare the contents of the files and return different lines

        Given two file directory strings, compare the contents of the two files
        and return the list of file contents string prepended with unique identifier codes.
        The identifier codes include:
        - '  '(two empty space characters): Line common to two files
        - '- '(minus followed by a space) : Line unique to first file
        - '+ '(plus followed by a space)  : Line unique to second file

        Args:
            first_file: First file directory string to compare the content
            second_file: Second file directory string to compare the content

        Returns:
            A list of the file content strings. For example:

            [
                "  Foo",
                "- Bar",
                "+ Baz"
            ]
        """

        d = Differ()
        first_file_contents = sort_methods(get_file_contents(first_file))
        second_file_contents = sort_methods(get_file_contents(second_file))
        diff = list(d.compare(first_file_contents, second_file_contents))
        ret = [f"diff {first_file} {second_file}"]

        idx = 0
        while idx < len(diff):
            line = diff[idx]
            line_code = line[:DIFFER_CODE_LEN]

            match line_code:
                case DifferCodes.COMMON:
                    if self.include_common:
                        ret.append(line)

                case DifferCodes.UNIQUE_FIRST:
                    # Should compare line
                    if (idx < len(diff) - 1 and
                        (next_line_code := diff[idx + 1][:DIFFER_CODE_LEN])
                        not in (DifferCodes.UNIQUE_FIRST, DifferCodes.COMMON)):
                        delta = 1 if next_line_code == DifferCodes.UNIQUE_SECOND else 2
                        line_to_compare = diff[idx + delta]
                        if self.lines_differ(line, line_to_compare):
                            ret.extend([line, line_to_compare])
                        else:
                            if self.include_common:
                                ret.append(DifferCodes.COMMON +
                                           line[DIFFER_CODE_LEN:])
                        idx += delta
                    else:
                        ret.append(line)

                case DifferCodes.UNIQUE_SECOND:
                    ret.append(line)

                case DifferCodes.DIFF_IDENT:
                    pass
            idx += 1
        return ret

    def lines_differ(self, line1: str, line2: str) -> bool:
        """Check if the input lines are different or not

        Compare the two lines word by word and check if the two lines are different or not.
        If the different words in the comparing lines are included in skip_words,
        the lines are not considered different.

        Args:
            line1:      first line to compare
            line2:      second line to compare

        Returns:
            Boolean value indicating if the two lines are different or not

        """
        # Split by '.' or ' '(whitespace)
        def split_words(line: str) -> List[str]:
            return split('\\s|\\.', line[DIFFER_CODE_LEN:])

        line1_words, line2_words = split_words(line1), split_words(line2)
        if len(line1_words) != len(line2_words):
            return True

        for word1, word2 in zip(line1_words, line2_words):
            if word1 != word2:
                # not check if words are equal to skip word, but
                # check if words contain skip word as substring
                if all(sw not in word1 and sw not in word2 for sw in self.skip_words):
                    return True

        return False

    def analyze(self) -> None:
        """Analyze file contents in both directories and write to output or console.
        """
        for file in tqdm(sorted(self.common_file_map.keys())):
            val = self.common_file_map[file]

            # When file exists in both directories
            lines = list()
            if val == set([self.first_dir, self.second_dir]):
                lines = self.compare_file_contents(
                    self.first_dir + file, self.second_dir + file)
            else:
                existing_dir, not_existing_dir = (
                    (self.first_dir, self.second_dir) if self.first_dir in val
                    else (self.second_dir, self.first_dir))

                lines = [f"{not_existing_dir}{file} does not exist."]

                if self.show_diff:
                    lines.append(f"Content of {existing_dir}{file}: \n")
                    lines.extend(get_file_contents(existing_dir + file))

            self.write(lines)

    def write(self, lines: List[str]) -> None:
        if self.out_dir == "":
            pprint(lines)
        else:
            write_lines(self.out_dir, lines)

###
# Helper functions
###

def sort_methods(lines: List[str]) -> List[str]:
    """Sort class methods in the file contents by alphabetical order

    Given lines of Java file contents, return lines with class methods sorted in alphabetical order.
    Also omit empty lines or lines with spaces.
    For example:
        l = [
            "package android.test;",
            "",
            "public static final int ORANGE = 1;",
            "",
            "public class TestClass {",
            "public TestClass() { throw new RuntimeException("Stub!"); }",
            "public void foo() { throw new RuntimeException("Stub!"); }",
            "public void bar() { throw new RuntimeException("Stub!"); }",
            "}"
        ]
        sort_methods(l) returns
        [
            "package android.test;",
            "public static final int ORANGE = 1;",
            "public class TestClass {",
            "public TestClass() { throw new RuntimeException("Stub!"); }",
            "public void bar() { throw new RuntimeException("Stub!"); }",
            "public void foo() { throw new RuntimeException("Stub!"); }",
            "}"
        ]

    Args:
        lines: List of strings consisted of Java file contents.

    Returns:
        A list of string with sorted class methods.

    """
    def is_not_blank(l: str) -> bool:
        return bool(l) and not l.isspace()

    ret = list()

    in_class = False
    buffer = list()
    for line in lines:
        if not in_class:
            if "class" in line:
                in_class = True
                ret.append(line)
            else:
                # Adding static variables, package info, etc.
                # Skipping empty or space lines.
                if is_not_blank(line):
                    ret.append(line)
        else:
            # End of class
            if line and line[0] == "}":
                in_class = False
                ret.extend(sorted(buffer))
                buffer = list()
                ret.append(line)
            else:
                if is_not_blank(line):
                    buffer.append(line)

    return ret

def get_file_contents(file_path: str) -> List[str]:
    lines = list()
    with open(file_path) as f:
        lines = [line.rstrip('\n') for line in f]
        f.close()
    return lines

def pprint(l: List[str]) -> None:
    for line in l:
        print(line)

def write_lines(out_dir: str, lines: List[str]) -> None:
    with open(out_dir, "a") as f:
        f.writelines(line + '\n' for line in lines)
        f.write("\n")
        f.close()

def dir_exists(dir: str) -> bool:
    return Path(dir).exists()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('first_dir', action='store', type=str,
                        help="first path to compare file directory and contents")
    parser.add_argument('second_dir', action='store', type=str,
                        help="second path to compare file directory and contents")
    parser.add_argument('--out', dest='out_dir',
                        action='store', default="", type=str,
                        help="optional directory to write log. If not set, will print to console")
    parser.add_argument('--show-diff-file', dest='show_diff',
                        action=argparse.BooleanOptionalAction,
                        help="optional flag. If passed, will print out the content of the file unique to each directories")
    parser.add_argument('--include-common', dest='include_common',
                        action=argparse.BooleanOptionalAction,
                        help="optional flag. If passed, will print out the contents common to both files as well,\
                            instead of printing only diff lines.")
    parser.add_argument('--skip-words', nargs='+',
                        dest='skip_words', default=[], help="optional words to skip in comparison")

    args = parser.parse_args()

    if not args.first_dir or not args.second_dir:
        parser.print_usage()
        exit(0)

    analyzer = FilesDiffAnalyzer(args)
    analyzer.analyze()
