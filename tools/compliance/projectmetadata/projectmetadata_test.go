// Copyright 2022 Google LLC
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

package projectmetadata

import (
	"fmt"
	"strings"
	"testing"

	"android/soong/compliance/project_metadata_proto"
	"android/soong/tools/compliance/testfs"
)

const (
	// EMPTY represents a METADATA file with no recognized fields
	EMPTY = ``

	// INVALID_NAME represents a METADATA file with the wrong type of name
	INVALID_NAME = `name: a library\n`

	// INVALID_DESCRIPTION represents a METADATA file with the wrong type of description
	INVALID_DESCRIPTION = `description: unquoted text\n`

	// INVALID_VERSION represents a METADATA file with the wrong type of version
	INVALID_VERSION = `third_party { version: 1 }`

	// MY_LIB_1_0 represents a METADATA file for version 1.0 of mylib
	MY_LIB_1_0 = `name: "mylib" description: "my library" third_party { version: "1.0" }`

	// NO_NAME_0_1 represents a METADATA file with a description but no name
	NO_NAME_0_1 = `description: "my library" third_party { version: "0.1" }`

	// URL values per type
	GIT_URL          = "http://example.github.com/my_lib"
	SVN_URL          = "http://example.svn.com/my_lib"
	HG_URL           = "http://example.hg.com/my_lib"
	DARCS_URL        = "http://example.darcs.com/my_lib"
	PIPER_URL        = "http://google3/third_party/my/package"
	HOMEPAGE_URL     = "http://example.com/homepage"
	OTHER_URL        = "http://google.com/"
	ARCHIVE_URL      = "http://ftp.example.com/"
	LOCAL_SOURCE_URL = "https://android.googlesource.com/platform/external/apache-http/"
)

// libWithUrl returns a METADATA file with the right download url
func libWithUrl(urlTypes ...string) string {
	var sb strings.Builder

	fmt.Fprintln(&sb, `name: "mylib" description: "my library"
	 third_party {
	 	version: "1.0"`)

	for _, urltype := range urlTypes {
		var urlValue string
		switch urltype {
		case "GIT":
			urlValue = GIT_URL
		case "SVN":
			urlValue = SVN_URL
		case "HG":
			urlValue = HG_URL
		case "DARCS":
			urlValue = DARCS_URL
		case "PIPER":
			urlValue = PIPER_URL
		case "HOMEPAGE":
			urlValue = HOMEPAGE_URL
		case "OTHER":
			urlValue = OTHER_URL
		case "ARCHIVE":
			urlValue = ARCHIVE_URL
		case "LOCAL_SOURCE":
			urlValue = LOCAL_SOURCE_URL
		default:
			panic(fmt.Errorf("unknown url type: %q. Please update libWithUrl() in build/make/tools/compliance/projectmetadata/projectmetadata_test.go", urltype))
		}
		fmt.Fprintf(&sb, "  url { type: %s value: %q }\n", urltype, urlValue)
	}
	fmt.Fprintln(&sb, `}`)

	return sb.String()
}

func TestVerifyAllUrlTypes(t *testing.T) {
	t.Run("verifyAllUrlTypes", func(t *testing.T) {
		types := make([]string, 0, len(project_metadata_proto.URL_Type_value))
		for t := range project_metadata_proto.URL_Type_value {
			types = append(types, t)
		}
		libWithUrl(types...)
	})
}

func TestUnknownPanics(t *testing.T) {
	t.Run("Unknown panics", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("unexpected success: got no error, want panic")
			}
		}()
		libWithUrl("SOME WILD VALUE THAT DOES NOT EXIST")
	})
}

