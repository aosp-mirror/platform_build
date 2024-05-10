# Copyright (C) 2023 The Android Open Source Project
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

import os
import pathlib

DEFAULT_REPORT_DIR = "benchmarks"

def get_root():
    top_dir = os.environ.get("ANDROID_BUILD_TOP")
    d = pathlib.Path.cwd()
    # with cog, someone may have a new workspace and new source tree top, but
    # not run lunch yet, resulting in a misleading ANDROID_BUILD_TOP value
    if top_dir and d.is_relative_to(top_dir):
        return pathlib.Path(top_dir).resolve()
    while True:
        if d.joinpath("build", "soong", "soong_ui.bash").exists():
            return d.resolve().absolute()
        d = d.parent
        if d == pathlib.Path("/"):
            return None

def get_dist_dir():
    dist_dir = os.getenv("DIST_DIR")
    if dist_dir:
        return pathlib.Path(dist_dir).resolve()
    return get_out_dir().joinpath("dist")

def get_out_dir():
    out_dir = os.getenv("OUT_DIR")
    if not out_dir:
        out_dir = "out"
    return pathlib.Path(out_dir).resolve()
