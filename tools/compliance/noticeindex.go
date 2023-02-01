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
	"crypto/md5"
	"fmt"
	"io"
	"io/fs"
	"net/url"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"android/soong/tools/compliance/projectmetadata"
)

var (
	licensesPathRegexp = regexp.MustCompile(`licen[cs]es?/`)
)

// NoticeIndex transforms license metadata into license text hashes, library
// names, and install paths indexing them for fast lookup/iteration.
type NoticeIndex struct {
	// lg identifies the license graph to which the index applies.
	lg *LicenseGraph
	// pmix indexes project metadata
	pmix *projectmetadata.Index
	// rs identifies the set of resolutions upon which the index is based.
	rs ResolutionSet
	// shipped identifies the set of target nodes shipped directly or as derivative works.
	shipped TargetNodeSet
	// rootFS locates the root of the file system from which to read the files.
	rootFS fs.FS
	// hash maps license text filenames to content hashes
	hash map[string]hash
	// text maps content hashes to content
	text map[hash][]byte
	// hashLibInstall maps hashes to libraries to install paths.
	hashLibInstall map[hash]map[string]map[string]struct{}
	// installHashLib maps install paths to libraries to hashes.
	installHashLib map[string]map[hash]map[string]struct{}
	// libHash maps libraries to hashes.
	libHash map[string]map[hash]struct{}
	// targetHash maps target nodes to hashes.
	targetHashes map[*TargetNode]map[hash]struct{}
	// projectName maps project directory names to project name text.
	projectName map[string]string
	// files lists all the files accessed during indexing
	files []string
}

