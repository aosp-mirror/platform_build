#
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Notice: this works only with Google's RBE service.
ifneq ($(filter-out false,$(USE_RBE)),)
  ifdef RBE_DIR
    rbe_dir := $(RBE_DIR)
  else
    rbe_dir := prebuilts/remoteexecution-client/live/
  endif

  ifdef RBE_CXX_POOL
    cxx_pool := $(RBE_CXX_POOL)
  else
    cxx_pool := default
  endif

  ifdef RBE_JAVA_POOL
    java_pool := $(RBE_JAVA_POOL)
  else
    java_pool := java16
  endif

  ifdef RBE_CXX_EXEC_STRATEGY
    cxx_rbe_exec_strategy := $(RBE_CXX_EXEC_STRATEGY)
  else
    cxx_rbe_exec_strategy := local
  endif

  ifdef RBE_CXX_COMPARE
    cxx_compare := $(RBE_CXX_COMPARE)
  else
    cxx_compare := false
  endif

  ifdef RBE_JAVAC_EXEC_STRATEGY
    javac_exec_strategy := $(RBE_JAVAC_EXEC_STRATEGY)
  else
    javac_exec_strategy := remote_local_fallback
  endif

  ifdef RBE_R8_EXEC_STRATEGY
    r8_exec_strategy := $(RBE_R8_EXEC_STRATEGY)
  else
    r8_exec_strategy := remote_local_fallback
  endif

  ifdef RBE_D8_EXEC_STRATEGY
    d8_exec_strategy := $(RBE_D8_EXEC_STRATEGY)
  else
    d8_exec_strategy := remote_local_fallback
  endif

  platform := container-image=docker://gcr.io/androidbuild-re-dockerimage/android-build-remoteexec-image@sha256:1eb7f64b9e17102b970bd7a1af7daaebdb01c3fb777715899ef462d6c6d01a45
  cxx_platform := $(platform),Pool=$(cxx_pool)
  java_r8_d8_platform := $(platform),Pool=$(java_pool)

  RBE_WRAPPER := $(rbe_dir)/rewrapper
  RBE_CXX := --labels=type=compile,lang=cpp,compiler=clang --env_var_allowlist=PWD --exec_strategy=$(cxx_rbe_exec_strategy) --platform=$(cxx_platform) --compare=$(cxx_compare)

  # Append rewrapper to existing *_WRAPPER variables so it's possible to
  # use both ccache and rewrapper.
  CC_WRAPPER := $(strip $(CC_WRAPPER) $(RBE_WRAPPER) $(RBE_CXX))
  CXX_WRAPPER := $(strip $(CXX_WRAPPER) $(RBE_WRAPPER) $(RBE_CXX))

  ifdef RBE_JAVAC
    JAVAC_WRAPPER := $(strip $(JAVAC_WRAPPER) $(RBE_WRAPPER) --labels=type=compile,lang=java,compiler=javac --exec_strategy=$(javac_exec_strategy) --platform=$(java_r8_d8_platform))
  endif

  ifdef RBE_R8
    R8_WRAPPER := $(strip $(RBE_WRAPPER) --labels=type=compile,compiler=r8 --exec_strategy=$(r8_exec_strategy) --platform=$(java_r8_d8_platform) --inputs=$(OUT_DIR)/host/linux-x86/framework/r8.jar,build/make/core/proguard_basic_keeps.flags --toolchain_inputs=$(firstword $(JAVA)))
  endif

  ifdef RBE_D8
    D8_WRAPPER := $(strip $(RBE_WRAPPER) --labels=type=compile,compiler=d8 --exec_strategy=$(d8_exec_strategy) --platform=$(java_r8_d8_platform) --inputs=$(OUT_DIR)/host/linux-x86/framework/d8.jar --toolchain_inputs=$(firstword $(JAVA)))
  endif

  rbe_dir :=
endif

