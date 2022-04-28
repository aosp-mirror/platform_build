#!/usr/bin/env python3

"""
The complete list of the remaining Make files in each partition for all lunch targets

How to run?
python3 $(path-to-file)/mk2bp_partition.py
"""

from pathlib import Path

import csv
import datetime
import os
import shutil
import subprocess
import sys
import time

def get_top():
  path = '.'
  while not os.path.isfile(os.path.join(path, 'build/soong/soong_ui.bash')):
    if os.path.abspath(path) == '/':
      sys.exit('Could not find android source tree root.')
    path = os.path.join(path, '..')
  return os.path.abspath(path)

# get the values of a build variable
def get_build_var(variable, product, build_variant):
  """Returns the result of the shell command get_build_var."""
  env = {
      **os.environ,
      'TARGET_PRODUCT': product if product else '',
      'TARGET_BUILD_VARIANT': build_variant if build_variant else '',
  }
  return subprocess.run([
      'build/soong/soong_ui.bash',
      '--dumpvar-mode',
      variable
  ], check=True, capture_output=True, env=env, text=True).stdout.strip()

def get_make_file_partitions():
    lunch_targets = set(get_build_var("all_named_products", "", "").split())
    total_lunch_targets = len(lunch_targets)
    makefile_by_partition = dict()
    partitions = set()
    current_count = 0
    start_time = time.time()
    # cannot run command `m lunch_target`
    broken_targets = {"mainline_sdk", "ndk"}
    for lunch_target in sorted(lunch_targets):
        current_count += 1
        current_time = time.time()
        print (current_count, "/", total_lunch_targets, lunch_target, datetime.timedelta(seconds=current_time - start_time))
        if lunch_target in broken_targets:
            continue
        installed_product_out = get_build_var("PRODUCT_OUT", lunch_target, "userdebug")
        filename = os.path.join(installed_product_out, "mk2bp_remaining.csv")
        copy_filename = os.path.join(installed_product_out, lunch_target + "_mk2bp_remaining.csv")
        # only generate if not exists
        if not os.path.exists(copy_filename):
            bash_cmd = "bash build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=" + lunch_target
            bash_cmd += " TARGET_BUILD_VARIANT=userdebug " + filename
            subprocess.run(bash_cmd, shell=True, text=True, check=True, stdout=subprocess.DEVNULL)
            # generate a copied .csv file, to avoid possible overwritings
            with open(copy_filename, "w") as file:
                shutil.copyfile(filename, copy_filename)

        # open mk2bp_remaining.csv file
        with open(copy_filename, "r") as csvfile:
            reader = csv.reader(csvfile, delimiter=",", quotechar='"')
            # bypass the header row
            next(reader, None)
            for row in reader:
                # read partition information
                partition = row[2]
                makefile_by_partition.setdefault(partition, set()).add(row[0])
                partitions.add(partition)

    # write merged make file list for each partition into a csv file
    installed_path = Path(installed_product_out).parents[0].as_posix()
    csv_path = installed_path + "/mk2bp_partition.csv"
    with open(csv_path, "wt") as csvfile:
        writer = csv.writer(csvfile, delimiter=",")
        count_makefile = 0
        for partition in sorted(partitions):
            number_file = len(makefile_by_partition[partition])
            count_makefile += number_file
            writer.writerow([partition, number_file])
            for makefile in sorted(makefile_by_partition[partition]):
                writer.writerow([makefile])
        row = ["The total count of make files is ", count_makefile]
        writer.writerow(row)

def main():
    os.chdir(get_top())
    get_make_file_partitions()

if __name__ == "__main__":
    main()
