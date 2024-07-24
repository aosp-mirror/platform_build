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

//! flag info update module defines the flag info file write to mapped bytes

use aconfig_storage_file::{
    read_u8_from_bytes, AconfigStorageError, FlagInfoBit, FlagInfoHeader, FlagValueType,
    FILE_VERSION,
};
use anyhow::anyhow;

fn get_flag_info_offset(
    buf: &mut [u8],
    flag_type: FlagValueType,
    flag_index: u32,
) -> Result<usize, AconfigStorageError> {
    let interpreted_header = FlagInfoHeader::from_bytes(buf)?;
    if interpreted_header.version > FILE_VERSION {
        return Err(AconfigStorageError::HigherStorageFileVersion(anyhow!(
            "Cannot write to storage file with a higher version of {} with lib version {}",
            interpreted_header.version,
            FILE_VERSION
        )));
    }

    // get byte offset to the flag info
    let head = match flag_type {
        FlagValueType::Boolean => (interpreted_header.boolean_flag_offset + flag_index) as usize,
    };

    if head >= interpreted_header.file_size as usize {
        return Err(AconfigStorageError::InvalidStorageFileOffset(anyhow!(
            "Flag value offset goes beyond the end of the file."
        )));
    }

    Ok(head)
}

fn get_flag_attribute_and_offset(
    buf: &mut [u8],
    flag_type: FlagValueType,
    flag_index: u32,
) -> Result<(u8, usize), AconfigStorageError> {
    let head = get_flag_info_offset(buf, flag_type, flag_index)?;
    let mut pos = head;
    let attribute = read_u8_from_bytes(buf, &mut pos)?;
    Ok((attribute, head))
}

/// Set if flag has server override
pub fn update_flag_has_server_override(
    buf: &mut [u8],
    flag_type: FlagValueType,
    flag_index: u32,
    value: bool,
) -> Result<usize, AconfigStorageError> {
    let (attribute, head) = get_flag_attribute_and_offset(buf, flag_type, flag_index)?;
    let has_override = (attribute & (FlagInfoBit::HasServerOverride as u8)) != 0;
    if has_override != value {
        buf[head] = (attribute ^ FlagInfoBit::HasServerOverride as u8).to_le_bytes()[0];
    }
    Ok(head)
}

/// Set if flag has local override
pub fn update_flag_has_local_override(
    buf: &mut [u8],
    flag_type: FlagValueType,
    flag_index: u32,
    value: bool,
) -> Result<usize, AconfigStorageError> {
    let (attribute, head) = get_flag_attribute_and_offset(buf, flag_type, flag_index)?;
    let has_override = (attribute & (FlagInfoBit::HasLocalOverride as u8)) != 0;
    if has_override != value {
        buf[head] = (attribute ^ FlagInfoBit::HasLocalOverride as u8).to_le_bytes()[0];
    }
    Ok(head)
}

#[cfg(test)]
mod tests {
    use super::*;
    use aconfig_storage_file::test_utils::create_test_flag_info_list;
    use aconfig_storage_read_api::flag_info_query::find_flag_attribute;

    #[test]
    // this test point locks down has server override update
    fn test_update_flag_has_server_override() {
        let flag_info_list = create_test_flag_info_list();
        let mut buf = flag_info_list.into_bytes();
        for i in 0..flag_info_list.header.num_flags {
            update_flag_has_server_override(&mut buf, FlagValueType::Boolean, i, true).unwrap();
            let attribute = find_flag_attribute(&buf, FlagValueType::Boolean, i).unwrap();
            assert!((attribute & (FlagInfoBit::HasServerOverride as u8)) != 0);
            update_flag_has_server_override(&mut buf, FlagValueType::Boolean, i, false).unwrap();
            let attribute = find_flag_attribute(&buf, FlagValueType::Boolean, i).unwrap();
            assert!((attribute & (FlagInfoBit::HasServerOverride as u8)) == 0);
        }
    }

    #[test]
    // this test point locks down has local override update
    fn test_update_flag_has_local_override() {
        let flag_info_list = create_test_flag_info_list();
        let mut buf = flag_info_list.into_bytes();
        for i in 0..flag_info_list.header.num_flags {
            update_flag_has_local_override(&mut buf, FlagValueType::Boolean, i, true).unwrap();
            let attribute = find_flag_attribute(&buf, FlagValueType::Boolean, i).unwrap();
            assert!((attribute & (FlagInfoBit::HasLocalOverride as u8)) != 0);
            update_flag_has_local_override(&mut buf, FlagValueType::Boolean, i, false).unwrap();
            let attribute = find_flag_attribute(&buf, FlagValueType::Boolean, i).unwrap();
            assert!((attribute & (FlagInfoBit::HasLocalOverride as u8)) == 0);
        }
    }
}