// IndexLicenseTexts creates a hashed index of license texts for `lg` and `rs`
// using the files rooted at `rootFS`.
func IndexLicenseTexts(rootFS fs.FS, lg *LicenseGraph, rs ResolutionSet) (*NoticeIndex, error) {
	if rs == nil {
		rs = ResolveNotices(lg)
	}
	ni := &NoticeIndex{
		lg:             lg,
		pmix:           projectmetadata.NewIndex(rootFS),
		rs:             rs,
		shipped:        ShippedNodes(lg),
		rootFS:         rootFS,
		hash:           make(map[string]hash),
		text:           make(map[hash][]byte),
		hashLibInstall: make(map[hash]map[string]map[string]struct{}),
		installHashLib: make(map[string]map[hash]map[string]struct{}),
		libHash:        make(map[string]map[hash]struct{}),
		targetHashes:   make(map[*TargetNode]map[hash]struct{}),
		projectName:    make(map[string]string),
	}

	// index adds all license texts for `tn` to the index.
	index := func(tn *TargetNode) (map[hash]struct{}, error) {
		if hashes, ok := ni.targetHashes[tn]; ok {
			return hashes, nil
		}
		hashes := make(map[hash]struct{})
		for _, text := range tn.LicenseTexts() {
			fname := strings.SplitN(text, ":", 2)[0]
			if _, ok := ni.hash[fname]; !ok {
				err := ni.addText(fname)
				if err != nil {
					return nil, err
				}
			}
			hash := ni.hash[fname]
			if _, ok := hashes[hash]; !ok {
				hashes[hash] = struct{}{}
			}
		}
		ni.targetHashes[tn] = hashes
		return hashes, nil
	}

	link := func(tn *TargetNode, hashes map[hash]struct{}, installPaths []string) error {
		for h := range hashes {
			libName, err := ni.getLibName(tn, h)
			if err != nil {
				return err
			}
			if _, ok := ni.libHash[libName]; !ok {
				ni.libHash[libName] = make(map[hash]struct{})
			}
			if _, ok := ni.hashLibInstall[h]; !ok {
				ni.hashLibInstall[h] = make(map[string]map[string]struct{})
			}
			if _, ok := ni.libHash[libName][h]; !ok {
				ni.libHash[libName][h] = struct{}{}
			}
			for _, installPath := range installPaths {
				if _, ok := ni.installHashLib[installPath]; !ok {
					ni.installHashLib[installPath] = make(map[hash]map[string]struct{})
					ni.installHashLib[installPath][h] = make(map[string]struct{})
					ni.installHashLib[installPath][h][libName] = struct{}{}
				} else if _, ok = ni.installHashLib[installPath][h]; !ok {
					ni.installHashLib[installPath][h] = make(map[string]struct{})
					ni.installHashLib[installPath][h][libName] = struct{}{}
				} else if _, ok = ni.installHashLib[installPath][h][libName]; !ok {
					ni.installHashLib[installPath][h][libName] = struct{}{}
				}
				if _, ok := ni.hashLibInstall[h]; !ok {
					ni.hashLibInstall[h] = make(map[string]map[string]struct{})
					ni.hashLibInstall[h][libName] = make(map[string]struct{})
					ni.hashLibInstall[h][libName][installPath] = struct{}{}
				} else if _, ok = ni.hashLibInstall[h][libName]; !ok {
					ni.hashLibInstall[h][libName] = make(map[string]struct{})
					ni.hashLibInstall[h][libName][installPath] = struct{}{}
				} else if _, ok = ni.hashLibInstall[h][libName][installPath]; !ok {
					ni.hashLibInstall[h][libName][installPath] = struct{}{}
				}
			}
		}
		return nil
	}

	cacheMetadata := func(tn *TargetNode) {
		ni.pmix.MetadataForProjects(tn.Projects()...)
	}

	// returns error from walk below.
	var err error

	WalkTopDown(NoEdgeContext{}, lg, func(lg *LicenseGraph, tn *TargetNode, path TargetEdgePath) bool {
		if err != nil {
			return false
		}
		if !ni.shipped.Contains(tn) {
			return false
		}
		go cacheMetadata(tn)
		installPaths := getInstallPaths(tn, path)
		var hashes map[hash]struct{}
		hashes, err = index(tn)
		if err != nil {
			return false
		}
		err = link(tn, hashes, installPaths)
		if err != nil {
			return false
		}
		if tn.IsContainer() {
			return true
		}

		for _, r := range rs.Resolutions(tn) {
			hashes, err = index(r.actsOn)
			if err != nil {
				return false
			}
			err = link(r.actsOn, hashes, installPaths)
			if err != nil {
				return false
			}
		}
		return false
	})

	if err != nil {
		return nil, err
	}

	return ni, nil
}

// Hashes returns an ordered channel of the hashed license texts.
func (ni *NoticeIndex) Hashes() chan hash {
	c := make(chan hash)
	go func() {
		libs := make([]string, 0, len(ni.libHash))
		for libName := range ni.libHash {
			libs = append(libs, libName)
		}
		sort.Strings(libs)
		hashes := make(map[hash]struct{})
		for _, libName := range libs {
			hl := make([]hash, 0, len(ni.libHash[libName]))
			for h := range ni.libHash[libName] {
				if _, ok := hashes[h]; ok {
					continue
				}
				hashes[h] = struct{}{}
				hl = append(hl, h)
			}
			if len(hl) > 0 {
				sort.Sort(hashList{ni, libName, "", &hl})
				for _, h := range hl {
					c <- h
				}
			}
		}
		close(c)
	}()
	return c

}

// InputFiles returns the complete list of files read during indexing.
func (ni *NoticeIndex) InputFiles() []string {
	projectMeta := ni.pmix.AllMetadataFiles()
	files := make([]string, 0, len(ni.files) + len(ni.lg.targets) + len(projectMeta))
	files = append(files, ni.files...)
	for f := range ni.lg.targets {
		files = append(files, f)
	}
	files = append(files, projectMeta...)
	return files
}

// HashLibs returns the ordered array of library names using the license text
// hashed as `h`.
func (ni *NoticeIndex) HashLibs(h hash) []string {
	libs := make([]string, 0, len(ni.hashLibInstall[h]))
	for libName := range ni.hashLibInstall[h] {
		libs = append(libs, libName)
	}
	sort.Strings(libs)
	return libs
}

