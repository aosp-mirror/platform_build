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

//! flag value update module defines the flag value file write to mapped bytes

use aconfig_storage_file::{AconfigStorageError, FlagValueHeader, FILE_VERSION};
use anyhow::anyhow;

/// Set flag value
pub fn update_boolean_flag_value(
    buf: &mut [u8],
    flag_index: u32,
    flag_value: bool,
) -> Result<usize, AconfigStorageError> {
    let interpreted_header = FlagValueHeader::from_bytes(buf)?;
    if interpreted_header.version > FILE_VERSION {
        return Err(AconfigStorageError::HigherStorageFileVersion(anyhow!(
            "Cannot write to storage file with a higher version of {} with lib version {}",
            interpreted_header.version,
            FILE_VERSION
        )));
    }

    // get byte offset to the flag
    let head = (interpreted_header.boolean_value_offset + flag_index) as usize;
    if head >= interpreted_header.file_size as usize {
        return Err(AconfigStorageError::InvalidStorageFileOffset(anyhow!(
            "Flag value offset goes beyond the end of the file."
        )));
    }

    buf[head] = u8::from(flag_value).to_le_bytes()[0];
    Ok(head)
}

#[cfg(test)]
mod tests {
    use super::*;
    use aconfig_storage_file::test_utils::create_test_flag_value_list;

    #[test]
    // this test point locks down flag value update
    fn test_boolean_flag_value_update() {
        let flag_value_list = create_test_flag_value_list();
        let value_offset = flag_value_list.header.boolean_value_offset;
        let mut content = flag_value_list.into_bytes();
        let true_byte = u8::from(true).to_le_bytes()[0];
        let false_byte = u8::from(false).to_le_bytes()[0];

        for i in 0..flag_value_list.header.num_flags {
            let offset = (value_offset + i) as usize;
            update_boolean_flag_value(&mut content, i, true).unwrap();
            assert_eq!(content[offset], true_byte);
            update_boolean_flag_value(&mut content, i, false).unwrap();
            assert_eq!(content[offset], false_byte);
        }
    }

    #[test]
    // this test point locks down update beyond the end of boolean section
    fn test_boolean_out_of_range() {
        let mut flag_value_list = create_test_flag_value_list().into_bytes();
        let error = update_boolean_flag_value(&mut flag_value_list[..], 8, true).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            "InvalidStorageFileOffset(Flag value offset goes beyond the end of the file.)"
        );
    }

    #[test]
    // this test point locks down query error when file has a higher version
    fn test_higher_version_storage_file() {
        let mut value_list = create_test_flag_value_list();
        value_list.header.version = FILE_VERSION + 1;
        let mut flag_value = value_list.into_bytes();
        let error = update_boolean_flag_value(&mut flag_value[..], 4, true).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            format!(
                "HigherStorageFileVersion(Cannot write to storage file with a higher version of {} with lib version {})",
                FILE_VERSION + 1,
                FILE_VERSION
            )
        );
    }
}
