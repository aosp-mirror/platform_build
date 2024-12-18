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
    flag_info::FlagInfoHeader, read_u8_from_bytes, FlagValueType, MAX_SUPPORTED_FILE_VERSION,
};
use anyhow::anyhow;

/// Get flag attribute bitfield
pub fn find_flag_attribute(
    buf: &[u8],
    flag_type: FlagValueType,
    flag_index: u32,
) -> Result<u8, AconfigStorageError> {
    let interpreted_header = FlagInfoHeader::from_bytes(buf)?;
    if interpreted_header.version > MAX_SUPPORTED_FILE_VERSION {
        return Err(AconfigStorageError::HigherStorageFileVersion(anyhow!(
            "Cannot read storage file with a higher version of {} with lib version {}",
            interpreted_header.version,
            MAX_SUPPORTED_FILE_VERSION
        )));
    }

    // get byte offset to the flag info
    let mut head = match flag_type {
        FlagValueType::Boolean => (interpreted_header.boolean_flag_offset + flag_index) as usize,
    };

    if head >= interpreted_header.file_size as usize {
        return Err(AconfigStorageError::InvalidStorageFileOffset(anyhow!(
            "Flag info offset goes beyond the end of the file."
        )));
    }

    let val = read_u8_from_bytes(buf, &mut head)?;
    Ok(val)
}

#[cfg(test)]
mod tests {
    use super::*;
    use aconfig_storage_file::{
        test_utils::create_test_flag_info_list, FlagInfoBit, DEFAULT_FILE_VERSION,
    };

    #[test]
    // this test point locks down query if flag has server override
    fn test_is_flag_sticky() {
        let flag_info_list = create_test_flag_info_list(DEFAULT_FILE_VERSION).into_bytes();
        for offset in 0..8 {
            let attribute =
                find_flag_attribute(&flag_info_list[..], FlagValueType::Boolean, offset).unwrap();
            assert_eq!((attribute & FlagInfoBit::HasServerOverride as u8) != 0u8, false);
        }
    }

    #[test]
    // this test point locks down query if flag is readwrite
    fn test_is_flag_readwrite() {
        let flag_info_list = create_test_flag_info_list(DEFAULT_FILE_VERSION).into_bytes();
        let baseline: Vec<bool> = vec![true, false, true, true, false, false, false, true];
        for offset in 0..8 {
            let attribute =
                find_flag_attribute(&flag_info_list[..], FlagValueType::Boolean, offset).unwrap();
            assert_eq!(
                (attribute & FlagInfoBit::IsReadWrite as u8) != 0u8,
                baseline[offset as usize]
            );
        }
    }

    #[test]
    // this test point locks down query if flag has local override
    fn test_flag_has_override() {
        let flag_info_list = create_test_flag_info_list(DEFAULT_FILE_VERSION).into_bytes();
        for offset in 0..8 {
            let attribute =
                find_flag_attribute(&flag_info_list[..], FlagValueType::Boolean, offset).unwrap();
            assert_eq!((attribute & FlagInfoBit::HasLocalOverride as u8) != 0u8, false);
        }
    }

    #[test]
    // this test point locks down query beyond the end of boolean section
    fn test_boolean_out_of_range() {
        let flag_info_list = create_test_flag_info_list(DEFAULT_FILE_VERSION).into_bytes();
        let error =
            find_flag_attribute(&flag_info_list[..], FlagValueType::Boolean, 8).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            "InvalidStorageFileOffset(Flag info offset goes beyond the end of the file.)"
        );
    }

    #[test]
    // this test point locks down query error when file has a higher version
    fn test_higher_version_storage_file() {
        let mut info_list = create_test_flag_info_list(DEFAULT_FILE_VERSION);
        info_list.header.version = MAX_SUPPORTED_FILE_VERSION + 1;
        let flag_info = info_list.into_bytes();
        let error = find_flag_attribute(&flag_info[..], FlagValueType::Boolean, 4).unwrap_err();
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
