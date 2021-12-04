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

package compliance

import (
	"fmt"
	"io"
	"io/fs"
	"strings"
	"sync"

	"android/soong/compliance/license_metadata_proto"

	"google.golang.org/protobuf/encoding/prototext"
)

var (
	// ConcurrentReaders is the size of the task pool for limiting resource usage e.g. open files.
	ConcurrentReaders = 5
)

// result describes the outcome of reading and parsing a single license metadata file.
type result struct {
	// file identifies the path to the license metadata file
	file string

	// target contains the parsed metadata or nil if an error
	target *TargetNode

	// edges contains the parsed dependencies
	edges []*dependencyEdge

	// err is nil unless an error occurs
	err error
}

// receiver coordinates the tasks for reading and parsing license metadata files.
type receiver struct {
	// lg accumulates the read metadata and becomes the final resulting LicensGraph.
	lg *LicenseGraph

	// rootFS locates the root of the file system from which to read the files.
	rootFS fs.FS

	// stderr identifies the error output writer.
	stderr io.Writer

	// task provides a fixed-size task pool to limit concurrent open files etc.
	task chan bool

	// results returns one license metadata file result at a time.
	results chan *result

	// wg detects when done
	wg sync.WaitGroup
}

// ReadLicenseGraph reads and parses `files` and their dependencies into a LicenseGraph.
//
// `files` become the root files of the graph for top-down walks of the graph.
func ReadLicenseGraph(rootFS fs.FS, stderr io.Writer, files []string) (*LicenseGraph, error) {
	if len(files) == 0 {
		return nil, fmt.Errorf("no license metadata to analyze")
	}
	if ConcurrentReaders < 1 {
		return nil, fmt.Errorf("need at least one task in pool")
	}

	lg := newLicenseGraph()
	for _, f := range files {
		if strings.HasSuffix(f, ".meta_lic") {
			lg.rootFiles = append(lg.rootFiles, f)
		} else {
			lg.rootFiles = append(lg.rootFiles, f+".meta_lic")
		}
	}

	recv := &receiver{
		lg:      lg,
		rootFS:  rootFS,
		stderr:  stderr,
		task:    make(chan bool, ConcurrentReaders),
		results: make(chan *result, ConcurrentReaders),
		wg:      sync.WaitGroup{},
	}
	for i := 0; i < ConcurrentReaders; i++ {
		recv.task <- true
	}

	readFiles := func() {
		lg.mu.Lock()
		// identify the metadata files to schedule reading tasks for
		for _, f := range lg.rootFiles {
			lg.targets[f] = nil
		}
		lg.mu.Unlock()

		// schedule tasks to read the files
		for _, f := range lg.rootFiles {
			readFile(recv, f)
		}

		// schedule a task to wait until finished and close the channel.
		go func() {
			recv.wg.Wait()
			close(recv.task)
			close(recv.results)
		}()
	}
	go readFiles()

	// tasks to read license metadata files are scheduled; read and process results from channel
	var err error
	for recv.results != nil {
		select {
		case r, ok := <-recv.results:
			if ok {
				// handle errors by nil'ing ls, setting err, and clobbering results channel
				if r.err != nil {
					err = r.err
					fmt.Fprintf(recv.stderr, "%s\n", err.Error())
					lg = nil
					recv.results = nil
					continue
				}

				// record the parsed metadata (guarded by mutex)
				recv.lg.mu.Lock()
				recv.lg.targets[r.file] = r.target
				if len(r.edges) > 0 {
					recv.lg.edges = append(recv.lg.edges, r.edges...)
				}
				recv.lg.mu.Unlock()
			} else {
				// finished -- nil the results channel
				recv.results = nil
			}
		}
	}

	return lg, err

}

// targetNode contains the license metadata for a node in the license graph.
type targetNode struct {
	proto license_metadata_proto.LicenseMetadata

	// name is the path to the metadata file
	name string
}

// dependencyEdge describes a single edge in the license graph.
type dependencyEdge struct {
	// target identifies the target node being built and/or installed.
	target string

	// dependency identifies the target node being depended on.
	//
	// i.e. `dependency` is necessary to build `target`.
	dependency string

	// annotations are a set of text attributes attached to the edge.
	//
	// Policy prescribes meaning to a limited set of annotations; others
	// are preserved and ignored.
	annotations TargetEdgeAnnotations
}

// addDependencies converts the proto AnnotatedDependencies into `edges`
func addDependencies(edges *[]*dependencyEdge, target string, dependencies []*license_metadata_proto.AnnotatedDependency) error {
	for _, ad := range dependencies {
		dependency := ad.GetFile()
		if len(dependency) == 0 {
			return fmt.Errorf("missing dependency name")
		}
		annotations := newEdgeAnnotations()
		for _, a := range ad.Annotations {
			if len(a) == 0 {
				continue
			}
			annotations.annotations[a] = true
		}
		*edges = append(*edges, &dependencyEdge{target, dependency, annotations})
	}
	return nil
}

// readFile is a task to read and parse a single license metadata file, and to schedule
// additional tasks for reading and parsing dependencies as necessary.
func readFile(recv *receiver, file string) {
	recv.wg.Add(1)
	<-recv.task
	go func() {
		f, err := recv.rootFS.Open(file)
		if err != nil {
			recv.results <- &result{file, nil, nil, fmt.Errorf("error opening license metadata %q: %w", file, err)}
			return
		}

		// read the file
		data, err := io.ReadAll(f)
		if err != nil {
			recv.results <- &result{file, nil, nil, fmt.Errorf("error reading license metadata %q: %w", file, err)}
			return
		}

		tn := &TargetNode{name: file}

		err = prototext.Unmarshal(data, &tn.proto)
		if err != nil {
			recv.results <- &result{file, nil, nil, fmt.Errorf("error license metadata %q: %w", file, err)}
			return
		}

		edges := []*dependencyEdge{}
		err = addDependencies(&edges, file, tn.proto.Deps)
		if err != nil {
			recv.results <- &result{file, nil, nil, fmt.Errorf("error license metadata dependency %q: %w", file, err)}
			return
		}
		tn.proto.Deps = []*license_metadata_proto.AnnotatedDependency{}

		// send result for this file and release task before scheduling dependencies,
		// but do not signal done to WaitGroup until dependencies are scheduled.
		recv.results <- &result{file, tn, edges, nil}
		recv.task <- true

		// schedule tasks as necessary to read dependencies
		for _, e := range edges {
			// decide, signal and record whether to schedule task in critical section
			recv.lg.mu.Lock()
			_, alreadyScheduled := recv.lg.targets[e.dependency]
			if !alreadyScheduled {
				recv.lg.targets[e.dependency] = nil
			}
			recv.lg.mu.Unlock()
			// schedule task to read dependency file outside critical section
			if !alreadyScheduled {
				readFile(recv, e.dependency)
			}
		}

		// signal task done after scheduling dependencies
		recv.wg.Done()
	}()
}
