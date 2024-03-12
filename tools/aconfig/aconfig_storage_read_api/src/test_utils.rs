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

use anyhow::Result;
use std::fs;
use tempfile::NamedTempFile;

fn set_file_read_only(file: &NamedTempFile) {
    let mut perms = fs::metadata(file.path()).unwrap().permissions();
    if !perms.readonly() {
        perms.set_readonly(true);
        fs::set_permissions(file.path(), perms).unwrap();
    }
}

fn set_file_read_write(file: &NamedTempFile) {
    let mut perms = fs::metadata(file.path()).unwrap().permissions();
    if perms.readonly() {
        perms.set_readonly(false);
        fs::set_permissions(file.path(), perms).unwrap();
    }
}

#[allow(dead_code)]
pub(crate) struct TestStorageFile {
    pub file: NamedTempFile,
    pub name: String,
}

impl TestStorageFile {
    pub(crate) fn new(source_file: &str, read_only: bool) -> Result<Self> {
        let file = NamedTempFile::new()?;
        fs::copy(source_file, file.path())?;
        if read_only {
            set_file_read_only(&file);
        } else {
            set_file_read_write(&file);
        }
        let name = file.path().display().to_string();
        Ok(Self { file, name })
    }
}

pub(crate) struct TestStorageFileSet {
    pub package_map: TestStorageFile,
    pub flag_map: TestStorageFile,
    pub flag_val: TestStorageFile,
}

impl TestStorageFileSet {
    pub(crate) fn new(
        package_map_path: &str,
        flag_map_path: &str,
        flag_val_path: &str,
        read_only: bool,
    ) -> Result<Self> {
        Ok(Self {
            package_map: TestStorageFile::new(package_map_path, read_only)?,
            flag_map: TestStorageFile::new(flag_map_path, read_only)?,
            flag_val: TestStorageFile::new(flag_val_path, read_only)?,
        })
    }
}
