#
# Copyright (C) 2010 The Android Open Source Project
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

.PHONY: help
help:
	@echo
	@echo "Common make targets:"
	@echo "----------------------------------------------------------------------------------"
	@echo "droid                   Default target"
	@echo "clean                   (aka clobber) equivalent to rm -rf out/"
	@echo "snod                    Quickly rebuild the system image from built packages"
	@echo "offline-sdk-docs        Generate the HTML for the developer SDK docs"
	@echo "doc-comment-check-docs  Check HTML doc links & validity, without generating HTML"
	@echo "libandroid_runtime      All the JNI framework stuff"
	@echo "framework               All the java framework stuff"
	@echo "services                The system server (Java) and friends"
	@echo "help                    You're reading it right now"

.PHONY: out
out:
	@echo "I'm sure you're nice and all, but no thanks."
