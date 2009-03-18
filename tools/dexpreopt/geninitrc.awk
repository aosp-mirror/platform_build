#
# Copyright (C) 2009 The Android Open Source Project
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
BEGIN {
    fixed_remount = 0;
    console_state = 0;
}

/^    mount yaffs2 mtd@system \/system ro remount$/ {
    fixed_remount = 1;
    print "    #   dexpreopt needs to write to /system";
    print "    ### " $0;
    next;
}

console_state == 0 && /^service console \/system\/bin\/sh$/ {
    console_state = 1;
    print;
    next;
}

console_state == 1 && /^    console$/ {
    console_state = 2;
    print;
    exit;
}

console_state == 1 {
    # The second line of the console entry should always immediately
    # follow the first.
    exit;
}

{ print }

END {
    failed = 0;
    if (fixed_remount != 1) {
        print "ERROR: no match for remount line" > "/dev/stderr";
        failed = 1;
    }
    if (console_state != 2) {
        print "ERROR: no match for console lines" > "/dev/stderr";
        failed = 1;
    }
    if (failed == 1) {
        print ">>>> FAILED <<<<"
        exit 1;
    }
}
