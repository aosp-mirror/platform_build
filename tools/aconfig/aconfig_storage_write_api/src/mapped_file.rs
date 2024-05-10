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

use anyhow::anyhow;
use memmap2::MmapMut;
use std::fs::{self, OpenOptions};

use aconfig_storage_file::AconfigStorageError::{self, FileReadFail, MapFileFail};

/// Get the mutable memory mapping of a storage file
///
/// # Safety
///
/// The memory mapped file may have undefined behavior if there are writes to this
/// file not thru this memory mapped file or there are concurrent writes to this
/// memory mapped file. Ensure all writes to the underlying file are thru this memory
/// mapped file and there are no concurrent writes.
pub(crate) unsafe fn map_file(file_path: &str) -> Result<MmapMut, AconfigStorageError> {
    // make sure file has read write permission
    let perms = fs::metadata(file_path).unwrap().permissions();
    if perms.readonly() {
        return Err(MapFileFail(anyhow!("fail to map non read write storage file {}", file_path)));
    }

    let file =
        OpenOptions::new().read(true).write(true).open(file_path).map_err(|errmsg| {
            FileReadFail(anyhow!("Failed to open file {}: {}", file_path, errmsg))
        })?;

    unsafe {
        let mapped_file = MmapMut::map_mut(&file).map_err(|errmsg| {
            MapFileFail(anyhow!("fail to map storage file {}: {}", file_path, errmsg))
        })?;
        Ok(mapped_file)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::copy_to_temp_file;
    use std::io::Read;

    #[test]
    fn test_mapped_file_contents() {
        let mut rw_val_file = copy_to_temp_file("./tests/flag.val", false).unwrap();
        let mut rw_info_file = copy_to_temp_file("./tests/flag.info", false).unwrap();
        let flag_val = rw_val_file.path().display().to_string();
        let flag_info = rw_info_file.path().display().to_string();

        let mut content = Vec::new();
        rw_val_file.read_to_end(&mut content).unwrap();

        // SAFETY:
        // The safety here is guaranteed here as no writes happens to this temp file
        unsafe {
            let mmaped_file = map_file(&flag_val).unwrap();
            assert_eq!(mmaped_file[..], content[..]);
        }

        let mut content = Vec::new();
        rw_info_file.read_to_end(&mut content).unwrap();

        // SAFETY:
        // The safety here is guaranteed here as no writes happens to this temp file
        unsafe {
            let mmaped_file = map_file(&flag_info).unwrap();
            assert_eq!(mmaped_file[..], content[..]);
        }
    }

    #[test]
    fn test_mapped_read_only_file() {
        let ro_val_file = copy_to_temp_file("./tests/flag.val", true).unwrap();
        let flag_val = ro_val_file.path().display().to_string();

        // SAFETY:
        // The safety here is guaranteed here as no writes happens to this temp file
        unsafe {
            let error = map_file(&flag_val).unwrap_err();
            assert_eq!(
                format!("{:?}", error),
                format!("MapFileFail(fail to map non read write storage file {})", flag_val)
            );
        }
    }
}
