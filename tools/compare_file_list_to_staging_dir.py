#!/usr/bin/env python3

import argparse
import os
import sys

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('partitions_were_clean_at_start_of_build')
    parser.add_argument('file_list')
    parser.add_argument('staging_dir')
    args = parser.parse_args()

    with open(args.partitions_were_clean_at_start_of_build, 'r') as f:
        contents = f.read().strip()
        if contents not in ['true', 'false']:
            sys.exit('failed to read ' + args.partitions_were_clean_at_start_of_build)
        if contents == 'false':
            # Since the partitions weren't clean at the start of the build, the test would
            # arbitrarily fail if we tried to run it. This is only for builds that directly follow
            # an `m installclean`. (Like most ci builds do)
            return

    with open(args.file_list, 'r') as f:
        files_in_file_list = set(f.read().strip().splitlines())

    files_in_staging_dir = set()
    for root, _, files in os.walk(args.staging_dir):
        for f in files:
            fullpath = os.path.join(root, f)
            files_in_staging_dir.add(os.path.relpath(fullpath, args.staging_dir))

    # backslashes aren't allowed in expression parts of f-strings
    sep = '\n  '
    if files_in_staging_dir != files_in_file_list:
        sys.exit(f'''Files in staging directory did not match files in file list after an installclean.
Note that in order to reproduce this error, you must run `m installclean` directly before `m`.
Files in the staging dir but not in the file list:
  {sep.join(sorted(files_in_staging_dir - files_in_file_list))}
Files in the file list but not in the staging dir:
  {sep.join(sorted(files_in_file_list - files_in_staging_dir))}
''')

if __name__ == "__main__":
    main()
