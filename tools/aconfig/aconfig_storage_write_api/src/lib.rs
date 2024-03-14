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

pub mod flag_value_update;
pub mod mapped_file;

#[cfg(test)]
mod test_utils;

use aconfig_storage_file::AconfigStorageError;

use anyhow::anyhow;
use memmap2::MmapMut;

/// Storage file location pb file
pub const STORAGE_LOCATION_FILE: &str = "/metadata/aconfig/persistent_storage_file_records.pb";

/// Get mmaped flag value file given the container name
///
/// \input container: the flag package container
/// \return a result of mapped file
///
///
/// # Safety
///
/// The memory mapped file may have undefined behavior if there are writes to this
/// file not thru this memory mapped file or there are concurrent writes to this
/// memory mapped file. Ensure all writes to the underlying file are thru this memory
/// mapped file and there are no concurrent writes.
pub unsafe fn get_mapped_flag_value_file(container: &str) -> Result<MmapMut, AconfigStorageError> {
    unsafe { crate::mapped_file::get_mapped_file(STORAGE_LOCATION_FILE, container) }
}

/// Set boolean flag value thru mapped file and flush the change to file
///
/// \input mapped_file: the mapped flag value file
/// \input offset: flag value offset
/// \input value: updated flag value
/// \return a result of ()
///
pub fn set_boolean_flag_value(
    file: &mut MmapMut,
    offset: u32,
    value: bool,
) -> Result<(), AconfigStorageError> {
    crate::flag_value_update::update_boolean_flag_value(file, offset, value)?;
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
        pub error_message: String,
    }

    // Rust export to c++
    extern "Rust" {
        pub fn update_boolean_flag_value_cxx(
            file: &mut [u8],
            offset: u32,
            value: bool,
        ) -> BooleanFlagValueUpdateCXX;
    }
}

pub(crate) fn update_boolean_flag_value_cxx(
    file: &mut [u8],
    offset: u32,
    value: bool,
) -> ffi::BooleanFlagValueUpdateCXX {
    match crate::flag_value_update::update_boolean_flag_value(file, offset, value) {
        Ok(()) => {
            ffi::BooleanFlagValueUpdateCXX { update_success: true, error_message: String::from("") }
        }
        Err(errmsg) => ffi::BooleanFlagValueUpdateCXX {
            update_success: false,
            error_message: format!("{:?}", errmsg),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::copy_to_temp_file;
    use aconfig_storage_file::protos::storage_record_pb::write_proto_to_temp_file;
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
            flag_value_path
        );
        let record_pb_file = write_proto_to_temp_file(&text_proto).unwrap();
        let record_pb_path = record_pb_file.path().display().to_string();

        // SAFETY:
        // The safety here is guaranteed as only this single threaded test process will
        // write to this file
        unsafe {
            let mut file = crate::mapped_file::get_mapped_file(&record_pb_path, "system").unwrap();
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
}
