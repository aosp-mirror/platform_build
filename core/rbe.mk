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
    rbe_dir := $(HOME)/rbe
  endif
  RBE_WRAPPER := $(rbe_dir)/rewrapper
  RBE_CXX := --labels=type=compile,lang=cpp,compiler=clang --env_var_whitelist=PWD

  # Append rewrapper to existing *_WRAPPER variables so it's possible to
  # use both ccache and rewrapper.
  CC_WRAPPER := $(strip $(CC_WRAPPER) $(RBE_WRAPPER) $(RBE_CXX))
  CXX_WRAPPER := $(strip $(CXX_WRAPPER) $(RBE_WRAPPER) $(RBE_CXX))

  ifdef RBE_JAVAC
    JAVAC_WRAPPER := $(strip $(JAVAC_WRAPPER) $(RBE_WRAPPER) --labels=type=compile,lang=java,compiler=javac,shallow=true)
  endif

  ifdef RBE_R8
    R8_WRAPPER := $(strip $(RBE_WRAPPER) --labels=type=compile,compiler=r8,shallow=true)
  endif

  ifdef RBE_D8
    D8_WRAPPER := $(strip $(RBE_WRAPPER) --labels=type=compile,compiler=d8,shallow=true)
  endif

  rbe_dir :=
endif
