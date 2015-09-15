# Copyright 2015 Google Inc. All rights reserved
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

# Find source file location from path to this Makefile
MAKEPARALLEL_SRC_PATH := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
ifndef MAKEPARALLEL_SRC_PATH
  MAKEPARALLEL_SRC_PATH := .
endif

# Set defaults if they weren't set by the including Makefile
MAKEPARALLEL_CXX ?= $(CXX)
MAKEPARALLEL_LD ?= $(CXX)
MAKEPARALLEL_INTERMEDIATES_PATH ?= .
MAKEPARALLEL_BIN_PATH ?= .

MAKEPARALLEL_CXX_SRCS := \
	makeparallel.cpp

MAKEPARALLEL_CXXFLAGS := -Wall -Werror -MMD -MP

MAKEPARALLEL_CXX_SRCS := $(addprefix $(MAKEPARALLEL_SRC_PATH)/,\
	$(MAKEPARALLEL_CXX_SRCS))

MAKEPARALLEL_CXX_OBJS := $(patsubst $(MAKEPARALLEL_SRC_PATH)/%.cpp,$(MAKEPARALLEL_INTERMEDIATES_PATH)/%.o,$(MAKEPARALLEL_CXX_SRCS))

MAKEPARALLEL := $(MAKEPARALLEL_BIN_PATH)/makeparallel

ifeq ($(shell uname),Linux)
MAKEPARALLEL_LIBS := -lrt -lpthread
endif

# Rule to build makeparallel into MAKEPARALLEL_BIN_PATH
$(MAKEPARALLEL): $(MAKEPARALLEL_CXX_OBJS)
	@mkdir -p $(dir $@)
	$(MAKEPARALLEL_LD) -std=c++11 $(MAKEPARALLEL_CXXFLAGS) -o $@ $^ $(MAKEPARALLEL_LIBS)

# Rule to build source files into object files in MAKEPARALLEL_INTERMEDIATES_PATH
$(MAKEPARALLEL_CXX_OBJS): $(MAKEPARALLEL_INTERMEDIATES_PATH)/%.o: $(MAKEPARALLEL_SRC_PATH)/%.cpp
	@mkdir -p $(dir $@)
	$(MAKEPARALLEL_CXX) -c -std=c++11 $(MAKEPARALLEL_CXXFLAGS) -o $@ $<

makeparallel_clean:
	rm -rf $(MAKEPARALLEL)
	rm -rf $(MAKEPARALLEL_INTERMEDIATES_PATH)/*.o
	rm -rf $(MAKEPARALLEL_INTERMEDIATES_PATH)/*.d

.PHONY: makeparallel_clean

-include $(MAKEPARALLEL_INTERMEDIATES_PATH)/*.d

.PHONY: test
test: $(MAKEPARALLEL)
	MAKEFLAGS= $(MAKE) -j1234 -C $(MAKEPARALLEL_SRC_PATH) -f Makefile.test MAKEPARALLEL=$(MAKEPARALLEL) test