// HashLibInstalls returns the ordered array of install paths referencing
// library `libName` using the license text hashed as `h`.
func (ni *NoticeIndex) HashLibInstalls(h hash, libName string) []string {
	installs := make([]string, 0, len(ni.hashLibInstall[h][libName]))
	for installPath := range ni.hashLibInstall[h][libName] {
		installs = append(installs, installPath)
	}
	sort.Strings(installs)
	return installs
}

// InstallPaths returns the ordered channel of indexed install paths.
func (ni *NoticeIndex) InstallPaths() chan string {
	c := make(chan string)
	go func() {
		paths := make([]string, 0, len(ni.installHashLib))
		for path := range ni.installHashLib {
			paths = append(paths, path)
		}
		sort.Strings(paths)
		for _, installPath := range paths {
			c <- installPath
		}
		close(c)
	}()
	return c
}

// InstallHashes returns the ordered array of hashes attached to `installPath`.
func (ni *NoticeIndex) InstallHashes(installPath string) []hash {
	result := make([]hash, 0, len(ni.installHashLib[installPath]))
	for h := range ni.installHashLib[installPath] {
		result = append(result, h)
	}
	if len(result) > 0 {
		sort.Sort(hashList{ni, "", installPath, &result})
	}
	return result
}

// InstallHashLibs returns the ordered array of library names attached to
// `installPath` as hash `h`.
func (ni *NoticeIndex) InstallHashLibs(installPath string, h hash) []string {
	result := make([]string, 0, len(ni.installHashLib[installPath][h]))
	for libName := range ni.installHashLib[installPath][h] {
		result = append(result, libName)
	}
	sort.Strings(result)
	return result
}

// Libraries returns the ordered channel of indexed library names.
func (ni *NoticeIndex) Libraries() chan string {
	c := make(chan string)
	go func() {
		libs := make([]string, 0, len(ni.libHash))
		for lib := range ni.libHash {
			libs = append(libs, lib)
		}
		sort.Strings(libs)
		for _, lib := range libs {
			c <- lib
		}
		close(c)
	}()
	return c
}

// HashText returns the file content of the license text hashed as `h`.
func (ni *NoticeIndex) HashText(h hash) []byte {
	return ni.text[h]
}

