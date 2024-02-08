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

//! package table module defines the package table file format and methods for serialization
//! and deserialization

use crate::AconfigStorageError::{self, BytesParseFail, HigherStorageFileVersion};
use crate::{get_bucket_index, read_str_from_bytes, read_u32_from_bytes};
use anyhow::anyhow;

/// Package table header struct
#[derive(PartialEq, Debug)]
pub struct PackageTableHeader {
    pub version: u32,
    pub container: String,
    pub file_size: u32,
    pub num_packages: u32,
    pub bucket_offset: u32,
    pub node_offset: u32,
}

impl PackageTableHeader {
    /// Serialize to bytes
    pub fn as_bytes(&self) -> Vec<u8> {
        let mut result = Vec::new();
        result.extend_from_slice(&self.version.to_le_bytes());
        let container_bytes = self.container.as_bytes();
        result.extend_from_slice(&(container_bytes.len() as u32).to_le_bytes());
        result.extend_from_slice(container_bytes);
        result.extend_from_slice(&self.file_size.to_le_bytes());
        result.extend_from_slice(&self.num_packages.to_le_bytes());
        result.extend_from_slice(&self.bucket_offset.to_le_bytes());
        result.extend_from_slice(&self.node_offset.to_le_bytes());
        result
    }

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AconfigStorageError> {
        let mut head = 0;
        Ok(Self {
            version: read_u32_from_bytes(bytes, &mut head)?,
            container: read_str_from_bytes(bytes, &mut head)?,
            file_size: read_u32_from_bytes(bytes, &mut head)?,
            num_packages: read_u32_from_bytes(bytes, &mut head)?,
            bucket_offset: read_u32_from_bytes(bytes, &mut head)?,
            node_offset: read_u32_from_bytes(bytes, &mut head)?,
        })
    }
}

/// Package table node struct
#[derive(PartialEq, Debug)]
pub struct PackageTableNode {
    pub package_name: String,
    pub package_id: u32,
    // offset of the first boolean flag in this flag package with respect to the start of
    // boolean flag value array in the flag value file
    pub boolean_offset: u32,
    pub next_offset: Option<u32>,
}

impl PackageTableNode {
    /// Serialize to bytes
    pub fn as_bytes(&self) -> Vec<u8> {
        let mut result = Vec::new();
        let name_bytes = self.package_name.as_bytes();
        result.extend_from_slice(&(name_bytes.len() as u32).to_le_bytes());
        result.extend_from_slice(name_bytes);
        result.extend_from_slice(&self.package_id.to_le_bytes());
        result.extend_from_slice(&self.boolean_offset.to_le_bytes());
        result.extend_from_slice(&self.next_offset.unwrap_or(0).to_le_bytes());
        result
    }

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AconfigStorageError> {
        let mut head = 0;
        let node = Self {
            package_name: read_str_from_bytes(bytes, &mut head)?,
            package_id: read_u32_from_bytes(bytes, &mut head)?,
            boolean_offset: read_u32_from_bytes(bytes, &mut head)?,
            next_offset: match read_u32_from_bytes(bytes, &mut head)? {
                0 => None,
                val => Some(val),
            },
        };
        Ok(node)
    }

    /// Get the bucket index for a package table node, defined it here so the
    /// construction side (aconfig binary) and consumption side (flag read lib)
    /// use the same method of hashing
    pub fn find_bucket_index(package: &str, num_buckets: u32) -> u32 {
        get_bucket_index(&package, num_buckets)
    }
}

/// Package table struct
#[derive(PartialEq, Debug)]
pub struct PackageTable {
    pub header: PackageTableHeader,
    pub buckets: Vec<Option<u32>>,
    pub nodes: Vec<PackageTableNode>,
}

impl PackageTable {
    /// Serialize to bytes
    pub fn as_bytes(&self) -> Vec<u8> {
        [
            self.header.as_bytes(),
            self.buckets.iter().map(|v| v.unwrap_or(0).to_le_bytes()).collect::<Vec<_>>().concat(),
            self.nodes.iter().map(|v| v.as_bytes()).collect::<Vec<_>>().concat(),
        ]
        .concat()
    }

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AconfigStorageError> {
        let header = PackageTableHeader::from_bytes(bytes)?;
        let num_packages = header.num_packages;
        let num_buckets = crate::get_table_size(num_packages)?;
        let mut head = header.as_bytes().len();
        let buckets = (0..num_buckets)
            .map(|_| match read_u32_from_bytes(bytes, &mut head).unwrap() {
                0 => None,
                val => Some(val),
            })
            .collect();
        let nodes = (0..num_packages)
            .map(|_| {
                let node = PackageTableNode::from_bytes(&bytes[head..])?;
                head += node.as_bytes().len();
                Ok(node)
            })
            .collect::<Result<Vec<_>, AconfigStorageError>>()
            .map_err(|errmsg| BytesParseFail(anyhow!("fail to parse package table: {}", errmsg)))?;

        let table = Self { header, buckets, nodes };
        Ok(table)
    }
}

/// Package table query return
#[derive(PartialEq, Debug)]
pub struct PackageOffset {
    pub package_id: u32,
    pub boolean_offset: u32,
}

