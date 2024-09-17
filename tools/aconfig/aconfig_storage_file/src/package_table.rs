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

use crate::{get_bucket_index, read_str_from_bytes, read_u32_from_bytes, read_u8_from_bytes};
use crate::{AconfigStorageError, StorageFileType};
use anyhow::anyhow;
use serde::{Deserialize, Serialize};
use std::fmt;

/// Package table header struct
#[derive(PartialEq, Serialize, Deserialize)]
pub struct PackageTableHeader {
    pub version: u32,
    pub container: String,
    pub file_type: u8,
    pub file_size: u32,
    pub num_packages: u32,
    pub bucket_offset: u32,
    pub node_offset: u32,
}

/// Implement debug print trait for header
impl fmt::Debug for PackageTableHeader {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        writeln!(
            f,
            "Version: {}, Container: {}, File Type: {:?}, File Size: {}",
            self.version,
            self.container,
            StorageFileType::try_from(self.file_type),
            self.file_size
        )?;
        writeln!(
            f,
            "Num of Packages: {}, Bucket Offset:{}, Node Offset: {}",
            self.num_packages, self.bucket_offset, self.node_offset
        )?;
        Ok(())
    }
}

impl PackageTableHeader {
    /// Serialize to bytes
    pub fn into_bytes(&self) -> Vec<u8> {
        let mut result = Vec::new();
        result.extend_from_slice(&self.version.to_le_bytes());
        let container_bytes = self.container.as_bytes();
        result.extend_from_slice(&(container_bytes.len() as u32).to_le_bytes());
        result.extend_from_slice(container_bytes);
        result.extend_from_slice(&self.file_type.to_le_bytes());
        result.extend_from_slice(&self.file_size.to_le_bytes());
        result.extend_from_slice(&self.num_packages.to_le_bytes());
        result.extend_from_slice(&self.bucket_offset.to_le_bytes());
        result.extend_from_slice(&self.node_offset.to_le_bytes());
        result
    }

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AconfigStorageError> {
        let mut head = 0;
        let table = Self {
            version: read_u32_from_bytes(bytes, &mut head)?,
            container: read_str_from_bytes(bytes, &mut head)?,
            file_type: read_u8_from_bytes(bytes, &mut head)?,
            file_size: read_u32_from_bytes(bytes, &mut head)?,
            num_packages: read_u32_from_bytes(bytes, &mut head)?,
            bucket_offset: read_u32_from_bytes(bytes, &mut head)?,
            node_offset: read_u32_from_bytes(bytes, &mut head)?,
        };
        if table.file_type != StorageFileType::PackageMap as u8 {
            return Err(AconfigStorageError::BytesParseFail(anyhow!(
                "binary file is not a package map"
            )));
        }
        Ok(table)
    }
}

/// Package table node struct
#[derive(PartialEq, Serialize, Deserialize)]
pub struct PackageTableNode {
    pub package_name: String,
    pub package_id: u32,
    // The index of the first boolean flag in this aconfig package among all boolean
    // flags in this container.
    pub boolean_start_index: u32,
    pub next_offset: Option<u32>,
}

/// Implement debug print trait for node
impl fmt::Debug for PackageTableNode {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        writeln!(
            f,
            "Package: {}, Id: {}, Boolean flag start index: {}, Next: {:?}",
            self.package_name, self.package_id, self.boolean_start_index, self.next_offset
        )?;
        Ok(())
    }
}

