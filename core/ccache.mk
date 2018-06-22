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

# We no longer provide a ccache prebuilt.
#
# Ours was old, and had a number of issues that triggered non-reproducible
# results and other failures. Newer ccache versions may fix some of those
# issues, but at the large scale of our build servers, we weren't seeing
# significant performance gains from using ccache -- you end up needing very
# good locality and/or very large caches if you're building many different
# configurations.
#
# Local no-change full rebuilds were showing better results, but why not just
# use incremental builds at that point?
#
# So if you still want to use ccache, continue setting USE_CCACHE, but also set
# the CCACHE_EXEC environment variable to the path to your ccache executable.
ifneq ($(CCACHE_EXEC),)
ifneq ($(filter-out false,$(USE_CCACHE)),)
  # The default check uses size and modification time, causing false misses
  # since the mtime depends when the repo was checked out
  CCACHE_COMPILERCHECK ?= content

  # See man page, optimizations to get more cache hits
  # implies that __DATE__ and __TIME__ are not critical for functionality.
  # Ignore include file modification time since it will depend on when
  # the repo was checked out
  CCACHE_SLOPPINESS := time_macros,include_file_mtime,file_macro

  # Turn all preprocessor absolute paths into relative paths.
  # Fixes absolute paths in preprocessed source due to use of -g.
  # We don't really use system headers much so the rootdir is
  # fine; ensures these paths are relative for all Android trees
  # on a workstation.
  CCACHE_BASEDIR := /

  # Workaround for ccache with clang.
  # See http://petereisentraut.blogspot.com/2011/09/ccache-and-clang-part-2.html
  CCACHE_CPP2 := true

  ifndef CC_WRAPPER
    CC_WRAPPER := $(CCACHE_EXEC)
  endif
  ifndef CXX_WRAPPER
    CXX_WRAPPER := $(CCACHE_EXEC)
  endif
endif
endif
