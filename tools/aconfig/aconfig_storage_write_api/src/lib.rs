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

use aconfig_storage_file::{AconfigStorageError, FlagValueType};

use anyhow::anyhow;
use memmap2::MmapMut;

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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::copy_to_temp_file;
    use aconfig_storage_file::FlagInfoBit;
    use aconfig_storage_read_api::flag_info_query::find_flag_attribute;
    use aconfig_storage_read_api::flag_value_query::find_boolean_flag_value;
    use std::fs::File;
    use std::io::Read;

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
}
