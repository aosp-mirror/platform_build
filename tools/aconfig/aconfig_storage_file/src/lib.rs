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

pub mod flag_table;
pub mod flag_value;
pub mod mapped_file;
pub mod package_table;
pub mod protos;

#[cfg(test)]
mod test_utils;

use anyhow::anyhow;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

pub use crate::flag_table::{FlagOffset, FlagTable, FlagTableHeader, FlagTableNode};
pub use crate::flag_value::{FlagValueHeader, FlagValueList};
pub use crate::package_table::{PackageOffset, PackageTable, PackageTableHeader, PackageTableNode};
pub use crate::protos::ProtoStorageFiles;

use crate::AconfigStorageError::{BytesParseFail, HashTableSizeLimit};

/// Storage file version
pub const FILE_VERSION: u32 = 1;

/// Good hash table prime number
pub(crate) const HASH_PRIMES: [u32; 29] = [
    7, 17, 29, 53, 97, 193, 389, 769, 1543, 3079, 6151, 12289, 24593, 49157, 98317, 196613, 393241,
    786433, 1572869, 3145739, 6291469, 12582917, 25165843, 50331653, 100663319, 201326611,
    402653189, 805306457, 1610612741,
];

/// Storage file location pb file
pub const STORAGE_LOCATION_FILE: &str = "/metadata/aconfig/storage_files.pb";

/// Storage file type enum
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum StorageFileSelection {
    PackageMap,
    FlagMap,
    FlagVal,
}

impl TryFrom<&str> for StorageFileSelection {
    type Error = anyhow::Error;

