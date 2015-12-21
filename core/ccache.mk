#
# Copyright (C) 2015 The Android Open Source Project
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

ifneq ($(filter-out false,$(USE_CCACHE)),)
  # The default check uses size and modification time, causing false misses
  # since the mtime depends when the repo was checked out
  export CCACHE_COMPILERCHECK := content

  # See man page, optimizations to get more cache hits
  # implies that __DATE__ and __TIME__ are not critical for functionality.
  # Ignore include file modification time since it will depend on when
  # the repo was checked out
  export CCACHE_SLOPPINESS := time_macros,include_file_mtime,file_macro

  # Turn all preprocessor absolute paths into relative paths.
  # Fixes absolute paths in preprocessed source due to use of -g.
  # We don't really use system headers much so the rootdir is
  # fine; ensures these paths are relative for all Android trees
  # on a workstation.
  export CCACHE_BASEDIR := /

  # Workaround for ccache with clang.
  # See http://petereisentraut.blogspot.com/2011/09/ccache-and-clang-part-2.html
  export CCACHE_CPP2 := true

  CCACHE_HOST_TAG := $(HOST_PREBUILT_TAG)
  ccache := prebuilts/misc/$(CCACHE_HOST_TAG)/ccache/ccache
  # Check that the executable is here.
  ccache := $(strip $(wildcard $(ccache)))
  ifdef ccache
    ifndef CC_WRAPPER
      CC_WRAPPER := $(ccache)
    endif
    ifndef CXX_WRAPPER
      CXX_WRAPPER := $(ccache)
    endif
    ccache =
  endif
endif
