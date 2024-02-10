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

use std::collections::HashMap;
use std::fs::File;
use std::io::{BufReader, Read};
use std::sync::{Arc, Mutex};

use anyhow::anyhow;
use memmap2::Mmap;
use once_cell::sync::Lazy;

use crate::protos::{
    storage_files::try_from_binary_proto, ProtoStorageFileInfo, ProtoStorageFiles,
};
use crate::AconfigStorageError::{
    self, FileReadFail, MapFileFail, ProtobufParseFail, StorageFileNotFound,
};
use crate::StorageFileSelection;

/// Cache for already mapped files
static ALL_MAPPED_FILES: Lazy<Mutex<HashMap<String, MappedStorageFileSet>>> = Lazy::new(|| {
    let mapped_files = HashMap::new();
    Mutex::new(mapped_files)
});

/// Mapped storage files for a particular container
#[derive(Debug)]
struct MappedStorageFileSet {
    package_map: Arc<Mmap>,
    flag_map: Arc<Mmap>,
    flag_val: Arc<Mmap>,
}

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
    let file = File::open(file_path)
        .map_err(|errmsg| FileReadFail(anyhow!("Failed to open file {}: {}", file_path, errmsg)))?;
    let metadata = file.metadata().map_err(|errmsg| {
        FileReadFail(anyhow!("Failed to find metadata for {}: {}", file_path, errmsg))
    })?;

    // ensure storage file is read only
    if !metadata.permissions().readonly() {
        return Err(MapFileFail(anyhow!("fail to map non read only storage file {}", file_path)));
    }

    // SAFETY:
    //
    // Mmap constructors are unsafe as it would have undefined behaviors if the file
    // is modified after mapped (https://docs.rs/memmap2/latest/memmap2/struct.Mmap.html).
    //
    // We either have to make this api unsafe or ensure that the file will not be modified
    // which means it is read only. Here in the code, we check explicitly that the file
    // being mapped must only have read permission, otherwise, error out, thus making sure
    // it is safe.
    //
    // We should remove this restriction if we need to support mmap non read only file in
    // the future (by making this api unsafe). But for now, all flags are boot stable, so
    // the boot flag file copy should be readonly.
    unsafe {
        let mapped_file = Mmap::map(&file).map_err(|errmsg| {
            MapFileFail(anyhow!("fail to map storage file {}: {}", file_path, errmsg))
        })?;
        Ok(mapped_file)
    }
}

/// Map all storage files for a particular container
fn map_container_storage_files(
    location_pb_file: &str,
    container: &str,
) -> Result<MappedStorageFileSet, AconfigStorageError> {
    let files_location = find_container_storage_location(location_pb_file, container)?;
    let package_map = Arc::new(verify_read_only_and_map(files_location.package_map())?);
    let flag_map = Arc::new(verify_read_only_and_map(files_location.flag_map())?);
    let flag_val = Arc::new(verify_read_only_and_map(files_location.flag_val())?);
    Ok(MappedStorageFileSet { package_map, flag_map, flag_val })
}

/// Get a mapped storage file given the container and file type
pub(crate) fn get_mapped_file(
    location_pb_file: &str,
    container: &str,
    file_selection: StorageFileSelection,
) -> Result<Arc<Mmap>, AconfigStorageError> {
    let mut all_mapped_files = ALL_MAPPED_FILES.lock().unwrap();
    match all_mapped_files.get(container) {
        Some(mapped_files) => Ok(match file_selection {
            StorageFileSelection::PackageMap => Arc::clone(&mapped_files.package_map),
            StorageFileSelection::FlagMap => Arc::clone(&mapped_files.flag_map),
            StorageFileSelection::FlagVal => Arc::clone(&mapped_files.flag_val),
        }),
        None => {
            let mapped_files = map_container_storage_files(location_pb_file, container)?;
            let file_ptr = match file_selection {
                StorageFileSelection::PackageMap => Arc::clone(&mapped_files.package_map),
                StorageFileSelection::FlagMap => Arc::clone(&mapped_files.flag_map),
                StorageFileSelection::FlagVal => Arc::clone(&mapped_files.flag_val),
            };
            all_mapped_files.insert(container.to_string(), mapped_files);
            Ok(file_ptr)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{write_storage_text_to_temp_file, TestStorageFileSet};

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
        let file = write_storage_text_to_temp_file(text_proto).unwrap();
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

    fn map_and_verify(
        location_pb_file: &str,
        file_selection: StorageFileSelection,
        actual_file: &str,
    ) {
        let mut opened_file = File::open(actual_file).unwrap();
        let mut content = Vec::new();
        opened_file.read_to_end(&mut content).unwrap();

        let mmaped_file = get_mapped_file(location_pb_file, "system", file_selection).unwrap();
        assert_eq!(mmaped_file[..], content[..]);
    }

    fn create_test_storage_files(read_only: bool) -> TestStorageFileSet {
        TestStorageFileSet::new(
            "./tests/package.map",
            "./tests/flag.map",
            "./tests/flag.val",
            read_only,
        )
        .unwrap()
    }

    #[test]
    fn test_mapped_file_contents() {
        let ro_files = create_test_storage_files(true);
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
            ro_files.package_map.name, ro_files.flag_map.name, ro_files.flag_val.name
        );

        let file = write_storage_text_to_temp_file(&text_proto).unwrap();
        let file_full_path = file.path().display().to_string();
        map_and_verify(
            &file_full_path,
            StorageFileSelection::PackageMap,
            &ro_files.package_map.name,
        );
        map_and_verify(&file_full_path, StorageFileSelection::FlagMap, &ro_files.flag_map.name);
        map_and_verify(&file_full_path, StorageFileSelection::FlagVal, &ro_files.flag_val.name);
    }

    #[test]
    fn test_map_non_read_only_file() {
        let ro_files = create_test_storage_files(true);
        let rw_files = create_test_storage_files(false);
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
            rw_files.package_map.name, ro_files.flag_map.name, ro_files.flag_val.name
        );

        let file = write_storage_text_to_temp_file(&text_proto).unwrap();
        let file_full_path = file.path().display().to_string();
        let error = map_container_storage_files(&file_full_path, "system").unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            format!(
                "MapFileFail(fail to map non read only storage file {})",
                rw_files.package_map.name
            )
        );

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
            ro_files.package_map.name, rw_files.flag_map.name, ro_files.flag_val.name
        );

        let file = write_storage_text_to_temp_file(&text_proto).unwrap();
        let file_full_path = file.path().display().to_string();
        let error = map_container_storage_files(&file_full_path, "system").unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            format!(
                "MapFileFail(fail to map non read only storage file {})",
                rw_files.flag_map.name
            )
        );

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
            ro_files.package_map.name, ro_files.flag_map.name, rw_files.flag_val.name
        );

        let file = write_storage_text_to_temp_file(&text_proto).unwrap();
        let file_full_path = file.path().display().to_string();
        let error = map_container_storage_files(&file_full_path, "system").unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            format!(
                "MapFileFail(fail to map non read only storage file {})",
                rw_files.flag_val.name
            )
        );
    }
}
