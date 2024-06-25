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

//! `aconfig_storage_write_api` is a crate that defines write apis to update flag value
//! in storage file. It provides one api to interface with storage files.

pub mod flag_info_update;
pub mod flag_value_update;
pub mod mapped_file;

#[cfg(test)]
mod test_utils;

use aconfig_storage_file::{
    AconfigStorageError, FlagInfoHeader, FlagInfoList, FlagInfoNode, FlagTable, FlagValueType,
    PackageTable, StorageFileType, StoredFlagType, FILE_VERSION,
};

use anyhow::anyhow;
use memmap2::MmapMut;
use std::fs::File;
use std::io::{Read, Write};

/// Get read write mapped storage files.
///
/// \input file_path: path to the storage file
///
/// # Safety
///
/// The memory mapped file may have undefined behavior if there are writes to this
/// file not thru this memory mapped file or there are concurrent writes to this
/// memory mapped file. Ensure all writes to the underlying file are thru this memory
/// mapped file and there are no concurrent writes.
pub unsafe fn map_mutable_storage_file(file_path: &str) -> Result<MmapMut, AconfigStorageError> {
    crate::mapped_file::map_file(file_path)
}

/// Set boolean flag value thru mapped file and flush the change to file
///
/// \input mapped_file: the mapped flag value file
/// \input index: flag index
/// \input value: updated flag value
/// \return a result of ()
///
pub fn set_boolean_flag_value(
    file: &mut MmapMut,
    index: u32,
    value: bool,
) -> Result<(), AconfigStorageError> {
    crate::flag_value_update::update_boolean_flag_value(file, index, value)?;
    file.flush().map_err(|errmsg| {
        AconfigStorageError::MapFlushFail(anyhow!("fail to flush storage file: {}", errmsg))
    })
}

/// Set if flag is has server override thru mapped file and flush the change to file
///
/// \input mapped_file: the mapped flag info file
/// \input index: flag index
/// \input value: updated flag has server override value
/// \return a result of ()
///
pub fn set_flag_has_server_override(
    file: &mut MmapMut,
    flag_type: FlagValueType,
    index: u32,
    value: bool,
) -> Result<(), AconfigStorageError> {
    crate::flag_info_update::update_flag_has_server_override(file, flag_type, index, value)?;
    file.flush().map_err(|errmsg| {
        AconfigStorageError::MapFlushFail(anyhow!("fail to flush storage file: {}", errmsg))
    })
}

/// Set if flag has local override thru mapped file and flush the change to file
///
/// \input mapped_file: the mapped flag info file
/// \input index: flag index
/// \input value: updated flag has local override value
/// \return a result of ()
///
pub fn set_flag_has_local_override(
    file: &mut MmapMut,
    flag_type: FlagValueType,
    index: u32,
    value: bool,
) -> Result<(), AconfigStorageError> {
    crate::flag_info_update::update_flag_has_local_override(file, flag_type, index, value)?;
    file.flush().map_err(|errmsg| {
        AconfigStorageError::MapFlushFail(anyhow!("fail to flush storage file: {}", errmsg))
    })
}

/// Read in storage file as bytes
fn read_file_to_bytes(file_path: &str) -> Result<Vec<u8>, AconfigStorageError> {
    let mut file = File::open(file_path).map_err(|errmsg| {
        AconfigStorageError::FileReadFail(anyhow!("Failed to open file {}: {}", file_path, errmsg))
    })?;
    let mut buffer = Vec::new();
    file.read_to_end(&mut buffer).map_err(|errmsg| {
        AconfigStorageError::FileReadFail(anyhow!(
            "Failed to read bytes from file {}: {}",
            file_path,
            errmsg
        ))
    })?;
    Ok(buffer)
}

