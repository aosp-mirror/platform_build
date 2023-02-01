// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bytes"
	"fmt"
	"os"
	"strings"
	"testing"

	"android/soong/tools/compliance"
)

func TestMain(m *testing.M) {
	// Change into the parent directory before running the tests
	// so they can find the testdata directory.
	if err := os.Chdir(".."); err != nil {
		fmt.Printf("failed to change to testdata directory: %s\n", err)
		os.Exit(1)
	}
	os.Exit(m.Run())
}

func Test_plaintext(t *testing.T) {
	tests := []struct {
		condition   string
		name        string
		outDir      string
		roots       []string
		ctx         context
		expectedOut []string
	}{
		{
			condition: "firstparty",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []string{
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/lib/liba.so.meta_lic static",
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/lib/libc.a.meta_lic static",
				"testdata/firstparty/bin/bin2.meta_lic testdata/firstparty/lib/libb.so.meta_lic dynamic",
				"testdata/firstparty/bin/bin2.meta_lic testdata/firstparty/lib/libd.so.meta_lic dynamic",
				"testdata/firstparty/highest.apex.meta_lic testdata/firstparty/bin/bin1.meta_lic static",
				"testdata/firstparty/highest.apex.meta_lic testdata/firstparty/bin/bin2.meta_lic static",
				"testdata/firstparty/highest.apex.meta_lic testdata/firstparty/lib/liba.so.meta_lic static",
				"testdata/firstparty/highest.apex.meta_lic testdata/firstparty/lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/firstparty/"}},
			expectedOut: []string{
				"bin/bin1.meta_lic lib/liba.so.meta_lic static",
				"bin/bin1.meta_lic lib/libc.a.meta_lic static",
				"bin/bin2.meta_lic lib/libb.so.meta_lic dynamic",
				"bin/bin2.meta_lic lib/libd.so.meta_lic dynamic",
				"highest.apex.meta_lic bin/bin1.meta_lic static",
				"highest.apex.meta_lic bin/bin2.meta_lic static",
				"highest.apex.meta_lic lib/liba.so.meta_lic static",
				"highest.apex.meta_lic lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/firstparty/"}, labelConditions: true},
			expectedOut: []string{
				"bin/bin1.meta_lic:notice lib/liba.so.meta_lic:notice static",
				"bin/bin1.meta_lic:notice lib/libc.a.meta_lic:notice static",
				"bin/bin2.meta_lic:notice lib/libb.so.meta_lic:notice dynamic",
				"bin/bin2.meta_lic:notice lib/libd.so.meta_lic:notice dynamic",
				"highest.apex.meta_lic:notice bin/bin1.meta_lic:notice static",
				"highest.apex.meta_lic:notice bin/bin2.meta_lic:notice static",
				"highest.apex.meta_lic:notice lib/liba.so.meta_lic:notice static",
				"highest.apex.meta_lic:notice lib/libb.so.meta_lic:notice static",
			},
		},
		{
			condition: "firstparty",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []string{
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/lib/liba.so.meta_lic static",
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/lib/libc.a.meta_lic static",
				"testdata/firstparty/bin/bin2.meta_lic testdata/firstparty/lib/libb.so.meta_lic dynamic",
				"testdata/firstparty/bin/bin2.meta_lic testdata/firstparty/lib/libd.so.meta_lic dynamic",
				"testdata/firstparty/container.zip.meta_lic testdata/firstparty/bin/bin1.meta_lic static",
				"testdata/firstparty/container.zip.meta_lic testdata/firstparty/bin/bin2.meta_lic static",
				"testdata/firstparty/container.zip.meta_lic testdata/firstparty/lib/liba.so.meta_lic static",
				"testdata/firstparty/container.zip.meta_lic testdata/firstparty/lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "firstparty",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []string{
				"testdata/firstparty/application.meta_lic testdata/firstparty/bin/bin3.meta_lic toolchain",
				"testdata/firstparty/application.meta_lic testdata/firstparty/lib/liba.so.meta_lic static",
				"testdata/firstparty/application.meta_lic testdata/firstparty/lib/libb.so.meta_lic dynamic",
			},
		},
		{
			condition: "firstparty",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []string{
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/lib/liba.so.meta_lic static",
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/lib/libc.a.meta_lic static",
			},
		},
		{
			condition:   "firstparty",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition: "notice",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []string{
				"testdata/notice/bin/bin1.meta_lic testdata/notice/lib/liba.so.meta_lic static",
				"testdata/notice/bin/bin1.meta_lic testdata/notice/lib/libc.a.meta_lic static",
				"testdata/notice/bin/bin2.meta_lic testdata/notice/lib/libb.so.meta_lic dynamic",
				"testdata/notice/bin/bin2.meta_lic testdata/notice/lib/libd.so.meta_lic dynamic",
				"testdata/notice/highest.apex.meta_lic testdata/notice/bin/bin1.meta_lic static",
				"testdata/notice/highest.apex.meta_lic testdata/notice/bin/bin2.meta_lic static",
				"testdata/notice/highest.apex.meta_lic testdata/notice/lib/liba.so.meta_lic static",
				"testdata/notice/highest.apex.meta_lic testdata/notice/lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "notice",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/notice/"}},
			expectedOut: []string{
				"bin/bin1.meta_lic lib/liba.so.meta_lic static",
				"bin/bin1.meta_lic lib/libc.a.meta_lic static",
				"bin/bin2.meta_lic lib/libb.so.meta_lic dynamic",
				"bin/bin2.meta_lic lib/libd.so.meta_lic dynamic",
				"highest.apex.meta_lic bin/bin1.meta_lic static",
				"highest.apex.meta_lic bin/bin2.meta_lic static",
				"highest.apex.meta_lic lib/liba.so.meta_lic static",
				"highest.apex.meta_lic lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "notice",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/notice/"}, labelConditions: true},
			expectedOut: []string{
				"bin/bin1.meta_lic:notice lib/liba.so.meta_lic:notice static",
				"bin/bin1.meta_lic:notice lib/libc.a.meta_lic:notice static",
				"bin/bin2.meta_lic:notice lib/libb.so.meta_lic:notice dynamic",
				"bin/bin2.meta_lic:notice lib/libd.so.meta_lic:notice dynamic",
				"highest.apex.meta_lic:notice bin/bin1.meta_lic:notice static",
				"highest.apex.meta_lic:notice bin/bin2.meta_lic:notice static",
				"highest.apex.meta_lic:notice lib/liba.so.meta_lic:notice static",
				"highest.apex.meta_lic:notice lib/libb.so.meta_lic:notice static",
			},
		},
		{
			condition: "notice",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []string{
				"testdata/notice/bin/bin1.meta_lic testdata/notice/lib/liba.so.meta_lic static",
				"testdata/notice/bin/bin1.meta_lic testdata/notice/lib/libc.a.meta_lic static",
				"testdata/notice/bin/bin2.meta_lic testdata/notice/lib/libb.so.meta_lic dynamic",
				"testdata/notice/bin/bin2.meta_lic testdata/notice/lib/libd.so.meta_lic dynamic",
				"testdata/notice/container.zip.meta_lic testdata/notice/bin/bin1.meta_lic static",
				"testdata/notice/container.zip.meta_lic testdata/notice/bin/bin2.meta_lic static",
				"testdata/notice/container.zip.meta_lic testdata/notice/lib/liba.so.meta_lic static",
				"testdata/notice/container.zip.meta_lic testdata/notice/lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "notice",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []string{
				"testdata/notice/application.meta_lic testdata/notice/bin/bin3.meta_lic toolchain",
				"testdata/notice/application.meta_lic testdata/notice/lib/liba.so.meta_lic static",
				"testdata/notice/application.meta_lic testdata/notice/lib/libb.so.meta_lic dynamic",
			},
		},
		{
			condition: "notice",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []string{
				"testdata/notice/bin/bin1.meta_lic testdata/notice/lib/liba.so.meta_lic static",
				"testdata/notice/bin/bin1.meta_lic testdata/notice/lib/libc.a.meta_lic static",
			},
		},
		{
			condition:   "notice",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition: "reciprocal",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []string{
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/lib/liba.so.meta_lic static",
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/lib/libc.a.meta_lic static",
				"testdata/reciprocal/bin/bin2.meta_lic testdata/reciprocal/lib/libb.so.meta_lic dynamic",
				"testdata/reciprocal/bin/bin2.meta_lic testdata/reciprocal/lib/libd.so.meta_lic dynamic",
				"testdata/reciprocal/highest.apex.meta_lic testdata/reciprocal/bin/bin1.meta_lic static",
				"testdata/reciprocal/highest.apex.meta_lic testdata/reciprocal/bin/bin2.meta_lic static",
				"testdata/reciprocal/highest.apex.meta_lic testdata/reciprocal/lib/liba.so.meta_lic static",
				"testdata/reciprocal/highest.apex.meta_lic testdata/reciprocal/lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/reciprocal/"}},
			expectedOut: []string{
				"bin/bin1.meta_lic lib/liba.so.meta_lic static",
				"bin/bin1.meta_lic lib/libc.a.meta_lic static",
				"bin/bin2.meta_lic lib/libb.so.meta_lic dynamic",
				"bin/bin2.meta_lic lib/libd.so.meta_lic dynamic",
				"highest.apex.meta_lic bin/bin1.meta_lic static",
				"highest.apex.meta_lic bin/bin2.meta_lic static",
				"highest.apex.meta_lic lib/liba.so.meta_lic static",
				"highest.apex.meta_lic lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/reciprocal/"}, labelConditions: true},
			expectedOut: []string{
				"bin/bin1.meta_lic:notice lib/liba.so.meta_lic:reciprocal static",
				"bin/bin1.meta_lic:notice lib/libc.a.meta_lic:reciprocal static",
				"bin/bin2.meta_lic:notice lib/libb.so.meta_lic:notice dynamic",
				"bin/bin2.meta_lic:notice lib/libd.so.meta_lic:notice dynamic",
				"highest.apex.meta_lic:notice bin/bin1.meta_lic:notice static",
				"highest.apex.meta_lic:notice bin/bin2.meta_lic:notice static",
				"highest.apex.meta_lic:notice lib/liba.so.meta_lic:reciprocal static",
				"highest.apex.meta_lic:notice lib/libb.so.meta_lic:notice static",
			},
		},
		{
			condition: "reciprocal",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []string{
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/lib/liba.so.meta_lic static",
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/lib/libc.a.meta_lic static",
				"testdata/reciprocal/bin/bin2.meta_lic testdata/reciprocal/lib/libb.so.meta_lic dynamic",
				"testdata/reciprocal/bin/bin2.meta_lic testdata/reciprocal/lib/libd.so.meta_lic dynamic",
				"testdata/reciprocal/container.zip.meta_lic testdata/reciprocal/bin/bin1.meta_lic static",
				"testdata/reciprocal/container.zip.meta_lic testdata/reciprocal/bin/bin2.meta_lic static",
				"testdata/reciprocal/container.zip.meta_lic testdata/reciprocal/lib/liba.so.meta_lic static",
				"testdata/reciprocal/container.zip.meta_lic testdata/reciprocal/lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "reciprocal",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []string{
				"testdata/reciprocal/application.meta_lic testdata/reciprocal/bin/bin3.meta_lic toolchain",
				"testdata/reciprocal/application.meta_lic testdata/reciprocal/lib/liba.so.meta_lic static",
				"testdata/reciprocal/application.meta_lic testdata/reciprocal/lib/libb.so.meta_lic dynamic",
			},
		},
		{
			condition: "reciprocal",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []string{
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/lib/liba.so.meta_lic static",
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/lib/libc.a.meta_lic static",
			},
		},
		{
			condition:   "reciprocal",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition: "restricted",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []string{
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/lib/liba.so.meta_lic static",
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/lib/libc.a.meta_lic static",
				"testdata/restricted/bin/bin2.meta_lic testdata/restricted/lib/libb.so.meta_lic dynamic",
				"testdata/restricted/bin/bin2.meta_lic testdata/restricted/lib/libd.so.meta_lic dynamic",
				"testdata/restricted/highest.apex.meta_lic testdata/restricted/bin/bin1.meta_lic static",
				"testdata/restricted/highest.apex.meta_lic testdata/restricted/bin/bin2.meta_lic static",
				"testdata/restricted/highest.apex.meta_lic testdata/restricted/lib/liba.so.meta_lic static",
				"testdata/restricted/highest.apex.meta_lic testdata/restricted/lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/restricted/"}},
			expectedOut: []string{
				"bin/bin1.meta_lic lib/liba.so.meta_lic static",
				"bin/bin1.meta_lic lib/libc.a.meta_lic static",
				"bin/bin2.meta_lic lib/libb.so.meta_lic dynamic",
				"bin/bin2.meta_lic lib/libd.so.meta_lic dynamic",
				"highest.apex.meta_lic bin/bin1.meta_lic static",
				"highest.apex.meta_lic bin/bin2.meta_lic static",
				"highest.apex.meta_lic lib/liba.so.meta_lic static",
				"highest.apex.meta_lic lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/restricted/"}, labelConditions: true},
			expectedOut: []string{
				"bin/bin1.meta_lic:notice lib/liba.so.meta_lic:restricted_if_statically_linked static",
				"bin/bin1.meta_lic:notice lib/libc.a.meta_lic:reciprocal static",
				"bin/bin2.meta_lic:notice lib/libb.so.meta_lic:restricted dynamic",
				"bin/bin2.meta_lic:notice lib/libd.so.meta_lic:notice dynamic",
				"highest.apex.meta_lic:notice bin/bin1.meta_lic:notice static",
				"highest.apex.meta_lic:notice bin/bin2.meta_lic:notice static",
				"highest.apex.meta_lic:notice lib/liba.so.meta_lic:restricted_if_statically_linked static",
				"highest.apex.meta_lic:notice lib/libb.so.meta_lic:restricted static",
			},
		},
		{
			condition: "restricted",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []string{
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/lib/liba.so.meta_lic static",
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/lib/libc.a.meta_lic static",
				"testdata/restricted/bin/bin2.meta_lic testdata/restricted/lib/libb.so.meta_lic dynamic",
				"testdata/restricted/bin/bin2.meta_lic testdata/restricted/lib/libd.so.meta_lic dynamic",
				"testdata/restricted/container.zip.meta_lic testdata/restricted/bin/bin1.meta_lic static",
				"testdata/restricted/container.zip.meta_lic testdata/restricted/bin/bin2.meta_lic static",
				"testdata/restricted/container.zip.meta_lic testdata/restricted/lib/liba.so.meta_lic static",
				"testdata/restricted/container.zip.meta_lic testdata/restricted/lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "restricted",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []string{
				"testdata/restricted/application.meta_lic testdata/restricted/bin/bin3.meta_lic toolchain",
				"testdata/restricted/application.meta_lic testdata/restricted/lib/liba.so.meta_lic static",
				"testdata/restricted/application.meta_lic testdata/restricted/lib/libb.so.meta_lic dynamic",
			},
		},
		{
			condition: "restricted",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []string{
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/lib/liba.so.meta_lic static",
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/lib/libc.a.meta_lic static",
			},
		},
		{
			condition:   "restricted",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition: "proprietary",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []string{
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/lib/liba.so.meta_lic static",
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/lib/libc.a.meta_lic static",
				"testdata/proprietary/bin/bin2.meta_lic testdata/proprietary/lib/libb.so.meta_lic dynamic",
				"testdata/proprietary/bin/bin2.meta_lic testdata/proprietary/lib/libd.so.meta_lic dynamic",
				"testdata/proprietary/highest.apex.meta_lic testdata/proprietary/bin/bin1.meta_lic static",
				"testdata/proprietary/highest.apex.meta_lic testdata/proprietary/bin/bin2.meta_lic static",
				"testdata/proprietary/highest.apex.meta_lic testdata/proprietary/lib/liba.so.meta_lic static",
				"testdata/proprietary/highest.apex.meta_lic testdata/proprietary/lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/proprietary/"}},
			expectedOut: []string{
				"bin/bin1.meta_lic lib/liba.so.meta_lic static",
				"bin/bin1.meta_lic lib/libc.a.meta_lic static",
				"bin/bin2.meta_lic lib/libb.so.meta_lic dynamic",
				"bin/bin2.meta_lic lib/libd.so.meta_lic dynamic",
				"highest.apex.meta_lic bin/bin1.meta_lic static",
				"highest.apex.meta_lic bin/bin2.meta_lic static",
				"highest.apex.meta_lic lib/liba.so.meta_lic static",
				"highest.apex.meta_lic lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/proprietary/"}, labelConditions: true},
			expectedOut: []string{
				"bin/bin1.meta_lic:notice lib/liba.so.meta_lic:by_exception_only:proprietary static",
				"bin/bin1.meta_lic:notice lib/libc.a.meta_lic:by_exception_only:proprietary static",
				"bin/bin2.meta_lic:by_exception_only:proprietary lib/libb.so.meta_lic:restricted dynamic",
				"bin/bin2.meta_lic:by_exception_only:proprietary lib/libd.so.meta_lic:notice dynamic",
				"highest.apex.meta_lic:notice bin/bin1.meta_lic:notice static",
				"highest.apex.meta_lic:notice bin/bin2.meta_lic:by_exception_only:proprietary static",
				"highest.apex.meta_lic:notice lib/liba.so.meta_lic:by_exception_only:proprietary static",
				"highest.apex.meta_lic:notice lib/libb.so.meta_lic:restricted static",
			},
		},
		{
			condition: "proprietary",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []string{
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/lib/liba.so.meta_lic static",
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/lib/libc.a.meta_lic static",
				"testdata/proprietary/bin/bin2.meta_lic testdata/proprietary/lib/libb.so.meta_lic dynamic",
				"testdata/proprietary/bin/bin2.meta_lic testdata/proprietary/lib/libd.so.meta_lic dynamic",
				"testdata/proprietary/container.zip.meta_lic testdata/proprietary/bin/bin1.meta_lic static",
				"testdata/proprietary/container.zip.meta_lic testdata/proprietary/bin/bin2.meta_lic static",
				"testdata/proprietary/container.zip.meta_lic testdata/proprietary/lib/liba.so.meta_lic static",
				"testdata/proprietary/container.zip.meta_lic testdata/proprietary/lib/libb.so.meta_lic static",
			},
		},
		{
			condition: "proprietary",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []string{
				"testdata/proprietary/application.meta_lic testdata/proprietary/bin/bin3.meta_lic toolchain",
				"testdata/proprietary/application.meta_lic testdata/proprietary/lib/liba.so.meta_lic static",
				"testdata/proprietary/application.meta_lic testdata/proprietary/lib/libb.so.meta_lic dynamic",
			},
		},
		{
			condition: "proprietary",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []string{
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/lib/liba.so.meta_lic static",
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/lib/libc.a.meta_lic static",
			},
		},
		{
			condition:   "proprietary",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{},
		},
	}
	for _, tt := range tests {
		t.Run(tt.condition+" "+tt.name, func(t *testing.T) {
			expectedOut := &bytes.Buffer{}
			for _, eo := range tt.expectedOut {
				expectedOut.WriteString(eo)
				expectedOut.WriteString("\n")
			}

			stdout := &bytes.Buffer{}
			stderr := &bytes.Buffer{}

			rootFiles := make([]string, 0, len(tt.roots))
			for _, r := range tt.roots {
				rootFiles = append(rootFiles, "testdata/"+tt.condition+"/"+r)
			}
			err := dumpGraph(&tt.ctx, stdout, stderr, compliance.GetFS(tt.outDir), rootFiles...)
			if err != nil {
				t.Fatalf("dumpgraph: error = %v, stderr = %v", err, stderr)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("dumpgraph: gotStderr = %v, want none", stderr)
			}
			out := stdout.String()
			expected := expectedOut.String()
			if out != expected {
				outList := strings.Split(out, "\n")
				expectedList := strings.Split(expected, "\n")
				startLine := 0
				for len(outList) > startLine && len(expectedList) > startLine && outList[startLine] == expectedList[startLine] {
					startLine++
				}
				t.Errorf("listshare: gotStdout = %v, want %v, somewhere near line %d Stdout = %v, want %v",
					out, expected, startLine+1, outList[startLine], expectedList[startLine])
			}
		})
	}
}

