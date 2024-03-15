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

use std::fs::{self, File, OpenOptions};
use std::io::{BufReader, Read};

use anyhow::anyhow;
use memmap2::MmapMut;

use aconfig_storage_file::protos::{storage_record_pb::try_from_binary_proto, ProtoStorageFiles};
use aconfig_storage_file::AconfigStorageError::{
    self, FileReadFail, MapFileFail, ProtobufParseFail, StorageFileNotFound,
};

/// Find where persistent storage value file is for a particular container
fn find_persist_flag_value_file(
    location_pb_file: &str,
    container: &str,
) -> Result<String, AconfigStorageError> {
    let file = File::open(location_pb_file).map_err(|errmsg| {
        FileReadFail(anyhow!("Failed to open file {}: {}", location_pb_file, errmsg))
    })?;
    let mut reader = BufReader::new(file);
    let mut bytes = Vec::new();
    reader.read_to_end(&mut bytes).map_err(|errmsg| {
        FileReadFail(anyhow!("Failed to read file {}: {}", location_pb_file, errmsg))
    })?;
    let storage_locations: ProtoStorageFiles = try_from_binary_proto(&bytes).map_err(|errmsg| {
        ProtobufParseFail(anyhow!(
            "Failed to parse storage location pb file {}: {}",
            location_pb_file,
            errmsg
        ))
    })?;
    for location_info in storage_locations.files.iter() {
        if location_info.container() == container {
            return Ok(location_info.flag_val().to_string());
        }
    }
    Err(StorageFileNotFound(anyhow!("Persistent flag value file does not exist for {}", container)))
}

/// Get a mapped storage file given the container and file type
///
/// # Safety
///
/// The memory mapped file may have undefined behavior if there are writes to this
/// file not thru this memory mapped file or there are concurrent writes to this
/// memory mapped file. Ensure all writes to the underlying file are thru this memory
/// mapped file and there are no concurrent writes.
pub unsafe fn get_mapped_file(
    location_pb_file: &str,
    container: &str,
) -> Result<MmapMut, AconfigStorageError> {
    let file_path = find_persist_flag_value_file(location_pb_file, container)?;

    // make sure file has read write permission
    let perms = fs::metadata(&file_path).unwrap().permissions();
    if perms.readonly() {
        return Err(MapFileFail(anyhow!("fail to map non read write storage file {}", file_path)));
    }

    let file =
        OpenOptions::new().read(true).write(true).open(&file_path).map_err(|errmsg| {
            FileReadFail(anyhow!("Failed to open file {}: {}", file_path, errmsg))
        })?;

    unsafe {
        MmapMut::map_mut(&file).map_err(|errmsg| {
            MapFileFail(anyhow!("fail to map storage file {}: {}", file_path, errmsg))
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::copy_to_temp_file;
    use aconfig_storage_file::protos::storage_record_pb::write_proto_to_temp_file;

    #[test]
    fn test_find_persist_flag_value_file_location() {
        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: "/system/etc/package.map"
    flag_map: "/system/etc/flag.map"
    flag_val: "/metadata/aconfig/system.val"
    timestamp: 12345
}
files {
    version: 1
    container: "product"
    package_map: "/product/etc/package.map"
    flag_map: "/product/etc/flag.map"
    flag_val: "/metadata/aconfig/product.val"
    timestamp: 54321
}
"#;
        let file = write_proto_to_temp_file(&text_proto).unwrap();
        let file_full_path = file.path().display().to_string();
        let flag_value_file = find_persist_flag_value_file(&file_full_path, "system").unwrap();
        assert_eq!(flag_value_file, "/metadata/aconfig/system.val");
        let flag_value_file = find_persist_flag_value_file(&file_full_path, "product").unwrap();
        assert_eq!(flag_value_file, "/metadata/aconfig/product.val");
        let err = find_persist_flag_value_file(&file_full_path, "vendor").unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "StorageFileNotFound(Persistent flag value file does not exist for vendor)"
        );
    }

    #[test]
    fn test_mapped_file_contents() {
        let mut rw_file = copy_to_temp_file("./tests/flag.val", false).unwrap();
        let text_proto = format!(
            r#"
files {{
    version: 0
    container: "system"
    package_map: "some_package.map"
    flag_map: "some_flag.map"
    flag_val: "{}"
    timestamp: 12345
}}
"#,
            rw_file.path().display().to_string()
        );
        let storage_record_file = write_proto_to_temp_file(&text_proto).unwrap();
        let storage_record_file_path = storage_record_file.path().display().to_string();

        let mut content = Vec::new();
        rw_file.read_to_end(&mut content).unwrap();

        // SAFETY:
        // The safety here is guaranteed here as no writes happens to this temp file
        unsafe {
            let mmaped_file = get_mapped_file(&storage_record_file_path, "system").unwrap();
            assert_eq!(mmaped_file[..], content[..]);
        }
    }

    #[test]
    fn test_mapped_read_only_file() {
        let ro_file = copy_to_temp_file("./tests/flag.val", true).unwrap();
        let text_proto = format!(
            r#"
files {{
    version: 0
    container: "system"
    package_map: "some_package.map"
    flag_map: "some_flag.map"
    flag_val: "{}"
    timestamp: 12345
}}
"#,
            ro_file.path().display().to_string()
        );
        let storage_record_file = write_proto_to_temp_file(&text_proto).unwrap();
        let storage_record_file_path = storage_record_file.path().display().to_string();

        // SAFETY:
        // The safety here is guaranteed here as no writes happens to this temp file
        unsafe {
            let error = get_mapped_file(&storage_record_file_path, "system").unwrap_err();
            assert_eq!(
                format!("{:?}", error),
                format!(
                    "MapFileFail(fail to map non read write storage file {})",
                    ro_file.path().display().to_string()
                )
            );
        }
    }
}