/// Create flag info file given package map file and flag map file
/// \input package_map: package map file
/// \input flag_map: flag map file
/// \output flag_info_out: created flag info file
pub fn create_flag_info(
    package_map: &str,
    flag_map: &str,
    flag_info_out: &str,
) -> Result<(), AconfigStorageError> {
    let package_table = PackageTable::from_bytes(&read_file_to_bytes(package_map)?)?;
    let flag_table = FlagTable::from_bytes(&read_file_to_bytes(flag_map)?)?;

    if package_table.header.container != flag_table.header.container {
        return Err(AconfigStorageError::FileCreationFail(anyhow!(
            "container for package map {} and flag map {} does not match",
            package_table.header.container,
            flag_table.header.container,
        )));
    }

    let mut package_start_index = vec![0; package_table.header.num_packages as usize];
    for node in package_table.nodes.iter() {
        package_start_index[node.package_id as usize] = node.boolean_start_index;
    }

    let mut is_flag_rw = vec![false; flag_table.header.num_flags as usize];
    for node in flag_table.nodes.iter() {
        let flag_index = package_start_index[node.package_id as usize] + node.flag_index as u32;
        is_flag_rw[flag_index as usize] = node.flag_type == StoredFlagType::ReadWriteBoolean;
    }

    let mut list = FlagInfoList {
        header: FlagInfoHeader {
            version: FILE_VERSION,
            container: flag_table.header.container,
            file_type: StorageFileType::FlagInfo as u8,
            file_size: 0,
            num_flags: flag_table.header.num_flags,
            boolean_flag_offset: 0,
        },
        nodes: is_flag_rw.iter().map(|&rw| FlagInfoNode::create(rw)).collect(),
    };

    list.header.boolean_flag_offset = list.header.into_bytes().len() as u32;
    list.header.file_size = list.into_bytes().len() as u32;

    let mut file = File::create(flag_info_out).map_err(|errmsg| {
        AconfigStorageError::FileCreationFail(anyhow!(
            "fail to create file {}: {}",
            flag_info_out,
            errmsg
        ))
    })?;
    file.write_all(&list.into_bytes()).map_err(|errmsg| {
        AconfigStorageError::FileCreationFail(anyhow!(
            "fail to write to file {}: {}",
            flag_info_out,
            errmsg
        ))
    })?;

    Ok(())
}

// *************************************** //
// CC INTERLOP
// *************************************** //

// Exported rust data structure and methods, c++ code will be generated
#[cxx::bridge]
mod ffi {
    // Flag value update return for cc interlop
    pub struct BooleanFlagValueUpdateCXX {
        pub update_success: bool,
        pub offset: usize,
        pub error_message: String,
    }

    // Flag has server override update return for cc interlop
    pub struct FlagHasServerOverrideUpdateCXX {
        pub update_success: bool,
        pub offset: usize,
        pub error_message: String,
    }

    // Flag has local override update return for cc interlop
    pub struct FlagHasLocalOverrideUpdateCXX {
        pub update_success: bool,
        pub offset: usize,
        pub error_message: String,
    }

    // Flag info file creation return for cc interlop
    pub struct FlagInfoCreationCXX {
        pub success: bool,
        pub error_message: String,
    }

    // Rust export to c++
    extern "Rust" {
        pub fn update_boolean_flag_value_cxx(
            file: &mut [u8],
            offset: u32,
            value: bool,
        ) -> BooleanFlagValueUpdateCXX;

        pub fn update_flag_has_server_override_cxx(
            file: &mut [u8],
            flag_type: u16,
            offset: u32,
            value: bool,
        ) -> FlagHasServerOverrideUpdateCXX;

        pub fn update_flag_has_local_override_cxx(
            file: &mut [u8],
            flag_type: u16,
            offset: u32,
            value: bool,
        ) -> FlagHasLocalOverrideUpdateCXX;

        pub fn create_flag_info_cxx(
            package_map: &str,
            flag_map: &str,
            flag_info_out: &str,
        ) -> FlagInfoCreationCXX;
    }
}

pub(crate) fn update_boolean_flag_value_cxx(
    file: &mut [u8],
    offset: u32,
    value: bool,
) -> ffi::BooleanFlagValueUpdateCXX {
    match crate::flag_value_update::update_boolean_flag_value(file, offset, value) {
        Ok(head) => ffi::BooleanFlagValueUpdateCXX {
            update_success: true,
            offset: head,
            error_message: String::from(""),
        },
        Err(errmsg) => ffi::BooleanFlagValueUpdateCXX {
            update_success: false,
            offset: usize::MAX,
            error_message: format!("{:?}", errmsg),
        },
    }
}

