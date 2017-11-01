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

# Used by the compiler wrapper, but should only be set by gomacc
unexport GOMACC_PATH

# Notice: this works only with Google's Goma build infrastructure.
ifneq ($(filter-out false,$(USE_GOMA)),)
  # Goma requires a lot of processes and file descriptors.
  ifeq ($(shell echo $$(($$(ulimit -u) < 2500 || $$(ulimit -n) < 16000))),1)
    $(warning Max user processes and/or open files are insufficient)
    ifeq ($(shell uname),Darwin)
      $(error See go/ma/how-to-use-goma/how-to-use-goma-for-android to relax the limit)
    else
      $(error Adjust the limit by ulimit -u and ulimit -n)
    endif
  endif

  ifdef GOMA_DIR
    goma_dir := $(GOMA_DIR)
  else
    goma_dir := $(HOME)/goma
  endif
  goma_ctl := $(goma_dir)/goma_ctl.py
  GOMA_CC := $(goma_dir)/gomacc

  $(if $(wildcard $(goma_ctl)),, \
   $(warning You should have goma in $$GOMA_DIR or $(HOME)/goma) \
   $(error See go/ma/how-to-use-goma/how-to-use-goma-for-android for detail))

  # Append gomacc to existing *_WRAPPER variables so it's possible to
  # use both ccache and gomacc.
  CC_WRAPPER := $(strip $(CC_WRAPPER) $(GOMA_CC))
  CXX_WRAPPER := $(strip $(CXX_WRAPPER) $(GOMA_CC))
  JAVAC_WRAPPER := $(strip $(JAVAC_WRAPPER) $(GOMA_CC))

  # gomacc can start goma client's daemon process automatically, but
  # it is safer and faster to start up it beforehand. We run this as a
  # background process so this won't slow down the build.
  ifndef NOSTART_GOMA
    $(shell ( $(goma_ctl) ensure_start ) &> /dev/null &)
  endif

  goma_ctl :=
  goma_dir :=
endif