func TestReadMetadataForProjects(t *testing.T) {
	tests := []struct {
		name          string
		fs            *testfs.TestFS
		projects      []string
		expectedError string
		expected      []pmeta
	}{
		{
			name: "trivial",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte("name: \"Android\"\n"),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "Android",
				name:          "Android",
				version:       "",
				downloadUrl:   "",
			}},
		},
		{
			name: "versioned",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(MY_LIB_1_0),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   "",
			}},
		},
		{
			name: "lib_with_homepage",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("HOMEPAGE")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   "",
			}},
		},
		{
			name: "lib_with_git",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("GIT")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   GIT_URL,
			}},
		},
		{
			name: "lib_with_svn",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("SVN")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   SVN_URL,
			}},
		},
		{
			name: "lib_with_hg",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("HG")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   HG_URL,
			}},
		},
		{
			name: "lib_with_darcs",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("DARCS")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   DARCS_URL,
			}},
		},
		{
			name: "lib_with_piper",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("PIPER")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   "",
			}},
		},
		{
			name: "lib_with_other",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("OTHER")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   "",
			}},
		},
		{
			name: "lib_with_local_source",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("LOCAL_SOURCE")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   "",
			}},
		},
		{
			name: "lib_with_archive",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("ARCHIVE")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   "",
			}},
		},
		{
			name: "lib_with_all_downloads",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("DARCS", "HG", "SVN", "GIT")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   GIT_URL,
			}},
		},
		{
			name: "lib_with_all_downloads_in_different_order",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("DARCS", "GIT", "SVN", "HG")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   GIT_URL,
			}},
		},
		{
			name: "lib_with_all_but_git",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("DARCS", "HG", "SVN")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   SVN_URL,
			}},
		},
		{
			name: "lib_with_all_but_git_and_svn",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("DARCS", "HG")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   HG_URL,
			}},
		},
		{
			name: "lib_with_all_nondownloads_and_git",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("HOMEPAGE", "LOCAL_SOURCE", "PIPER", "ARCHIVE", "GIT")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   GIT_URL,
			}},
		},
		{
			name: "lib_with_all_nondownloads",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl("HOMEPAGE", "LOCAL_SOURCE", "PIPER", "ARCHIVE")),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   "",
			}},
		},
		{
			name: "lib_with_all_nondownloads",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(libWithUrl()),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   "",
			}},
		},
		{
			name: "versioneddesc",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(NO_NAME_0_1),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "my library",
				name:          "",
				version:       "0.1",
				downloadUrl:   "",
			}},
		},
		{
			name: "unterminated",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte("name: \"Android\n"),
			},
			projects:      []string{"/a"},
			expectedError: `invalid character '\n' in string`,
		},
		{
			name: "abc",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(EMPTY),
				"/b/METADATA": []byte(MY_LIB_1_0),
				"/c/METADATA": []byte(NO_NAME_0_1),
			},
			projects: []string{"/a", "/b", "/c"},
			expected: []pmeta{
				{
					project:       "/a",
					versionedName: "",
					name:          "",
					version:       "",
					downloadUrl:   "",
				},
				{
					project:       "/b",
					versionedName: "mylib_v_1.0",
					name:          "mylib",
					version:       "1.0",
					downloadUrl:   "",
				},
				{
					project:       "/c",
					versionedName: "my library",
					name:          "",
					version:       "0.1",
					downloadUrl:   "",
				},
			},
		},
		{
			name: "ab",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(EMPTY),
				"/b/METADATA": []byte(MY_LIB_1_0),
			},
			projects: []string{"/a", "/b", "/c"},
			expected: []pmeta{
				{
					project:       "/a",
					versionedName: "",
					name:          "",
					version:       "",
					downloadUrl:   "",
				},
				{
					project:       "/b",
					versionedName: "mylib_v_1.0",
					name:          "mylib",
					version:       "1.0",
					downloadUrl:   "",
				},
			},
		},
		{
			name: "ac",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(EMPTY),
				"/c/METADATA": []byte(NO_NAME_0_1),
			},
			projects: []string{"/a", "/b", "/c"},
			expected: []pmeta{
				{
					project:       "/a",
					versionedName: "",
					name:          "",
					version:       "",
					downloadUrl:   "",
				},
				{
					project:       "/c",
					versionedName: "my library",
					name:          "",
					version:       "0.1",
					downloadUrl:   "",
				},
			},
		},
		{
			name: "bc",
			fs: &testfs.TestFS{
				"/b/METADATA": []byte(MY_LIB_1_0),
				"/c/METADATA": []byte(NO_NAME_0_1),
			},
			projects: []string{"/a", "/b", "/c"},
			expected: []pmeta{
				{
					project:       "/b",
					versionedName: "mylib_v_1.0",
					name:          "mylib",
					version:       "1.0",
					downloadUrl:   "",
				},
				{
					project:       "/c",
					versionedName: "my library",
					name:          "",
					version:       "0.1",
					downloadUrl:   "",
				},
			},
		},
		{
			name: "wrongnametype",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(INVALID_NAME),
			},
			projects:      []string{"/a"},
			expectedError: `invalid value for string type`,
		},
		{
			name: "wrongdescriptiontype",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(INVALID_DESCRIPTION),
			},
			projects:      []string{"/a"},
			expectedError: `invalid value for string type`,
		},
		{
			name: "wrongversiontype",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(INVALID_VERSION),
			},
			projects:      []string{"/a"},
			expectedError: `invalid value for string type`,
		},
		{
			name: "wrongtype",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(INVALID_NAME + INVALID_DESCRIPTION + INVALID_VERSION),
			},
			projects:      []string{"/a"},
			expectedError: `invalid value for string type`,
		},
		{
			name: "empty",
			fs: &testfs.TestFS{
				"/a/METADATA": []byte(EMPTY),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "",
				name:          "",
				version:       "",
				downloadUrl:   "",
			}},
		},
		{
			name: "emptyother",
			fs: &testfs.TestFS{
				"/a/METADATA.bp": []byte(EMPTY),
			},
			projects: []string{"/a"},
		},
		{
			name:     "emptyfs",
			fs:       &testfs.TestFS{},
			projects: []string{"/a"},
		},
		{
			name: "override",
			fs: &testfs.TestFS{
				"/a/METADATA":         []byte(INVALID_NAME + INVALID_DESCRIPTION + INVALID_VERSION),
				"/a/METADATA.android": []byte(MY_LIB_1_0),
			},
			projects: []string{"/a"},
			expected: []pmeta{{
				project:       "/a",
				versionedName: "mylib_v_1.0",
				name:          "mylib",
				version:       "1.0",
				downloadUrl:   "",
			}},
		},
		{
			name: "enchilada",
			fs: &testfs.TestFS{
				"/a/METADATA":         []byte(INVALID_NAME + INVALID_DESCRIPTION + INVALID_VERSION),
				"/a/METADATA.android": []byte(EMPTY),
				"/b/METADATA":         []byte(MY_LIB_1_0),
				"/c/METADATA":         []byte(NO_NAME_0_1),
			},
			projects: []string{"/a", "/b", "/c"},
			expected: []pmeta{
				{
					project:       "/a",
					versionedName: "",
					name:          "",
					version:       "",
					downloadUrl:   "",
				},
				{
					project:       "/b",
					versionedName: "mylib_v_1.0",
					name:          "mylib",
					version:       "1.0",
					downloadUrl:   "",
				},
				{
					project:       "/c",
					versionedName: "my library",
					name:          "",
					version:       "0.1",
					downloadUrl:   "",
				},
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ix := NewIndex(tt.fs)
			pms, err := ix.MetadataForProjects(tt.projects...)
			if err != nil {
				if len(tt.expectedError) == 0 {
					t.Errorf("unexpected error: got %s, want no error", err)
				} else if !strings.Contains(err.Error(), tt.expectedError) {
					t.Errorf("unexpected error: got %s, want %q", err, tt.expectedError)
				}
				return
			}
			t.Logf("actual %d project metadata", len(pms))
			for _, pm := range pms {
				t.Logf("  %v", pm.String())
			}
			t.Logf("expected %d project metadata", len(tt.expected))
			for _, pm := range tt.expected {
				t.Logf("  %s", pm.String())
			}
			if len(tt.expectedError) > 0 {
				t.Errorf("unexpected success: got no error, want %q err", tt.expectedError)
				return
			}
			if len(pms) != len(tt.expected) {
				t.Errorf("missing project metadata: got %d project metadata, want %d", len(pms), len(tt.expected))
			}
			for i := 0; i < len(pms) && i < len(tt.expected); i++ {
				if msg := tt.expected[i].difference(pms[i]); msg != "" {
					t.Errorf("unexpected metadata starting at index %d: %s", i, msg)
					return
				}
			}
			if len(pms) < len(tt.expected) {
				t.Errorf("missing metadata starting at index %d: got nothing, want %s", len(pms), tt.expected[len(pms)].String())
			}
			if len(tt.expected) < len(pms) {
				t.Errorf("unexpected metadata starting at index %d: got %s, want nothing", len(tt.expected), pms[len(tt.expected)].String())
			}
		})
	}
}

