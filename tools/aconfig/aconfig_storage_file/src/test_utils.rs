/*
 * Copyright (C) 2023 The Android Open Source Project
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

use crate::protos::ProtoStorageFiles;
use anyhow::Result;
use protobuf::Message;
use std::fs;
use std::io::Write;
use std::path::Path;
use std::sync::Once;
use tempfile::NamedTempFile;

static INIT: Once = Once::new();

pub(crate) fn get_binary_storage_proto_bytes(text_proto: &str) -> Result<Vec<u8>> {
    let storage_files: ProtoStorageFiles = protobuf::text_format::parse_from_str(text_proto)?;
    let mut binary_proto = Vec::new();
    storage_files.write_to_vec(&mut binary_proto)?;
    Ok(binary_proto)
}

pub(crate) fn write_bytes_to_temp_file(bytes: &[u8]) -> Result<NamedTempFile> {
    let mut file = NamedTempFile::new()?;
    let _ = file.write_all(&bytes);
    Ok(file)
}

fn has_same_content(file1: &Path, file2: &Path) -> Result<bool> {
    let bytes1 = fs::read(file1)?;
    let bytes2 = fs::read(file2)?;
    if bytes1.len() != bytes2.len() {
        return Ok(false);
    }
    for (i, &b1) in bytes1.iter().enumerate() {
        if b1 != bytes2[i] {
            return Ok(false);
        }
    }
    Ok(true)
}

pub(crate) fn create_temp_storage_files_for_test() {
    INIT.call_once(|| {
        let file_paths = [
            ("./tests/package.map", "./tests/tmp.ro.package.map"),
            ("./tests/flag.map", "./tests/tmp.ro.flag.map"),
            ("./tests/flag.val", "./tests/tmp.ro.flag.val"),
            ("./tests/package.map", "./tests/tmp.rw.package.map"),
            ("./tests/flag.map", "./tests/tmp.rw.flag.map"),
            ("./tests/flag.val", "./tests/tmp.rw.flag.val"),
        ];
        for (file_path, copied_file_path) in file_paths.into_iter() {
            let file_path = Path::new(&file_path);
            let copied_file_path = Path::new(&copied_file_path);
            if copied_file_path.exists() && !has_same_content(file_path, copied_file_path).unwrap()
            {
                fs::remove_file(copied_file_path).unwrap();
            }
            if !copied_file_path.exists() {
                fs::copy(file_path, copied_file_path).unwrap();
            }
        }
    });
}

pub(crate) fn set_temp_storage_files_to_read_only() {
    let file_paths =
        ["./tests/tmp.ro.package.map", "./tests/tmp.ro.flag.map", "./tests/tmp.ro.flag.val"];
    for file_path in file_paths.into_iter() {
        let file_path = Path::new(&file_path);
        let mut perms = fs::metadata(file_path).unwrap().permissions();
        if !perms.readonly() {
            perms.set_readonly(true);
            fs::set_permissions(file_path, perms).unwrap();
        }
    }
}
