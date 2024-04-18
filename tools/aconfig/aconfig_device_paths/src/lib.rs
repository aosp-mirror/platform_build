/*
 * Copyright (C) 2024 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//! Library for finding all aconfig on-device protobuf file paths.

use anyhow::Result;
use std::path::PathBuf;

use std::fs;

/// Determine all paths that contain an aconfig protobuf file.
pub fn parsed_flags_proto_paths() -> Result<Vec<PathBuf>> {
    let mut result: Vec<PathBuf> = include!("../partition_aconfig_flags_paths.txt")
        .map(|s| PathBuf::from(s.to_string()))
        .to_vec();
    for dir in fs::read_dir("/apex")? {
        let dir = dir?;

        // Only scan the currently active version of each mainline module; skip the @version dirs.
        if dir.file_name().as_encoded_bytes().iter().any(|&b| b == b'@') {
            continue;
        }

        let mut path = PathBuf::from("/apex");
        path.push(dir.path());
        path.push("etc");
        path.push("aconfig_flags.pb");
        if path.exists() {
            result.push(path);
        }
    }

    Ok(result)
}
