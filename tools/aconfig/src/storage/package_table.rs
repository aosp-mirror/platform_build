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

use crate::storage::{self, FlagPackage};
use anyhow::Result;

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
    fn new(container: &str, num_packages: u32) -> Self {
        Self {
            version: storage::FILE_VERSION,
            container: String::from(container),
            file_size: 0,
            num_packages,
            bucket_offset: 0,
            node_offset: 0,
        }
    }

    fn as_bytes(&self) -> Vec<u8> {
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
}

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
    fn new(package: &FlagPackage, num_buckets: u32) -> Self {
        let bucket_index =
            storage::get_bucket_index(&package.package_name.to_string(), num_buckets);
        Self {
            package_name: String::from(package.package_name),
            package_id: package.package_id,
            boolean_offset: package.boolean_offset,
            next_offset: None,
            bucket_index,
        }
    }

    fn as_bytes(&self) -> Vec<u8> {
        let mut result = Vec::new();
        let name_bytes = self.package_name.as_bytes();
        result.extend_from_slice(&(name_bytes.len() as u32).to_le_bytes());
        result.extend_from_slice(name_bytes);
        result.extend_from_slice(&self.package_id.to_le_bytes());
        result.extend_from_slice(&self.boolean_offset.to_le_bytes());
        result.extend_from_slice(&self.next_offset.unwrap_or(0).to_le_bytes());
        result
    }
}

#[derive(PartialEq, Debug)]
pub struct PackageTable {
    pub header: PackageTableHeader,
    pub buckets: Vec<Option<u32>>,
    pub nodes: Vec<PackageTableNode>,
}

impl PackageTable {
    pub fn new(container: &str, packages: &[FlagPackage]) -> Result<Self> {
        // create table
        let num_packages = packages.len() as u32;
        let num_buckets = storage::get_table_size(num_packages)?;
        let mut table = Self {
            header: PackageTableHeader::new(container, num_packages),
            buckets: vec![None; num_buckets as usize],
            nodes: packages.iter().map(|pkg| PackageTableNode::new(pkg, num_buckets)).collect(),
        };

        // initialize all header fields
        table.header.bucket_offset = table.header.as_bytes().len() as u32;
        table.header.node_offset = table.header.bucket_offset + num_buckets * 4;
        table.header.file_size = table.header.node_offset
            + table.nodes.iter().map(|x| x.as_bytes().len()).sum::<usize>() as u32;

        // sort nodes by bucket index for efficiency
        table.nodes.sort_by(|a, b| a.bucket_index.cmp(&b.bucket_index));

        // fill all node offset
        let mut offset = table.header.node_offset;
        for i in 0..table.nodes.len() {
            let node_bucket_idx = table.nodes[i].bucket_index;
            let next_node_bucket_idx = if i + 1 < table.nodes.len() {
                Some(table.nodes[i + 1].bucket_index)
            } else {
                None
            };

            if table.buckets[node_bucket_idx as usize].is_none() {
                table.buckets[node_bucket_idx as usize] = Some(offset);
            }
            offset += table.nodes[i].as_bytes().len() as u32;

            if let Some(index) = next_node_bucket_idx {
                if index == node_bucket_idx {
                    table.nodes[i].next_offset = Some(offset);
                }
            }
        }

        Ok(table)
    }

    pub fn as_bytes(&self) -> Vec<u8> {
        [
            self.header.as_bytes(),
            self.buckets.iter().map(|v| v.unwrap_or(0).to_le_bytes()).collect::<Vec<_>>().concat(),
            self.nodes.iter().map(|v| v.as_bytes()).collect::<Vec<_>>().concat(),
        ]
        .concat()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::{
        group_flags_by_package, tests::parse_all_test_flags, tests::read_str_from_bytes,
        tests::read_u32_from_bytes,
    };

    impl PackageTableHeader {
        // test only method to deserialize back into the header struct
        fn from_bytes(bytes: &[u8]) -> Result<Self> {
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

    impl PackageTableNode {
        // test only method to deserialize back into the node struct
        fn from_bytes(bytes: &[u8], num_buckets: u32) -> Result<Self> {
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
            node.bucket_index = storage::get_bucket_index(&node.package_name, num_buckets);
            Ok(node)
        }
    }

    impl PackageTable {
        // test only method to deserialize back into the table struct
        fn from_bytes(bytes: &[u8]) -> Result<Self> {
            let header = PackageTableHeader::from_bytes(bytes)?;
            let num_packages = header.num_packages;
            let num_buckets = storage::get_table_size(num_packages)?;
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

    pub fn create_test_package_table() -> Result<PackageTable> {
        let caches = parse_all_test_flags();
        let packages = group_flags_by_package(caches.iter());
        PackageTable::new("system", &packages)
    }

    #[test]
    // this test point locks down the table creation and each field
    fn test_table_contents() {
        let package_table = create_test_package_table();
        assert!(package_table.is_ok());

        let header: &PackageTableHeader = &package_table.as_ref().unwrap().header;
        let expected_header = PackageTableHeader {
            version: storage::FILE_VERSION,
            container: String::from("system"),
            file_size: 208,
            num_packages: 3,
            bucket_offset: 30,
            node_offset: 58,
        };
        assert_eq!(header, &expected_header);

        let buckets: &Vec<Option<u32>> = &package_table.as_ref().unwrap().buckets;
        let expected: Vec<Option<u32>> = vec![Some(58), None, None, Some(108), None, None, None];
        assert_eq!(buckets, &expected);

        let nodes: &Vec<PackageTableNode> = &package_table.as_ref().unwrap().nodes;
        assert_eq!(nodes.len(), 3);
        let first_node_expected = PackageTableNode {
            package_name: String::from("com.android.aconfig.storage.test_2"),
            package_id: 1,
            boolean_offset: 3,
            next_offset: None,
            bucket_index: 0,
        };
        assert_eq!(nodes[0], first_node_expected);
        let second_node_expected = PackageTableNode {
            package_name: String::from("com.android.aconfig.storage.test_1"),
            package_id: 0,
            boolean_offset: 0,
            next_offset: Some(158),
            bucket_index: 3,
        };
        assert_eq!(nodes[1], second_node_expected);
        let third_node_expected = PackageTableNode {
            package_name: String::from("com.android.aconfig.storage.test_4"),
            package_id: 2,
            boolean_offset: 6,
            next_offset: None,
            bucket_index: 3,
        };
        assert_eq!(nodes[2], third_node_expected);
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
        let num_buckets = storage::get_table_size(header.num_packages).unwrap();
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
