#!/bin/bash
#
# Copyright (C) 2008 The Android Open Source Project
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
#

#
# Finds files with the specified name under a particular directory, stopping
# the search in a given subdirectory when the file is found.
#

set -o nounset  # fail when dereferencing unset variables
set -o errexit  # fail if any subcommand fails

progName=`basename $0`

function warn() {
    echo "$progName: $@" >&2
}

function trace() {
    echo "$progName: $@"
}

function usage() {
    if [[ $# > 0 ]]
    then
        warn $@
    fi
    cat <<-EOF
Usage: $progName [<options>] <dirlist> <filename>
Options:
       --mindepth=<mindepth>
       --maxdepth=<maxdepth>
       Both behave in the same way as their find(1) equivalents.
       --prune=<glob>
       Avoids returning results from any path matching the given glob-style
       pattern (e.g., "*/out/*"). May be used multiple times.
EOF
    exit 1
}

function fail() {
    warn $@
    exit 1
}

if [ $# -lt 2 ]
then
    usage
fi

findargs=""
while [[ "${1:0:2}" == "--" ]]
do
    arg=${1:2}
    name=${arg%%=*}
    value=${arg##*=}
    if [[ "$name" == "mindepth" || "$name" == "maxdepth" ]]
    then
        # Add to beginning of findargs; these must come before the expression.
        findargs="-$name $value $findargs"
    elif [[ "$name" == "prune" ]]
    then
        # Add to end of findargs; these are part of the expression.
        findargs="$findargs -path $value -prune -or"
    fi
    shift
done

nargs=$#
# The filename is the last argument
filename="${!nargs}"

# Print out all files that match, as long as the path isn't explicitly
# pruned. This will print out extraneous results from directories whose
# parents have a match. These are filtered out by the awk script below.
find -L "${@:1:$nargs-1}" $findargs -type f -name "$filename" -print 2>/dev/null |

# Only pass along the directory of each match.
sed -e 's/\/[^\/]*$/\//' |

# Sort the output, so directories appear immediately before their contents.
# If there are any duplicates, the awk script will implicitly ignore them.
# The LC_ALL=C forces sort(1) to use bytewise ordering instead of listening
# to the locale, which may do case-insensitive and/or alphanumeric-only
# sorting.
LC_ALL=C sort |

# Always print the first line, which can't possibly be covered by a
# parent directory match. After that, only print lines where the last
# line printed isn't a prefix.
awk -v "filename=$filename" '
    (NR == 1) || (index($0, last) != 1) {
        last = $0;
        printf("%s%s\n", $0, filename);
    }
'
