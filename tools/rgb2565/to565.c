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

#define to565(r,g,b)                                            \
    ((((r) >> 3) << 11) | (((g) >> 2) << 5) | ((b) >> 3))

#define from565_r(x) ((((x) >> 11) & 0x1f) * 255 / 31)
#define from565_g(x) ((((x) >> 5) & 0x3f) * 255 / 63)
#define from565_b(x) (((x) & 0x1f) * 255 / 31)

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

void to_565_raw_dither(int width)
{
    unsigned char in[3];
    unsigned short out;
    int i = 0;
    int e;

    int* error = malloc((width+2) * 3 * sizeof(int));
    int* next_error = malloc((width+2) * 3 * sizeof(int));
    memset(error, 0, (width+2) * 3 * sizeof(int));
    memset(next_error, 0, (width+2) * 3 * sizeof(int));
    error += 3;        // array goes from [-3..((width+1)*3+2)]
    next_error += 3;

    while(read(0, in, 3) == 3) {
        int r = in[0] + error[i*3+0];
        int rb = (r < 0) ? 0 : ((r > 255) ? 255 : r);

        int g = in[1] + error[i*3+1];
        int gb = (g < 0) ? 0 : ((g > 255) ? 255 : g);

        int b = in[2] + error[i*3+2];
        int bb = (b < 0) ? 0 : ((b > 255) ? 255 : b);

        out = to565(rb, gb, bb);
        write(1, &out, 2);

#define apply_error(ch) {                                               \
            next_error[(i-1)*3+ch] += e * 3 / 16;                       \
            next_error[(i)*3+ch] += e * 5 / 16;                         \
            next_error[(i+1)*3+ch] += e * 1 / 16;                       \
            error[(i+1)*3+ch] += e - ((e*1/16) + (e*3/16) + (e*5/16));  \
        }

        e = r - from565_r(out);
        apply_error(0);

        e = g - from565_g(out);
        apply_error(1);

        e = b - from565_b(out);
        apply_error(2);

#undef apply_error

        ++i;
        if (i == width) {
            // error <- next_error; next_error <- 0
            int* temp = error; error = next_error; next_error = temp;
            memset(next_error, 0, (width+1) * 3 * sizeof(int));
            i = 0;
        }
    }

    free(error-3);
    free(next_error-3);

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
    if ((argc == 2) && (!strcmp(argv[1],"-rle"))) {
        to_565_rle();
    } else {
        if (argc > 2 && (!strcmp(argv[1], "-w"))) {
            to_565_raw_dither(atoi(argv[2]));
        } else {
            to_565_raw();
        }
    }
    return 0;
}
