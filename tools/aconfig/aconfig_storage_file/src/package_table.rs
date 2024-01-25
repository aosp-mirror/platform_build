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

use crate::{read_str_from_bytes, read_u32_from_bytes};
use anyhow::Result;

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
    pub fn from_bytes(bytes: &[u8]) -> Result<Self> {
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
    pub bucket_index: u32,
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
    pub fn from_bytes(bytes: &[u8], num_buckets: u32) -> Result<Self> {
        let mut head = 0;
        let mut node = Self {
            package_name: read_str_from_bytes(bytes, &mut head)?,
            package_id: read_u32_from_bytes(bytes, &mut head)?,
            boolean_offset: read_u32_from_bytes(bytes, &mut head)?,
            next_offset: match read_u32_from_bytes(bytes, &mut head)? {
                0 => None,
                val => Some(val),
            },
            bucket_index: 0,
        };
        node.bucket_index = crate::get_bucket_index(&node.package_name, num_buckets);
        Ok(node)
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
    pub fn from_bytes(bytes: &[u8]) -> Result<Self> {
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
                let node = PackageTableNode::from_bytes(&bytes[head..], num_buckets).unwrap();
                head += node.as_bytes().len();
                node
            })
            .collect();

        let table = Self { header, buckets, nodes };
        Ok(table)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    pub fn create_test_package_table() -> Result<PackageTable> {
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
            bucket_index: 0,
        };
        let second_node = PackageTableNode {
            package_name: String::from("com.android.aconfig.storage.test_1"),
            package_id: 0,
            boolean_offset: 0,
            next_offset: Some(158),
            bucket_index: 3,
        };
        let third_node = PackageTableNode {
            package_name: String::from("com.android.aconfig.storage.test_4"),
            package_id: 2,
            boolean_offset: 6,
            next_offset: None,
            bucket_index: 3,
        };
        let nodes = vec![first_node, second_node, third_node];
        Ok(PackageTable { header, buckets, nodes })
    }

    #[test]
    // this test point locks down the table serialization
    fn test_serialization() {
        let package_table = create_test_package_table().unwrap();

        let header: &PackageTableHeader = &package_table.header;
        let reinterpreted_header = PackageTableHeader::from_bytes(&header.as_bytes());
        assert!(reinterpreted_header.is_ok());
        assert_eq!(header, &reinterpreted_header.unwrap());

        let nodes: &Vec<PackageTableNode> = &package_table.nodes;
        let num_buckets = crate::get_table_size(header.num_packages).unwrap();
        for node in nodes.iter() {
            let reinterpreted_node = PackageTableNode::from_bytes(&node.as_bytes(), num_buckets);
            assert!(reinterpreted_node.is_ok());
            assert_eq!(node, &reinterpreted_node.unwrap());
        }

        let reinterpreted_table = PackageTable::from_bytes(&package_table.as_bytes());
        assert!(reinterpreted_table.is_ok());
        assert_eq!(&package_table, &reinterpreted_table.unwrap());
    }
}