pub(crate) fn update_flag_has_server_override_cxx(
    file: &mut [u8],
    flag_type: u16,
    offset: u32,
    value: bool,
) -> ffi::FlagHasServerOverrideUpdateCXX {
    match FlagValueType::try_from(flag_type) {
        Ok(value_type) => {
            match crate::flag_info_update::update_flag_has_server_override(
                file, value_type, offset, value,
            ) {
                Ok(head) => ffi::FlagHasServerOverrideUpdateCXX {
                    update_success: true,
                    offset: head,
                    error_message: String::from(""),
                },
                Err(errmsg) => ffi::FlagHasServerOverrideUpdateCXX {
                    update_success: false,
                    offset: usize::MAX,
                    error_message: format!("{:?}", errmsg),
                },
            }
        }
        Err(errmsg) => ffi::FlagHasServerOverrideUpdateCXX {
            update_success: false,
            offset: usize::MAX,
            error_message: format!("{:?}", errmsg),
        },
    }
}

pub(crate) fn update_flag_has_local_override_cxx(
    file: &mut [u8],
    flag_type: u16,
    offset: u32,
    value: bool,
) -> ffi::FlagHasLocalOverrideUpdateCXX {
    match FlagValueType::try_from(flag_type) {
        Ok(value_type) => {
            match crate::flag_info_update::update_flag_has_local_override(
                file, value_type, offset, value,
            ) {
                Ok(head) => ffi::FlagHasLocalOverrideUpdateCXX {
                    update_success: true,
                    offset: head,
                    error_message: String::from(""),
                },
                Err(errmsg) => ffi::FlagHasLocalOverrideUpdateCXX {
                    update_success: false,
                    offset: usize::MAX,
                    error_message: format!("{:?}", errmsg),
                },
            }
        }
        Err(errmsg) => ffi::FlagHasLocalOverrideUpdateCXX {
            update_success: false,
            offset: usize::MAX,
            error_message: format!("{:?}", errmsg),
        },
    }
}

