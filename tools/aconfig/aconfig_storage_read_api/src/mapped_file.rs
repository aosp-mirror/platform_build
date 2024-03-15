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

use std::fs::{self, File};
use std::io::{BufReader, Read};

use anyhow::anyhow;
use memmap2::Mmap;

use crate::AconfigStorageError::{
    self, FileReadFail, MapFileFail, ProtobufParseFail, StorageFileNotFound,
};
use crate::StorageFileType;
use aconfig_storage_file::protos::{
    storage_record_pb::try_from_binary_proto, ProtoStorageFileInfo, ProtoStorageFiles,
};

/// Find where storage files are stored for a particular container
fn find_container_storage_location(
    location_pb_file: &str,
    container: &str,
) -> Result<ProtoStorageFileInfo, AconfigStorageError> {
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
            return Ok(location_info.clone());
        }
    }
    Err(StorageFileNotFound(anyhow!("Storage file does not exist for {}", container)))
}

/// Verify the file is read only and then map it
fn verify_read_only_and_map(file_path: &str) -> Result<Mmap, AconfigStorageError> {
    // ensure file has read only permission
    let perms = fs::metadata(file_path).unwrap().permissions();
    if !perms.readonly() {
        return Err(MapFileFail(anyhow!("fail to map non read only storage file {}", file_path)));
    }

    let file = File::open(file_path)
        .map_err(|errmsg| FileReadFail(anyhow!("Failed to open file {}: {}", file_path, errmsg)))?;

    // SAFETY:
    //
    // Mmap constructors are unsafe as it would have undefined behaviors if the file
    // is modified after mapped (https://docs.rs/memmap2/latest/memmap2/struct.Mmap.html).
    //
    // We either have to make this api unsafe or ensure that the file will not be modified
    // which means it is read only. Here in the code, we check explicitly that the file
    // being mapped must only have read permission, otherwise, error out, thus making sure
    // it is safe.
    unsafe {
        let mapped_file = Mmap::map(&file).map_err(|errmsg| {
            MapFileFail(anyhow!("fail to map storage file {}: {}", file_path, errmsg))
        })?;
        Ok(mapped_file)
    }
}

/// Get a mapped storage file given the container and file type
pub fn get_mapped_file(
    location_pb_file: &str,
    container: &str,
    file_type: StorageFileType,
) -> Result<Mmap, AconfigStorageError> {
    let files_location = find_container_storage_location(location_pb_file, container)?;
    match file_type {
        StorageFileType::PackageMap => verify_read_only_and_map(files_location.package_map()),
        StorageFileType::FlagMap => verify_read_only_and_map(files_location.flag_map()),
        StorageFileType::FlagVal => verify_read_only_and_map(files_location.flag_val()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::copy_to_temp_file;
    use aconfig_storage_file::protos::storage_record_pb::write_proto_to_temp_file;
    use tempfile::NamedTempFile;

    #[test]
    fn test_find_storage_file_location() {
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
        let file_info = find_container_storage_location(&file_full_path, "system").unwrap();
        assert_eq!(file_info.version(), 0);
        assert_eq!(file_info.container(), "system");
        assert_eq!(file_info.package_map(), "/system/etc/package.map");
        assert_eq!(file_info.flag_map(), "/system/etc/flag.map");
        assert_eq!(file_info.flag_val(), "/metadata/aconfig/system.val");
        assert_eq!(file_info.timestamp(), 12345);

        let file_info = find_container_storage_location(&file_full_path, "product").unwrap();
        assert_eq!(file_info.version(), 1);
        assert_eq!(file_info.container(), "product");
        assert_eq!(file_info.package_map(), "/product/etc/package.map");
        assert_eq!(file_info.flag_map(), "/product/etc/flag.map");
        assert_eq!(file_info.flag_val(), "/metadata/aconfig/product.val");
        assert_eq!(file_info.timestamp(), 54321);

        let err = find_container_storage_location(&file_full_path, "vendor").unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "StorageFileNotFound(Storage file does not exist for vendor)"
        );
    }

    fn map_and_verify(location_pb_file: &str, file_type: StorageFileType, actual_file: &str) {
        let mut opened_file = File::open(actual_file).unwrap();
        let mut content = Vec::new();
        opened_file.read_to_end(&mut content).unwrap();

        let mmaped_file = get_mapped_file(location_pb_file, "system", file_type).unwrap();
        assert_eq!(mmaped_file[..], content[..]);
    }

    fn create_test_storage_files(read_only: bool) -> [NamedTempFile; 4] {
        let package_map = copy_to_temp_file("./tests/package.map", read_only).unwrap();
        let flag_map = copy_to_temp_file("./tests/flag.map", read_only).unwrap();
        let flag_val = copy_to_temp_file("./tests/package.map", read_only).unwrap();

        let text_proto = format!(
            r#"
files {{
    version: 0
    container: "system"
    package_map: "{}"
    flag_map: "{}"
    flag_val: "{}"
    timestamp: 12345
}}
"#,
            package_map.path().display(),
            flag_map.path().display(),
            flag_val.path().display()
        );
        let pb_file = write_proto_to_temp_file(&text_proto).unwrap();
        [package_map, flag_map, flag_val, pb_file]
    }

    #[test]
    fn test_mapped_file_contents() {
        let [package_map, flag_map, flag_val, pb_file] = create_test_storage_files(true);
        let pb_file_path = pb_file.path().display().to_string();
        map_and_verify(
            &pb_file_path,
            StorageFileType::PackageMap,
            &package_map.path().display().to_string(),
        );
        map_and_verify(
            &pb_file_path,
            StorageFileType::FlagMap,
            &flag_map.path().display().to_string(),
        );
        map_and_verify(
            &pb_file_path,
            StorageFileType::FlagVal,
            &flag_val.path().display().to_string(),
        );
    }

    #[test]
    fn test_map_non_read_only_file() {
        let [package_map, flag_map, flag_val, pb_file] = create_test_storage_files(false);
        let pb_file_path = pb_file.path().display().to_string();
        let error =
            get_mapped_file(&pb_file_path, "system", StorageFileType::PackageMap).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            format!(
                "MapFileFail(fail to map non read only storage file {})",
                package_map.path().display()
            )
        );
        let error = get_mapped_file(&pb_file_path, "system", StorageFileType::FlagMap).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            format!(
                "MapFileFail(fail to map non read only storage file {})",
                flag_map.path().display()
            )
        );
        let error = get_mapped_file(&pb_file_path, "system", StorageFileType::FlagVal).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            format!(
                "MapFileFail(fail to map non read only storage file {})",
                flag_val.path().display()
            )
        );
    }
}
