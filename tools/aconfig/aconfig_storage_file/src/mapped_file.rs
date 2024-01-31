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

use anyhow::{bail, ensure, Result};
use memmap2::Mmap;
use once_cell::sync::Lazy;

use crate::protos::{
    storage_files::try_from_binary_proto, ProtoStorageFileInfo, ProtoStorageFiles,
};
use crate::StorageFileSelection;

/// Cache for already mapped files
static ALL_MAPPED_FILES: Lazy<Mutex<HashMap<String, MappedStorageFileSet>>> =
    Lazy::new(|| {
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
) -> Result<ProtoStorageFileInfo> {
    let file = File::open(location_pb_file)?;
    let mut reader = BufReader::new(file);
    let mut bytes = Vec::new();
    reader.read_to_end(&mut bytes)?;

    let storage_locations: ProtoStorageFiles = try_from_binary_proto(&bytes)?;
    for location_info in storage_locations.files.iter() {
        if location_info.container() == container {
            return Ok(location_info.clone());
        }
    }
    bail!("Storage file does not exist for {}", container)
}

/// Map all storage files for a particular container
fn map_container_storage_files(
    location_pb_file: &str,
    container: &str,
) -> Result<MappedStorageFileSet> {
    let files_location = find_container_storage_location(location_pb_file, container)?;

    let package_map_file = File::open(files_location.package_map())?;
    let metadata = package_map_file.metadata()?;
    ensure!(
        metadata.permissions().readonly(),
        "Cannot mmap file {} as it is not read only",
        files_location.package_map()
    );
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
    let package_map = Arc::new(unsafe { Mmap::map(&package_map_file)? });

    let flag_map_file = File::open(files_location.flag_map())?;
    let metadata = flag_map_file.metadata()?;
    ensure!(
        metadata.permissions().readonly(),
        "Cannot mmap file {} as it is not read only",
        files_location.flag_map()
    );
    // SAFETY: Refer to the previous safety statement
    let flag_map = Arc::new(unsafe { Mmap::map(&flag_map_file)? });

    let flag_val_file = File::open(files_location.flag_val())?;
    let metadata = flag_val_file.metadata()?;
    ensure!(
        metadata.permissions().readonly(),
        "Cannot mmap file {} as it is not read only",
        files_location.flag_val()
    );
    // SAFETY: Refer to the previous safety statement
    let flag_val = Arc::new(unsafe { Mmap::map(&flag_val_file)? });

    Ok(MappedStorageFileSet { package_map, flag_map, flag_val })
}

/// Get a mapped storage file given the container and file type
pub fn get_mapped_file(
    location_pb_file: &str,
    container: &str,
    file_selection: StorageFileSelection,
) -> Result<Arc<Mmap>> {
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
    use crate::test_utils::get_binary_storage_proto_bytes;
    use std::io::Write;

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
        let binary_proto_bytes = get_binary_storage_proto_bytes(text_proto).unwrap();
        let file_full_path = "./tests/temp_location_file_1.pb";
        let mut file = File::create(&file_full_path).unwrap();
        file.write_all(&binary_proto_bytes).unwrap();

        let file_info = find_container_storage_location(file_full_path, "system").unwrap();
        assert_eq!(file_info.version(), 0);
        assert_eq!(file_info.container(), "system");
        assert_eq!(file_info.package_map(), "/system/etc/package.map");
        assert_eq!(file_info.flag_map(), "/system/etc/flag.map");
        assert_eq!(file_info.flag_val(), "/metadata/aconfig/system.val");
        assert_eq!(file_info.timestamp(), 12345);

        let file_info = find_container_storage_location(file_full_path, "product").unwrap();
        assert_eq!(file_info.version(), 1);
        assert_eq!(file_info.container(), "product");
        assert_eq!(file_info.package_map(), "/product/etc/package.map");
        assert_eq!(file_info.flag_map(), "/product/etc/flag.map");
        assert_eq!(file_info.flag_val(), "/metadata/aconfig/product.val");
        assert_eq!(file_info.timestamp(), 54321);

        let err = find_container_storage_location(file_full_path, "vendor").unwrap_err();
        assert_eq!(format!("{:?}", err), "Storage file does not exist for vendor");
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

    #[test]
    fn test_mapped_file_contents() {
        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: "./tests/package.map"
    flag_map: "./tests/flag.map"
    flag_val: "./tests/flag.val"
    timestamp: 12345
}
"#;
        let binary_proto_bytes = get_binary_storage_proto_bytes(text_proto).unwrap();
        let location_file_full_path = "./tests/temp_location_file_2.pb";
        let mut file = File::create(&location_file_full_path).unwrap();
        file.write_all(&binary_proto_bytes).unwrap();

        map_and_verify(
            location_file_full_path,
            StorageFileSelection::PackageMap,
            "./tests/package.map",
        );

        map_and_verify(
            location_file_full_path,
            StorageFileSelection::FlagMap,
            "./tests/flag.map");

        map_and_verify(
            location_file_full_path,
            StorageFileSelection::FlagVal,
            "./tests/flag.val");
    }

    #[test]
    fn test_map_non_read_only_file() {
        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: "./tests/rw.package.map"
    flag_map: "./tests/rw.flag.map"
    flag_val: "./tests/rw.flag.val"
    timestamp: 12345
}
"#;
        let binary_proto_bytes = get_binary_storage_proto_bytes(text_proto).unwrap();
        let location_file_full_path = "./tests/temp_location_file_3.pb";
        let mut file = File::create(&location_file_full_path).unwrap();
        file.write_all(&binary_proto_bytes).unwrap();

        let error = map_container_storage_files(
            location_file_full_path,
            "system",
        ).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            "Cannot mmap file ./tests/rw.package.map as it is not read only"
        );

        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: "./tests/package.map"
    flag_map: "./tests/rw.flag.map"
    flag_val: "./tests/rw.flag.val"
    timestamp: 12345
}
"#;
        let binary_proto_bytes = get_binary_storage_proto_bytes(text_proto).unwrap();
        let location_file_full_path = "./tests/temp_location_file_3.pb";
        let mut file = File::create(&location_file_full_path).unwrap();
        file.write_all(&binary_proto_bytes).unwrap();

        let error = map_container_storage_files(
            location_file_full_path,
            "system",
        ).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            "Cannot mmap file ./tests/rw.flag.map as it is not read only"
        );

        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: "./tests/package.map"
    flag_map: "./tests/flag.map"
    flag_val: "./tests/rw.flag.val"
    timestamp: 12345
}
"#;
        let binary_proto_bytes = get_binary_storage_proto_bytes(text_proto).unwrap();
        let location_file_full_path = "./tests/temp_location_file_3.pb";
        let mut file = File::create(&location_file_full_path).unwrap();
        file.write_all(&binary_proto_bytes).unwrap();

        let error = map_container_storage_files(
            location_file_full_path,
            "system",
        ).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            "Cannot mmap file ./tests/rw.flag.val as it is not read only"
        );
    }
}
