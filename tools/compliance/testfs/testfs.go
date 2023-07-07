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

package testfs

import (
	"fmt"
	"io"
	"io/fs"
	"strings"
	"time"
)

// TestFS implements a test file system (fs.FS) simulated by a map from filename to []byte content.
type TestFS map[string][]byte

var _ fs.FS = (*TestFS)(nil)
var _ fs.StatFS = (*TestFS)(nil)

// Open implements fs.FS.Open() to open a file based on the filename.
func (tfs *TestFS) Open(name string) (fs.File, error) {
	if _, ok := (*tfs)[name]; !ok {
		return nil, fmt.Errorf("unknown file %q", name)
	}
	return &TestFile{tfs, name, 0}, nil
}

// Stat implements fs.StatFS.Stat() to examine a file based on the filename.
func (tfs *TestFS) Stat(name string) (fs.FileInfo, error) {
	if content, ok := (*tfs)[name]; ok {
		return &TestFileInfo{name, len(content), 0666}, nil
	}
	dirname := name
	if !strings.HasSuffix(dirname, "/") {
		dirname = dirname + "/"
	}
	for name := range (*tfs) {
		if strings.HasPrefix(name, dirname) {
			return &TestFileInfo{name, 8, fs.ModeDir | fs.ModePerm}, nil
		}
	}
	return nil, fmt.Errorf("file not found: %q", name)
}

// TestFileInfo implements a file info (fs.FileInfo) based on TestFS above.
type TestFileInfo struct {
	name string
	size int
	mode fs.FileMode
}

var _ fs.FileInfo = (*TestFileInfo)(nil)

// Name returns the name of the file
func (fi *TestFileInfo) Name() string {
	return fi.name
}

// Size returns the size of the file in bytes.
func (fi *TestFileInfo) Size() int64 {
	return int64(fi.size)
}

// Mode returns the fs.FileMode bits.
func (fi *TestFileInfo) Mode() fs.FileMode {
	return fi.mode
}

// ModTime fakes a modification time.
func (fi *TestFileInfo) ModTime() time.Time {
	return time.UnixMicro(0xb0bb)
}

// IsDir is a synonym for Mode().IsDir()
func (fi *TestFileInfo) IsDir() bool {
	return fi.mode.IsDir()
}

// Sys is unused and returns nil.
func (fi *TestFileInfo) Sys() any {
	return nil
}

// TestFile implements a test file (fs.File) based on TestFS above.
type TestFile struct {
	fs   *TestFS
	name string
	posn int
}

var _ fs.File = (*TestFile)(nil)

// Stat not implemented to obviate implementing fs.FileInfo.
func (f *TestFile) Stat() (fs.FileInfo, error) {
	return f.fs.Stat(f.name)
}

// Read copies bytes from the TestFS map.
func (f *TestFile) Read(b []byte) (int, error) {
	if f.posn < 0 {
		return 0, fmt.Errorf("file not open: %q", f.name)
	}
	if f.posn >= len((*f.fs)[f.name]) {
		return 0, io.EOF
	}
	n := copy(b, (*f.fs)[f.name][f.posn:])
	f.posn += n
	return n, nil
}

// Close marks the TestFile as no longer in use.
func (f *TestFile) Close() error {
	if f.posn < 0 {
		return fmt.Errorf("file already closed: %q", f.name)
	}
	f.posn = -1
	return nil
}