// getLibName returns the name of the library associated with `noticeFor`.
func (ni *NoticeIndex) getLibName(noticeFor *TargetNode, h hash) (string, error) {
	for _, text := range noticeFor.LicenseTexts() {
		if !strings.Contains(text, ":") {
			if ni.hash[text].key != h.key {
				continue
			}
			ln, err := ni.checkMetadataForLicenseText(noticeFor, text)
			if err != nil {
				return "", err
			}
			if len(ln) > 0 {
				return ln, nil
			}
			continue
		}

		fields := strings.SplitN(text, ":", 2)
		fname, pname := fields[0], fields[1]
		if ni.hash[fname].key != h.key {
			continue
		}

		ln, err := url.QueryUnescape(pname)
		if err != nil {
			continue
		}
		return ln, nil
	}
	// use name from METADATA if available
	ln, err := ni.checkMetadata(noticeFor)
	if err != nil {
		return "", err
	}
	if len(ln) > 0 {
		return ln, nil
	}
	// use package_name: from license{} module if available
	pn := noticeFor.PackageName()
	if len(pn) > 0 {
		return pn, nil
	}
	for _, p := range noticeFor.Projects() {
		if strings.HasPrefix(p, "prebuilts/") {
			for _, licenseText := range noticeFor.LicenseTexts() {
				if !strings.HasPrefix(licenseText, "prebuilts/") {
					continue
				}
				if !strings.Contains(licenseText, ":") {
					if ni.hash[licenseText].key != h.key {
						continue
					}
				} else {
					fields := strings.SplitN(licenseText, ":", 2)
					fname := fields[0]
					if ni.hash[fname].key != h.key {
						continue
					}
				}
				for _, safePrebuiltPrefix := range safePrebuiltPrefixes {
					match := safePrebuiltPrefix.re.FindString(licenseText)
					if len(match) == 0 {
						continue
					}
					if safePrebuiltPrefix.strip {
						// strip entire prefix
						match = licenseText[len(match):]
					} else {
						// strip from prebuilts/ until safe prefix
						match = licenseText[len(match)-len(safePrebuiltPrefix.prefix):]
					}
					// remove LICENSE or NOTICE or other filename
					li := strings.LastIndex(match, "/")
					if li > 0 {
						match = match[:li]
					}
					// remove *licenses/ path segment and subdirectory if in path
					if offsets := licensesPathRegexp.FindAllStringIndex(match, -1); offsets != nil && offsets[len(offsets)-1][0] > 0 {
						match = match[:offsets[len(offsets)-1][0]]
						li = strings.LastIndex(match, "/")
						if li > 0 {
							match = match[:li]
						}
					}
					return match, nil
				}
				break
			}
		}
		for _, safePathPrefix := range safePathPrefixes {
			if strings.HasPrefix(p, safePathPrefix.prefix) {
				if safePathPrefix.strip {
					return p[len(safePathPrefix.prefix):], nil
				} else {
					return p, nil
				}
			}
		}
	}
	// strip off [./]meta_lic from license metadata path and extract base name
	n := noticeFor.name[:len(noticeFor.name)-9]
	li := strings.LastIndex(n, "/")
	if li > 0 {
		n = n[li+1:]
	}
	fi := strings.Index(n, "@")
	if fi > 0 {
		n = n[:fi]
	}
	return n, nil
}

// checkMetadata tries to look up a library name from a METADATA file associated with `noticeFor`.
func (ni *NoticeIndex) checkMetadata(noticeFor *TargetNode) (string, error) {
	pms, err := ni.pmix.MetadataForProjects(noticeFor.Projects()...)
	if err != nil {
		return "", err
	}
	for _, pm := range pms {
		name := pm.VersionedName()
		if name != "" {
			return name, nil
		}
	}
	return "", nil
}

// checkMetadataForLicenseText
func (ni *NoticeIndex) checkMetadataForLicenseText(noticeFor *TargetNode, licenseText string) (string, error) {
	p := ""
	for _, proj := range noticeFor.Projects() {
		if strings.HasPrefix(licenseText, proj) {
			p = proj
		}
	}
	if len(p) == 0 {
		p = filepath.Dir(licenseText)
		for {
			fi, err := fs.Stat(ni.rootFS, filepath.Join(p, ".git"))
			if err == nil && fi.IsDir() {
				break
			}
			if strings.Contains(p, "/") && p != "/" {
				p = filepath.Dir(p)
				continue
			}
			return "", nil
		}
	}
	pms, err := ni.pmix.MetadataForProjects(p)
	if err != nil {
		return "", err
	}
	if pms == nil {
		return "", nil
	}
	return pms[0].VersionedName(), nil
}

// addText reads and indexes the content of a license text file.
func (ni *NoticeIndex) addText(file string) error {
	f, err := ni.rootFS.Open(filepath.Clean(file))
	if err != nil {
		return fmt.Errorf("error opening license text file %q: %w", file, err)
	}

	// read the file
	text, err := io.ReadAll(f)
	if err != nil {
		return fmt.Errorf("error reading license text file %q: %w", file, err)
	}

	hash := hash{fmt.Sprintf("%x", md5.Sum(text))}
	ni.hash[file] = hash
	if _, alreadyPresent := ni.text[hash]; !alreadyPresent {
		ni.text[hash] = text
	}

	ni.files = append(ni.files, file)

	return nil
}