type testContext struct {
	nextNode int
	nodes    map[string]string
}

type matcher interface {
	matchString(*testContext) string
	typeString() string
}

type targetMatcher struct {
	target     string
	conditions []string
}

func (tm *targetMatcher) matchString(ctx *testContext) string {
	m := tm.target
	if len(tm.conditions) > 0 {
		m += "\\n" + strings.Join(tm.conditions, "\\n")
	}
	m = ctx.nodes[tm.target] + " [label=\"" + m + "\"];"
	return m
}

func (tm *targetMatcher) typeString() string {
	return "target"
}

type edgeMatcher struct {
	target      string
	dep         string
	annotations []string
}

func (em *edgeMatcher) matchString(ctx *testContext) string {
	return ctx.nodes[em.dep] + " -> " + ctx.nodes[em.target] + " [label=\"" + strings.Join(em.annotations, "\\n") + "\"];"
}

func (tm *edgeMatcher) typeString() string {
	return "edge"
}

type getMatcher func(*testContext) matcher

func matchTarget(target string, conditions ...string) getMatcher {
	return func(ctx *testContext) matcher {
		ctx.nodes[target] = fmt.Sprintf("n%d", ctx.nextNode)
		ctx.nextNode++
		return &targetMatcher{target, append([]string{}, conditions...)}
	}
}

