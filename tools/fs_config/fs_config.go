// Copyright (C) 2019 The Android Open Source Project
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

package fs_config

import (
	"android/soong/android"
)

var pctx = android.NewPackageContext("android/soong/fs_config")

func init() {
	android.RegisterModuleType("target_fs_config_gen_filegroup", targetFSConfigGenFactory)
}

// target_fs_config_gen_filegroup is used to expose the files pointed to by TARGET_FS_CONFIG_GEN to
// genrules in Soong. If TARGET_FS_CONFIG_GEN is empty, it will export an empty file instead.
func targetFSConfigGenFactory() android.Module {
	module := &targetFSConfigGen{}
	android.InitAndroidModule(module)
	return module
}

var _ android.SourceFileProducer = (*targetFSConfigGen)(nil)

type targetFSConfigGen struct {
	android.ModuleBase
	paths android.Paths
}

func (targetFSConfigGen) DepsMutator(ctx android.BottomUpMutatorContext) {}

func (t *targetFSConfigGen) GenerateAndroidBuildActions(ctx android.ModuleContext) {
	if ret := ctx.DeviceConfig().TargetFSConfigGen(); len(ret) != 0 {
		t.paths = android.PathsForSource(ctx, ret)
	} else {
		path := android.PathForModuleGen(ctx, "empty")
		t.paths = android.Paths{path}

		rule := android.NewRuleBuilder()
		rule.Command().Text("rm -rf").Output(path)
		rule.Command().Text("touch").Output(path)
		rule.Build(pctx, ctx, "fs_config_empty", "create empty file")
	}
}

func (t *targetFSConfigGen) Srcs() android.Paths {
	return t.paths
}