// getInstallPaths returns the names of the used dependencies mapped to their
// installed locations.
func getInstallPaths(attachesTo *TargetNode, path TargetEdgePath) []string {
	if len(path) == 0 {
		installs := attachesTo.Installed()
		if 0 == len(installs) {
			installs = attachesTo.Built()
		}
		return installs
	}

	var getInstalls func(path TargetEdgePath) []string

	getInstalls = func(path TargetEdgePath) []string {
		// deps contains the output targets from the dependencies in the path
		var deps []string
		if len(path) > 1 {
			// recursively get the targets from the sub-path skipping 1 path segment
			deps = getInstalls(path[1:])
		} else {
			// stop recursion at 1 path segment
			deps = path[0].Dependency().TargetFiles()
		}
		size := 0
		prefixes := path[0].Target().TargetFiles()
		installMap := path[0].Target().InstallMap()
		sources := path[0].Target().Sources()
		for _, dep := range deps {
			found := false
			for _, source := range sources {
				if strings.HasPrefix(dep, source) {
					found = true
					break
				}
			}
			if !found {
				continue
			}
			for _, im := range installMap {
				if strings.HasPrefix(dep, im.FromPath) {
					size += len(prefixes)
					break
				}
			}
		}

		installs := make([]string, 0, size)
		for _, dep := range deps {
			found := false
			for _, source := range sources {
				if strings.HasPrefix(dep, source) {
					found = true
					break
				}
			}
			if !found {
				continue
			}
			for _, im := range installMap {
				if strings.HasPrefix(dep, im.FromPath) {
					for _, prefix := range prefixes {
						installs = append(installs, prefix+im.ContainerPath+dep[len(im.FromPath):])
					}
					break
				}
			}
		}
		return installs
	}
	allInstalls := getInstalls(path)
	installs := path[0].Target().Installed()
	if len(installs) == 0 {
		return allInstalls
	}
	result := make([]string, 0, len(allInstalls))
	for _, install := range allInstalls {
		for _, prefix := range installs {
			if strings.HasPrefix(install, prefix) {
				result = append(result, install)
			}
		}
	}
	return result
}

// hash is an opaque string derived from md5sum.
type hash struct {
	key string
}

// String returns the hexadecimal representation of the hash.
func (h hash) String() string {
	return h.key
}

// hashList orders an array of hashes
type hashList struct {
	ni          *NoticeIndex
	libName     string
	installPath string
	hashes      *[]hash
}

// Len returns the count of elements in the slice.
func (l hashList) Len() int { return len(*l.hashes) }

// Swap rearranges 2 elements of the slice so that each occupies the other's
// former position.
func (l hashList) Swap(i, j int) { (*l.hashes)[i], (*l.hashes)[j] = (*l.hashes)[j], (*l.hashes)[i] }

// Less returns true when the `i`th element is lexicographically less than
// the `j`th element.
func (l hashList) Less(i, j int) bool {
	var insti, instj int
	if len(l.libName) > 0 {
		insti = len(l.ni.hashLibInstall[(*l.hashes)[i]][l.libName])
		instj = len(l.ni.hashLibInstall[(*l.hashes)[j]][l.libName])
	} else {
		libsi := l.ni.InstallHashLibs(l.installPath, (*l.hashes)[i])
		libsj := l.ni.InstallHashLibs(l.installPath, (*l.hashes)[j])
		libsis := strings.Join(libsi, " ")
		libsjs := strings.Join(libsj, " ")
		if libsis != libsjs {
			return libsis < libsjs
		}
	}
	if insti == instj {
		leni := len(l.ni.text[(*l.hashes)[i]])
		lenj := len(l.ni.text[(*l.hashes)[j]])
		if leni == lenj {
			// all else equal, just order by hash value
			return (*l.hashes)[i].key < (*l.hashes)[j].key
		}
		// put shortest texts first within same # of installs
		return leni < lenj
	}
	// reverse order of # installs so that most popular appears first
	return instj < insti
}