/// Create flag info file cc interlop
pub(crate) fn create_flag_info_cxx(
    package_map: &str,
    flag_map: &str,
    flag_info_out: &str,
) -> ffi::FlagInfoCreationCXX {
    match create_flag_info(package_map, flag_map, flag_info_out) {
        Ok(()) => ffi::FlagInfoCreationCXX { success: true, error_message: String::from("") },
        Err(errmsg) => {
            ffi::FlagInfoCreationCXX { success: false, error_message: format!("{:?}", errmsg) }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::copy_to_temp_file;
    use aconfig_storage_file::test_utils::{
        create_test_flag_info_list, create_test_flag_table, create_test_package_table,
        write_bytes_to_temp_file,
    };
    use aconfig_storage_file::FlagInfoBit;
    use aconfig_storage_read_api::flag_info_query::find_flag_attribute;
    use aconfig_storage_read_api::flag_value_query::find_boolean_flag_value;
    use std::fs::File;
    use std::io::Read;
    use tempfile::NamedTempFile;

    fn get_boolean_flag_value_at_offset(file: &str, offset: u32) -> bool {
        let mut f = File::open(&file).unwrap();
        let mut bytes = Vec::new();
        f.read_to_end(&mut bytes).unwrap();
        find_boolean_flag_value(&bytes, offset).unwrap()
    }

    #[test]
    fn test_set_boolean_flag_value() {
        let flag_value_file = copy_to_temp_file("./tests/flag.val", false).unwrap();
        let flag_value_path = flag_value_file.path().display().to_string();

        // SAFETY:
        // The safety here is guaranteed as only this single threaded test process will
        // write to this file
        unsafe {
            let mut file = map_mutable_storage_file(&flag_value_path).unwrap();
            for i in 0..8 {
                set_boolean_flag_value(&mut file, i, true).unwrap();
                let value = get_boolean_flag_value_at_offset(&flag_value_path, i);
                assert_eq!(value, true);

                set_boolean_flag_value(&mut file, i, false).unwrap();
                let value = get_boolean_flag_value_at_offset(&flag_value_path, i);
                assert_eq!(value, false);
            }
        }
    }

    fn get_flag_attribute_at_offset(file: &str, value_type: FlagValueType, offset: u32) -> u8 {
        let mut f = File::open(&file).unwrap();
        let mut bytes = Vec::new();
        f.read_to_end(&mut bytes).unwrap();
        find_flag_attribute(&bytes, value_type, offset).unwrap()
    }

    #[test]
    fn test_set_flag_has_server_override() {
        let flag_info_file = copy_to_temp_file("./tests/flag.info", false).unwrap();
        let flag_info_path = flag_info_file.path().display().to_string();

        // SAFETY:
        // The safety here is guaranteed as only this single threaded test process will
        // write to this file
        unsafe {
            let mut file = map_mutable_storage_file(&flag_info_path).unwrap();
            for i in 0..8 {
                set_flag_has_server_override(&mut file, FlagValueType::Boolean, i, true).unwrap();
                let attribute =
                    get_flag_attribute_at_offset(&flag_info_path, FlagValueType::Boolean, i);
                assert!((attribute & (FlagInfoBit::HasServerOverride as u8)) != 0);
                set_flag_has_server_override(&mut file, FlagValueType::Boolean, i, false).unwrap();
                let attribute =
                    get_flag_attribute_at_offset(&flag_info_path, FlagValueType::Boolean, i);
                assert!((attribute & (FlagInfoBit::HasServerOverride as u8)) == 0);
            }
        }
    }

    #[test]
    fn test_set_flag_has_local_override() {
        let flag_info_file = copy_to_temp_file("./tests/flag.info", false).unwrap();
        let flag_info_path = flag_info_file.path().display().to_string();

        // SAFETY:
        // The safety here is guaranteed as only this single threaded test process will
        // write to this file
        unsafe {
            let mut file = map_mutable_storage_file(&flag_info_path).unwrap();
            for i in 0..8 {
                set_flag_has_local_override(&mut file, FlagValueType::Boolean, i, true).unwrap();
                let attribute =
                    get_flag_attribute_at_offset(&flag_info_path, FlagValueType::Boolean, i);
                assert!((attribute & (FlagInfoBit::HasLocalOverride as u8)) != 0);
                set_flag_has_local_override(&mut file, FlagValueType::Boolean, i, false).unwrap();
                let attribute =
                    get_flag_attribute_at_offset(&flag_info_path, FlagValueType::Boolean, i);
                assert!((attribute & (FlagInfoBit::HasLocalOverride as u8)) == 0);
            }
        }
    }

    fn create_empty_temp_file() -> Result<NamedTempFile, AconfigStorageError> {
        let file = NamedTempFile::new().map_err(|_| {
            AconfigStorageError::FileCreationFail(anyhow!("Failed to create temp file"))
        })?;
        Ok(file)
    }

    #[test]
    // this test point locks down the flag info creation
    fn test_create_flag_info() {
        let package_table =
            write_bytes_to_temp_file(&create_test_package_table().into_bytes()).unwrap();
        let flag_table = write_bytes_to_temp_file(&create_test_flag_table().into_bytes()).unwrap();
        let flag_info = create_empty_temp_file().unwrap();

        let package_table_path = package_table.path().display().to_string();
        let flag_table_path = flag_table.path().display().to_string();
        let flag_info_path = flag_info.path().display().to_string();

        assert!(create_flag_info(&package_table_path, &flag_table_path, &flag_info_path).is_ok());

        let flag_info =
            FlagInfoList::from_bytes(&read_file_to_bytes(&flag_info_path).unwrap()).unwrap();
        let expected_flag_info = create_test_flag_info_list();
        assert_eq!(flag_info, expected_flag_info);
    }
}
