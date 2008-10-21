/*
 * Copyright (C) 2008 The Android Open Source Project
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
	      
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#define to565(r,g,b) \
    ((((r) >> 3) << 11) | (((g) >> 2) << 5) | ((b) >> 3))

void to_565_raw(void)
{
    unsigned char in[3];
    unsigned short out;
    
    while(read(0, in, 3) == 3) {
        out = to565(in[0],in[1],in[2]);
        write(1, &out, 2);
    }
    return;
}

void to_565_rle(void)
{
    unsigned char in[3];
    unsigned short last, color, count;
    unsigned total = 0;
    count = 0;

    while(read(0, in, 3) == 3) {
        color = to565(in[0],in[1],in[2]);
        if (count) {
            if ((color == last) && (count != 65535)) {
                count++;
                continue;
            } else {
                write(1, &count, 2);
                write(1, &last, 2);
                total += count;
            }
        }
        last = color;
        count = 1;
    }
    if (count) {
        write(1, &count, 2);
        write(1, &last, 2);
        total += count;
    }
    fprintf(stderr,"%d pixels\n",total);
}

int main(int argc, char **argv)
{
    if ((argc > 1) && (!strcmp(argv[1],"-rle"))) {
        to_565_rle();
    } else {
        to_565_raw();
    }
    return 0;
}