type pmeta struct {
	project       string
	versionedName string
	name          string
	version       string
	downloadUrl   string
}

func (pm pmeta) String() string {
	return fmt.Sprintf("project: %q versionedName: %q name: %q version: %q downloadUrl: %q\n", pm.project, pm.versionedName, pm.name, pm.version, pm.downloadUrl)
}

func (pm pmeta) equals(other *ProjectMetadata) bool {
	if pm.project != other.project {
		return false
	}
	if pm.versionedName != other.VersionedName() {
		return false
	}
	if pm.name != other.Name() {
		return false
	}
	if pm.version != other.Version() {
		return false
	}
	if pm.downloadUrl != other.UrlsByTypeName().DownloadUrl() {
		return false
	}
	return true
}

func (pm pmeta) difference(other *ProjectMetadata) string {
	if pm.equals(other) {
		return ""
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "got")
	if pm.project != other.project {
		fmt.Fprintf(&sb, " project: %q", other.project)
	}
	if pm.versionedName != other.VersionedName() {
		fmt.Fprintf(&sb, " versionedName: %q", other.VersionedName())
	}
	if pm.name != other.Name() {
		fmt.Fprintf(&sb, " name: %q", other.Name())
	}
	if pm.version != other.Version() {
		fmt.Fprintf(&sb, " version: %q", other.Version())
	}
	if pm.downloadUrl != other.UrlsByTypeName().DownloadUrl() {
		fmt.Fprintf(&sb, " downloadUrl: %q", other.UrlsByTypeName().DownloadUrl())
	}
	fmt.Fprintf(&sb, ", want")
	if pm.project != other.project {
		fmt.Fprintf(&sb, " project: %q", pm.project)
	}
	if pm.versionedName != other.VersionedName() {
		fmt.Fprintf(&sb, " versionedName: %q", pm.versionedName)
	}
	if pm.name != other.Name() {
		fmt.Fprintf(&sb, " name: %q", pm.name)
	}
	if pm.version != other.Version() {
		fmt.Fprintf(&sb, " version: %q", pm.version)
	}
	if pm.downloadUrl != other.UrlsByTypeName().DownloadUrl() {
		fmt.Fprintf(&sb, " downloadUrl: %q", pm.downloadUrl)
	}
	return sb.String()
}
