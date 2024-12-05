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
use memmap2::Mmap;
use std::fs::File;

use crate::AconfigStorageError::{self, FileReadFail, MapFileFail, StorageFileNotFound};
use crate::StorageFileType;

/// Get the read only memory mapping of a storage file
///
/// # Safety
///
/// The memory mapped file may have undefined behavior if there are writes to this
/// file after being mapped. Ensure no writes can happen to this file while this
/// mapping stays alive.
pub unsafe fn map_file(file_path: &str) -> Result<Mmap, AconfigStorageError> {
    let file = File::open(file_path)
        .map_err(|errmsg| FileReadFail(anyhow!("Failed to open file {}: {}", file_path, errmsg)))?;
    unsafe {
        let mapped_file = Mmap::map(&file).map_err(|errmsg| {
            MapFileFail(anyhow!("fail to map storage file {}: {}", file_path, errmsg))
        })?;
        Ok(mapped_file)
    }
}

/// Get a mapped storage file given the container and file type
///
/// # Safety
///
/// The memory mapped file may have undefined behavior if there are writes to this
/// file after being mapped. Ensure no writes can happen to this file while this
/// mapping stays alive.
pub unsafe fn get_mapped_file(
    storage_dir: &str,
    container: &str,
    file_type: StorageFileType,
) -> Result<Mmap, AconfigStorageError> {
    let storage_file = match file_type {
        StorageFileType::PackageMap => {
            String::from(storage_dir) + "/maps/" + container + ".package.map"
        }
        StorageFileType::FlagMap => String::from(storage_dir) + "/maps/" + container + ".flag.map",
        StorageFileType::FlagVal => String::from(storage_dir) + "/boot/" + container + ".val",
        StorageFileType::FlagInfo => String::from(storage_dir) + "/boot/" + container + ".info",
    };
    if std::fs::metadata(&storage_file).is_err() {
        return Err(StorageFileNotFound(anyhow!("storage file {} does not exist", storage_file)));
    }
    unsafe { map_file(&storage_file) }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rand::Rng;
    use std::fs;
    use std::io::Read;

    fn map_and_verify(storage_dir: &str, file_type: StorageFileType, actual_file: &str) {
        let mut opened_file = File::open(actual_file).unwrap();
        let mut content = Vec::new();
        opened_file.read_to_end(&mut content).unwrap();
        let mmaped_file = unsafe { get_mapped_file(storage_dir, "mockup", file_type).unwrap() };
        assert_eq!(mmaped_file[..], content[..]);
    }

    fn create_test_storage_files() -> String {
        let mut rng = rand::thread_rng();
        let number: u32 = rng.gen();
        let storage_dir = String::from("/tmp/") + &number.to_string();
        if std::fs::metadata(&storage_dir).is_ok() {
            fs::remove_dir_all(&storage_dir).unwrap();
        }
        let maps_dir = storage_dir.clone() + "/maps";
        let boot_dir = storage_dir.clone() + "/boot";
        fs::create_dir(&storage_dir).unwrap();
        fs::create_dir(&maps_dir).unwrap();
        fs::create_dir(&boot_dir).unwrap();

        let package_map = storage_dir.clone() + "/maps/mockup.package.map";
        let flag_map = storage_dir.clone() + "/maps/mockup.flag.map";
        let flag_val = storage_dir.clone() + "/boot/mockup.val";
        let flag_info = storage_dir.clone() + "/boot/mockup.info";
        fs::copy("./tests/data/v1/package_v1.map", &package_map).unwrap();
        fs::copy("./tests/data/v1/flag_v1.map", &flag_map).unwrap();
        fs::copy("./tests/data/v1/flag_v1.val", &flag_val).unwrap();
        fs::copy("./tests/data/v1/flag_v1.info", &flag_info).unwrap();

        return storage_dir;
    }

    #[test]
    fn test_mapped_file_contents() {
        let storage_dir = create_test_storage_files();
        map_and_verify(&storage_dir, StorageFileType::PackageMap, "./tests/data/v1/package_v1.map");
        map_and_verify(&storage_dir, StorageFileType::FlagMap, "./tests/data/v1/flag_v1.map");
        map_and_verify(&storage_dir, StorageFileType::FlagVal, "./tests/data/v1/flag_v1.val");
        map_and_verify(&storage_dir, StorageFileType::FlagInfo, "./tests/data/v1/flag_v1.info");
    }
}
