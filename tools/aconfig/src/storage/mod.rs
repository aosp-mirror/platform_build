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

pub mod flag_table;
pub mod flag_value;
pub mod package_table;

use anyhow::{anyhow, Result};
use std::collections::{hash_map::DefaultHasher, HashMap, HashSet};
use std::hash::{Hash, Hasher};

use crate::protos::{ProtoParsedFlag, ProtoParsedFlags};
use crate::storage::{
    flag_table::FlagTable, flag_value::FlagValueList, package_table::PackageTable,
};

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

pub const FILE_VERSION: u32 = 1;

pub const HASH_PRIMES: [u32; 29] = [
    7, 17, 29, 53, 97, 193, 389, 769, 1543, 3079, 6151, 12289, 24593, 49157, 98317, 196613, 393241,
    786433, 1572869, 3145739, 6291469, 12582917, 25165843, 50331653, 100663319, 201326611,
    402653189, 805306457, 1610612741,
];

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

pub struct FlagPackage<'a> {
    pub package_name: &'a str,
    pub package_id: u32,
    pub flag_names: HashSet<&'a str>,
    pub boolean_flags: Vec<&'a ProtoParsedFlag>,
    // offset of the first boolean flag in this flag package with respect to the start of
    // boolean flag value array in the flag value file
    pub boolean_offset: u32,
}

impl<'a> FlagPackage<'a> {
    fn new(package_name: &'a str, package_id: u32) -> Self {
        FlagPackage {
            package_name,
            package_id,
            flag_names: HashSet::new(),
            boolean_flags: vec![],
            boolean_offset: 0,
        }
    }

    fn insert(&mut self, pf: &'a ProtoParsedFlag) {
        if self.flag_names.insert(pf.name()) {
            self.boolean_flags.push(pf);
        }
    }
}

pub fn group_flags_by_package<'a, I>(parsed_flags_vec_iter: I) -> Vec<FlagPackage<'a>>
where
    I: Iterator<Item = &'a ProtoParsedFlags>,
{
    // group flags by package
    let mut packages: Vec<FlagPackage<'a>> = Vec::new();
    let mut package_index: HashMap<&str, usize> = HashMap::new();
    for parsed_flags in parsed_flags_vec_iter {
        for parsed_flag in parsed_flags.parsed_flag.iter() {
            let index = *(package_index.entry(parsed_flag.package()).or_insert(packages.len()));
            if index == packages.len() {
                packages.push(FlagPackage::new(parsed_flag.package(), index as u32));
            }
            packages[index].insert(parsed_flag);
        }
    }

    // calculate package flag value start offset, in flag value file, each boolean
    // is stored as a single byte
    let mut boolean_offset = 0;
    for p in packages.iter_mut() {
        p.boolean_offset = boolean_offset;
        boolean_offset += p.boolean_flags.len() as u32;
    }

    packages
}

pub fn generate_storage_file<'a, I>(
    container: &str,
    parsed_flags_vec_iter: I,
    file: &StorageFileSelection,
) -> Result<Vec<u8>>
where
    I: Iterator<Item = &'a ProtoParsedFlags>,
{
    let packages = group_flags_by_package(parsed_flags_vec_iter);

    match file {
        StorageFileSelection::PackageMap => {
            let package_table = PackageTable::new(container, &packages)?;
            Ok(package_table.as_bytes())
        }
        StorageFileSelection::FlagMap => {
            let flag_table = FlagTable::new(container, &packages)?;
            Ok(flag_table.as_bytes())
        }
        StorageFileSelection::FlagVal => {
            let flag_value = FlagValueList::new(container, &packages)?;
            Ok(flag_value.as_bytes())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Input;

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

    pub fn parse_all_test_flags() -> Vec<ProtoParsedFlags> {
        let aconfig_files = [
            (
                "com.android.aconfig.storage.test_1",
                "storage_test_1.aconfig",
                include_bytes!("../../tests/storage_test_1.aconfig").as_slice(),
            ),
            (
                "com.android.aconfig.storage.test_2",
                "storage_test_2.aconfig",
                include_bytes!("../../tests/storage_test_2.aconfig").as_slice(),
            ),
            (
                "com.android.aconfig.storage.test_4",
                "storage_test_4.aconfig",
                include_bytes!("../../tests/storage_test_4.aconfig").as_slice(),
            ),
        ];

        aconfig_files
            .into_iter()
            .map(|(pkg, file, content)| {
                let bytes = crate::commands::parse_flags(
                    pkg,
                    Some("system"),
                    vec![Input {
                        source: format!("tests/{}", file).to_string(),
                        reader: Box::new(content),
                    }],
                    vec![],
                    crate::commands::DEFAULT_FLAG_PERMISSION,
                )
                .unwrap();
                crate::protos::parsed_flags::try_from_binary_proto(&bytes).unwrap()
            })
            .collect()
    }

    #[test]
    fn test_flag_package() {
        let caches = parse_all_test_flags();
        let packages = group_flags_by_package(caches.iter());

        for pkg in packages.iter() {
            let pkg_name = pkg.package_name;
            assert_eq!(pkg.flag_names.len(), pkg.boolean_flags.len());
            for pf in pkg.boolean_flags.iter() {
                assert!(pkg.flag_names.contains(pf.name()));
                assert_eq!(pf.package(), pkg_name);
            }
        }

        assert_eq!(packages.len(), 3);

        assert_eq!(packages[0].package_name, "com.android.aconfig.storage.test_1");
        assert_eq!(packages[0].package_id, 0);
        assert_eq!(packages[0].flag_names.len(), 3);
        assert!(packages[0].flag_names.contains("enabled_rw"));
        assert!(packages[0].flag_names.contains("disabled_rw"));
        assert!(packages[0].flag_names.contains("enabled_ro"));
        assert_eq!(packages[0].boolean_offset, 0);

        assert_eq!(packages[1].package_name, "com.android.aconfig.storage.test_2");
        assert_eq!(packages[1].package_id, 1);
        assert_eq!(packages[1].flag_names.len(), 3);
        assert!(packages[1].flag_names.contains("enabled_ro"));
        assert!(packages[1].flag_names.contains("disabled_ro"));
        assert!(packages[1].flag_names.contains("enabled_fixed_ro"));
        assert_eq!(packages[1].boolean_offset, 3);

        assert_eq!(packages[2].package_name, "com.android.aconfig.storage.test_4");
        assert_eq!(packages[2].package_id, 2);
        assert_eq!(packages[2].flag_names.len(), 2);
        assert!(packages[2].flag_names.contains("enabled_ro"));
        assert!(packages[2].flag_names.contains("enabled_fixed_ro"));
        assert_eq!(packages[2].boolean_offset, 6);
    }
}