impl PackageTableNode {
    /// Serialize to bytes
    pub fn into_bytes(&self) -> Vec<u8> {
        let mut result = Vec::new();
        let name_bytes = self.package_name.as_bytes();
        result.extend_from_slice(&(name_bytes.len() as u32).to_le_bytes());
        result.extend_from_slice(name_bytes);
        result.extend_from_slice(&self.package_id.to_le_bytes());
        result.extend_from_slice(&self.boolean_start_index.to_le_bytes());
        result.extend_from_slice(&self.next_offset.unwrap_or(0).to_le_bytes());
        result
    }

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AconfigStorageError> {
        let mut head = 0;
        let node = Self {
            package_name: read_str_from_bytes(bytes, &mut head)?,
            package_id: read_u32_from_bytes(bytes, &mut head)?,
            boolean_start_index: read_u32_from_bytes(bytes, &mut head)?,
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
        get_bucket_index(package.as_bytes(), num_buckets)
    }
}

/// Package table struct
#[derive(PartialEq, Serialize, Deserialize)]
pub struct PackageTable {
    pub header: PackageTableHeader,
    pub buckets: Vec<Option<u32>>,
    pub nodes: Vec<PackageTableNode>,
}

/// Implement debug print trait for package table
impl fmt::Debug for PackageTable {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        writeln!(f, "Header:")?;
        write!(f, "{:?}", self.header)?;
        writeln!(f, "Buckets:")?;
        writeln!(f, "{:?}", self.buckets)?;
        writeln!(f, "Nodes:")?;
        for node in self.nodes.iter() {
            write!(f, "{:?}", node)?;
        }
        Ok(())
    }
}

impl PackageTable {
    /// Serialize to bytes
    pub fn into_bytes(&self) -> Vec<u8> {
        [
            self.header.into_bytes(),
            self.buckets.iter().map(|v| v.unwrap_or(0).to_le_bytes()).collect::<Vec<_>>().concat(),
            self.nodes.iter().map(|v| v.into_bytes()).collect::<Vec<_>>().concat(),
        ]
        .concat()
    }

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AconfigStorageError> {
        let header = PackageTableHeader::from_bytes(bytes)?;
        let num_packages = header.num_packages;
        let num_buckets = crate::get_table_size(num_packages)?;
        let mut head = header.into_bytes().len();
        let buckets = (0..num_buckets)
            .map(|_| match read_u32_from_bytes(bytes, &mut head).unwrap() {
                0 => None,
                val => Some(val),
            })
            .collect();
        let nodes = (0..num_packages)
            .map(|_| {
                let node = PackageTableNode::from_bytes(&bytes[head..])?;
                head += node.into_bytes().len();
                Ok(node)
            })
            .collect::<Result<Vec<_>, AconfigStorageError>>()
            .map_err(|errmsg| {
                AconfigStorageError::BytesParseFail(anyhow!(
                    "fail to parse package table: {}",
                    errmsg
                ))
            })?;

        let table = Self { header, buckets, nodes };
        Ok(table)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::create_test_package_table;

    #[test]
    // this test point locks down the table serialization
    fn test_serialization() {
        let package_table = create_test_package_table();
        let header: &PackageTableHeader = &package_table.header;
        let reinterpreted_header = PackageTableHeader::from_bytes(&header.into_bytes());
        assert!(reinterpreted_header.is_ok());
        assert_eq!(header, &reinterpreted_header.unwrap());

        let nodes: &Vec<PackageTableNode> = &package_table.nodes;
        for node in nodes.iter() {
            let reinterpreted_node = PackageTableNode::from_bytes(&node.into_bytes()).unwrap();
            assert_eq!(node, &reinterpreted_node);
        }

        let package_table_bytes = package_table.into_bytes();
        let reinterpreted_table = PackageTable::from_bytes(&package_table_bytes);
        assert!(reinterpreted_table.is_ok());
        assert_eq!(&package_table, &reinterpreted_table.unwrap());
        assert_eq!(package_table_bytes.len() as u32, header.file_size);
    }

    #[test]
    // this test point locks down that version number should be at the top of serialized
    // bytes
    fn test_version_number() {
        let package_table = create_test_package_table();
        let bytes = &package_table.into_bytes();
        let mut head = 0;
        let version = read_u32_from_bytes(bytes, &mut head).unwrap();
        assert_eq!(version, 1);
    }

    #[test]
    // this test point locks down file type check
    fn test_file_type_check() {
        let mut package_table = create_test_package_table();
        package_table.header.file_type = 123u8;
        let error = PackageTable::from_bytes(&package_table.into_bytes()).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            format!("BytesParseFail(binary file is not a package map)")
        );
    }
}
