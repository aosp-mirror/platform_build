/*
 * Copyright (C) 2023 The Android Open Source Project
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

//! `aconfig_storage_file` is a crate that defines aconfig storage file format, it
//! also includes apis to read flags from storage files. It provides three apis to
//! interface with storage files:
//!
//! 1, function to get package flag value start offset
//! pub fn get_package_offset(container: &str, package: &str) -> `Result<Option<PackageOffset>>>`
//!
//! 2, function to get flag offset within a specific package
//! pub fn get_flag_offset(container: &str, package_id: u32, flag: &str) -> `Result<Option<u16>>>`
//!
//! 3, function to get the actual flag value given the global offset (combined package and
//! flag offset).
//! pub fn get_boolean_flag_value(container: &str, offset: u32) -> `Result<bool>`
//!
//! Note these are low level apis that are expected to be only used in auto generated flag
//! apis. DO NOT DIRECTLY USE THESE APIS IN YOUR SOURCE CODE. For auto generated flag apis
//! please refer to the g3doc go/android-flags

pub mod flag_info;
pub mod flag_table;
pub mod flag_value;
pub mod package_table;
pub mod protos;
pub mod sip_hasher13;
pub mod test_utils;

use anyhow::anyhow;
use serde::{Deserialize, Serialize};
use std::cmp::Ordering;
use std::fs::File;
use std::hash::Hasher;
use std::io::Read;

pub use crate::flag_info::{FlagInfoBit, FlagInfoHeader, FlagInfoList, FlagInfoNode};
pub use crate::flag_table::{FlagTable, FlagTableHeader, FlagTableNode};
pub use crate::flag_value::{FlagValueHeader, FlagValueList};
pub use crate::package_table::{PackageTable, PackageTableHeader, PackageTableNode};
pub use crate::sip_hasher13::SipHasher13;

use crate::AconfigStorageError::{
    BytesParseFail, HashTableSizeLimit, InvalidFlagValueType, InvalidStoredFlagType,
};

/// Storage file version
pub const FILE_VERSION: u32 = 1;

/// Good hash table prime number
pub(crate) const HASH_PRIMES: [u32; 29] = [
    7, 17, 29, 53, 97, 193, 389, 769, 1543, 3079, 6151, 12289, 24593, 49157, 98317, 196613, 393241,
    786433, 1572869, 3145739, 6291469, 12582917, 25165843, 50331653, 100663319, 201326611,
    402653189, 805306457, 1610612741,
];

/// Storage file type enum
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum StorageFileType {
    PackageMap = 0,
    FlagMap = 1,
    FlagVal = 2,
    FlagInfo = 3,
}

impl TryFrom<&str> for StorageFileType {
    type Error = anyhow::Error;

    fn try_from(value: &str) -> std::result::Result<Self, Self::Error> {
        match value {
            "package_map" => Ok(Self::PackageMap),
            "flag_map" => Ok(Self::FlagMap),
            "flag_val" => Ok(Self::FlagVal),
            "flag_info" => Ok(Self::FlagInfo),
            _ => Err(anyhow!(
                "Invalid storage file type, valid types are package_map|flag_map|flag_val|flag_info"
            )),
        }
    }
}

impl TryFrom<u8> for StorageFileType {
    type Error = anyhow::Error;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            x if x == Self::PackageMap as u8 => Ok(Self::PackageMap),
            x if x == Self::FlagMap as u8 => Ok(Self::FlagMap),
            x if x == Self::FlagVal as u8 => Ok(Self::FlagVal),
            x if x == Self::FlagInfo as u8 => Ok(Self::FlagInfo),
            _ => Err(anyhow!("Invalid storage file type")),
        }
    }
}

/// Flag type enum as stored by storage file
/// ONLY APPEND, NEVER REMOVE FOR BACKWARD COMPATIBILITY. THE MAX IS U16.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum StoredFlagType {
    ReadWriteBoolean = 0,
    ReadOnlyBoolean = 1,
    FixedReadOnlyBoolean = 2,
}

impl TryFrom<u16> for StoredFlagType {
    type Error = AconfigStorageError;

    fn try_from(value: u16) -> Result<Self, Self::Error> {
        match value {
            x if x == Self::ReadWriteBoolean as u16 => Ok(Self::ReadWriteBoolean),
            x if x == Self::ReadOnlyBoolean as u16 => Ok(Self::ReadOnlyBoolean),
            x if x == Self::FixedReadOnlyBoolean as u16 => Ok(Self::FixedReadOnlyBoolean),
            _ => Err(InvalidStoredFlagType(anyhow!("Invalid stored flag type"))),
        }
    }
}

/// Flag value type enum, one FlagValueType maps to many StoredFlagType
/// ONLY APPEND, NEVER REMOVE FOR BACKWARD COMPATIBILITY. THE MAX IS U16
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FlagValueType {
    Boolean = 0,
}

impl TryFrom<StoredFlagType> for FlagValueType {
    type Error = AconfigStorageError;

    fn try_from(value: StoredFlagType) -> Result<Self, Self::Error> {
        match value {
            StoredFlagType::ReadWriteBoolean => Ok(Self::Boolean),
            StoredFlagType::ReadOnlyBoolean => Ok(Self::Boolean),
            StoredFlagType::FixedReadOnlyBoolean => Ok(Self::Boolean),
        }
    }
}

impl TryFrom<u16> for FlagValueType {
    type Error = AconfigStorageError;

    fn try_from(value: u16) -> Result<Self, Self::Error> {
        match value {
            x if x == Self::Boolean as u16 => Ok(Self::Boolean),
            _ => Err(InvalidFlagValueType(anyhow!("Invalid flag value type"))),
        }
    }
}

/// Storage query api error
#[non_exhaustive]
#[derive(thiserror::Error, Debug)]
pub enum AconfigStorageError {
    #[error("failed to read the file")]
    FileReadFail(#[source] anyhow::Error),

    #[error("fail to parse protobuf")]
    ProtobufParseFail(#[source] anyhow::Error),

    #[error("storage files not found for this container")]
    StorageFileNotFound(#[source] anyhow::Error),

    #[error("fail to map storage file")]
    MapFileFail(#[source] anyhow::Error),

    #[error("fail to get mapped file")]
    ObtainMappedFileFail(#[source] anyhow::Error),

    #[error("fail to flush mapped storage file")]
    MapFlushFail(#[source] anyhow::Error),

    #[error("number of items in hash table exceed limit")]
    HashTableSizeLimit(#[source] anyhow::Error),

    #[error("failed to parse bytes into data")]
    BytesParseFail(#[source] anyhow::Error),

    #[error("cannot parse storage files with a higher version")]
    HigherStorageFileVersion(#[source] anyhow::Error),

    #[error("invalid storage file byte offset")]
    InvalidStorageFileOffset(#[source] anyhow::Error),

    #[error("failed to create file")]
    FileCreationFail(#[source] anyhow::Error),

    #[error("invalid stored flag type")]
    InvalidStoredFlagType(#[source] anyhow::Error),

    #[error("invalid flag value type")]
    InvalidFlagValueType(#[source] anyhow::Error),
}

/// Get the right hash table size given number of entries in the table. Use a
/// load factor of 0.5 for performance.
pub fn get_table_size(entries: u32) -> Result<u32, AconfigStorageError> {
    HASH_PRIMES
        .iter()
        .find(|&&num| num >= 2 * entries)
        .copied()
        .ok_or(HashTableSizeLimit(anyhow!("Number of items in a hash table exceeds limit")))
}

/// Get the corresponding bucket index given the key and number of buckets
pub(crate) fn get_bucket_index(val: &[u8], num_buckets: u32) -> u32 {
    let mut s = SipHasher13::new();
    s.write(val);
    s.write_u8(0xff);
    let ret = (s.finish() % num_buckets as u64) as u32;
    ret
}

/// Read and parse bytes as u8
pub fn read_u8_from_bytes(buf: &[u8], head: &mut usize) -> Result<u8, AconfigStorageError> {
    let val =
        u8::from_le_bytes(buf[*head..*head + 1].try_into().map_err(|errmsg| {
            BytesParseFail(anyhow!("fail to parse u8 from bytes: {}", errmsg))
        })?);
    *head += 1;
    Ok(val)
}

/// Read and parse bytes as u16
pub(crate) fn read_u16_from_bytes(
    buf: &[u8],
    head: &mut usize,
) -> Result<u16, AconfigStorageError> {
    let val =
        u16::from_le_bytes(buf[*head..*head + 2].try_into().map_err(|errmsg| {
            BytesParseFail(anyhow!("fail to parse u16 from bytes: {}", errmsg))
        })?);
    *head += 2;
    Ok(val)
}

/// Read and parse bytes as u32
pub fn read_u32_from_bytes(buf: &[u8], head: &mut usize) -> Result<u32, AconfigStorageError> {
    let val =
        u32::from_le_bytes(buf[*head..*head + 4].try_into().map_err(|errmsg| {
            BytesParseFail(anyhow!("fail to parse u32 from bytes: {}", errmsg))
        })?);
    *head += 4;
    Ok(val)
}

/// Read and parse bytes as string
pub(crate) fn read_str_from_bytes(
    buf: &[u8],
    head: &mut usize,
) -> Result<String, AconfigStorageError> {
    let num_bytes = read_u32_from_bytes(buf, head)? as usize;
    let val = String::from_utf8(buf[*head..*head + num_bytes].to_vec())
        .map_err(|errmsg| BytesParseFail(anyhow!("fail to parse string from bytes: {}", errmsg)))?;
    *head += num_bytes;
    Ok(val)
}

/// Read in storage file as bytes
pub fn read_file_to_bytes(file_path: &str) -> Result<Vec<u8>, AconfigStorageError> {
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

/// Flag value summary
#[derive(Debug, PartialEq)]
pub struct FlagValueSummary {
    pub package_name: String,
    pub flag_name: String,
    pub flag_value: String,
    pub value_type: StoredFlagType,
}

/// List flag values from storage files
pub fn list_flags(
    package_map: &str,
    flag_map: &str,
    flag_val: &str,
) -> Result<Vec<FlagValueSummary>, AconfigStorageError> {
    let package_table = PackageTable::from_bytes(&read_file_to_bytes(package_map)?)?;
    let flag_table = FlagTable::from_bytes(&read_file_to_bytes(flag_map)?)?;
    let flag_value_list = FlagValueList::from_bytes(&read_file_to_bytes(flag_val)?)?;

    let mut package_info = vec![("", 0); package_table.header.num_packages as usize];
    for node in package_table.nodes.iter() {
        package_info[node.package_id as usize] = (&node.package_name, node.boolean_start_index);
    }

    let mut flags = Vec::new();
    for node in flag_table.nodes.iter() {
        let (package_name, boolean_start_index) = package_info[node.package_id as usize];
        let flag_index = boolean_start_index + node.flag_index as u32;
        let flag_value = flag_value_list.booleans[flag_index as usize];
        flags.push(FlagValueSummary {
            package_name: String::from(package_name),
            flag_name: node.flag_name.clone(),
            flag_value: flag_value.to_string(),
            value_type: node.flag_type,
        });
    }

    flags.sort_by(|v1, v2| match v1.package_name.cmp(&v2.package_name) {
        Ordering::Equal => v1.flag_name.cmp(&v2.flag_name),
        other => other,
    });
    Ok(flags)
}

/// Flag value and info summary
#[derive(Debug, PartialEq)]
pub struct FlagValueAndInfoSummary {
    pub package_name: String,
    pub flag_name: String,
    pub flag_value: String,
    pub value_type: StoredFlagType,
    pub is_readwrite: bool,
    pub has_server_override: bool,
    pub has_local_override: bool,
}

/// List flag values and info from storage files
pub fn list_flags_with_info(
    package_map: &str,
    flag_map: &str,
    flag_val: &str,
    flag_info: &str,
) -> Result<Vec<FlagValueAndInfoSummary>, AconfigStorageError> {
    let package_table = PackageTable::from_bytes(&read_file_to_bytes(package_map)?)?;
    let flag_table = FlagTable::from_bytes(&read_file_to_bytes(flag_map)?)?;
    let flag_value_list = FlagValueList::from_bytes(&read_file_to_bytes(flag_val)?)?;
    let flag_info = FlagInfoList::from_bytes(&read_file_to_bytes(flag_info)?)?;

    let mut package_info = vec![("", 0); package_table.header.num_packages as usize];
    for node in package_table.nodes.iter() {
        package_info[node.package_id as usize] = (&node.package_name, node.boolean_start_index);
    }

    let mut flags = Vec::new();
    for node in flag_table.nodes.iter() {
        let (package_name, boolean_start_index) = package_info[node.package_id as usize];
        let flag_index = boolean_start_index + node.flag_index as u32;
        let flag_value = flag_value_list.booleans[flag_index as usize];
        let flag_attribute = flag_info.nodes[flag_index as usize].attributes;
        flags.push(FlagValueAndInfoSummary {
            package_name: String::from(package_name),
            flag_name: node.flag_name.clone(),
            flag_value: flag_value.to_string(),
            value_type: node.flag_type,
            is_readwrite: flag_attribute & (FlagInfoBit::IsReadWrite as u8) != 0,
            has_server_override: flag_attribute & (FlagInfoBit::HasServerOverride as u8) != 0,
            has_local_override: flag_attribute & (FlagInfoBit::HasLocalOverride as u8) != 0,
        });
    }

    flags.sort_by(|v1, v2| match v1.package_name.cmp(&v2.package_name) {
        Ordering::Equal => v1.flag_name.cmp(&v2.flag_name),
        other => other,
    });
    Ok(flags)
}

// *************************************** //
// CC INTERLOP
// *************************************** //

// Exported rust data structure and methods, c++ code will be generated
#[cxx::bridge]
mod ffi {
    /// flag value summary cxx return
    pub struct FlagValueSummaryCXX {
        pub package_name: String,
        pub flag_name: String,
        pub flag_value: String,
        pub value_type: String,
    }

    /// flag value and info summary cxx return
    pub struct FlagValueAndInfoSummaryCXX {
        pub package_name: String,
        pub flag_name: String,
        pub flag_value: String,
        pub value_type: String,
        pub is_readwrite: bool,
        pub has_server_override: bool,
        pub has_local_override: bool,
    }

    /// list flag result cxx return
    pub struct ListFlagValueResultCXX {
        pub query_success: bool,
        pub error_message: String,
        pub flags: Vec<FlagValueSummaryCXX>,
    }

    /// list flag with info result cxx return
    pub struct ListFlagValueAndInfoResultCXX {
        pub query_success: bool,
        pub error_message: String,
        pub flags: Vec<FlagValueAndInfoSummaryCXX>,
    }

    // Rust export to c++
    extern "Rust" {
        pub fn list_flags_cxx(
            package_map: &str,
            flag_map: &str,
            flag_val: &str,
        ) -> ListFlagValueResultCXX;

        pub fn list_flags_with_info_cxx(
            package_map: &str,
            flag_map: &str,
            flag_val: &str,
            flag_info: &str,
        ) -> ListFlagValueAndInfoResultCXX;
    }
}

/// implement flag value summary cxx return type
impl ffi::FlagValueSummaryCXX {
    pub(crate) fn new(summary: FlagValueSummary) -> Self {
        Self {
            package_name: summary.package_name,
            flag_name: summary.flag_name,
            flag_value: summary.flag_value,
            value_type: format!("{:?}", summary.value_type),
        }
    }
}

/// implement flag value and info summary cxx return type
impl ffi::FlagValueAndInfoSummaryCXX {
    pub(crate) fn new(summary: FlagValueAndInfoSummary) -> Self {
        Self {
            package_name: summary.package_name,
            flag_name: summary.flag_name,
            flag_value: summary.flag_value,
            value_type: format!("{:?}", summary.value_type),
            is_readwrite: summary.is_readwrite,
            has_server_override: summary.has_server_override,
            has_local_override: summary.has_local_override,
        }
    }
}

/// implement list flag cxx interlop
pub fn list_flags_cxx(
    package_map: &str,
    flag_map: &str,
    flag_val: &str,
) -> ffi::ListFlagValueResultCXX {
    match list_flags(package_map, flag_map, flag_val) {
        Ok(summary) => ffi::ListFlagValueResultCXX {
            query_success: true,
            error_message: String::new(),
            flags: summary.into_iter().map(ffi::FlagValueSummaryCXX::new).collect(),
        },
        Err(errmsg) => ffi::ListFlagValueResultCXX {
            query_success: false,
            error_message: format!("{:?}", errmsg),
            flags: Vec::new(),
        },
    }
}

/// implement list flag with info cxx interlop
pub fn list_flags_with_info_cxx(
    package_map: &str,
    flag_map: &str,
    flag_val: &str,
    flag_info: &str,
) -> ffi::ListFlagValueAndInfoResultCXX {
    match list_flags_with_info(package_map, flag_map, flag_val, flag_info) {
        Ok(summary) => ffi::ListFlagValueAndInfoResultCXX {
            query_success: true,
            error_message: String::new(),
            flags: summary.into_iter().map(ffi::FlagValueAndInfoSummaryCXX::new).collect(),
        },
        Err(errmsg) => ffi::ListFlagValueAndInfoResultCXX {
            query_success: false,
            error_message: format!("{:?}", errmsg),
            flags: Vec::new(),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{
        create_test_flag_info_list, create_test_flag_table, create_test_flag_value_list,
        create_test_package_table, write_bytes_to_temp_file,
    };

    #[test]
    // this test point locks down the flag list api
    fn test_list_flag() {
        let package_table =
            write_bytes_to_temp_file(&create_test_package_table().into_bytes()).unwrap();
        let flag_table = write_bytes_to_temp_file(&create_test_flag_table().into_bytes()).unwrap();
        let flag_value_list =
            write_bytes_to_temp_file(&create_test_flag_value_list().into_bytes()).unwrap();

        let package_table_path = package_table.path().display().to_string();
        let flag_table_path = flag_table.path().display().to_string();
        let flag_value_list_path = flag_value_list.path().display().to_string();

        let flags =
            list_flags(&package_table_path, &flag_table_path, &flag_value_list_path).unwrap();
        let expected = [
            FlagValueSummary {
                package_name: String::from("com.android.aconfig.storage.test_1"),
                flag_name: String::from("disabled_rw"),
                value_type: StoredFlagType::ReadWriteBoolean,
                flag_value: String::from("false"),
            },
            FlagValueSummary {
                package_name: String::from("com.android.aconfig.storage.test_1"),
                flag_name: String::from("enabled_ro"),
                value_type: StoredFlagType::ReadOnlyBoolean,
                flag_value: String::from("true"),
            },
            FlagValueSummary {
                package_name: String::from("com.android.aconfig.storage.test_1"),
                flag_name: String::from("enabled_rw"),
                value_type: StoredFlagType::ReadWriteBoolean,
                flag_value: String::from("true"),
            },
            FlagValueSummary {
                package_name: String::from("com.android.aconfig.storage.test_2"),
                flag_name: String::from("disabled_rw"),
                value_type: StoredFlagType::ReadWriteBoolean,
                flag_value: String::from("false"),
            },
            FlagValueSummary {
                package_name: String::from("com.android.aconfig.storage.test_2"),
                flag_name: String::from("enabled_fixed_ro"),
                value_type: StoredFlagType::FixedReadOnlyBoolean,
                flag_value: String::from("true"),
            },
            FlagValueSummary {
                package_name: String::from("com.android.aconfig.storage.test_2"),
                flag_name: String::from("enabled_ro"),
                value_type: StoredFlagType::ReadOnlyBoolean,
                flag_value: String::from("true"),
            },
            FlagValueSummary {
                package_name: String::from("com.android.aconfig.storage.test_4"),
                flag_name: String::from("enabled_fixed_ro"),
                value_type: StoredFlagType::FixedReadOnlyBoolean,
                flag_value: String::from("true"),
            },
            FlagValueSummary {
                package_name: String::from("com.android.aconfig.storage.test_4"),
                flag_name: String::from("enabled_rw"),
                value_type: StoredFlagType::ReadWriteBoolean,
                flag_value: String::from("true"),
            },
        ];
        assert_eq!(flags, expected);
    }

    #[test]
    // this test point locks down the flag list with info api
    fn test_list_flag_with_info() {
        let package_table =
            write_bytes_to_temp_file(&create_test_package_table().into_bytes()).unwrap();
        let flag_table = write_bytes_to_temp_file(&create_test_flag_table().into_bytes()).unwrap();
        let flag_value_list =
            write_bytes_to_temp_file(&create_test_flag_value_list().into_bytes()).unwrap();
        let flag_info_list =
            write_bytes_to_temp_file(&create_test_flag_info_list().into_bytes()).unwrap();

        let package_table_path = package_table.path().display().to_string();
        let flag_table_path = flag_table.path().display().to_string();
        let flag_value_list_path = flag_value_list.path().display().to_string();
        let flag_info_list_path = flag_info_list.path().display().to_string();

        let flags = list_flags_with_info(
            &package_table_path,
            &flag_table_path,
            &flag_value_list_path,
            &flag_info_list_path,
        )
        .unwrap();
        let expected = [
            FlagValueAndInfoSummary {
                package_name: String::from("com.android.aconfig.storage.test_1"),
                flag_name: String::from("disabled_rw"),
                value_type: StoredFlagType::ReadWriteBoolean,
                flag_value: String::from("false"),
                is_readwrite: true,
                has_server_override: false,
                has_local_override: false,
            },
            FlagValueAndInfoSummary {
                package_name: String::from("com.android.aconfig.storage.test_1"),
                flag_name: String::from("enabled_ro"),
                value_type: StoredFlagType::ReadOnlyBoolean,
                flag_value: String::from("true"),
                is_readwrite: false,
                has_server_override: false,
                has_local_override: false,
            },
            FlagValueAndInfoSummary {
                package_name: String::from("com.android.aconfig.storage.test_1"),
                flag_name: String::from("enabled_rw"),
                value_type: StoredFlagType::ReadWriteBoolean,
                flag_value: String::from("true"),
                is_readwrite: true,
                has_server_override: false,
                has_local_override: false,
            },
            FlagValueAndInfoSummary {
                package_name: String::from("com.android.aconfig.storage.test_2"),
                flag_name: String::from("disabled_rw"),
                value_type: StoredFlagType::ReadWriteBoolean,
                flag_value: String::from("false"),
                is_readwrite: true,
                has_server_override: false,
                has_local_override: false,
            },
            FlagValueAndInfoSummary {
                package_name: String::from("com.android.aconfig.storage.test_2"),
                flag_name: String::from("enabled_fixed_ro"),
                value_type: StoredFlagType::FixedReadOnlyBoolean,
                flag_value: String::from("true"),
                is_readwrite: false,
                has_server_override: false,
                has_local_override: false,
            },
            FlagValueAndInfoSummary {
                package_name: String::from("com.android.aconfig.storage.test_2"),
                flag_name: String::from("enabled_ro"),
                value_type: StoredFlagType::ReadOnlyBoolean,
                flag_value: String::from("true"),
                is_readwrite: false,
                has_server_override: false,
                has_local_override: false,
            },
            FlagValueAndInfoSummary {
                package_name: String::from("com.android.aconfig.storage.test_4"),
                flag_name: String::from("enabled_fixed_ro"),
                value_type: StoredFlagType::FixedReadOnlyBoolean,
                flag_value: String::from("true"),
                is_readwrite: false,
                has_server_override: false,
                has_local_override: false,
            },
            FlagValueAndInfoSummary {
                package_name: String::from("com.android.aconfig.storage.test_4"),
                flag_name: String::from("enabled_rw"),
                value_type: StoredFlagType::ReadWriteBoolean,
                flag_value: String::from("true"),
                is_readwrite: true,
                has_server_override: false,
                has_local_override: false,
            },
        ];
        assert_eq!(flags, expected);
    }
}
