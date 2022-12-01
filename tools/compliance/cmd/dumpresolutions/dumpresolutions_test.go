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
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/bin/bin1.meta_lic notice",
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/lib/liba.so.meta_lic notice",
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/lib/libc.a.meta_lic notice",
				"testdata/firstparty/bin/bin2.meta_lic testdata/firstparty/bin/bin2.meta_lic notice",
				"testdata/firstparty/highest.apex.meta_lic testdata/firstparty/bin/bin1.meta_lic notice",
				"testdata/firstparty/highest.apex.meta_lic testdata/firstparty/bin/bin2.meta_lic notice",
				"testdata/firstparty/highest.apex.meta_lic testdata/firstparty/highest.apex.meta_lic notice",
				"testdata/firstparty/highest.apex.meta_lic testdata/firstparty/lib/liba.so.meta_lic notice",
				"testdata/firstparty/highest.apex.meta_lic testdata/firstparty/lib/libb.so.meta_lic notice",
				"testdata/firstparty/highest.apex.meta_lic testdata/firstparty/lib/libc.a.meta_lic notice",
				"testdata/firstparty/lib/liba.so.meta_lic testdata/firstparty/lib/liba.so.meta_lic notice",
				"testdata/firstparty/lib/libb.so.meta_lic testdata/firstparty/lib/libb.so.meta_lic notice",
			},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/firstparty/"}},
			expectedOut: []string{
				"bin/bin1.meta_lic bin/bin1.meta_lic notice",
				"bin/bin1.meta_lic lib/liba.so.meta_lic notice",
				"bin/bin1.meta_lic lib/libc.a.meta_lic notice",
				"bin/bin2.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic bin/bin1.meta_lic notice",
				"highest.apex.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic highest.apex.meta_lic notice",
				"highest.apex.meta_lic lib/liba.so.meta_lic notice",
				"highest.apex.meta_lic lib/libb.so.meta_lic notice",
				"highest.apex.meta_lic lib/libc.a.meta_lic notice",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic notice",
				"lib/libb.so.meta_lic lib/libb.so.meta_lic notice",
			},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed_notice",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  []compliance.LicenseCondition{compliance.NoticeCondition},
				stripPrefix: []string{"testdata/firstparty/"},
			},
			expectedOut: []string{
				"bin/bin1.meta_lic bin/bin1.meta_lic notice",
				"bin/bin1.meta_lic lib/liba.so.meta_lic notice",
				"bin/bin1.meta_lic lib/libc.a.meta_lic notice",
				"bin/bin2.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic bin/bin1.meta_lic notice",
				"highest.apex.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic highest.apex.meta_lic notice",
				"highest.apex.meta_lic lib/liba.so.meta_lic notice",
				"highest.apex.meta_lic lib/libb.so.meta_lic notice",
				"highest.apex.meta_lic lib/libc.a.meta_lic notice",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic notice",
				"lib/libb.so.meta_lic lib/libb.so.meta_lic notice",
			},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed_share",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.AsList(),
				stripPrefix: []string{"testdata/firstparty/"},
			},
			expectedOut: []string{},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesPrivate.AsList(),
				stripPrefix: []string{"testdata/firstparty/"},
			},
			expectedOut: []string{},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed_share_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  append(compliance.ImpliesPrivate.AsList(), compliance.ImpliesShared.AsList()...),
				stripPrefix: []string{"testdata/firstparty/"},
			},
			expectedOut: []string{},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/firstparty/"}, labelConditions: true},
			expectedOut: []string{
				"bin/bin1.meta_lic:notice bin/bin1.meta_lic:notice notice",
				"bin/bin1.meta_lic:notice lib/liba.so.meta_lic:notice notice",
				"bin/bin1.meta_lic:notice lib/libc.a.meta_lic:notice notice",
				"bin/bin2.meta_lic:notice bin/bin2.meta_lic:notice notice",
				"highest.apex.meta_lic:notice bin/bin1.meta_lic:notice notice",
				"highest.apex.meta_lic:notice bin/bin2.meta_lic:notice notice",
				"highest.apex.meta_lic:notice highest.apex.meta_lic:notice notice",
				"highest.apex.meta_lic:notice lib/liba.so.meta_lic:notice notice",
				"highest.apex.meta_lic:notice lib/libb.so.meta_lic:notice notice",
				"highest.apex.meta_lic:notice lib/libc.a.meta_lic:notice notice",
				"lib/liba.so.meta_lic:notice lib/liba.so.meta_lic:notice notice",
				"lib/libb.so.meta_lic:notice lib/libb.so.meta_lic:notice notice",
			},
		},
		{
			condition: "firstparty",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []string{
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/bin/bin1.meta_lic notice",
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/lib/liba.so.meta_lic notice",
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/lib/libc.a.meta_lic notice",
				"testdata/firstparty/bin/bin2.meta_lic testdata/firstparty/bin/bin2.meta_lic notice",
				"testdata/firstparty/container.zip.meta_lic testdata/firstparty/bin/bin1.meta_lic notice",
				"testdata/firstparty/container.zip.meta_lic testdata/firstparty/bin/bin2.meta_lic notice",
				"testdata/firstparty/container.zip.meta_lic testdata/firstparty/container.zip.meta_lic notice",
				"testdata/firstparty/container.zip.meta_lic testdata/firstparty/lib/liba.so.meta_lic notice",
				"testdata/firstparty/container.zip.meta_lic testdata/firstparty/lib/libb.so.meta_lic notice",
				"testdata/firstparty/container.zip.meta_lic testdata/firstparty/lib/libc.a.meta_lic notice",
				"testdata/firstparty/lib/liba.so.meta_lic testdata/firstparty/lib/liba.so.meta_lic notice",
				"testdata/firstparty/lib/libb.so.meta_lic testdata/firstparty/lib/libb.so.meta_lic notice",
			},
		},
		{
			condition: "firstparty",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []string{
				"testdata/firstparty/application.meta_lic testdata/firstparty/application.meta_lic notice",
				"testdata/firstparty/application.meta_lic testdata/firstparty/lib/liba.so.meta_lic notice",
			},
		},
		{
			condition: "firstparty",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []string{
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/bin/bin1.meta_lic notice",
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/lib/liba.so.meta_lic notice",
				"testdata/firstparty/bin/bin1.meta_lic testdata/firstparty/lib/libc.a.meta_lic notice",
			},
		},
		{
			condition: "firstparty",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{
				"testdata/firstparty/lib/libd.so.meta_lic testdata/firstparty/lib/libd.so.meta_lic notice",
			},
		},
		{
			condition: "notice",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []string{
				"testdata/notice/bin/bin1.meta_lic testdata/notice/bin/bin1.meta_lic notice",
				"testdata/notice/bin/bin1.meta_lic testdata/notice/lib/liba.so.meta_lic notice",
				"testdata/notice/bin/bin1.meta_lic testdata/notice/lib/libc.a.meta_lic notice",
				"testdata/notice/bin/bin2.meta_lic testdata/notice/bin/bin2.meta_lic notice",
				"testdata/notice/highest.apex.meta_lic testdata/notice/bin/bin1.meta_lic notice",
				"testdata/notice/highest.apex.meta_lic testdata/notice/bin/bin2.meta_lic notice",
				"testdata/notice/highest.apex.meta_lic testdata/notice/highest.apex.meta_lic notice",
				"testdata/notice/highest.apex.meta_lic testdata/notice/lib/liba.so.meta_lic notice",
				"testdata/notice/highest.apex.meta_lic testdata/notice/lib/libb.so.meta_lic notice",
				"testdata/notice/highest.apex.meta_lic testdata/notice/lib/libc.a.meta_lic notice",
				"testdata/notice/lib/liba.so.meta_lic testdata/notice/lib/liba.so.meta_lic notice",
				"testdata/notice/lib/libb.so.meta_lic testdata/notice/lib/libb.so.meta_lic notice",
			},
		},
		{
			condition: "notice",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/notice/"}},
			expectedOut: []string{
				"bin/bin1.meta_lic bin/bin1.meta_lic notice",
				"bin/bin1.meta_lic lib/liba.so.meta_lic notice",
				"bin/bin1.meta_lic lib/libc.a.meta_lic notice",
				"bin/bin2.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic bin/bin1.meta_lic notice",
				"highest.apex.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic highest.apex.meta_lic notice",
				"highest.apex.meta_lic lib/liba.so.meta_lic notice",
				"highest.apex.meta_lic lib/libb.so.meta_lic notice",
				"highest.apex.meta_lic lib/libc.a.meta_lic notice",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic notice",
				"lib/libb.so.meta_lic lib/libb.so.meta_lic notice",
			},
		},
		{
			condition: "notice",
			name:      "apex_trimmed_notice",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  []compliance.LicenseCondition{compliance.NoticeCondition},
				stripPrefix: []string{"testdata/notice/"},
			},
			expectedOut: []string{
				"bin/bin1.meta_lic bin/bin1.meta_lic notice",
				"bin/bin1.meta_lic lib/liba.so.meta_lic notice",
				"bin/bin1.meta_lic lib/libc.a.meta_lic notice",
				"bin/bin2.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic bin/bin1.meta_lic notice",
				"highest.apex.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic highest.apex.meta_lic notice",
				"highest.apex.meta_lic lib/liba.so.meta_lic notice",
				"highest.apex.meta_lic lib/libb.so.meta_lic notice",
				"highest.apex.meta_lic lib/libc.a.meta_lic notice",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic notice",
				"lib/libb.so.meta_lic lib/libb.so.meta_lic notice",
			},
		},
		{
			condition: "notice",
			name:      "apex_trimmed_share",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.AsList(),
				stripPrefix: []string{"testdata/notice/"},
			},
			expectedOut: []string{},
		},
		{
			condition: "notice",
			name:      "apex_trimmed_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesPrivate.AsList(),
				stripPrefix: []string{"testdata/notice/"},
			},
			expectedOut: []string{},
		},
		{
			condition: "notice",
			name:      "apex_trimmed_share_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  append(compliance.ImpliesShared.AsList(), compliance.ImpliesPrivate.AsList()...),
				stripPrefix: []string{"testdata/notice/"},
			},
			expectedOut: []string{},
		},
		{
			condition: "notice",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/notice/"}, labelConditions: true},
			expectedOut: []string{
				"bin/bin1.meta_lic:notice bin/bin1.meta_lic:notice notice",
				"bin/bin1.meta_lic:notice lib/liba.so.meta_lic:notice notice",
				"bin/bin1.meta_lic:notice lib/libc.a.meta_lic:notice notice",
				"bin/bin2.meta_lic:notice bin/bin2.meta_lic:notice notice",
				"highest.apex.meta_lic:notice bin/bin1.meta_lic:notice notice",
				"highest.apex.meta_lic:notice bin/bin2.meta_lic:notice notice",
				"highest.apex.meta_lic:notice highest.apex.meta_lic:notice notice",
				"highest.apex.meta_lic:notice lib/liba.so.meta_lic:notice notice",
				"highest.apex.meta_lic:notice lib/libb.so.meta_lic:notice notice",
				"highest.apex.meta_lic:notice lib/libc.a.meta_lic:notice notice",
				"lib/liba.so.meta_lic:notice lib/liba.so.meta_lic:notice notice",
				"lib/libb.so.meta_lic:notice lib/libb.so.meta_lic:notice notice",
			},
		},
		{
			condition: "notice",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []string{
				"testdata/notice/bin/bin1.meta_lic testdata/notice/bin/bin1.meta_lic notice",
				"testdata/notice/bin/bin1.meta_lic testdata/notice/lib/liba.so.meta_lic notice",
				"testdata/notice/bin/bin1.meta_lic testdata/notice/lib/libc.a.meta_lic notice",
				"testdata/notice/bin/bin2.meta_lic testdata/notice/bin/bin2.meta_lic notice",
				"testdata/notice/container.zip.meta_lic testdata/notice/bin/bin1.meta_lic notice",
				"testdata/notice/container.zip.meta_lic testdata/notice/bin/bin2.meta_lic notice",
				"testdata/notice/container.zip.meta_lic testdata/notice/container.zip.meta_lic notice",
				"testdata/notice/container.zip.meta_lic testdata/notice/lib/liba.so.meta_lic notice",
				"testdata/notice/container.zip.meta_lic testdata/notice/lib/libb.so.meta_lic notice",
				"testdata/notice/container.zip.meta_lic testdata/notice/lib/libc.a.meta_lic notice",
				"testdata/notice/lib/liba.so.meta_lic testdata/notice/lib/liba.so.meta_lic notice",
				"testdata/notice/lib/libb.so.meta_lic testdata/notice/lib/libb.so.meta_lic notice",
			},
		},
		{
			condition: "notice",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []string{
				"testdata/notice/application.meta_lic testdata/notice/application.meta_lic notice",
				"testdata/notice/application.meta_lic testdata/notice/lib/liba.so.meta_lic notice",
			},
		},
		{
			condition: "notice",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []string{
				"testdata/notice/bin/bin1.meta_lic testdata/notice/bin/bin1.meta_lic notice",
				"testdata/notice/bin/bin1.meta_lic testdata/notice/lib/liba.so.meta_lic notice",
				"testdata/notice/bin/bin1.meta_lic testdata/notice/lib/libc.a.meta_lic notice",
			},
		},
		{
			condition: "notice",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{
				"testdata/notice/lib/libd.so.meta_lic testdata/notice/lib/libd.so.meta_lic notice",
			},
		},
		{
			condition: "reciprocal",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []string{
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/bin/bin1.meta_lic notice",
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/lib/liba.so.meta_lic reciprocal",
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/lib/libc.a.meta_lic reciprocal",
				"testdata/reciprocal/bin/bin2.meta_lic testdata/reciprocal/bin/bin2.meta_lic notice",
				"testdata/reciprocal/highest.apex.meta_lic testdata/reciprocal/bin/bin1.meta_lic notice",
				"testdata/reciprocal/highest.apex.meta_lic testdata/reciprocal/bin/bin2.meta_lic notice",
				"testdata/reciprocal/highest.apex.meta_lic testdata/reciprocal/highest.apex.meta_lic notice",
				"testdata/reciprocal/highest.apex.meta_lic testdata/reciprocal/lib/liba.so.meta_lic reciprocal",
				"testdata/reciprocal/highest.apex.meta_lic testdata/reciprocal/lib/libb.so.meta_lic notice",
				"testdata/reciprocal/highest.apex.meta_lic testdata/reciprocal/lib/libc.a.meta_lic reciprocal",
				"testdata/reciprocal/lib/liba.so.meta_lic testdata/reciprocal/lib/liba.so.meta_lic reciprocal",
				"testdata/reciprocal/lib/libb.so.meta_lic testdata/reciprocal/lib/libb.so.meta_lic notice",
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/reciprocal/"}},
			expectedOut: []string{
				"bin/bin1.meta_lic bin/bin1.meta_lic notice",
				"bin/bin1.meta_lic lib/liba.so.meta_lic reciprocal",
				"bin/bin1.meta_lic lib/libc.a.meta_lic reciprocal",
				"bin/bin2.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic bin/bin1.meta_lic notice",
				"highest.apex.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic highest.apex.meta_lic notice",
				"highest.apex.meta_lic lib/liba.so.meta_lic reciprocal",
				"highest.apex.meta_lic lib/libb.so.meta_lic notice",
				"highest.apex.meta_lic lib/libc.a.meta_lic reciprocal",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic reciprocal",
				"lib/libb.so.meta_lic lib/libb.so.meta_lic notice",
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed_notice",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  []compliance.LicenseCondition{compliance.NoticeCondition},
				stripPrefix: []string{"testdata/reciprocal/"},
			},
			expectedOut: []string{
				"bin/bin1.meta_lic bin/bin1.meta_lic notice",
				"bin/bin2.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic bin/bin1.meta_lic notice",
				"highest.apex.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic highest.apex.meta_lic notice",
				"highest.apex.meta_lic lib/libb.so.meta_lic notice",
				"lib/libb.so.meta_lic lib/libb.so.meta_lic notice",
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed_share",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.AsList(),
				stripPrefix: []string{"testdata/reciprocal/"},
			},
			expectedOut: []string{
				"bin/bin1.meta_lic lib/liba.so.meta_lic reciprocal",
				"bin/bin1.meta_lic lib/libc.a.meta_lic reciprocal",
				"highest.apex.meta_lic lib/liba.so.meta_lic reciprocal",
				"highest.apex.meta_lic lib/libc.a.meta_lic reciprocal",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic reciprocal",
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesPrivate.AsList(),
				stripPrefix: []string{"testdata/reciprocal/"},
			},
			expectedOut: []string{},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed_share_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  append(compliance.ImpliesShared.AsList(), compliance.ImpliesPrivate.AsList()...),
				stripPrefix: []string{"testdata/reciprocal/"},
			},
			expectedOut: []string{
				"bin/bin1.meta_lic lib/liba.so.meta_lic reciprocal",
				"bin/bin1.meta_lic lib/libc.a.meta_lic reciprocal",
				"highest.apex.meta_lic lib/liba.so.meta_lic reciprocal",
				"highest.apex.meta_lic lib/libc.a.meta_lic reciprocal",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic reciprocal",
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/reciprocal/"}, labelConditions: true},
			expectedOut: []string{
				"bin/bin1.meta_lic:notice bin/bin1.meta_lic:notice notice",
				"bin/bin1.meta_lic:notice lib/liba.so.meta_lic:reciprocal reciprocal",
				"bin/bin1.meta_lic:notice lib/libc.a.meta_lic:reciprocal reciprocal",
				"bin/bin2.meta_lic:notice bin/bin2.meta_lic:notice notice",
				"highest.apex.meta_lic:notice bin/bin1.meta_lic:notice notice",
				"highest.apex.meta_lic:notice bin/bin2.meta_lic:notice notice",
				"highest.apex.meta_lic:notice highest.apex.meta_lic:notice notice",
				"highest.apex.meta_lic:notice lib/liba.so.meta_lic:reciprocal reciprocal",
				"highest.apex.meta_lic:notice lib/libb.so.meta_lic:notice notice",
				"highest.apex.meta_lic:notice lib/libc.a.meta_lic:reciprocal reciprocal",
				"lib/liba.so.meta_lic:reciprocal lib/liba.so.meta_lic:reciprocal reciprocal",
				"lib/libb.so.meta_lic:notice lib/libb.so.meta_lic:notice notice",
			},
		},
		{
			condition: "reciprocal",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []string{
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/bin/bin1.meta_lic notice",
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/lib/liba.so.meta_lic reciprocal",
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/lib/libc.a.meta_lic reciprocal",
				"testdata/reciprocal/bin/bin2.meta_lic testdata/reciprocal/bin/bin2.meta_lic notice",
				"testdata/reciprocal/container.zip.meta_lic testdata/reciprocal/bin/bin1.meta_lic notice",
				"testdata/reciprocal/container.zip.meta_lic testdata/reciprocal/bin/bin2.meta_lic notice",
				"testdata/reciprocal/container.zip.meta_lic testdata/reciprocal/container.zip.meta_lic notice",
				"testdata/reciprocal/container.zip.meta_lic testdata/reciprocal/lib/liba.so.meta_lic reciprocal",
				"testdata/reciprocal/container.zip.meta_lic testdata/reciprocal/lib/libb.so.meta_lic notice",
				"testdata/reciprocal/container.zip.meta_lic testdata/reciprocal/lib/libc.a.meta_lic reciprocal",
				"testdata/reciprocal/lib/liba.so.meta_lic testdata/reciprocal/lib/liba.so.meta_lic reciprocal",
				"testdata/reciprocal/lib/libb.so.meta_lic testdata/reciprocal/lib/libb.so.meta_lic notice",
			},
		},
		{
			condition: "reciprocal",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []string{
				"testdata/reciprocal/application.meta_lic testdata/reciprocal/application.meta_lic notice",
				"testdata/reciprocal/application.meta_lic testdata/reciprocal/lib/liba.so.meta_lic reciprocal",
			},
		},
		{
			condition: "reciprocal",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []string{
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/bin/bin1.meta_lic notice",
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/lib/liba.so.meta_lic reciprocal",
				"testdata/reciprocal/bin/bin1.meta_lic testdata/reciprocal/lib/libc.a.meta_lic reciprocal",
			},
		},
		{
			condition: "reciprocal",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{
				"testdata/reciprocal/lib/libd.so.meta_lic testdata/reciprocal/lib/libd.so.meta_lic notice",
			},
		},
		{
			condition: "restricted",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []string{
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/bin/bin1.meta_lic notice:restricted_if_statically_linked",
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/lib/liba.so.meta_lic restricted_if_statically_linked",
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/lib/libc.a.meta_lic reciprocal:restricted_if_statically_linked",
				"testdata/restricted/bin/bin2.meta_lic testdata/restricted/bin/bin2.meta_lic notice:restricted",
				"testdata/restricted/bin/bin2.meta_lic testdata/restricted/lib/libb.so.meta_lic restricted",
				"testdata/restricted/highest.apex.meta_lic testdata/restricted/bin/bin1.meta_lic notice:restricted_if_statically_linked",
				"testdata/restricted/highest.apex.meta_lic testdata/restricted/bin/bin2.meta_lic notice:restricted",
				"testdata/restricted/highest.apex.meta_lic testdata/restricted/highest.apex.meta_lic notice:restricted:restricted_if_statically_linked",
				"testdata/restricted/highest.apex.meta_lic testdata/restricted/lib/liba.so.meta_lic restricted_if_statically_linked",
				"testdata/restricted/highest.apex.meta_lic testdata/restricted/lib/libb.so.meta_lic restricted",
				"testdata/restricted/highest.apex.meta_lic testdata/restricted/lib/libc.a.meta_lic reciprocal:restricted_if_statically_linked",
				"testdata/restricted/lib/liba.so.meta_lic testdata/restricted/lib/liba.so.meta_lic restricted_if_statically_linked",
				"testdata/restricted/lib/libb.so.meta_lic testdata/restricted/lib/libb.so.meta_lic restricted",
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/restricted/"}},
			expectedOut: []string{
				"bin/bin1.meta_lic bin/bin1.meta_lic notice:restricted_if_statically_linked",
				"bin/bin1.meta_lic lib/liba.so.meta_lic restricted_if_statically_linked",
				"bin/bin1.meta_lic lib/libc.a.meta_lic reciprocal:restricted_if_statically_linked",
				"bin/bin2.meta_lic bin/bin2.meta_lic notice:restricted",
				"bin/bin2.meta_lic lib/libb.so.meta_lic restricted",
				"highest.apex.meta_lic bin/bin1.meta_lic notice:restricted_if_statically_linked",
				"highest.apex.meta_lic bin/bin2.meta_lic notice:restricted",
				"highest.apex.meta_lic highest.apex.meta_lic notice:restricted:restricted_if_statically_linked",
				"highest.apex.meta_lic lib/liba.so.meta_lic restricted_if_statically_linked",
				"highest.apex.meta_lic lib/libb.so.meta_lic restricted",
				"highest.apex.meta_lic lib/libc.a.meta_lic reciprocal:restricted_if_statically_linked",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic restricted_if_statically_linked",
				"lib/libb.so.meta_lic lib/libb.so.meta_lic restricted",
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_notice",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  []compliance.LicenseCondition{compliance.NoticeCondition},
				stripPrefix: []string{"testdata/restricted/"},
			},
			expectedOut: []string{
				"bin/bin1.meta_lic bin/bin1.meta_lic notice",
				"bin/bin2.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic bin/bin1.meta_lic notice",
				"highest.apex.meta_lic bin/bin2.meta_lic notice",
				"highest.apex.meta_lic highest.apex.meta_lic notice",
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_share",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.AsList(),
				stripPrefix: []string{"testdata/restricted/"},
			},
			expectedOut: []string{
				"bin/bin1.meta_lic bin/bin1.meta_lic restricted_if_statically_linked",
				"bin/bin1.meta_lic lib/liba.so.meta_lic restricted_if_statically_linked",
				"bin/bin1.meta_lic lib/libc.a.meta_lic reciprocal:restricted_if_statically_linked",
				"bin/bin2.meta_lic bin/bin2.meta_lic restricted",
				"bin/bin2.meta_lic lib/libb.so.meta_lic restricted",
				"highest.apex.meta_lic bin/bin1.meta_lic restricted_if_statically_linked",
				"highest.apex.meta_lic bin/bin2.meta_lic restricted",
				"highest.apex.meta_lic highest.apex.meta_lic restricted:restricted_if_statically_linked",
				"highest.apex.meta_lic lib/liba.so.meta_lic restricted_if_statically_linked",
				"highest.apex.meta_lic lib/libb.so.meta_lic restricted",
				"highest.apex.meta_lic lib/libc.a.meta_lic reciprocal:restricted_if_statically_linked",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic restricted_if_statically_linked",
				"lib/libb.so.meta_lic lib/libb.so.meta_lic restricted",
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesPrivate.AsList(),
				stripPrefix: []string{"testdata/restricted/"},
			},
			expectedOut: []string{},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_share_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  append(compliance.ImpliesShared.AsList(), compliance.ImpliesPrivate.AsList()...),
				stripPrefix: []string{"testdata/restricted/"},
			},
			expectedOut: []string{
				"bin/bin1.meta_lic bin/bin1.meta_lic restricted_if_statically_linked",
				"bin/bin1.meta_lic lib/liba.so.meta_lic restricted_if_statically_linked",
				"bin/bin1.meta_lic lib/libc.a.meta_lic reciprocal:restricted_if_statically_linked",
				"bin/bin2.meta_lic bin/bin2.meta_lic restricted",
				"bin/bin2.meta_lic lib/libb.so.meta_lic restricted",
				"highest.apex.meta_lic bin/bin1.meta_lic restricted_if_statically_linked",
				"highest.apex.meta_lic bin/bin2.meta_lic restricted",
				"highest.apex.meta_lic highest.apex.meta_lic restricted:restricted_if_statically_linked",
				"highest.apex.meta_lic lib/liba.so.meta_lic restricted_if_statically_linked",
				"highest.apex.meta_lic lib/libb.so.meta_lic restricted",
				"highest.apex.meta_lic lib/libc.a.meta_lic reciprocal:restricted_if_statically_linked",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic restricted_if_statically_linked",
				"lib/libb.so.meta_lic lib/libb.so.meta_lic restricted",
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/restricted/"}, labelConditions: true},
			expectedOut: []string{
				"bin/bin1.meta_lic:notice bin/bin1.meta_lic:notice notice:restricted_if_statically_linked",
				"bin/bin1.meta_lic:notice lib/liba.so.meta_lic:restricted_if_statically_linked restricted_if_statically_linked",
				"bin/bin1.meta_lic:notice lib/libc.a.meta_lic:reciprocal reciprocal:restricted_if_statically_linked",
				"bin/bin2.meta_lic:notice bin/bin2.meta_lic:notice notice:restricted",
				"bin/bin2.meta_lic:notice lib/libb.so.meta_lic:restricted restricted",
				"highest.apex.meta_lic:notice bin/bin1.meta_lic:notice notice:restricted_if_statically_linked",
				"highest.apex.meta_lic:notice bin/bin2.meta_lic:notice notice:restricted",
				"highest.apex.meta_lic:notice highest.apex.meta_lic:notice notice:restricted:restricted_if_statically_linked",
				"highest.apex.meta_lic:notice lib/liba.so.meta_lic:restricted_if_statically_linked restricted_if_statically_linked",
				"highest.apex.meta_lic:notice lib/libb.so.meta_lic:restricted restricted",
				"highest.apex.meta_lic:notice lib/libc.a.meta_lic:reciprocal reciprocal:restricted_if_statically_linked",
				"lib/liba.so.meta_lic:restricted_if_statically_linked lib/liba.so.meta_lic:restricted_if_statically_linked restricted_if_statically_linked",
				"lib/libb.so.meta_lic:restricted lib/libb.so.meta_lic:restricted restricted",
			},
		},
		{
			condition: "restricted",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []string{
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/bin/bin1.meta_lic notice:restricted_if_statically_linked",
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/lib/liba.so.meta_lic restricted_if_statically_linked",
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/lib/libc.a.meta_lic reciprocal:restricted_if_statically_linked",
				"testdata/restricted/bin/bin2.meta_lic testdata/restricted/bin/bin2.meta_lic notice:restricted",
				"testdata/restricted/bin/bin2.meta_lic testdata/restricted/lib/libb.so.meta_lic restricted",
				"testdata/restricted/container.zip.meta_lic testdata/restricted/bin/bin1.meta_lic notice:restricted_if_statically_linked",
				"testdata/restricted/container.zip.meta_lic testdata/restricted/bin/bin2.meta_lic notice:restricted",
				"testdata/restricted/container.zip.meta_lic testdata/restricted/container.zip.meta_lic notice:restricted:restricted_if_statically_linked",
				"testdata/restricted/container.zip.meta_lic testdata/restricted/lib/liba.so.meta_lic restricted_if_statically_linked",
				"testdata/restricted/container.zip.meta_lic testdata/restricted/lib/libb.so.meta_lic restricted",
				"testdata/restricted/container.zip.meta_lic testdata/restricted/lib/libc.a.meta_lic reciprocal:restricted_if_statically_linked",
				"testdata/restricted/lib/liba.so.meta_lic testdata/restricted/lib/liba.so.meta_lic restricted_if_statically_linked",
				"testdata/restricted/lib/libb.so.meta_lic testdata/restricted/lib/libb.so.meta_lic restricted",
			},
		},
		{
			condition: "restricted",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []string{
				"testdata/restricted/application.meta_lic testdata/restricted/application.meta_lic notice:restricted:restricted_if_statically_linked",
				"testdata/restricted/application.meta_lic testdata/restricted/lib/liba.so.meta_lic restricted:restricted_if_statically_linked",
			},
		},
		{
			condition: "restricted",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []string{
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/bin/bin1.meta_lic notice:restricted_if_statically_linked",
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/lib/liba.so.meta_lic restricted_if_statically_linked",
				"testdata/restricted/bin/bin1.meta_lic testdata/restricted/lib/libc.a.meta_lic reciprocal:restricted_if_statically_linked",
			},
		},
		{
			condition: "restricted",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{
				"testdata/restricted/lib/libd.so.meta_lic testdata/restricted/lib/libd.so.meta_lic notice",
			},
		},
		{
			condition: "proprietary",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []string{
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/bin/bin1.meta_lic notice",
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/lib/liba.so.meta_lic proprietary:by_exception_only",
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/lib/libc.a.meta_lic proprietary:by_exception_only",
				"testdata/proprietary/bin/bin2.meta_lic testdata/proprietary/bin/bin2.meta_lic restricted:proprietary:by_exception_only",
				"testdata/proprietary/bin/bin2.meta_lic testdata/proprietary/lib/libb.so.meta_lic restricted",
				"testdata/proprietary/highest.apex.meta_lic testdata/proprietary/bin/bin1.meta_lic notice",
				"testdata/proprietary/highest.apex.meta_lic testdata/proprietary/bin/bin2.meta_lic restricted:proprietary:by_exception_only",
				"testdata/proprietary/highest.apex.meta_lic testdata/proprietary/highest.apex.meta_lic notice:restricted",
				"testdata/proprietary/highest.apex.meta_lic testdata/proprietary/lib/liba.so.meta_lic proprietary:by_exception_only",
				"testdata/proprietary/highest.apex.meta_lic testdata/proprietary/lib/libb.so.meta_lic restricted",
				"testdata/proprietary/highest.apex.meta_lic testdata/proprietary/lib/libc.a.meta_lic proprietary:by_exception_only",
				"testdata/proprietary/lib/liba.so.meta_lic testdata/proprietary/lib/liba.so.meta_lic proprietary:by_exception_only",
				"testdata/proprietary/lib/libb.so.meta_lic testdata/proprietary/lib/libb.so.meta_lic restricted",
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/proprietary/"}},
			expectedOut: []string{
				"bin/bin1.meta_lic bin/bin1.meta_lic notice",
				"bin/bin1.meta_lic lib/liba.so.meta_lic proprietary:by_exception_only",
				"bin/bin1.meta_lic lib/libc.a.meta_lic proprietary:by_exception_only",
				"bin/bin2.meta_lic bin/bin2.meta_lic restricted:proprietary:by_exception_only",
				"bin/bin2.meta_lic lib/libb.so.meta_lic restricted",
				"highest.apex.meta_lic bin/bin1.meta_lic notice",
				"highest.apex.meta_lic bin/bin2.meta_lic restricted:proprietary:by_exception_only",
				"highest.apex.meta_lic highest.apex.meta_lic notice:restricted",
				"highest.apex.meta_lic lib/liba.so.meta_lic proprietary:by_exception_only",
				"highest.apex.meta_lic lib/libb.so.meta_lic restricted",
				"highest.apex.meta_lic lib/libc.a.meta_lic proprietary:by_exception_only",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic proprietary:by_exception_only",
				"lib/libb.so.meta_lic lib/libb.so.meta_lic restricted",
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_notice",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  []compliance.LicenseCondition{compliance.NoticeCondition},
				stripPrefix: []string{"testdata/proprietary/"},
			},
			expectedOut: []string{
				"bin/bin1.meta_lic bin/bin1.meta_lic notice",
				"highest.apex.meta_lic bin/bin1.meta_lic notice",
				"highest.apex.meta_lic highest.apex.meta_lic notice",
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_share",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.AsList(),
				stripPrefix: []string{"testdata/proprietary/"},
			},
			expectedOut: []string{
				"bin/bin2.meta_lic bin/bin2.meta_lic restricted",
				"bin/bin2.meta_lic lib/libb.so.meta_lic restricted",
				"highest.apex.meta_lic bin/bin2.meta_lic restricted",
				"highest.apex.meta_lic highest.apex.meta_lic restricted",
				"highest.apex.meta_lic lib/libb.so.meta_lic restricted",
				"lib/libb.so.meta_lic lib/libb.so.meta_lic restricted",
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesPrivate.AsList(),
				stripPrefix: []string{"testdata/proprietary/"},
			},
			expectedOut: []string{
				"bin/bin1.meta_lic lib/liba.so.meta_lic proprietary",
				"bin/bin1.meta_lic lib/libc.a.meta_lic proprietary",
				"bin/bin2.meta_lic bin/bin2.meta_lic proprietary",
				"highest.apex.meta_lic bin/bin2.meta_lic proprietary",
				"highest.apex.meta_lic lib/liba.so.meta_lic proprietary",
				"highest.apex.meta_lic lib/libc.a.meta_lic proprietary",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic proprietary",
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_share_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  append(compliance.ImpliesShared.AsList(), compliance.ImpliesPrivate.AsList()...),
				stripPrefix: []string{"testdata/proprietary/"},
			},
			expectedOut: []string{
				"bin/bin1.meta_lic lib/liba.so.meta_lic proprietary",
				"bin/bin1.meta_lic lib/libc.a.meta_lic proprietary",
				"bin/bin2.meta_lic bin/bin2.meta_lic restricted:proprietary",
				"bin/bin2.meta_lic lib/libb.so.meta_lic restricted",
				"highest.apex.meta_lic bin/bin2.meta_lic restricted:proprietary",
				"highest.apex.meta_lic highest.apex.meta_lic restricted",
				"highest.apex.meta_lic lib/liba.so.meta_lic proprietary",
				"highest.apex.meta_lic lib/libb.so.meta_lic restricted",
				"highest.apex.meta_lic lib/libc.a.meta_lic proprietary",
				"lib/liba.so.meta_lic lib/liba.so.meta_lic proprietary",
				"lib/libb.so.meta_lic lib/libb.so.meta_lic restricted",
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/proprietary/"}, labelConditions: true},
			expectedOut: []string{
				"bin/bin1.meta_lic:notice bin/bin1.meta_lic:notice notice",
				"bin/bin1.meta_lic:notice lib/liba.so.meta_lic:proprietary:by_exception_only proprietary:by_exception_only",
				"bin/bin1.meta_lic:notice lib/libc.a.meta_lic:proprietary:by_exception_only proprietary:by_exception_only",
				"bin/bin2.meta_lic:proprietary:by_exception_only bin/bin2.meta_lic:proprietary:by_exception_only restricted:proprietary:by_exception_only",
				"bin/bin2.meta_lic:proprietary:by_exception_only lib/libb.so.meta_lic:restricted restricted",
				"highest.apex.meta_lic:notice bin/bin1.meta_lic:notice notice",
				"highest.apex.meta_lic:notice bin/bin2.meta_lic:proprietary:by_exception_only restricted:proprietary:by_exception_only",
				"highest.apex.meta_lic:notice highest.apex.meta_lic:notice notice:restricted",
				"highest.apex.meta_lic:notice lib/liba.so.meta_lic:proprietary:by_exception_only proprietary:by_exception_only",
				"highest.apex.meta_lic:notice lib/libb.so.meta_lic:restricted restricted",
				"highest.apex.meta_lic:notice lib/libc.a.meta_lic:proprietary:by_exception_only proprietary:by_exception_only",
				"lib/liba.so.meta_lic:proprietary:by_exception_only lib/liba.so.meta_lic:proprietary:by_exception_only proprietary:by_exception_only",
				"lib/libb.so.meta_lic:restricted lib/libb.so.meta_lic:restricted restricted",
			},
		},
		{
			condition: "proprietary",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []string{
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/bin/bin1.meta_lic notice",
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/lib/liba.so.meta_lic proprietary:by_exception_only",
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/lib/libc.a.meta_lic proprietary:by_exception_only",
				"testdata/proprietary/bin/bin2.meta_lic testdata/proprietary/bin/bin2.meta_lic restricted:proprietary:by_exception_only",
				"testdata/proprietary/bin/bin2.meta_lic testdata/proprietary/lib/libb.so.meta_lic restricted",
				"testdata/proprietary/container.zip.meta_lic testdata/proprietary/bin/bin1.meta_lic notice",
				"testdata/proprietary/container.zip.meta_lic testdata/proprietary/bin/bin2.meta_lic restricted:proprietary:by_exception_only",
				"testdata/proprietary/container.zip.meta_lic testdata/proprietary/container.zip.meta_lic notice:restricted",
				"testdata/proprietary/container.zip.meta_lic testdata/proprietary/lib/liba.so.meta_lic proprietary:by_exception_only",
				"testdata/proprietary/container.zip.meta_lic testdata/proprietary/lib/libb.so.meta_lic restricted",
				"testdata/proprietary/container.zip.meta_lic testdata/proprietary/lib/libc.a.meta_lic proprietary:by_exception_only",
				"testdata/proprietary/lib/liba.so.meta_lic testdata/proprietary/lib/liba.so.meta_lic proprietary:by_exception_only",
				"testdata/proprietary/lib/libb.so.meta_lic testdata/proprietary/lib/libb.so.meta_lic restricted",
			},
		},
		{
			condition: "proprietary",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []string{
				"testdata/proprietary/application.meta_lic testdata/proprietary/application.meta_lic notice:restricted",
				"testdata/proprietary/application.meta_lic testdata/proprietary/lib/liba.so.meta_lic restricted:proprietary:by_exception_only",
			},
		},
		{
			condition: "proprietary",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []string{
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/bin/bin1.meta_lic notice",
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/lib/liba.so.meta_lic proprietary:by_exception_only",
				"testdata/proprietary/bin/bin1.meta_lic testdata/proprietary/lib/libc.a.meta_lic proprietary:by_exception_only",
			},
		},
		{
			condition: "proprietary",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{
				"testdata/proprietary/lib/libd.so.meta_lic testdata/proprietary/lib/libd.so.meta_lic notice",
			},
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
			_, err := dumpResolutions(&tt.ctx, stdout, stderr, compliance.GetFS(tt.outDir), rootFiles...)
			if err != nil {
				t.Fatalf("dumpresolutions: error = %v, stderr = %v", err, stderr)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("dumpresolutions: gotStderr = %v, want none", stderr)
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
				t.Errorf("dumpresoliutions: gotStdout = %v, want %v, somewhere near line %d Stdout = %v, want %v",
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
	matchString(*testContext, *compliance.LicenseGraph) string
	typeString() string
}

type targetMatcher struct {
	target     string
	conditions []string
}

// newTestCondition constructs a test license condition in the license graph.
func newTestCondition(lg *compliance.LicenseGraph, conditionName ...string) compliance.LicenseConditionSet {
	cs := compliance.NewLicenseConditionSet()
	for _, name := range conditionName {
		cs = cs.Plus(compliance.RecognizedConditionNames[name])
	}
	if cs.IsEmpty() && len(conditionName) != 0 {
		panic(fmt.Errorf("attempt to create unrecognized condition: %q", conditionName))
	}
	return cs
}

func (tm *targetMatcher) matchString(ctx *testContext, lg *compliance.LicenseGraph) string {
	cs := newTestCondition(lg, tm.conditions...)
	m := tm.target
	if !cs.IsEmpty() {
		m += "\\n" + strings.Join(cs.Names(), "\\n")
	}
	m = ctx.nodes[tm.target] + " [label=\"" + m + "\"];"
	return m
}

func (tm *targetMatcher) typeString() string {
	return "target"
}

type resolutionMatcher struct {
	appliesTo  string
	actsOn     string
	conditions []string
}

func (rm *resolutionMatcher) matchString(ctx *testContext, lg *compliance.LicenseGraph) string {
	cs := newTestCondition(lg, rm.conditions...)
	return ctx.nodes[rm.appliesTo] + " -> " + ctx.nodes[rm.actsOn] +
		" [label=\"" + strings.Join(cs.Names(), "\\n") + "\"];"
}

func (rm *resolutionMatcher) typeString() string {
	return "resolution"
}

type getMatcher func(*testContext) matcher

func matchTarget(target string, conditions ...string) getMatcher {
	return func(ctx *testContext) matcher {
		ctx.nodes[target] = fmt.Sprintf("n%d", ctx.nextNode)
		ctx.nextNode++
		return &targetMatcher{target, append([]string{}, conditions...)}
	}
}

func matchResolution(appliesTo, actsOn string, conditions ...string) getMatcher {
	return func(ctx *testContext) matcher {
		if _, ok := ctx.nodes[appliesTo]; !ok {
			ctx.nodes[appliesTo] = fmt.Sprintf("unknown%d", ctx.nextNode)
			ctx.nextNode++
		}
		if _, ok := ctx.nodes[actsOn]; !ok {
			ctx.nodes[actsOn] = fmt.Sprintf("unknown%d", ctx.nextNode)
			ctx.nextNode++
		}
		return &resolutionMatcher{appliesTo, actsOn, append([]string{}, conditions...)}
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
				matchTarget("testdata/firstparty/lib/liba.so.meta_lic"),
				matchTarget("testdata/firstparty/lib/libc.a.meta_lic"),
				matchTarget("testdata/firstparty/bin/bin2.meta_lic"),
				matchTarget("testdata/firstparty/highest.apex.meta_lic"),
				matchTarget("testdata/firstparty/lib/libb.so.meta_lic"),
				matchResolution(
					"testdata/firstparty/bin/bin1.meta_lic",
					"testdata/firstparty/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/bin/bin1.meta_lic",
					"testdata/firstparty/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/bin/bin1.meta_lic",
					"testdata/firstparty/lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/bin/bin2.meta_lic",
					"testdata/firstparty/bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/highest.apex.meta_lic",
					"testdata/firstparty/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/highest.apex.meta_lic",
					"testdata/firstparty/bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/highest.apex.meta_lic",
					"testdata/firstparty/highest.apex.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/highest.apex.meta_lic",
					"testdata/firstparty/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/highest.apex.meta_lic",
					"testdata/firstparty/lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/highest.apex.meta_lic",
					"testdata/firstparty/lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/lib/liba.so.meta_lic",
					"testdata/firstparty/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/lib/libb.so.meta_lic",
					"testdata/firstparty/lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/firstparty/"}},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed_notice",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  []compliance.LicenseCondition{compliance.NoticeCondition},
				stripPrefix: []string{"testdata/firstparty/"},
			},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed_share",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.AsList(),
				stripPrefix: []string{"testdata/firstparty/"},
			},
			expectedOut: []getMatcher{},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesPrivate.AsList(),
				stripPrefix: []string{"testdata/firstparty/"},
			},
			expectedOut: []getMatcher{},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed_share_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.Union(compliance.ImpliesPrivate).AsList(),
				stripPrefix: []string{"testdata/firstparty/"},
			},
			expectedOut: []getMatcher{},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/firstparty/"}, labelConditions: true},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic", "notice"),
				matchTarget("lib/liba.so.meta_lic", "notice"),
				matchTarget("lib/libc.a.meta_lic", "notice"),
				matchTarget("bin/bin2.meta_lic", "notice"),
				matchTarget("highest.apex.meta_lic", "notice"),
				matchTarget("lib/libb.so.meta_lic", "notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "firstparty",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/firstparty/bin/bin1.meta_lic"),
				matchTarget("testdata/firstparty/lib/liba.so.meta_lic"),
				matchTarget("testdata/firstparty/lib/libc.a.meta_lic"),
				matchTarget("testdata/firstparty/bin/bin2.meta_lic"),
				matchTarget("testdata/firstparty/container.zip.meta_lic"),
				matchTarget("testdata/firstparty/lib/libb.so.meta_lic"),
				matchResolution(
					"testdata/firstparty/bin/bin1.meta_lic",
					"testdata/firstparty/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/bin/bin1.meta_lic",
					"testdata/firstparty/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/bin/bin1.meta_lic",
					"testdata/firstparty/lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/bin/bin2.meta_lic",
					"testdata/firstparty/bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/container.zip.meta_lic",
					"testdata/firstparty/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/container.zip.meta_lic",
					"testdata/firstparty/bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/container.zip.meta_lic",
					"testdata/firstparty/container.zip.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/container.zip.meta_lic",
					"testdata/firstparty/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/container.zip.meta_lic",
					"testdata/firstparty/lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/container.zip.meta_lic",
					"testdata/firstparty/lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/lib/liba.so.meta_lic",
					"testdata/firstparty/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/lib/libb.so.meta_lic",
					"testdata/firstparty/lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "firstparty",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/firstparty/application.meta_lic"),
				matchTarget("testdata/firstparty/lib/liba.so.meta_lic"),
				matchResolution(
					"testdata/firstparty/application.meta_lic",
					"testdata/firstparty/application.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/application.meta_lic",
					"testdata/firstparty/lib/liba.so.meta_lic",
					"notice"),
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
				matchResolution(
					"testdata/firstparty/bin/bin1.meta_lic",
					"testdata/firstparty/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/bin/bin1.meta_lic",
					"testdata/firstparty/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/firstparty/bin/bin1.meta_lic",
					"testdata/firstparty/lib/libc.a.meta_lic",
					"notice"),
			},
		},
		{
			condition: "firstparty",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/firstparty/lib/libd.so.meta_lic"),
				matchResolution(
					"testdata/firstparty/lib/libd.so.meta_lic",
					"testdata/firstparty/lib/libd.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "notice",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/notice/bin/bin1.meta_lic"),
				matchTarget("testdata/notice/lib/liba.so.meta_lic"),
				matchTarget("testdata/notice/lib/libc.a.meta_lic"),
				matchTarget("testdata/notice/bin/bin2.meta_lic"),
				matchTarget("testdata/notice/highest.apex.meta_lic"),
				matchTarget("testdata/notice/lib/libb.so.meta_lic"),
				matchResolution(
					"testdata/notice/bin/bin1.meta_lic",
					"testdata/notice/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/bin/bin1.meta_lic",
					"testdata/notice/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/bin/bin1.meta_lic",
					"testdata/notice/lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/bin/bin2.meta_lic",
					"testdata/notice/bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/highest.apex.meta_lic",
					"testdata/notice/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/highest.apex.meta_lic",
					"testdata/notice/bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/highest.apex.meta_lic",
					"testdata/notice/highest.apex.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/highest.apex.meta_lic",
					"testdata/notice/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/highest.apex.meta_lic",
					"testdata/notice/lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/highest.apex.meta_lic",
					"testdata/notice/lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/lib/liba.so.meta_lic",
					"testdata/notice/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/lib/libb.so.meta_lic",
					"testdata/notice/lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "notice",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/notice/"}},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "notice",
			name:      "apex_trimmed_notice",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  []compliance.LicenseCondition{compliance.NoticeCondition},
				stripPrefix: []string{"testdata/notice/"},
			},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "notice",
			name:      "apex_trimmed_share",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.AsList(),
				stripPrefix: []string{"testdata/notice/"},
			},
			expectedOut: []getMatcher{},
		},
		{
			condition: "notice",
			name:      "apex_trimmed_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesPrivate.AsList(),
				stripPrefix: []string{"testdata/notice/"},
			},
			expectedOut: []getMatcher{},
		},
		{
			condition: "notice",
			name:      "apex_trimmed_share_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.Union(compliance.ImpliesPrivate).AsList(),
				stripPrefix: []string{"testdata/notice/"},
			},
			expectedOut: []getMatcher{},
		},
		{
			condition: "notice",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/notice/"}, labelConditions: true},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic", "notice"),
				matchTarget("lib/liba.so.meta_lic", "notice"),
				matchTarget("lib/libc.a.meta_lic", "notice"),
				matchTarget("bin/bin2.meta_lic", "notice"),
				matchTarget("highest.apex.meta_lic", "notice"),
				matchTarget("lib/libb.so.meta_lic", "notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "notice",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/notice/bin/bin1.meta_lic"),
				matchTarget("testdata/notice/lib/liba.so.meta_lic"),
				matchTarget("testdata/notice/lib/libc.a.meta_lic"),
				matchTarget("testdata/notice/bin/bin2.meta_lic"),
				matchTarget("testdata/notice/container.zip.meta_lic"),
				matchTarget("testdata/notice/lib/libb.so.meta_lic"),
				matchResolution(
					"testdata/notice/bin/bin1.meta_lic",
					"testdata/notice/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/bin/bin1.meta_lic",
					"testdata/notice/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/bin/bin1.meta_lic",
					"testdata/notice/lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/bin/bin2.meta_lic",
					"testdata/notice/bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/container.zip.meta_lic",
					"testdata/notice/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/container.zip.meta_lic",
					"testdata/notice/bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/container.zip.meta_lic",
					"testdata/notice/container.zip.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/container.zip.meta_lic",
					"testdata/notice/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/container.zip.meta_lic",
					"testdata/notice/lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/container.zip.meta_lic",
					"testdata/notice/lib/libc.a.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/lib/liba.so.meta_lic",
					"testdata/notice/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/lib/libb.so.meta_lic",
					"testdata/notice/lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "notice",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/notice/application.meta_lic"),
				matchTarget("testdata/notice/lib/liba.so.meta_lic"),
				matchResolution(
					"testdata/notice/application.meta_lic",
					"testdata/notice/application.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/application.meta_lic",
					"testdata/notice/lib/liba.so.meta_lic",
					"notice"),
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
				matchResolution(
					"testdata/notice/bin/bin1.meta_lic",
					"testdata/notice/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/bin/bin1.meta_lic",
					"testdata/notice/lib/liba.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/notice/bin/bin1.meta_lic",
					"testdata/notice/lib/libc.a.meta_lic",
					"notice"),
			},
		},
		{
			condition: "notice",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/notice/lib/libd.so.meta_lic"),
				matchResolution(
					"testdata/notice/lib/libd.so.meta_lic",
					"testdata/notice/lib/libd.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "reciprocal",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/reciprocal/bin/bin1.meta_lic"),
				matchTarget("testdata/reciprocal/lib/liba.so.meta_lic"),
				matchTarget("testdata/reciprocal/lib/libc.a.meta_lic"),
				matchTarget("testdata/reciprocal/bin/bin2.meta_lic"),
				matchTarget("testdata/reciprocal/highest.apex.meta_lic"),
				matchTarget("testdata/reciprocal/lib/libb.so.meta_lic"),
				matchResolution(
					"testdata/reciprocal/bin/bin1.meta_lic",
					"testdata/reciprocal/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/bin/bin1.meta_lic",
					"testdata/reciprocal/lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"testdata/reciprocal/bin/bin1.meta_lic",
					"testdata/reciprocal/lib/libc.a.meta_lic",
					"reciprocal"),
				matchResolution(
					"testdata/reciprocal/bin/bin2.meta_lic",
					"testdata/reciprocal/bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/highest.apex.meta_lic",
					"testdata/reciprocal/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/highest.apex.meta_lic",
					"testdata/reciprocal/bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/highest.apex.meta_lic",
					"testdata/reciprocal/highest.apex.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/highest.apex.meta_lic",
					"testdata/reciprocal/lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"testdata/reciprocal/highest.apex.meta_lic",
					"testdata/reciprocal/lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/highest.apex.meta_lic",
					"testdata/reciprocal/lib/libc.a.meta_lic",
					"reciprocal"),
				matchResolution(
					"testdata/reciprocal/lib/liba.so.meta_lic",
					"testdata/reciprocal/lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"testdata/reciprocal/lib/libb.so.meta_lic",
					"testdata/reciprocal/lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/reciprocal/"}},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed_notice",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  []compliance.LicenseCondition{compliance.NoticeCondition},
				stripPrefix: []string{"testdata/reciprocal/"},
			},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed_share",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.AsList(),
				stripPrefix: []string{"testdata/reciprocal/"},
			},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"reciprocal"),
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesPrivate.AsList(),
				stripPrefix: []string{"testdata/reciprocal/"},
			},
			expectedOut: []getMatcher{},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed_share_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.Union(compliance.ImpliesPrivate).AsList(),
				stripPrefix: []string{"testdata/reciprocal/"},
			},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"reciprocal"),
			},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/reciprocal/"}, labelConditions: true},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic", "notice"),
				matchTarget("lib/liba.so.meta_lic", "reciprocal"),
				matchTarget("lib/libc.a.meta_lic", "reciprocal"),
				matchTarget("bin/bin2.meta_lic", "notice"),
				matchTarget("highest.apex.meta_lic", "notice"),
				matchTarget("lib/libb.so.meta_lic", "notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "reciprocal",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/reciprocal/bin/bin1.meta_lic"),
				matchTarget("testdata/reciprocal/lib/liba.so.meta_lic"),
				matchTarget("testdata/reciprocal/lib/libc.a.meta_lic"),
				matchTarget("testdata/reciprocal/bin/bin2.meta_lic"),
				matchTarget("testdata/reciprocal/container.zip.meta_lic"),
				matchTarget("testdata/reciprocal/lib/libb.so.meta_lic"),
				matchResolution(
					"testdata/reciprocal/bin/bin1.meta_lic",
					"testdata/reciprocal/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/bin/bin1.meta_lic",
					"testdata/reciprocal/lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"testdata/reciprocal/bin/bin1.meta_lic",
					"testdata/reciprocal/lib/libc.a.meta_lic",
					"reciprocal"),
				matchResolution(
					"testdata/reciprocal/bin/bin2.meta_lic",
					"testdata/reciprocal/bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/container.zip.meta_lic",
					"testdata/reciprocal/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/container.zip.meta_lic",
					"testdata/reciprocal/bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/container.zip.meta_lic",
					"testdata/reciprocal/container.zip.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/container.zip.meta_lic",
					"testdata/reciprocal/lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"testdata/reciprocal/container.zip.meta_lic",
					"testdata/reciprocal/lib/libb.so.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/container.zip.meta_lic",
					"testdata/reciprocal/lib/libc.a.meta_lic",
					"reciprocal"),
				matchResolution(
					"testdata/reciprocal/lib/liba.so.meta_lic",
					"testdata/reciprocal/lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"testdata/reciprocal/lib/libb.so.meta_lic",
					"testdata/reciprocal/lib/libb.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "reciprocal",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/reciprocal/application.meta_lic"),
				matchTarget("testdata/reciprocal/lib/liba.so.meta_lic"),
				matchResolution(
					"testdata/reciprocal/application.meta_lic",
					"testdata/reciprocal/application.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/application.meta_lic",
					"testdata/reciprocal/lib/liba.so.meta_lic",
					"reciprocal"),
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
				matchResolution(
					"testdata/reciprocal/bin/bin1.meta_lic",
					"testdata/reciprocal/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/reciprocal/bin/bin1.meta_lic",
					"testdata/reciprocal/lib/liba.so.meta_lic",
					"reciprocal"),
				matchResolution(
					"testdata/reciprocal/bin/bin1.meta_lic",
					"testdata/reciprocal/lib/libc.a.meta_lic",
					"reciprocal"),
			},
		},
		{
			condition: "reciprocal",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/reciprocal/lib/libd.so.meta_lic"),
				matchResolution(
					"testdata/reciprocal/lib/libd.so.meta_lic",
					"testdata/reciprocal/lib/libd.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "restricted",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/restricted/bin/bin1.meta_lic"),
				matchTarget("testdata/restricted/lib/liba.so.meta_lic"),
				matchTarget("testdata/restricted/lib/libc.a.meta_lic"),
				matchTarget("testdata/restricted/bin/bin2.meta_lic"),
				matchTarget("testdata/restricted/lib/libb.so.meta_lic"),
				matchTarget("testdata/restricted/highest.apex.meta_lic"),
				matchResolution(
					"testdata/restricted/bin/bin1.meta_lic",
					"testdata/restricted/bin/bin1.meta_lic",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"testdata/restricted/bin/bin1.meta_lic",
					"testdata/restricted/lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"testdata/restricted/bin/bin1.meta_lic",
					"testdata/restricted/lib/libc.a.meta_lic",
					"reciprocal",
					"restricted_if_statically_linked"),
				matchResolution(
					"testdata/restricted/bin/bin2.meta_lic",
					"testdata/restricted/bin/bin2.meta_lic",
					"restricted",
					"notice"),
				matchResolution(
					"testdata/restricted/bin/bin2.meta_lic",
					"testdata/restricted/lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"testdata/restricted/highest.apex.meta_lic",
					"testdata/restricted/bin/bin1.meta_lic",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"testdata/restricted/highest.apex.meta_lic",
					"testdata/restricted/bin/bin2.meta_lic",
					"restricted",
					"notice"),
				matchResolution(
					"testdata/restricted/highest.apex.meta_lic",
					"testdata/restricted/highest.apex.meta_lic",
					"restricted",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"testdata/restricted/highest.apex.meta_lic",
					"testdata/restricted/lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"testdata/restricted/highest.apex.meta_lic",
					"testdata/restricted/lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"testdata/restricted/highest.apex.meta_lic",
					"testdata/restricted/lib/libc.a.meta_lic",
					"reciprocal",
					"restricted_if_statically_linked"),
				matchResolution(
					"testdata/restricted/lib/liba.so.meta_lic",
					"testdata/restricted/lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"testdata/restricted/lib/libb.so.meta_lic",
					"testdata/restricted/lib/libb.so.meta_lic",
					"restricted"),
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/restricted/"}},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal",
					"restricted_if_statically_linked"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"restricted",
					"notice"),
				matchResolution(
					"bin/bin2.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"restricted",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"restricted",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal",
					"restricted_if_statically_linked"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_notice",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  []compliance.LicenseCondition{compliance.NoticeCondition},
				stripPrefix: []string{"testdata/restricted/"},
			},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"notice"),
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_share",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.AsList(),
				stripPrefix: []string{"testdata/restricted/"},
			},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal",
					"restricted_if_statically_linked"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"restricted"),
				matchResolution(
					"bin/bin2.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"restricted",
					"restricted_if_statically_linked"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal",
					"restricted_if_statically_linked"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesPrivate.AsList(),
				stripPrefix: []string{"testdata/restricted/"},
			},
			expectedOut: []getMatcher{},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_share_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.Union(compliance.ImpliesPrivate).AsList(),
				stripPrefix: []string{"testdata/restricted/"},
			},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal",
					"restricted_if_statically_linked"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"restricted"),
				matchResolution(
					"bin/bin2.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"restricted",
					"restricted_if_statically_linked"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal",
					"restricted_if_statically_linked"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/restricted/"}, labelConditions: true},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic", "notice"),
				matchTarget("lib/liba.so.meta_lic", "restricted_if_statically_linked"),
				matchTarget("lib/libc.a.meta_lic", "reciprocal"),
				matchTarget("bin/bin2.meta_lic", "notice"),
				matchTarget("lib/libb.so.meta_lic", "restricted"),
				matchTarget("highest.apex.meta_lic", "notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal",
					"restricted_if_statically_linked"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"restricted",
					"notice"),
				matchResolution(
					"bin/bin2.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"restricted",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"restricted",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"reciprocal",
					"restricted_if_statically_linked"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
			},
		},
		{
			condition: "restricted",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/restricted/bin/bin1.meta_lic"),
				matchTarget("testdata/restricted/lib/liba.so.meta_lic"),
				matchTarget("testdata/restricted/lib/libc.a.meta_lic"),
				matchTarget("testdata/restricted/bin/bin2.meta_lic"),
				matchTarget("testdata/restricted/lib/libb.so.meta_lic"),
				matchTarget("testdata/restricted/container.zip.meta_lic"),
				matchResolution(
					"testdata/restricted/bin/bin1.meta_lic",
					"testdata/restricted/bin/bin1.meta_lic",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"testdata/restricted/bin/bin1.meta_lic",
					"testdata/restricted/lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"testdata/restricted/bin/bin1.meta_lic",
					"testdata/restricted/lib/libc.a.meta_lic",
					"reciprocal",
					"restricted_if_statically_linked"),
				matchResolution(
					"testdata/restricted/bin/bin2.meta_lic",
					"testdata/restricted/bin/bin2.meta_lic",
					"restricted",
					"notice"),
				matchResolution(
					"testdata/restricted/bin/bin2.meta_lic",
					"testdata/restricted/lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"testdata/restricted/container.zip.meta_lic",
					"testdata/restricted/bin/bin1.meta_lic",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"testdata/restricted/container.zip.meta_lic",
					"testdata/restricted/bin/bin2.meta_lic",
					"restricted",
					"notice"),
				matchResolution(
					"testdata/restricted/container.zip.meta_lic",
					"testdata/restricted/container.zip.meta_lic",
					"restricted",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"testdata/restricted/container.zip.meta_lic",
					"testdata/restricted/lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"testdata/restricted/container.zip.meta_lic",
					"testdata/restricted/lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"testdata/restricted/container.zip.meta_lic",
					"testdata/restricted/lib/libc.a.meta_lic",
					"reciprocal",
					"restricted_if_statically_linked"),
				matchResolution(
					"testdata/restricted/lib/liba.so.meta_lic",
					"testdata/restricted/lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"testdata/restricted/lib/libb.so.meta_lic",
					"testdata/restricted/lib/libb.so.meta_lic",
					"restricted"),
			},
		},
		{
			condition: "restricted",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/restricted/application.meta_lic"),
				matchTarget("testdata/restricted/lib/liba.so.meta_lic"),
				matchResolution(
					"testdata/restricted/application.meta_lic",
					"testdata/restricted/application.meta_lic",
					"restricted",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"testdata/restricted/application.meta_lic",
					"testdata/restricted/lib/liba.so.meta_lic",
					"restricted_if_statically_linked",
					"restricted"),
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
				matchResolution(
					"testdata/restricted/bin/bin1.meta_lic",
					"testdata/restricted/bin/bin1.meta_lic",
					"restricted_if_statically_linked",
					"notice"),
				matchResolution(
					"testdata/restricted/bin/bin1.meta_lic",
					"testdata/restricted/lib/liba.so.meta_lic",
					"restricted_if_statically_linked"),
				matchResolution(
					"testdata/restricted/bin/bin1.meta_lic",
					"testdata/restricted/lib/libc.a.meta_lic",
					"restricted_if_statically_linked",
					"reciprocal"),
			},
		},
		{
			condition: "restricted",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/restricted/lib/libd.so.meta_lic"),
				matchResolution(
					"testdata/restricted/lib/libd.so.meta_lic",
					"testdata/restricted/lib/libd.so.meta_lic",
					"notice"),
			},
		},
		{
			condition: "proprietary",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/proprietary/bin/bin1.meta_lic"),
				matchTarget("testdata/proprietary/lib/liba.so.meta_lic"),
				matchTarget("testdata/proprietary/lib/libc.a.meta_lic"),
				matchTarget("testdata/proprietary/bin/bin2.meta_lic"),
				matchTarget("testdata/proprietary/lib/libb.so.meta_lic"),
				matchTarget("testdata/proprietary/highest.apex.meta_lic"),
				matchResolution(
					"testdata/proprietary/bin/bin1.meta_lic",
					"testdata/proprietary/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/proprietary/bin/bin1.meta_lic",
					"testdata/proprietary/lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/bin/bin1.meta_lic",
					"testdata/proprietary/lib/libc.a.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/bin/bin2.meta_lic",
					"testdata/proprietary/bin/bin2.meta_lic",
					"restricted",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/bin/bin2.meta_lic",
					"testdata/proprietary/lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"testdata/proprietary/highest.apex.meta_lic",
					"testdata/proprietary/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/proprietary/highest.apex.meta_lic",
					"testdata/proprietary/bin/bin2.meta_lic",
					"restricted",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/highest.apex.meta_lic",
					"testdata/proprietary/highest.apex.meta_lic",
					"restricted",
					"notice"),
				matchResolution(
					"testdata/proprietary/highest.apex.meta_lic",
					"testdata/proprietary/lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/highest.apex.meta_lic",
					"testdata/proprietary/lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"testdata/proprietary/highest.apex.meta_lic",
					"testdata/proprietary/lib/libc.a.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/lib/liba.so.meta_lic",
					"testdata/proprietary/lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/lib/libb.so.meta_lic",
					"testdata/proprietary/lib/libb.so.meta_lic",
					"restricted"),
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/proprietary/"}},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"by_exception_only",
					"restricted",
					"proprietary"),
				matchResolution(
					"bin/bin2.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"restricted",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"restricted",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_notice",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  []compliance.LicenseCondition{compliance.NoticeCondition},
				stripPrefix: []string{"testdata/proprietary/"},
			},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"notice"),
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_share",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.AsList(),
				stripPrefix: []string{"testdata/proprietary/"},
			},
			expectedOut: []getMatcher{
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"restricted"),
				matchResolution(
					"bin/bin2.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesPrivate.AsList(),
				stripPrefix: []string{"testdata/proprietary/"},
			},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"proprietary"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"proprietary"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"proprietary"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"proprietary"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"proprietary"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"proprietary"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"proprietary"),
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_share_private",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				conditions:  compliance.ImpliesShared.Union(compliance.ImpliesPrivate).AsList(),
				stripPrefix: []string{"testdata/proprietary/"},
			},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic"),
				matchTarget("lib/liba.so.meta_lic"),
				matchTarget("lib/libc.a.meta_lic"),
				matchTarget("bin/bin2.meta_lic"),
				matchTarget("lib/libb.so.meta_lic"),
				matchTarget("highest.apex.meta_lic"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"proprietary"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"proprietary"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"restricted",
					"proprietary"),
				matchResolution(
					"bin/bin2.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"restricted",
					"proprietary"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"proprietary"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"proprietary"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"proprietary"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
			},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_labelled",
			roots:     []string{"highest.apex.meta_lic"},
			ctx:       context{stripPrefix: []string{"testdata/proprietary/"}, labelConditions: true},
			expectedOut: []getMatcher{
				matchTarget("bin/bin1.meta_lic", "notice"),
				matchTarget("lib/liba.so.meta_lic", "by_exception_only", "proprietary"),
				matchTarget("lib/libc.a.meta_lic", "by_exception_only", "proprietary"),
				matchTarget("bin/bin2.meta_lic", "by_exception_only", "proprietary"),
				matchTarget("lib/libb.so.meta_lic", "restricted"),
				matchTarget("highest.apex.meta_lic", "notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"bin/bin1.meta_lic",
					"lib/libc.a.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"bin/bin2.meta_lic",
					"bin/bin2.meta_lic",
					"restricted",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"bin/bin2.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"bin/bin2.meta_lic",
					"restricted",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"highest.apex.meta_lic",
					"highest.apex.meta_lic",
					"restricted",
					"notice"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"highest.apex.meta_lic",
					"lib/libc.a.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"lib/liba.so.meta_lic",
					"lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"lib/libb.so.meta_lic",
					"lib/libb.so.meta_lic",
					"restricted"),
			},
		},
		{
			condition: "proprietary",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/proprietary/bin/bin1.meta_lic"),
				matchTarget("testdata/proprietary/lib/liba.so.meta_lic"),
				matchTarget("testdata/proprietary/lib/libc.a.meta_lic"),
				matchTarget("testdata/proprietary/bin/bin2.meta_lic"),
				matchTarget("testdata/proprietary/lib/libb.so.meta_lic"),
				matchTarget("testdata/proprietary/container.zip.meta_lic"),
				matchResolution(
					"testdata/proprietary/bin/bin1.meta_lic",
					"testdata/proprietary/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/proprietary/bin/bin1.meta_lic",
					"testdata/proprietary/lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/bin/bin1.meta_lic",
					"testdata/proprietary/lib/libc.a.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/bin/bin2.meta_lic",
					"testdata/proprietary/bin/bin2.meta_lic",
					"restricted",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/bin/bin2.meta_lic",
					"testdata/proprietary/lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"testdata/proprietary/container.zip.meta_lic",
					"testdata/proprietary/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/proprietary/container.zip.meta_lic",
					"testdata/proprietary/bin/bin2.meta_lic",
					"restricted",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/container.zip.meta_lic",
					"testdata/proprietary/container.zip.meta_lic",
					"restricted",
					"notice"),
				matchResolution(
					"testdata/proprietary/container.zip.meta_lic",
					"testdata/proprietary/lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/container.zip.meta_lic",
					"testdata/proprietary/lib/libb.so.meta_lic",
					"restricted"),
				matchResolution(
					"testdata/proprietary/container.zip.meta_lic",
					"testdata/proprietary/lib/libc.a.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/lib/liba.so.meta_lic",
					"testdata/proprietary/lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/lib/libb.so.meta_lic",
					"testdata/proprietary/lib/libb.so.meta_lic",
					"restricted"),
			},
		},
		{
			condition: "proprietary",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/proprietary/application.meta_lic"),
				matchTarget("testdata/proprietary/lib/liba.so.meta_lic"),
				matchResolution(
					"testdata/proprietary/application.meta_lic",
					"testdata/proprietary/application.meta_lic",
					"notice",
					"restricted"),
				matchResolution(
					"testdata/proprietary/application.meta_lic",
					"testdata/proprietary/lib/liba.so.meta_lic",
					"restricted",
					"by_exception_only",
					"proprietary"),
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
				matchResolution(
					"testdata/proprietary/bin/bin1.meta_lic",
					"testdata/proprietary/bin/bin1.meta_lic",
					"notice"),
				matchResolution(
					"testdata/proprietary/bin/bin1.meta_lic",
					"testdata/proprietary/lib/liba.so.meta_lic",
					"by_exception_only",
					"proprietary"),
				matchResolution(
					"testdata/proprietary/bin/bin1.meta_lic",
					"testdata/proprietary/lib/libc.a.meta_lic",
					"by_exception_only",
					"proprietary"),
			},
		},
		{
			condition: "proprietary",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []getMatcher{
				matchTarget("testdata/proprietary/lib/libd.so.meta_lic"),
				matchResolution(
					"testdata/proprietary/lib/libd.so.meta_lic",
					"testdata/proprietary/lib/libd.so.meta_lic",
					"notice"),
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.condition+" "+tt.name, func(t *testing.T) {
			ctx := &testContext{0, make(map[string]string)}

			stdout := &bytes.Buffer{}
			stderr := &bytes.Buffer{}

			rootFiles := make([]string, 0, len(tt.roots))
			for _, r := range tt.roots {
				rootFiles = append(rootFiles, "testdata/"+tt.condition+"/"+r)
			}
			tt.ctx.graphViz = true
			lg, err := dumpResolutions(&tt.ctx, stdout, stderr, compliance.GetFS(tt.outDir), rootFiles...)
			if err != nil {
				t.Fatalf("dumpresolutions: error = %v, stderr = %v", err, stderr)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("dumpresolutions: gotStderr = %v, want none", stderr)
			}

			expectedOut := &bytes.Buffer{}
			for _, eo := range tt.expectedOut {
				m := eo(ctx)
				expectedOut.WriteString(m.matchString(ctx, lg))
				expectedOut.WriteString("\n")
			}

			outList := strings.Split(stdout.String(), "\n")
			outLine := 0
			if outList[outLine] != "strict digraph {" {
				t.Errorf("dumpresolutions: got 1st line %v, want strict digraph {", outList[outLine])
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
				t.Errorf("dumpresolutions: got last line %v, want }", outList[endOut-1])
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
					t.Errorf("dumpresolutions: missing lines at end of graph, want %d lines %v", len(expectedList)-matchLine, strings.Join(expectedList[matchLine:], "\n"))
				} else if matchLine >= len(expectedList) {
					t.Errorf("dumpresolutions: unexpected lines at end of graph starting line %d, got %v, want nothing", outLine+1, strings.Join(outList[outLine:], "\n"))
				} else {
					t.Errorf("dumpresolutions: at line %d, got %v, want %v", outLine+1, strings.Join(outList[outLine:], "\n"), strings.Join(expectedList[matchLine:], "\n"))
				}
			}
		})
	}
}
