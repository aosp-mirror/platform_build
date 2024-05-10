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
	"io"
	"io/fs"
	"path/filepath"
	"strings"
	"sync"

	"android/soong/compliance/project_metadata_proto"

	"google.golang.org/protobuf/encoding/prototext"
)

var (
	// ConcurrentReaders is the size of the task pool for limiting resource usage e.g. open files.
	ConcurrentReaders = 5
)

// ProjectMetadata contains the METADATA for a git project.
type ProjectMetadata struct {
	proto project_metadata_proto.Metadata

	// project is the path to the directory containing the METADATA file.
	project string
}

// ProjectUrlMap maps url type name to url value
type ProjectUrlMap map[string]string

// DownloadUrl returns the address of a download location
func (m ProjectUrlMap) DownloadUrl() string {
	for _, urlType := range []string{"GIT", "SVN", "HG", "DARCS"} {
		if url, ok := m[urlType]; ok {
			return url
		}
	}
	return ""
}

// String returns a string representation of the metadata for error messages.
func (pm *ProjectMetadata) String() string {
	return fmt.Sprintf("project: %q\n%s", pm.project, pm.proto.String())
}

// Project returns the path to the directory containing the METADATA file
func (pm *ProjectMetadata) Project() string {
	return pm.project
}

// Name returns the name of the project.
func (pm *ProjectMetadata) Name() string {
	return pm.proto.GetName()
}

// Version returns the version of the project if available.
func (pm *ProjectMetadata) Version() string {
	tp := pm.proto.GetThirdParty()
	if tp != nil {
		version := tp.GetVersion()
		return version
	}
	return ""
}

// VersionedName returns the name of the project including the version if any.
func (pm *ProjectMetadata) VersionedName() string {
	name := pm.proto.GetName()
	if name != "" {
		tp := pm.proto.GetThirdParty()
		if tp != nil {
			version := tp.GetVersion()
			if version != "" {
				if version[0] == 'v' || version[0] == 'V' {
					return name + "_" + version
				} else {
					return name + "_v_" + version
				}
			}
		}
		return name
	}
	return pm.proto.GetDescription()
}

// UrlsByTypeName returns a map of URLs by Type Name
func (pm *ProjectMetadata) UrlsByTypeName() ProjectUrlMap {
	tp := pm.proto.GetThirdParty()
	if tp == nil {
		return nil
	}
	if len(tp.Url) == 0 {
		return nil
	}
	urls := make(ProjectUrlMap)

	for _, url := range tp.Url {
		uri := url.GetValue()
		if uri == "" {
			continue
		}
		urls[project_metadata_proto.URL_Type_name[int32(url.GetType())]] = uri
	}
	return urls
}

// projectIndex describes a project to be read; after `wg.Wait()`, will contain either
// a `ProjectMetadata`, pm (can be nil even without error), or a non-nil `err`.
type projectIndex struct {
	project string
	path    string
	pm      *ProjectMetadata
	err     error
	done    chan struct{}
}

// finish marks the task to read the `projectIndex` completed.
func (pi *projectIndex) finish() {
	close(pi.done)
}

// wait suspends execution until the `projectIndex` task completes.
func (pi *projectIndex) wait() {
	<-pi.done
}

// Index reads and caches ProjectMetadata (thread safe)
type Index struct {
	// projecs maps project name to a wait group if read has already started, and
	// to a `ProjectMetadata` or to an `error` after the read completes.
	projects sync.Map

	// task provides a fixed-size task pool to limit concurrent open files etc.
	task chan bool

	// rootFS locates the root of the file system from which to read the files.
	rootFS fs.FS
}

// NewIndex constructs a project metadata `Index` for the given file system.
func NewIndex(rootFS fs.FS) *Index {
	ix := &Index{task: make(chan bool, ConcurrentReaders), rootFS: rootFS}
	for i := 0; i < ConcurrentReaders; i++ {
		ix.task <- true
	}
	return ix
}

