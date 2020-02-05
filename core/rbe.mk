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

  ifdef RBE_CXX_EXEC_STRATEGY
    cxx_rbe_exec_strategy := $(RBE_CXX_EXEC_STRATEGY)
  else
    cxx_rbe_exec_strategy := "local"
  endif

  ifdef RBE_JAVAC_EXEC_STRATEGY
    javac_exec_strategy := $(RBE_JAVAC_EXEC_STRATEGY)
  else
    javac_exec_strategy := "local"
  endif

  ifdef RBE_R8_EXEC_STRATEGY
    r8_exec_strategy := $(RBE_R8_EXEC_STRATEGY)
  else
    r8_exec_strategy := "local"
  endif

  ifdef RBE_D8_EXEC_STRATEGY
    d8_exec_strategy := $(RBE_D8_EXEC_STRATEGY)
  else
    d8_exec_strategy := "local"
  endif

  RBE_WRAPPER := $(rbe_dir)/rewrapper
  RBE_CXX := --labels=type=compile,lang=cpp,compiler=clang --env_var_whitelist=PWD --exec_strategy=$(cxx_rbe_exec_strategy)

  # Append rewrapper to existing *_WRAPPER variables so it's possible to
  # use both ccache and rewrapper.
  CC_WRAPPER := $(strip $(CC_WRAPPER) $(RBE_WRAPPER) $(RBE_CXX))
  CXX_WRAPPER := $(strip $(CXX_WRAPPER) $(RBE_WRAPPER) $(RBE_CXX))

  ifdef RBE_JAVAC
    JAVAC_WRAPPER := $(strip $(JAVAC_WRAPPER) $(RBE_WRAPPER) --labels=type=compile,lang=java,compiler=javac,shallow=true --exec_strategy=$(javac_exec_strategy))
  endif

  ifdef RBE_R8
    R8_WRAPPER := $(strip $(RBE_WRAPPER) --labels=type=compile,compiler=r8,shallow=true --exec_strategy=$(r8_exec_strategy))
  endif

  ifdef RBE_D8
    D8_WRAPPER := $(strip $(RBE_WRAPPER) --labels=type=compile,compiler=d8,shallow=true --exec_strategy=$(d8_exec_strategy))
  endif

  rbe_dir :=
endif
