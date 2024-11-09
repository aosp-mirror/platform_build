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

//! flag value query module defines the flag value file read from mapped bytes

use crate::AconfigStorageError;
use aconfig_storage_file::{
    flag_value::FlagValueHeader, read_u8_from_bytes, MAX_SUPPORTED_FILE_VERSION,
};
use anyhow::anyhow;

/// Query flag value
pub fn find_boolean_flag_value(buf: &[u8], flag_index: u32) -> Result<bool, AconfigStorageError> {
    let interpreted_header = FlagValueHeader::from_bytes(buf)?;
    if interpreted_header.version > MAX_SUPPORTED_FILE_VERSION {
        return Err(AconfigStorageError::HigherStorageFileVersion(anyhow!(
            "Cannot read storage file with a higher version of {} with lib version {}",
            interpreted_header.version,
            MAX_SUPPORTED_FILE_VERSION
        )));
    }

    // Find byte offset to the flag value, each boolean flag cost one byte to store
    let mut head = (interpreted_header.boolean_value_offset + flag_index) as usize;
    if head >= interpreted_header.file_size as usize {
        return Err(AconfigStorageError::InvalidStorageFileOffset(anyhow!(
            "Flag value offset goes beyond the end of the file."
        )));
    }

    let val = read_u8_from_bytes(buf, &mut head)?;
    Ok(val == 1)
}

#[cfg(test)]
mod tests {
    use super::*;
    use aconfig_storage_file::{test_utils::create_test_flag_value_list, DEFAULT_FILE_VERSION};

    #[test]
    // this test point locks down flag value query
    fn test_flag_value_query() {
        let flag_value_list = create_test_flag_value_list(DEFAULT_FILE_VERSION).into_bytes();
        let baseline: Vec<bool> = vec![false, true, true, false, true, true, true, true];
        for (offset, expected_value) in baseline.into_iter().enumerate() {
            let flag_value = find_boolean_flag_value(&flag_value_list[..], offset as u32).unwrap();
            assert_eq!(flag_value, expected_value);
        }
    }

    #[test]
    // this test point locks down query beyond the end of boolean section
    fn test_boolean_out_of_range() {
        let flag_value_list = create_test_flag_value_list(DEFAULT_FILE_VERSION).into_bytes();
        let error = find_boolean_flag_value(&flag_value_list[..], 8).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            "InvalidStorageFileOffset(Flag value offset goes beyond the end of the file.)"
        );
    }

    #[test]
    // this test point locks down query error when file has a higher version
    fn test_higher_version_storage_file() {
        let mut value_list = create_test_flag_value_list(DEFAULT_FILE_VERSION);
        value_list.header.version = MAX_SUPPORTED_FILE_VERSION + 1;
        let flag_value = value_list.into_bytes();
        let error = find_boolean_flag_value(&flag_value[..], 4).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            format!(
                "HigherStorageFileVersion(Cannot read storage file with a higher version of {} with lib version {})",
                MAX_SUPPORTED_FILE_VERSION + 1,
                MAX_SUPPORTED_FILE_VERSION
            )
        );
    }
}