// MetadataForProjects returns 0..n ProjectMetadata for n `projects`, or an error.
// Each project that has a METADATA.android or a METADATA file in the root of the project will have
// a corresponding ProjectMetadata in the result. Projects with neither file get skipped. A nil
// result with no error indicates none of the given `projects` has a METADATA file.
// (thread safe -- can be called concurrently from multiple goroutines)
func (ix *Index) MetadataForProjects(projects ...string) ([]*ProjectMetadata, error) {
	if ConcurrentReaders < 1 {
		return nil, fmt.Errorf("need at least one task in project metadata pool")
	}
	if len(projects) == 0 {
		return nil, nil
	}
	// Identify the projects that have never been read
	projectsToRead := make([]*projectIndex, 0, len(projects))
	projectIndexes := make([]*projectIndex, 0, len(projects))
	for _, p := range projects {
		pi, loaded := ix.projects.LoadOrStore(p, &projectIndex{project: p, done: make(chan struct{})})
		if !loaded {
			projectsToRead = append(projectsToRead, pi.(*projectIndex))
		}
		projectIndexes = append(projectIndexes, pi.(*projectIndex))
	}
	// findMeta locates and reads the appropriate METADATA file, if any.
	findMeta := func(pi *projectIndex) {
		<-ix.task
		defer func() {
			ix.task <- true
			pi.finish()
		}()

		// Support METADATA.android for projects that already have a different sort of METADATA file.
		path := filepath.Join(pi.project, "METADATA.android")
		fi, err := fs.Stat(ix.rootFS, path)
		if err == nil {
			if fi.Mode().IsRegular() {
				ix.readMetadataFile(pi, path)
				return
			}
		}
		// No METADATA.android try METADATA file.
		path = filepath.Join(pi.project, "METADATA")
		fi, err = fs.Stat(ix.rootFS, path)
		if err == nil {
			if fi.Mode().IsRegular() {
				ix.readMetadataFile(pi, path)
				return
			}
		}
		// no METADATA file exists -- leave nil and finish
	}
	// Look for the METADATA files to read, and record any missing.
	for _, p := range projectsToRead {
		go findMeta(p)
	}
	// Wait until all of the projects have been read.
	var msg strings.Builder
	result := make([]*ProjectMetadata, 0, len(projects))
	for _, pi := range projectIndexes {
		pi.wait()
		// Combine any errors into a single error.
		if pi.err != nil {
			fmt.Fprintf(&msg, "  %v\n", pi.err)
		} else if pi.pm != nil {
			result = append(result, pi.pm)
		}
	}
	if msg.Len() > 0 {
		return nil, fmt.Errorf("error reading project(s):\n%s", msg.String())
	}
	if len(result) == 0 {
		return nil, nil
	}
	return result, nil
}

// AllMetadataFiles returns the sorted list of all METADATA files read thus far.
func (ix *Index) AllMetadataFiles() []string {
	var files []string
	ix.projects.Range(func(key, value any) bool {
		pi := value.(*projectIndex)
		if pi.path != "" {
			files = append(files, pi.path)
		}
		return true
	})
	return files
}

// readMetadataFile tries to read and parse a METADATA file at `path` for `project`.
func (ix *Index) readMetadataFile(pi *projectIndex, path string) {
	f, err := ix.rootFS.Open(path)
	if err != nil {
		pi.err = fmt.Errorf("error opening project %q metadata %q: %w", pi.project, path, err)
		return
	}

	// read the file
	data, err := io.ReadAll(f)
	if err != nil {
		pi.err = fmt.Errorf("error reading project %q metadata %q: %w", pi.project, path, err)
		return
	}
	f.Close()

	uo := prototext.UnmarshalOptions{DiscardUnknown: true}
	pm := &ProjectMetadata{project: pi.project}
	err = uo.Unmarshal(data, &pm.proto)
	if err != nil {
		pi.err = fmt.Errorf(`error in project %q METADATA %q: %v

METADATA and METADATA.android files must parse as text protobufs
defined by
   build/soong/compliance/project_metadata_proto/project_metadata.proto

* unknown fields don't matter
* check invalid ENUM names
* check quoting
* check unescaped nested quotes
* check the comment marker for protobuf is '#' not '//'

if importing a library that uses a different sort of METADATA file, add
a METADATA.android file beside it to parse instead
`, pi.project, path, err)
		return
	}

	pi.path = path
	pi.pm = pm
}