/// Query package id and start offset
pub fn find_package_offset(
    buf: &[u8],
    package: &str,
) -> Result<Option<PackageOffset>, AconfigStorageError> {
    let interpreted_header = PackageTableHeader::from_bytes(buf)?;
    if interpreted_header.version > crate::FILE_VERSION {
        return Err(HigherStorageFileVersion(anyhow!(
            "Cannot read storage file with a higher version of {} with lib version {}",
            interpreted_header.version,
            crate::FILE_VERSION
        )));
    }

    let num_buckets = (interpreted_header.node_offset - interpreted_header.bucket_offset) / 4;
    let bucket_index = PackageTableNode::find_bucket_index(package, num_buckets);

    let mut pos = (interpreted_header.bucket_offset + 4 * bucket_index) as usize;
    let mut package_node_offset = read_u32_from_bytes(buf, &mut pos)? as usize;
    if package_node_offset < interpreted_header.node_offset as usize
        || package_node_offset >= interpreted_header.file_size as usize
    {
        return Ok(None);
    }

    loop {
        let interpreted_node = PackageTableNode::from_bytes(&buf[package_node_offset..])?;
        if interpreted_node.package_name == package {
            return Ok(Some(PackageOffset {
                package_id: interpreted_node.package_id,
                boolean_offset: interpreted_node.boolean_offset,
            }));
        }
        match interpreted_node.next_offset {
            Some(offset) => package_node_offset = offset as usize,
            None => return Ok(None),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    pub fn create_test_package_table() -> PackageTable {
        let header = PackageTableHeader {
            version: crate::FILE_VERSION,
            container: String::from("system"),
            file_size: 208,
            num_packages: 3,
            bucket_offset: 30,
            node_offset: 58,
        };
        let buckets: Vec<Option<u32>> = vec![Some(58), None, None, Some(108), None, None, None];
        let first_node = PackageTableNode {
            package_name: String::from("com.android.aconfig.storage.test_2"),
            package_id: 1,
            boolean_offset: 3,
            next_offset: None,
        };
        let second_node = PackageTableNode {
            package_name: String::from("com.android.aconfig.storage.test_1"),
            package_id: 0,
            boolean_offset: 0,
            next_offset: Some(158),
        };
        let third_node = PackageTableNode {
            package_name: String::from("com.android.aconfig.storage.test_4"),
            package_id: 2,
            boolean_offset: 6,
            next_offset: None,
        };
        let nodes = vec![first_node, second_node, third_node];
        PackageTable { header, buckets, nodes }
    }

    #[test]
    // this test point locks down the table serialization
    fn test_serialization() {
        let package_table = create_test_package_table();
        let header: &PackageTableHeader = &package_table.header;
        let reinterpreted_header = PackageTableHeader::from_bytes(&header.as_bytes());
        assert!(reinterpreted_header.is_ok());
        assert_eq!(header, &reinterpreted_header.unwrap());

        let nodes: &Vec<PackageTableNode> = &package_table.nodes;
        for node in nodes.iter() {
            let reinterpreted_node = PackageTableNode::from_bytes(&node.as_bytes()).unwrap();
            assert_eq!(node, &reinterpreted_node);
        }

        let reinterpreted_table = PackageTable::from_bytes(&package_table.as_bytes());
        assert!(reinterpreted_table.is_ok());
        assert_eq!(&package_table, &reinterpreted_table.unwrap());
    }

    #[test]
    // this test point locks down table query
    fn test_package_query() {
        let package_table = create_test_package_table().as_bytes();
        let package_offset =
            find_package_offset(&package_table[..], "com.android.aconfig.storage.test_1")
                .unwrap()
                .unwrap();
        let expected_package_offset = PackageOffset { package_id: 0, boolean_offset: 0 };
        assert_eq!(package_offset, expected_package_offset);
        let package_offset =
            find_package_offset(&package_table[..], "com.android.aconfig.storage.test_2")
                .unwrap()
                .unwrap();
        let expected_package_offset = PackageOffset { package_id: 1, boolean_offset: 3 };
        assert_eq!(package_offset, expected_package_offset);
        let package_offset =
            find_package_offset(&package_table[..], "com.android.aconfig.storage.test_4")
                .unwrap()
                .unwrap();
        let expected_package_offset = PackageOffset { package_id: 2, boolean_offset: 6 };
        assert_eq!(package_offset, expected_package_offset);
    }

    #[test]
    // this test point locks down table query of a non exist package
    fn test_not_existed_package_query() {
        // this will land at an empty bucket
        let package_table = create_test_package_table().as_bytes();
        let package_offset =
            find_package_offset(&package_table[..], "com.android.aconfig.storage.test_3").unwrap();
        assert_eq!(package_offset, None);
        // this will land at the end of a linked list
        let package_offset =
            find_package_offset(&package_table[..], "com.android.aconfig.storage.test_5").unwrap();
        assert_eq!(package_offset, None);
    }

    #[test]
    // this test point locks down query error when file has a higher version
    fn test_higher_version_storage_file() {
        let mut table = create_test_package_table();
        table.header.version = crate::FILE_VERSION + 1;
        let package_table = table.as_bytes();
        let error = find_package_offset(&package_table[..], "com.android.aconfig.storage.test_1")
            .unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            format!(
                "HigherStorageFileVersion(Cannot read storage file with a higher version of {} with lib version {})",
                crate::FILE_VERSION + 1,
                crate::FILE_VERSION
            )
        );
    }
}