func matchEdge(target, dep string, annotations ...string) getMatcher {
	return func(ctx *testContext) matcher {
		if _, ok := ctx.nodes[target]; !ok {
			panic(fmt.Errorf("no node for target %v in %v -> %v [label=\"%s\"];", target, dep, target, strings.Join(annotations, "\\n")))
		}
		if _, ok := ctx.nodes[dep]; !ok {
			panic(fmt.Errorf("no node for dep %v in %v -> %v [label=\"%s\"];", target, dep, target, strings.Join(annotations, "\\n")))
		}
		return &edgeMatcher{target, dep, append([]string{}, annotations...)}
	}
}

func Test_graphviz(t *testing.T) {
	tests := []struct {
		condition   string
		name        string
		outDir      string
		roots       []string
		ctx         context
		expectedOut []getMatcher
	}{
		{
			condition: "firstparty",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/firstparty/bin/bin1.meta_lic"),
				matchTarget("testdata/firstparty/bin/bin2.meta_lic"),
				matchTarget("testdata/firstparty/highest.apex.meta_lic"),
				matchTarget("testdata/firstparty/lib/liba.so.meta_lic"),
				matchTarget("testdata/firstparty/lib/libb.so.meta_lic"),
				matchTarget("testdata/firstparty/lib/libc.a.meta_lic"),
				matchTarget("testdata/firstparty/lib/libd.so.meta_lic"),
				matchEdge("testdata/firstparty/bin/bin1.meta_lic", "testdata/firstparty/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/firstparty/bin/bin1.meta_lic", "testdata/firstparty/lib/libc.a.meta_lic", "static"),
				matchEdge("testdata/firstparty/bin/bin2.meta_lic", "testdata/firstparty/lib/libb.so.meta_lic", "dynamic"),
				matchEdge("testdata/firstparty/bin/bin2.meta_lic", "testdata/firstparty/lib/libd.so.meta_lic", "dynamic"),
				matchEdge("testdata/firstparty/highest.apex.meta_lic", "testdata/firstparty/bin/bin1.meta_lic", "static"),
				matchEdge("testdata/firstparty/highest.apex.meta_lic", "testdata/firstparty/bin/bin2.meta_lic", "static"),
				matchEdge("testdata/firstparty/highest.apex.meta_lic", "testdata/firstparty/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/firstparty/highest.apex.meta_lic", "testdata/firstparty/lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/firstparty/"}},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("lib/libd.so.meta_lic"),
				matchEdge("bin/bin1.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("bin/bin1.meta_lic", "lib/libc.a.meta_lic", "static"),
				matchEdge("bin/bin2.meta_lic", "lib/libb.so.meta_lic", "dynamic"),
				matchEdge("bin/bin2.meta_lic", "lib/libd.so.meta_lic", "dynamic"),
				matchEdge("highest.apex.meta_lic", "bin/bin1.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "bin/bin2.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/firstparty/"}, labelConditions: true},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic", "notice"),
				matchTarget("bin/bin2.meta_lic", "notice"),
				matchTarget("highest.apex.meta_lic", "notice"),
				matchTarget("lib/liba.so.meta_lic", "notice"),
				matchTarget("lib/libb.so.meta_lic", "notice"),
				matchTarget("lib/libc.a.meta_lic", "notice"),
				matchTarget("lib/libd.so.meta_lic", "notice"),
				matchEdge("bin/bin1.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("bin/bin1.meta_lic", "lib/libc.a.meta_lic", "static"),
				matchEdge("bin/bin2.meta_lic", "lib/libb.so.meta_lic", "dynamic"),
				matchEdge("bin/bin2.meta_lic", "lib/libd.so.meta_lic", "dynamic"),
				matchEdge("highest.apex.meta_lic", "bin/bin1.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "bin/bin2.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "firstparty",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/firstparty/bin/bin1.meta_lic"),
				matchTarget("testdata/firstparty/bin/bin2.meta_lic"),
				matchTarget("testdata/firstparty/container.zip.meta_lic"),
				matchTarget("testdata/firstparty/lib/liba.so.meta_lic"),
				matchTarget("testdata/firstparty/lib/libb.so.meta_lic"),
				matchTarget("testdata/firstparty/lib/libc.a.meta_lic"),
				matchTarget("testdata/firstparty/lib/libd.so.meta_lic"),
				matchEdge("testdata/firstparty/bin/bin1.meta_lic", "testdata/firstparty/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/firstparty/bin/bin1.meta_lic", "testdata/firstparty/lib/libc.a.meta_lic", "static"),
				matchEdge("testdata/firstparty/bin/bin2.meta_lic", "testdata/firstparty/lib/libb.so.meta_lic", "dynamic"),
				matchEdge("testdata/firstparty/bin/bin2.meta_lic", "testdata/firstparty/lib/libd.so.meta_lic", "dynamic"),
				matchEdge("testdata/firstparty/container.zip.meta_lic", "testdata/firstparty/bin/bin1.meta_lic", "static"),
				matchEdge("testdata/firstparty/container.zip.meta_lic", "testdata/firstparty/bin/bin2.meta_lic", "static"),
				matchEdge("testdata/firstparty/container.zip.meta_lic", "testdata/firstparty/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/firstparty/container.zip.meta_lic", "testdata/firstparty/lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "firstparty",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/firstparty/application.meta_lic"),
				matchTarget("testdata/firstparty/bin/bin3.meta_lic"),
				matchTarget("testdata/firstparty/lib/liba.so.meta_lic"),
				matchTarget("testdata/firstparty/lib/libb.so.meta_lic"),
				matchEdge("testdata/firstparty/application.meta_lic", "testdata/firstparty/bin/bin3.meta_lic", "toolchain"),
				matchEdge("testdata/firstparty/application.meta_lic", "testdata/firstparty/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/firstparty/application.meta_lic", "testdata/firstparty/lib/libb.so.meta_lic", "dynamic"),
			},
		},
		{
			condition: "firstparty",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/firstparty/bin/bin1.meta_lic"),
				matchTarget("testdata/firstparty/lib/liba.so.meta_lic"),
				matchTarget("testdata/firstparty/lib/libc.a.meta_lic"),
				matchEdge("testdata/firstparty/bin/bin1.meta_lic", "testdata/firstparty/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/firstparty/bin/bin1.meta_lic", "testdata/firstparty/lib/libc.a.meta_lic", "static"),
			},
		},
		{
			condition:   "firstparty",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []getMatcher{matchTarget("testdata/firstparty/lib/libd.so.meta_lic")},
		},
		{
			condition: "notice",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/notice/bin/bin1.meta_lic"),
				matchTarget("testdata/notice/bin/bin2.meta_lic"),
				matchTarget("testdata/notice/highest.apex.meta_lic"),
				matchTarget("testdata/notice/lib/liba.so.meta_lic"),
				matchTarget("testdata/notice/lib/libb.so.meta_lic"),
				matchTarget("testdata/notice/lib/libc.a.meta_lic"),
				matchTarget("testdata/notice/lib/libd.so.meta_lic"),
				matchEdge("testdata/notice/bin/bin1.meta_lic", "testdata/notice/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/notice/bin/bin1.meta_lic", "testdata/notice/lib/libc.a.meta_lic", "static"),
				matchEdge("testdata/notice/bin/bin2.meta_lic", "testdata/notice/lib/libb.so.meta_lic", "dynamic"),
				matchEdge("testdata/notice/bin/bin2.meta_lic", "testdata/notice/lib/libd.so.meta_lic", "dynamic"),
				matchEdge("testdata/notice/highest.apex.meta_lic", "testdata/notice/bin/bin1.meta_lic", "static"),
				matchEdge("testdata/notice/highest.apex.meta_lic", "testdata/notice/bin/bin2.meta_lic", "static"),
				matchEdge("testdata/notice/highest.apex.meta_lic", "testdata/notice/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/notice/highest.apex.meta_lic", "testdata/notice/lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "notice",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/notice/"}},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("lib/libd.so.meta_lic"),
				matchEdge("bin/bin1.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("bin/bin1.meta_lic", "lib/libc.a.meta_lic", "static"),
				matchEdge("bin/bin2.meta_lic", "lib/libb.so.meta_lic", "dynamic"),
				matchEdge("bin/bin2.meta_lic", "lib/libd.so.meta_lic", "dynamic"),
				matchEdge("highest.apex.meta_lic", "bin/bin1.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "bin/bin2.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "notice",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/notice/"}, labelConditions: true},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic", "notice"),
				matchTarget("bin/bin2.meta_lic", "notice"),
				matchTarget("highest.apex.meta_lic", "notice"),
				matchTarget("lib/liba.so.meta_lic", "notice"),
				matchTarget("lib/libb.so.meta_lic", "notice"),
				matchTarget("lib/libc.a.meta_lic", "notice"),
				matchTarget("lib/libd.so.meta_lic", "notice"),
				matchEdge("bin/bin1.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("bin/bin1.meta_lic", "lib/libc.a.meta_lic", "static"),
				matchEdge("bin/bin2.meta_lic", "lib/libb.so.meta_lic", "dynamic"),
				matchEdge("bin/bin2.meta_lic", "lib/libd.so.meta_lic", "dynamic"),
				matchEdge("highest.apex.meta_lic", "bin/bin1.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "bin/bin2.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "notice",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/notice/bin/bin1.meta_lic"),
				matchTarget("testdata/notice/bin/bin2.meta_lic"),
				matchTarget("testdata/notice/container.zip.meta_lic"),
				matchTarget("testdata/notice/lib/liba.so.meta_lic"),
				matchTarget("testdata/notice/lib/libb.so.meta_lic"),
				matchTarget("testdata/notice/lib/libc.a.meta_lic"),
				matchTarget("testdata/notice/lib/libd.so.meta_lic"),
				matchEdge("testdata/notice/bin/bin1.meta_lic", "testdata/notice/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/notice/bin/bin1.meta_lic", "testdata/notice/lib/libc.a.meta_lic", "static"),
				matchEdge("testdata/notice/bin/bin2.meta_lic", "testdata/notice/lib/libb.so.meta_lic", "dynamic"),
				matchEdge("testdata/notice/bin/bin2.meta_lic", "testdata/notice/lib/libd.so.meta_lic", "dynamic"),
				matchEdge("testdata/notice/container.zip.meta_lic", "testdata/notice/bin/bin1.meta_lic", "static"),
				matchEdge("testdata/notice/container.zip.meta_lic", "testdata/notice/bin/bin2.meta_lic", "static"),
				matchEdge("testdata/notice/container.zip.meta_lic", "testdata/notice/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/notice/container.zip.meta_lic", "testdata/notice/lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "notice",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/notice/application.meta_lic"),
				matchTarget("testdata/notice/bin/bin3.meta_lic"),
				matchTarget("testdata/notice/lib/liba.so.meta_lic"),
				matchTarget("testdata/notice/lib/libb.so.meta_lic"),
				matchEdge("testdata/notice/application.meta_lic", "testdata/notice/bin/bin3.meta_lic", "toolchain"),
				matchEdge("testdata/notice/application.meta_lic", "testdata/notice/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/notice/application.meta_lic", "testdata/notice/lib/libb.so.meta_lic", "dynamic"),
			},
		},
		{
			condition: "notice",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/notice/bin/bin1.meta_lic"),
				matchTarget("testdata/notice/lib/liba.so.meta_lic"),
				matchTarget("testdata/notice/lib/libc.a.meta_lic"),
				matchEdge("testdata/notice/bin/bin1.meta_lic", "testdata/notice/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/notice/bin/bin1.meta_lic", "testdata/notice/lib/libc.a.meta_lic", "static"),
			},
		},
		{
			condition:   "notice",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []getMatcher{matchTarget("testdata/notice/lib/libd.so.meta_lic")},
		},
		{
			condition: "reciprocal",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/reciprocal/bin/bin1.meta_lic"),
				matchTarget("testdata/reciprocal/bin/bin2.meta_lic"),
				matchTarget("testdata/reciprocal/highest.apex.meta_lic"),
				matchTarget("testdata/reciprocal/lib/liba.so.meta_lic"),
				matchTarget("testdata/reciprocal/lib/libb.so.meta_lic"),
				matchTarget("testdata/reciprocal/lib/libc.a.meta_lic"),
				matchTarget("testdata/reciprocal/lib/libd.so.meta_lic"),
				matchEdge("testdata/reciprocal/bin/bin1.meta_lic", "testdata/reciprocal/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/reciprocal/bin/bin1.meta_lic", "testdata/reciprocal/lib/libc.a.meta_lic", "static"),
				matchEdge("testdata/reciprocal/bin/bin2.meta_lic", "testdata/reciprocal/lib/libb.so.meta_lic", "dynamic"),
				matchEdge("testdata/reciprocal/bin/bin2.meta_lic", "testdata/reciprocal/lib/libd.so.meta_lic", "dynamic"),
				matchEdge("testdata/reciprocal/highest.apex.meta_lic", "testdata/reciprocal/bin/bin1.meta_lic", "static"),
				matchEdge("testdata/reciprocal/highest.apex.meta_lic", "testdata/reciprocal/bin/bin2.meta_lic", "static"),
				matchEdge("testdata/reciprocal/highest.apex.meta_lic", "testdata/reciprocal/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/reciprocal/highest.apex.meta_lic", "testdata/reciprocal/lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/reciprocal/"}},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("lib/libd.so.meta_lic"),
				matchEdge("bin/bin1.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("bin/bin1.meta_lic", "lib/libc.a.meta_lic", "static"),
				matchEdge("bin/bin2.meta_lic", "lib/libb.so.meta_lic", "dynamic"),
				matchEdge("bin/bin2.meta_lic", "lib/libd.so.meta_lic", "dynamic"),
				matchEdge("highest.apex.meta_lic", "bin/bin1.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "bin/bin2.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/reciprocal/"}, labelConditions: true},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic", "notice"),
				matchTarget("bin/bin2.meta_lic", "notice"),
				matchTarget("highest.apex.meta_lic", "notice"),
				matchTarget("lib/liba.so.meta_lic", "reciprocal"),
				matchTarget("lib/libb.so.meta_lic", "notice"),
				matchTarget("lib/libc.a.meta_lic", "reciprocal"),
				matchTarget("lib/libd.so.meta_lic", "notice"),
				matchEdge("bin/bin1.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("bin/bin1.meta_lic", "lib/libc.a.meta_lic", "static"),
				matchEdge("bin/bin2.meta_lic", "lib/libb.so.meta_lic", "dynamic"),
				matchEdge("bin/bin2.meta_lic", "lib/libd.so.meta_lic", "dynamic"),
				matchEdge("highest.apex.meta_lic", "bin/bin1.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "bin/bin2.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "reciprocal",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/reciprocal/bin/bin1.meta_lic"),
				matchTarget("testdata/reciprocal/bin/bin2.meta_lic"),
				matchTarget("testdata/reciprocal/container.zip.meta_lic"),
				matchTarget("testdata/reciprocal/lib/liba.so.meta_lic"),
				matchTarget("testdata/reciprocal/lib/libb.so.meta_lic"),
				matchTarget("testdata/reciprocal/lib/libc.a.meta_lic"),
				matchTarget("testdata/reciprocal/lib/libd.so.meta_lic"),
				matchEdge("testdata/reciprocal/bin/bin1.meta_lic", "testdata/reciprocal/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/reciprocal/bin/bin1.meta_lic", "testdata/reciprocal/lib/libc.a.meta_lic", "static"),
				matchEdge("testdata/reciprocal/bin/bin2.meta_lic", "testdata/reciprocal/lib/libb.so.meta_lic", "dynamic"),
				matchEdge("testdata/reciprocal/bin/bin2.meta_lic", "testdata/reciprocal/lib/libd.so.meta_lic", "dynamic"),
				matchEdge("testdata/reciprocal/container.zip.meta_lic", "testdata/reciprocal/bin/bin1.meta_lic", "static"),
				matchEdge("testdata/reciprocal/container.zip.meta_lic", "testdata/reciprocal/bin/bin2.meta_lic", "static"),
				matchEdge("testdata/reciprocal/container.zip.meta_lic", "testdata/reciprocal/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/reciprocal/container.zip.meta_lic", "testdata/reciprocal/lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "reciprocal",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/reciprocal/application.meta_lic"),
				matchTarget("testdata/reciprocal/bin/bin3.meta_lic"),
				matchTarget("testdata/reciprocal/lib/liba.so.meta_lic"),
				matchTarget("testdata/reciprocal/lib/libb.so.meta_lic"),
				matchEdge("testdata/reciprocal/application.meta_lic", "testdata/reciprocal/bin/bin3.meta_lic", "toolchain"),
				matchEdge("testdata/reciprocal/application.meta_lic", "testdata/reciprocal/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/reciprocal/application.meta_lic", "testdata/reciprocal/lib/libb.so.meta_lic", "dynamic"),
			},
		},
		{
			condition: "reciprocal",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/reciprocal/bin/bin1.meta_lic"),
				matchTarget("testdata/reciprocal/lib/liba.so.meta_lic"),
				matchTarget("testdata/reciprocal/lib/libc.a.meta_lic"),
				matchEdge("testdata/reciprocal/bin/bin1.meta_lic", "testdata/reciprocal/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/reciprocal/bin/bin1.meta_lic", "testdata/reciprocal/lib/libc.a.meta_lic", "static"),
			},
		},
		{
			condition:   "reciprocal",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []getMatcher{matchTarget("testdata/reciprocal/lib/libd.so.meta_lic")},
		},
		{
			condition: "restricted",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/restricted/bin/bin1.meta_lic"),
				matchTarget("testdata/restricted/bin/bin2.meta_lic"),
				matchTarget("testdata/restricted/highest.apex.meta_lic"),
				matchTarget("testdata/restricted/lib/liba.so.meta_lic"),
				matchTarget("testdata/restricted/lib/libb.so.meta_lic"),
				matchTarget("testdata/restricted/lib/libc.a.meta_lic"),
				matchTarget("testdata/restricted/lib/libd.so.meta_lic"),
				matchEdge("testdata/restricted/bin/bin1.meta_lic", "testdata/restricted/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/restricted/bin/bin1.meta_lic", "testdata/restricted/lib/libc.a.meta_lic", "static"),
				matchEdge("testdata/restricted/bin/bin2.meta_lic", "testdata/restricted/lib/libb.so.meta_lic", "dynamic"),
				matchEdge("testdata/restricted/bin/bin2.meta_lic", "testdata/restricted/lib/libd.so.meta_lic", "dynamic"),
				matchEdge("testdata/restricted/highest.apex.meta_lic", "testdata/restricted/bin/bin1.meta_lic", "static"),
				matchEdge("testdata/restricted/highest.apex.meta_lic", "testdata/restricted/bin/bin2.meta_lic", "static"),
				matchEdge("testdata/restricted/highest.apex.meta_lic", "testdata/restricted/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/restricted/highest.apex.meta_lic", "testdata/restricted/lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/restricted/"}},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("lib/libd.so.meta_lic"),
				matchEdge("bin/bin1.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("bin/bin1.meta_lic", "lib/libc.a.meta_lic", "static"),
				matchEdge("bin/bin2.meta_lic", "lib/libb.so.meta_lic", "dynamic"),
				matchEdge("bin/bin2.meta_lic", "lib/libd.so.meta_lic", "dynamic"),
				matchEdge("highest.apex.meta_lic", "bin/bin1.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "bin/bin2.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/restricted/"}, labelConditions: true},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic", "notice"),
				matchTarget("bin/bin2.meta_lic", "notice"),
				matchTarget("highest.apex.meta_lic", "notice"),
				matchTarget("lib/liba.so.meta_lic", "restricted_if_statically_linked"),
				matchTarget("lib/libb.so.meta_lic", "restricted"),
				matchTarget("lib/libc.a.meta_lic", "reciprocal"),
				matchTarget("lib/libd.so.meta_lic", "notice"),
				matchEdge("bin/bin1.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("bin/bin1.meta_lic", "lib/libc.a.meta_lic", "static"),
				matchEdge("bin/bin2.meta_lic", "lib/libb.so.meta_lic", "dynamic"),
				matchEdge("bin/bin2.meta_lic", "lib/libd.so.meta_lic", "dynamic"),
				matchEdge("highest.apex.meta_lic", "bin/bin1.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "bin/bin2.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "restricted",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/restricted/bin/bin1.meta_lic"),
				matchTarget("testdata/restricted/bin/bin2.meta_lic"),
				matchTarget("testdata/restricted/container.zip.meta_lic"),
				matchTarget("testdata/restricted/lib/liba.so.meta_lic"),
				matchTarget("testdata/restricted/lib/libb.so.meta_lic"),
				matchTarget("testdata/restricted/lib/libc.a.meta_lic"),
				matchTarget("testdata/restricted/lib/libd.so.meta_lic"),
				matchEdge("testdata/restricted/bin/bin1.meta_lic", "testdata/restricted/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/restricted/bin/bin1.meta_lic", "testdata/restricted/lib/libc.a.meta_lic", "static"),
				matchEdge("testdata/restricted/bin/bin2.meta_lic", "testdata/restricted/lib/libb.so.meta_lic", "dynamic"),
				matchEdge("testdata/restricted/bin/bin2.meta_lic", "testdata/restricted/lib/libd.so.meta_lic", "dynamic"),
				matchEdge("testdata/restricted/container.zip.meta_lic", "testdata/restricted/bin/bin1.meta_lic", "static"),
				matchEdge("testdata/restricted/container.zip.meta_lic", "testdata/restricted/bin/bin2.meta_lic", "static"),
				matchEdge("testdata/restricted/container.zip.meta_lic", "testdata/restricted/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/restricted/container.zip.meta_lic", "testdata/restricted/lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "restricted",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/restricted/application.meta_lic"),
				matchTarget("testdata/restricted/bin/bin3.meta_lic"),
				matchTarget("testdata/restricted/lib/liba.so.meta_lic"),
				matchTarget("testdata/restricted/lib/libb.so.meta_lic"),
				matchEdge("testdata/restricted/application.meta_lic", "testdata/restricted/bin/bin3.meta_lic", "toolchain"),
				matchEdge("testdata/restricted/application.meta_lic", "testdata/restricted/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/restricted/application.meta_lic", "testdata/restricted/lib/libb.so.meta_lic", "dynamic"),
			},
		},
		{
			condition: "restricted",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/restricted/bin/bin1.meta_lic"),
				matchTarget("testdata/restricted/lib/liba.so.meta_lic"),
				matchTarget("testdata/restricted/lib/libc.a.meta_lic"),
				matchEdge("testdata/restricted/bin/bin1.meta_lic", "testdata/restricted/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/restricted/bin/bin1.meta_lic", "testdata/restricted/lib/libc.a.meta_lic", "static"),
			},
		},
		{
			condition:   "restricted",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []getMatcher{matchTarget("testdata/restricted/lib/libd.so.meta_lic")},
		},
		{
			condition: "proprietary",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/proprietary/bin/bin1.meta_lic"),
				matchTarget("testdata/proprietary/bin/bin2.meta_lic"),
				matchTarget("testdata/proprietary/highest.apex.meta_lic"),
				matchTarget("testdata/proprietary/lib/liba.so.meta_lic"),
				matchTarget("testdata/proprietary/lib/libb.so.meta_lic"),
				matchTarget("testdata/proprietary/lib/libc.a.meta_lic"),
				matchTarget("testdata/proprietary/lib/libd.so.meta_lic"),
				matchEdge("testdata/proprietary/bin/bin1.meta_lic", "testdata/proprietary/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/proprietary/bin/bin1.meta_lic", "testdata/proprietary/lib/libc.a.meta_lic", "static"),
				matchEdge("testdata/proprietary/bin/bin2.meta_lic", "testdata/proprietary/lib/libb.so.meta_lic", "dynamic"),
				matchEdge("testdata/proprietary/bin/bin2.meta_lic", "testdata/proprietary/lib/libd.so.meta_lic", "dynamic"),
				matchEdge("testdata/proprietary/highest.apex.meta_lic", "testdata/proprietary/bin/bin1.meta_lic", "static"),
				matchEdge("testdata/proprietary/highest.apex.meta_lic", "testdata/proprietary/bin/bin2.meta_lic", "static"),
				matchEdge("testdata/proprietary/highest.apex.meta_lic", "testdata/proprietary/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/proprietary/highest.apex.meta_lic", "testdata/proprietary/lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/proprietary/"}},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("lib/libd.so.meta_lic"),
				matchEdge("bin/bin1.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("bin/bin1.meta_lic", "lib/libc.a.meta_lic", "static"),
				matchEdge("bin/bin2.meta_lic", "lib/libb.so.meta_lic", "dynamic"),
				matchEdge("bin/bin2.meta_lic", "lib/libd.so.meta_lic", "dynamic"),
				matchEdge("highest.apex.meta_lic", "bin/bin1.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "bin/bin2.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/proprietary/"}, labelConditions: true},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic", "notice"),
				matchTarget("bin/bin2.meta_lic", "by_exception_only", "proprietary"),
				matchTarget("highest.apex.meta_lic", "notice"),
				matchTarget("lib/liba.so.meta_lic", "by_exception_only", "proprietary"),
				matchTarget("lib/libb.so.meta_lic", "restricted"),
				matchTarget("lib/libc.a.meta_lic", "by_exception_only", "proprietary"),
				matchTarget("lib/libd.so.meta_lic", "notice"),
				matchEdge("bin/bin1.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("bin/bin1.meta_lic", "lib/libc.a.meta_lic", "static"),
				matchEdge("bin/bin2.meta_lic", "lib/libb.so.meta_lic", "dynamic"),
				matchEdge("bin/bin2.meta_lic", "lib/libd.so.meta_lic", "dynamic"),
				matchEdge("highest.apex.meta_lic", "bin/bin1.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "bin/bin2.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/liba.so.meta_lic", "static"),
				matchEdge("highest.apex.meta_lic", "lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "proprietary",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/proprietary/bin/bin1.meta_lic"),
				matchTarget("testdata/proprietary/bin/bin2.meta_lic"),
				matchTarget("testdata/proprietary/container.zip.meta_lic"),
				matchTarget("testdata/proprietary/lib/liba.so.meta_lic"),
				matchTarget("testdata/proprietary/lib/libb.so.meta_lic"),
				matchTarget("testdata/proprietary/lib/libc.a.meta_lic"),
				matchTarget("testdata/proprietary/lib/libd.so.meta_lic"),
				matchEdge("testdata/proprietary/bin/bin1.meta_lic", "testdata/proprietary/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/proprietary/bin/bin1.meta_lic", "testdata/proprietary/lib/libc.a.meta_lic", "static"),
				matchEdge("testdata/proprietary/bin/bin2.meta_lic", "testdata/proprietary/lib/libb.so.meta_lic", "dynamic"),
				matchEdge("testdata/proprietary/bin/bin2.meta_lic", "testdata/proprietary/lib/libd.so.meta_lic", "dynamic"),
				matchEdge("testdata/proprietary/container.zip.meta_lic", "testdata/proprietary/bin/bin1.meta_lic", "static"),
				matchEdge("testdata/proprietary/container.zip.meta_lic", "testdata/proprietary/bin/bin2.meta_lic", "static"),
				matchEdge("testdata/proprietary/container.zip.meta_lic", "testdata/proprietary/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/proprietary/container.zip.meta_lic", "testdata/proprietary/lib/libb.so.meta_lic", "static"),
			},
		},
		{
			condition: "proprietary",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/proprietary/application.meta_lic"),
				matchTarget("testdata/proprietary/bin/bin3.meta_lic"),
				matchTarget("testdata/proprietary/lib/liba.so.meta_lic"),
				matchTarget("testdata/proprietary/lib/libb.so.meta_lic"),
				matchEdge("testdata/proprietary/application.meta_lic", "testdata/proprietary/bin/bin3.meta_lic", "toolchain"),
				matchEdge("testdata/proprietary/application.meta_lic", "testdata/proprietary/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/proprietary/application.meta_lic", "testdata/proprietary/lib/libb.so.meta_lic", "dynamic"),
			},
		},
		{
			condition: "proprietary",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/proprietary/bin/bin1.meta_lic"),
				matchTarget("testdata/proprietary/lib/liba.so.meta_lic"),
				matchTarget("testdata/proprietary/lib/libc.a.meta_lic"),
				matchEdge("testdata/proprietary/bin/bin1.meta_lic", "testdata/proprietary/lib/liba.so.meta_lic", "static"),
				matchEdge("testdata/proprietary/bin/bin1.meta_lic", "testdata/proprietary/lib/libc.a.meta_lic", "static"),
			},
		},
		{
			condition:   "proprietary",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []getMatcher{matchTarget("testdata/proprietary/lib/libd.so.meta_lic")},
		},
	}
	for _, tt := range tests {
		t.Run(tt.condition+" "+tt.name, func(t *testing.T) {
			ctx := &testContext{0, make(map[string]string)}

			expectedOut := &bytes.Buffer{}
			for _, eo := range tt.expectedOut {
				m := eo(ctx)
				expectedOut.WriteString(m.matchString(ctx))
				expectedOut.WriteString("\n")
			}

			stdout := &bytes.Buffer{}
			stderr := &bytes.Buffer{}

			rootFiles := make([]string, 0, len(tt.roots))
			for _, r := range tt.roots {
				rootFiles = append(rootFiles, "testdata/"+tt.condition+"/"+r)
			}
			tt.ctx.graphViz = true
			err := dumpGraph(&tt.ctx, stdout, stderr, compliance.GetFS(tt.outDir), rootFiles...)
			if err != nil {
				t.Fatalf("dumpgraph: error = %v, stderr = %v", err, stderr)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("dumpgraph: gotStderr = %v, want none", stderr)
			}
			outList := strings.Split(stdout.String(), "\n")
			outLine := 0
			if outList[outLine] != "strict digraph {" {
				t.Errorf("dumpgraph: got 1st line %v, want strict digraph {", outList[outLine])
			}
			outLine++
			if strings.HasPrefix(strings.TrimLeft(outList[outLine], " \t"), "rankdir") {
				outLine++
			}
			endOut := len(outList)
			for endOut > 0 && strings.TrimLeft(outList[endOut-1], " \t") == "" {
				endOut--
			}
			if outList[endOut-1] != "}" {
				t.Errorf("dumpgraph: got last line %v, want }", outList[endOut-1])
			}
			endOut--
			if strings.HasPrefix(strings.TrimLeft(outList[endOut-1], " \t"), "{rank=same") {
				endOut--
			}
			expectedList := strings.Split(expectedOut.String(), "\n")
			for len(expectedList) > 0 && expectedList[len(expectedList)-1] == "" {
				expectedList = expectedList[0 : len(expectedList)-1]
			}
			matchLine := 0

			for outLine < endOut && matchLine < len(expectedList) && strings.TrimLeft(outList[outLine], " \t") == expectedList[matchLine] {
				outLine++
				matchLine++
			}
			if outLine < endOut || matchLine < len(expectedList) {
				if outLine >= endOut {
					t.Errorf("dumpgraph: missing lines at end of graph, want %d lines %v", len(expectedList)-matchLine, strings.Join(expectedList[matchLine:], "\n"))
				} else if matchLine >= len(expectedList) {
					t.Errorf("dumpgraph: unexpected lines at end of graph starting line %d, got %v, want nothing", outLine+1, strings.Join(outList[outLine:], "\n"))
				} else {
					t.Errorf("dumpgraph: at line %d, got %v, want %v", outLine+1, strings.Join(outList[outLine:], "\n"), strings.Join(expectedList[matchLine:], "\n"))
				}
			}
		})
	}
}
