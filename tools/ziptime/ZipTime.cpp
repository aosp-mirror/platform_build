/*
 * Copyright (C) 2015 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * Zip tool to remove dynamic timestamps
 */
#include "ZipFile.h"

#include <stdlib.h>
#include <stdio.h>

using namespace android;

static void usage(void)
{
    fprintf(stderr, "Zip timestamp utility\n");
    fprintf(stderr, "Copyright (C) 2015 The Android Open Source Project\n\n");
    fprintf(stderr, "Usage: ziptime file.zip\n");
}

int main(int argc, char* const argv[])
{
    if (argc != 2) {
        usage();
        return 2;
    }

    ZipFile zip;
    if (zip.rewrite(argv[1]) != 0) {
        fprintf(stderr, "Unable to rewrite '%s' as zip archive\n", argv[1]);
        return 1;
    }

    return 0;
}