    fn try_from(value: &str) -> std::result::Result<Self, Self::Error> {
        match value {
            "package_map" => Ok(Self::PackageMap),
            "flag_map" => Ok(Self::FlagMap),
            "flag_val" => Ok(Self::FlagVal),
            _ => Err(anyhow!("Invalid storage file to create")),
        }
    }
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
pub(crate) fn get_bucket_index<T: Hash>(val: &T, num_buckets: u32) -> u32 {
    let mut s = DefaultHasher::new();
    val.hash(&mut s);
    (s.finish() % num_buckets as u64) as u32
}

/// Read and parse bytes as u8
pub(crate) fn read_u8_from_bytes(buf: &[u8], head: &mut usize) -> Result<u8, AconfigStorageError> {
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
pub(crate) fn read_u32_from_bytes(
    buf: &[u8],
    head: &mut usize,
) -> Result<u32, AconfigStorageError> {
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

    #[error("number of items in hash table exceed limit")]
    HashTableSizeLimit(#[source] anyhow::Error),

    #[error("failed to parse bytes into data")]
    BytesParseFail(#[source] anyhow::Error),

    #[error("cannot parse storage files with a higher version")]
    HigherStorageFileVersion(#[source] anyhow::Error),

    #[error("invalid storage file byte offset")]
    InvalidStorageFileOffset(#[source] anyhow::Error),
}

/// Get package start offset implementation
pub fn get_package_offset_impl(
    pb_file: &str,
    container: &str,
    package: &str,
) -> Result<Option<PackageOffset>, AconfigStorageError> {
    let mapped_file =
        crate::mapped_file::get_mapped_file(pb_file, container, StorageFileSelection::PackageMap)?;
    crate::package_table::find_package_offset(&mapped_file, package)
}

/// Get flag offset implementation
pub fn get_flag_offset_impl(
    pb_file: &str,
    container: &str,
    package_id: u32,
    flag: &str,
) -> Result<Option<FlagOffset>, AconfigStorageError> {
    let mapped_file =
        crate::mapped_file::get_mapped_file(pb_file, container, StorageFileSelection::FlagMap)?;
    crate::flag_table::find_flag_offset(&mapped_file, package_id, flag)
}

/// Get boolean flag value implementation
pub fn get_boolean_flag_value_impl(
    pb_file: &str,
    container: &str,
    offset: u32,
) -> Result<bool, AconfigStorageError> {
    let mapped_file =
        crate::mapped_file::get_mapped_file(pb_file, container, StorageFileSelection::FlagVal)?;
    crate::flag_value::find_boolean_flag_value(&mapped_file, offset)
}

/// Get package start offset for flags given the container and package name.
///
/// This function would map the corresponding package map file if has not been mapped yet,
/// and then look for the target package in this mapped file.
///
/// If a package is found, it returns Ok(Some(PackageOffset))
/// If a package is not found, it returns Ok(None)
/// If errors out such as no such package map file is found, it returns an Err(errmsg)
pub fn get_package_offset(
    container: &str,
    package: &str,
) -> Result<Option<PackageOffset>, AconfigStorageError> {
    get_package_offset_impl(STORAGE_LOCATION_FILE, container, package)
}

/// Get flag offset within a package given the container name, package id and flag name.
///
/// This function would map the corresponding flag map file if has not been mapped yet,
/// and then look for the target flag in this mapped file.
///
/// If a flag is found, it returns Ok(Some(u16))
/// If a flag is not found, it returns Ok(None)
/// If errors out such as no such flag map file is found, it returns an Err(errmsg)
pub fn get_flag_offset(
    container: &str,
    package_id: u32,
    flag: &str,
) -> Result<Option<FlagOffset>, AconfigStorageError> {
    get_flag_offset_impl(STORAGE_LOCATION_FILE, container, package_id, flag)
}

/// Get the boolean flag value given the container name and flag global offset
///
/// This function would map the corresponding flag value file if has not been mapped yet,
/// and then look for the target flag value at the specified offset.
///
/// If flag value file is successfully mapped and the provide offset is valid, it returns
/// the boolean flag value, otherwise it returns the error message.
pub fn get_boolean_flag_value(container: &str, offset: u32) -> Result<bool, AconfigStorageError> {
    get_boolean_flag_value_impl(STORAGE_LOCATION_FILE, container, offset)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{
        create_temp_storage_files_for_test, get_binary_storage_proto_bytes,
        set_temp_storage_files_to_read_only, write_bytes_to_temp_file,
    };

    #[test]
    // this test point locks down flag package offset query
    fn test_package_offset_query() {
        #[cfg(feature = "cargo")]
        create_temp_storage_files_for_test();

        set_temp_storage_files_to_read_only();
        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: "./tests/tmp.ro.package.map"
    flag_map: "./tests/tmp.ro.flag.map"
    flag_val: "./tests/tmp.ro.flag.val"
    timestamp: 12345
}
"#;
        let binary_proto_bytes = get_binary_storage_proto_bytes(text_proto).unwrap();
        let file = write_bytes_to_temp_file(&binary_proto_bytes).unwrap();
        let file_full_path = file.path().display().to_string();

        let package_offset = get_package_offset_impl(
            &file_full_path,
            "system",
            "com.android.aconfig.storage.test_1",
        )
        .unwrap()
        .unwrap();
        let expected_package_offset = PackageOffset { package_id: 0, boolean_offset: 0 };
        assert_eq!(package_offset, expected_package_offset);

        let package_offset = get_package_offset_impl(
            &file_full_path,
            "system",
            "com.android.aconfig.storage.test_2",
        )
        .unwrap()
        .unwrap();
        let expected_package_offset = PackageOffset { package_id: 1, boolean_offset: 3 };
        assert_eq!(package_offset, expected_package_offset);

        let package_offset = get_package_offset_impl(
            &file_full_path,
            "system",
            "com.android.aconfig.storage.test_4",
        )
        .unwrap()
        .unwrap();
        let expected_package_offset = PackageOffset { package_id: 2, boolean_offset: 6 };
        assert_eq!(package_offset, expected_package_offset);
    }

    #[test]
    // this test point locks down flag offset query
    fn test_flag_offset_query() {
        #[cfg(feature = "cargo")]
        create_temp_storage_files_for_test();

        set_temp_storage_files_to_read_only();
        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: "./tests/tmp.ro.package.map"
    flag_map: "./tests/tmp.ro.flag.map"
    flag_val: "./tests/tmp.ro.flag.val"
    timestamp: 12345
}
"#;
        let binary_proto_bytes = get_binary_storage_proto_bytes(text_proto).unwrap();
        let file = write_bytes_to_temp_file(&binary_proto_bytes).unwrap();
        let file_full_path = file.path().display().to_string();

        let baseline = vec![
            (0, "enabled_ro", 1u16),
            (0, "enabled_rw", 2u16),
            (1, "disabled_ro", 0u16),
            (2, "enabled_ro", 1u16),
            (1, "enabled_fixed_ro", 1u16),
            (1, "enabled_ro", 2u16),
            (2, "enabled_fixed_ro", 0u16),
            (0, "disabled_rw", 0u16),
        ];
        for (package_id, flag_name, expected_offset) in baseline.into_iter() {
            let flag_offset =
                get_flag_offset_impl(&file_full_path, "system", package_id, flag_name)
                    .unwrap()
                    .unwrap();
            assert_eq!(flag_offset, expected_offset);
        }
    }

    #[test]
    // this test point locks down flag offset query
    fn test_flag_value_query() {
        #[cfg(feature = "cargo")]
        create_temp_storage_files_for_test();

        set_temp_storage_files_to_read_only();
        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: "./tests/tmp.ro.package.map"
    flag_map: "./tests/tmp.ro.flag.map"
    flag_val: "./tests/tmp.ro.flag.val"
    timestamp: 12345
}
"#;
        let binary_proto_bytes = get_binary_storage_proto_bytes(text_proto).unwrap();
        let file = write_bytes_to_temp_file(&binary_proto_bytes).unwrap();
        let file_full_path = file.path().display().to_string();

        let baseline: Vec<bool> = vec![false; 8];
        for (offset, expected_value) in baseline.into_iter().enumerate() {
            let flag_value =
                get_boolean_flag_value_impl(&file_full_path, "system", offset as u32).unwrap();
            assert_eq!(flag_value, expected_value);
        }
    }
}
