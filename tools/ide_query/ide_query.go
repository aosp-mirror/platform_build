/*
 * Copyright (C) 2024 The Android Open Source Project
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

// Binary ide_query generates and analyzes build artifacts.
// The produced result can be consumed by IDEs to provide language features.
package main

import (
	"bytes"
	"container/list"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"slices"
	"strings"

	"google.golang.org/protobuf/proto"
	apb "ide_query/cc_analyzer_proto"
	pb "ide_query/ide_query_proto"
)

// Env contains information about the current environment.
type Env struct {
	LunchTarget    LunchTarget
	RepoDir        string
	OutDir         string
	ClangToolsRoot string
}

// LunchTarget is a parsed Android lunch target.
// Input format: <product_name>-<release_type>-<build_variant>
type LunchTarget struct {
	Product string
	Release string
	Variant string
}

var _ flag.Value = (*LunchTarget)(nil)

// // Get implements flag.Value.
// func (l *LunchTarget) Get() any {
// 	return l
// }

// Set implements flag.Value.
func (l *LunchTarget) Set(s string) error {
	parts := strings.Split(s, "-")
	if len(parts) != 3 {
		return fmt.Errorf("invalid lunch target: %q, must have form <product_name>-<release_type>-<build_variant>", s)
	}
	*l = LunchTarget{
		Product: parts[0],
		Release: parts[1],
		Variant: parts[2],
	}
	return nil
}

// String implements flag.Value.
func (l *LunchTarget) String() string {
	return fmt.Sprintf("%s-%s-%s", l.Product, l.Release, l.Variant)
}

func main() {
	var env Env
	env.OutDir = strings.TrimSuffix(os.Getenv("OUT_DIR"), "/")
	env.RepoDir = os.Getenv("ANDROID_BUILD_TOP")
	env.ClangToolsRoot = os.Getenv("PREBUILTS_CLANG_TOOLS_ROOT")
	flag.Var(&env.LunchTarget, "lunch_target", "The lunch target to query")
	flag.Parse()
	files := flag.Args()
	if len(files) == 0 {
		fmt.Println("No files provided.")
		os.Exit(1)
		return
	}

	var ccFiles, javaFiles []string
	for _, f := range files {
		switch {
		case strings.HasSuffix(f, ".java") || strings.HasSuffix(f, ".kt"):
			javaFiles = append(javaFiles, f)
		case strings.HasSuffix(f, ".cc") || strings.HasSuffix(f, ".cpp") || strings.HasSuffix(f, ".h"):
			ccFiles = append(ccFiles, f)
		default:
			log.Printf("File %q is supported - will be skipped.", f)
		}
	}

	ctx := context.Background()
	// TODO(michaelmerg): Figure out if module_bp_java_deps.json and compile_commands.json is outdated.
	runMake(ctx, env, "nothing")

	javaModules, err := loadJavaModules(env)
	if err != nil {
		log.Printf("Failed to load java modules: %v", err)
	}

	var targets []string
	javaTargetsByFile := findJavaModules(javaFiles, javaModules)
	for _, t := range javaTargetsByFile {
		targets = append(targets, t)
	}

	ccTargets, err := getCCTargets(ctx, env, ccFiles)
	if err != nil {
		log.Fatalf("Failed to query cc targets: %v", err)
	}
	targets = append(targets, ccTargets...)
	if len(targets) == 0 {
		fmt.Println("No targets found.")
		os.Exit(1)
		return
	}

	fmt.Fprintf(os.Stderr, "Running make for modules: %v\n", strings.Join(targets, ", "))
	if err := runMake(ctx, env, targets...); err != nil {
		log.Printf("Building modules failed: %v", err)
	}

	var analysis pb.IdeAnalysis
	results, units := getJavaInputs(env, javaTargetsByFile, javaModules)
	analysis.Results = results
	analysis.Units = units
	if err != nil && analysis.Error == nil {
		analysis.Error = &pb.AnalysisError{
			ErrorMessage: err.Error(),
		}
	}

	results, units, err = getCCInputs(ctx, env, ccFiles)
	analysis.Results = append(analysis.Results, results...)
	analysis.Units = append(analysis.Units, units...)
	if err != nil && analysis.Error == nil {
		analysis.Error = &pb.AnalysisError{
			ErrorMessage: err.Error(),
		}
	}

	analysis.BuildOutDir = env.OutDir
	data, err := proto.Marshal(&analysis)
	if err != nil {
		log.Fatalf("Failed to marshal result proto: %v", err)
	}

	_, err = os.Stdout.Write(data)
	if err != nil {
		log.Fatalf("Failed to write result proto: %v", err)
	}

	for _, r := range analysis.Results {
		fmt.Fprintf(os.Stderr, "%s: %+v\n", r.GetSourceFilePath(), r.GetStatus())
	}
}

func repoState(env Env, filePaths []string) *apb.RepoState {
	const compDbPath = "soong/development/ide/compdb/compile_commands.json"
	return &apb.RepoState{
		RepoDir:        env.RepoDir,
		ActiveFilePath: filePaths,
		OutDir:         env.OutDir,
		CompDbPath:     path.Join(env.OutDir, compDbPath),
	}
}

func runCCanalyzer(ctx context.Context, env Env, mode string, in []byte) ([]byte, error) {
	ccAnalyzerPath := path.Join(env.ClangToolsRoot, "bin/ide_query_cc_analyzer")
	outBuffer := new(bytes.Buffer)

	inBuffer := new(bytes.Buffer)
	inBuffer.Write(in)

	cmd := exec.CommandContext(ctx, ccAnalyzerPath, "--mode="+mode)
	cmd.Dir = env.RepoDir

	cmd.Stdin = inBuffer
	cmd.Stdout = outBuffer
	cmd.Stderr = os.Stderr

	err := cmd.Run()

	return outBuffer.Bytes(), err
}

// Execute cc_analyzer and get all the targets that needs to be build for analyzing files.
func getCCTargets(ctx context.Context, env Env, filePaths []string) ([]string, error) {
	state, err := proto.Marshal(repoState(env, filePaths))
	if err != nil {
		log.Fatalln("Failed to serialize state:", err)
	}

	resp := new(apb.DepsResponse)
	result, err := runCCanalyzer(ctx, env, "deps", state)
	if err != nil {
		return nil, err
	}

	if err := proto.Unmarshal(result, resp); err != nil {
		return nil, fmt.Errorf("malformed response from cc_analyzer: %v", err)
	}

	var targets []string
	if resp.Status != nil && resp.Status.Code != apb.Status_OK {
		return targets, fmt.Errorf("cc_analyzer failed: %v", resp.Status.Message)
	}

	for _, deps := range resp.Deps {
		targets = append(targets, deps.BuildTarget...)
	}
	return targets, nil
}

func getCCInputs(ctx context.Context, env Env, filePaths []string) ([]*pb.AnalysisResult, []*pb.BuildableUnit, error) {
	state, err := proto.Marshal(repoState(env, filePaths))
	if err != nil {
		log.Fatalln("Failed to serialize state:", err)
	}

	resp := new(apb.IdeAnalysis)
	result, err := runCCanalyzer(ctx, env, "inputs", state)
	if err != nil {
		return nil, nil, fmt.Errorf("cc_analyzer failed:", err)
	}
	if err := proto.Unmarshal(result, resp); err != nil {
		return nil, nil, fmt.Errorf("malformed response from cc_analyzer: %v", err)
	}
	if resp.Status != nil && resp.Status.Code != apb.Status_OK {
		return nil, nil, fmt.Errorf("cc_analyzer failed: %v", resp.Status.Message)
	}

	var results []*pb.AnalysisResult
	var units []*pb.BuildableUnit
	for _, s := range resp.Sources {
		status := &pb.AnalysisResult_Status{
			Code: pb.AnalysisResult_Status_CODE_OK,
		}
		if s.GetStatus().GetCode() != apb.Status_OK {
			status.Code = pb.AnalysisResult_Status_CODE_BUILD_FAILED
			status.StatusMessage = proto.String(s.GetStatus().GetMessage())
		}

		result := &pb.AnalysisResult{
			SourceFilePath: s.GetPath(),
			UnitId:         s.GetPath(),
			Status:         status,
		}
		results = append(results, result)

		var generated []*pb.GeneratedFile
		for _, f := range s.Generated {
			generated = append(generated, &pb.GeneratedFile{
				Path:     f.GetPath(),
				Contents: f.GetContents(),
			})
		}
		genUnit := &pb.BuildableUnit{
			Id:              "genfiles_for_" + s.GetPath(),
			SourceFilePaths: s.GetDeps(),
			GeneratedFiles:  generated,
		}

		unit := &pb.BuildableUnit{
			Id:                s.GetPath(),
			Language:          pb.Language_LANGUAGE_CPP,
			SourceFilePaths:   []string{s.GetPath()},
			CompilerArguments: s.GetCompilerArguments(),
			DependencyIds:     []string{genUnit.GetId()},
		}
		units = append(units, unit, genUnit)
	}
	return results, units, nil
}

// findJavaModules tries to find the modules that cover the given file paths.
// If a file is covered by multiple modules, the first module is returned.
func findJavaModules(paths []string, modules map[string]*javaModule) map[string]string {
	ret := make(map[string]string)
	for name, module := range modules {
		if strings.HasSuffix(name, ".impl") {
			continue
		}

		for i, p := range paths {
			if slices.Contains(module.Srcs, p) {
				ret[p] = name
				paths = append(paths[:i], paths[i+1:]...)
				break
			}
		}
		if len(paths) == 0 {
			break
		}
	}
	return ret
}

func getJavaInputs(env Env, modulesByPath map[string]string, modules map[string]*javaModule) ([]*pb.AnalysisResult, []*pb.BuildableUnit) {
	var results []*pb.AnalysisResult
	unitsById := make(map[string]*pb.BuildableUnit)
	for p, moduleName := range modulesByPath {
		r := &pb.AnalysisResult{
			SourceFilePath: p,
		}
		results = append(results, r)

		m := modules[moduleName]
		if m == nil {
			r.Status = &pb.AnalysisResult_Status{
				Code:          pb.AnalysisResult_Status_CODE_NOT_FOUND,
				StatusMessage: proto.String("File not found in any module."),
			}
			continue
		}

		r.UnitId = moduleName
		r.Status = &pb.AnalysisResult_Status{Code: pb.AnalysisResult_Status_CODE_OK}
		if unitsById[r.UnitId] != nil {
			// File is covered by an already created unit.
			continue
		}

		u := &pb.BuildableUnit{
			Id:              moduleName,
			Language:        pb.Language_LANGUAGE_JAVA,
			SourceFilePaths: m.Srcs,
		}
		unitsById[u.Id] = u

		q := list.New()
		for _, d := range m.Deps {
			q.PushBack(d)
		}
		for q.Len() > 0 {
			name := q.Remove(q.Front()).(string)
			mod := modules[name]
			if mod == nil || unitsById[name] != nil {
				continue
			}

			var paths []string
			paths = append(paths, mod.Srcs...)
			paths = append(paths, mod.SrcJars...)
			paths = append(paths, mod.Jars...)
			unitsById[name] = &pb.BuildableUnit{
				Id:              name,
				SourceFilePaths: mod.Srcs,
				GeneratedFiles:  genFiles(env, paths),
			}

			for _, d := range mod.Deps {
				q.PushBack(d)
			}
		}
	}

	units := make([]*pb.BuildableUnit, 0, len(unitsById))
	for _, u := range unitsById {
		units = append(units, u)
	}
	return results, units
}

// genFiles returns the generated files (paths that start with outDir/) for the
// given paths. Generated files that do not exist are ignored.
func genFiles(env Env, paths []string) []*pb.GeneratedFile {
	prefix := env.OutDir + "/"
	var ret []*pb.GeneratedFile
	for _, p := range paths {
		relPath, ok := strings.CutPrefix(p, prefix)
		if !ok {
			continue
		}

		contents, err := os.ReadFile(path.Join(env.RepoDir, p))
		if err != nil {
			continue
		}

		ret = append(ret, &pb.GeneratedFile{
			Path:     relPath,
			Contents: contents,
		})
	}
	return ret
}

// runMake runs Soong build for the given modules.
func runMake(ctx context.Context, env Env, modules ...string) error {
	args := []string{
		"--make-mode",
		"ANDROID_BUILD_ENVIRONMENT_CONFIG=googler-cog",
		"SOONG_GEN_COMPDB=1",
		"TARGET_PRODUCT=" + env.LunchTarget.Product,
		"TARGET_RELEASE=" + env.LunchTarget.Release,
		"TARGET_BUILD_VARIANT=" + env.LunchTarget.Variant,
		"TARGET_BUILD_TYPE=release",
		"-k",
	}
	args = append(args, modules...)
	cmd := exec.CommandContext(ctx, "build/soong/soong_ui.bash", args...)
	cmd.Dir = env.RepoDir
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

type javaModule struct {
	Path    []string `json:"path,omitempty"`
	Deps    []string `json:"dependencies,omitempty"`
	Srcs    []string `json:"srcs,omitempty"`
	Jars    []string `json:"jars,omitempty"`
	SrcJars []string `json:"srcjars,omitempty"`
}

func loadJavaModules(env Env) (map[string]*javaModule, error) {
	javaDepsPath := path.Join(env.RepoDir, env.OutDir, "soong/module_bp_java_deps.json")
	data, err := os.ReadFile(javaDepsPath)
	if err != nil {
		return nil, err
	}

	var ret map[string]*javaModule // module name -> module
	if err = json.Unmarshal(data, &ret); err != nil {
		return nil, err
	}

	// Add top level java_sdk_library for .impl modules.
	for name, module := range ret {
		if striped := strings.TrimSuffix(name, ".impl"); striped != name {
			ret[striped] = module
		}
	}
	return ret, nil
}
