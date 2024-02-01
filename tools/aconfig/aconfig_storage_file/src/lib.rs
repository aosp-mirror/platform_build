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
//! also includes apis to read flags from storage files

pub mod flag_table;
pub mod flag_value;
pub mod package_table;

#[cfg(feature = "cargo")]
pub mod mapped_file;

mod protos;
#[cfg(test)]
mod test_utils;

use anyhow::{anyhow, Result};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

pub use crate::flag_table::{FlagTable, FlagTableHeader, FlagTableNode};
pub use crate::flag_value::{FlagValueHeader, FlagValueList};
pub use crate::package_table::{PackageTable, PackageTableHeader, PackageTableNode};

/// Storage file version
pub const FILE_VERSION: u32 = 1;

/// Good hash table prime number
pub const HASH_PRIMES: [u32; 29] = [
    7, 17, 29, 53, 97, 193, 389, 769, 1543, 3079, 6151, 12289, 24593, 49157, 98317, 196613, 393241,
    786433, 1572869, 3145739, 6291469, 12582917, 25165843, 50331653, 100663319, 201326611,
    402653189, 805306457, 1610612741,
];

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
pub fn get_table_size(entries: u32) -> Result<u32> {
    HASH_PRIMES
        .iter()
        .find(|&&num| num >= 2 * entries)
        .copied()
        .ok_or(anyhow!("Number of packages is too large"))
}

/// Get the corresponding bucket index given the key and number of buckets
pub fn get_bucket_index<T: Hash>(val: &T, num_buckets: u32) -> u32 {
    let mut s = DefaultHasher::new();
    val.hash(&mut s);
    (s.finish() % num_buckets as u64) as u32
}

/// Read and parse bytes as u8
pub fn read_u8_from_bytes(buf: &[u8], head: &mut usize) -> Result<u8> {
    let val = u8::from_le_bytes(buf[*head..*head + 1].try_into()?);
    *head += 1;
    Ok(val)
}

/// Read and parse bytes as u16
pub fn read_u16_from_bytes(buf: &[u8], head: &mut usize) -> Result<u16> {
    let val = u16::from_le_bytes(buf[*head..*head + 2].try_into()?);
    *head += 2;
    Ok(val)
}

/// Read and parse bytes as u32
pub fn read_u32_from_bytes(buf: &[u8], head: &mut usize) -> Result<u32> {
    let val = u32::from_le_bytes(buf[*head..*head + 4].try_into()?);
    *head += 4;
    Ok(val)
}

/// Read and parse bytes as string
pub fn read_str_from_bytes(buf: &[u8], head: &mut usize) -> Result<String> {
    let num_bytes = read_u32_from_bytes(buf, head)? as usize;
    let val = String::from_utf8(buf[*head..*head + num_bytes].to_vec())?;
    *head += num_bytes;
    Ok(val)
}
