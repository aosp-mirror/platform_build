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

use crate::commands::assign_flag_ids;
use crate::storage::{self, FlagPackage};
use anyhow::{anyhow, Result};

#[derive(PartialEq, Debug)]
pub struct FlagTableHeader {
    pub version: u32,
    pub container: String,
    pub file_size: u32,
    pub num_flags: u32,
    pub bucket_offset: u32,
    pub node_offset: u32,
}

impl FlagTableHeader {
    fn new(container: &str, num_flags: u32) -> Self {
        Self {
            version: storage::FILE_VERSION,
            container: String::from(container),
            file_size: 0,
            num_flags,
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
        result.extend_from_slice(&self.num_flags.to_le_bytes());
        result.extend_from_slice(&self.bucket_offset.to_le_bytes());
        result.extend_from_slice(&self.node_offset.to_le_bytes());
        result
    }
}

#[derive(PartialEq, Debug, Clone)]
pub struct FlagTableNode {
    pub package_id: u32,
    pub flag_name: String,
    pub flag_type: u16,
    pub flag_id: u16,
    pub next_offset: Option<u32>,
    pub bucket_index: u32,
}

impl FlagTableNode {
    fn new(
        package_id: u32,
        flag_name: &str,
        flag_type: u16,
        flag_id: u16,
        num_buckets: u32,
    ) -> Self {
        let full_flag_name = package_id.to_string() + "/" + flag_name;
        let bucket_index = storage::get_bucket_index(&full_flag_name, num_buckets);
        Self {
            package_id,
            flag_name: flag_name.to_string(),
            flag_type,
            flag_id,
            next_offset: None,
            bucket_index,
        }
    }

    fn as_bytes(&self) -> Vec<u8> {
        let mut result = Vec::new();
        result.extend_from_slice(&self.package_id.to_le_bytes());
        let name_bytes = self.flag_name.as_bytes();
        result.extend_from_slice(&(name_bytes.len() as u32).to_le_bytes());
        result.extend_from_slice(name_bytes);
        result.extend_from_slice(&self.flag_type.to_le_bytes());
        result.extend_from_slice(&self.flag_id.to_le_bytes());
        result.extend_from_slice(&self.next_offset.unwrap_or(0).to_le_bytes());
        result
    }
}

#[derive(PartialEq, Debug)]
pub struct FlagTable {
    pub header: FlagTableHeader,
    pub buckets: Vec<Option<u32>>,
    pub nodes: Vec<FlagTableNode>,
}

impl FlagTable {
    fn create_nodes(package: &FlagPackage, num_buckets: u32) -> Result<Vec<FlagTableNode>> {
        let flag_ids =
            assign_flag_ids(package.package_name, package.boolean_flags.iter().copied())?;
        package
            .boolean_flags
            .iter()
            .map(|&pf| {
                let fid = flag_ids
                    .get(pf.name())
                    .ok_or(anyhow!(format!("missing flag id for {}", pf.name())))?;
                // all flags are boolean value at the moment, thus using the last bit. When more
                // flag value types are supported, flag value type information should come from the
                // parsed flag, and we will set the flag_type bit mask properly.
                let flag_type = 1;
                Ok(FlagTableNode::new(package.package_id, pf.name(), flag_type, *fid, num_buckets))
            })
            .collect::<Result<Vec<_>>>()
    }

    pub fn new(container: &str, packages: &[FlagPackage]) -> Result<Self> {
        // create table
        let num_flags = packages.iter().map(|pkg| pkg.boolean_flags.len() as u32).sum();
        let num_buckets = storage::get_table_size(num_flags)?;

        let mut table = Self {
            header: FlagTableHeader::new(container, num_flags),
            buckets: vec![None; num_buckets as usize],
            nodes: packages
                .iter()
                .map(|pkg| FlagTable::create_nodes(pkg, num_buckets))
                .collect::<Result<Vec<_>>>()?
                .concat(),
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
        tests::read_u16_from_bytes, tests::read_u32_from_bytes,
    };

    impl FlagTableHeader {
        // test only method to deserialize back into the header struct
        fn from_bytes(bytes: &[u8]) -> Result<Self> {
            let mut head = 0;
            Ok(Self {
                version: read_u32_from_bytes(bytes, &mut head)?,
                container: read_str_from_bytes(bytes, &mut head)?,
                file_size: read_u32_from_bytes(bytes, &mut head)?,
                num_flags: read_u32_from_bytes(bytes, &mut head)?,
                bucket_offset: read_u32_from_bytes(bytes, &mut head)?,
                node_offset: read_u32_from_bytes(bytes, &mut head)?,
            })
        }
    }

    impl FlagTableNode {
        // test only method to deserialize back into the node struct
        fn from_bytes(bytes: &[u8], num_buckets: u32) -> Result<Self> {
            let mut head = 0;
            let mut node = Self {
                package_id: read_u32_from_bytes(bytes, &mut head)?,
                flag_name: read_str_from_bytes(bytes, &mut head)?,
                flag_type: read_u16_from_bytes(bytes, &mut head)?,
                flag_id: read_u16_from_bytes(bytes, &mut head)?,
                next_offset: match read_u32_from_bytes(bytes, &mut head)? {
                    0 => None,
                    val => Some(val),
                },
                bucket_index: 0,
            };
            let full_flag_name = node.package_id.to_string() + "/" + &node.flag_name;
            node.bucket_index = storage::get_bucket_index(&full_flag_name, num_buckets);
            Ok(node)
        }

        // create test baseline, syntactic sugar
        fn new_expected(
            package_id: u32,
            flag_name: &str,
            flag_type: u16,
            flag_id: u16,
            next_offset: Option<u32>,
            bucket_index: u32,
        ) -> Self {
            Self {
                package_id,
                flag_name: flag_name.to_string(),
                flag_type,
                flag_id,
                next_offset,
                bucket_index,
            }
        }
    }

    impl FlagTable {
        // test only method to deserialize back into the table struct
        fn from_bytes(bytes: &[u8]) -> Result<Self> {
            let header = FlagTableHeader::from_bytes(bytes)?;
            let num_flags = header.num_flags;
            let num_buckets = storage::get_table_size(num_flags)?;
            let mut head = header.as_bytes().len();
            let buckets = (0..num_buckets)
                .map(|_| match read_u32_from_bytes(bytes, &mut head).unwrap() {
                    0 => None,
                    val => Some(val),
                })
                .collect();
            let nodes = (0..num_flags)
                .map(|_| {
                    let node = FlagTableNode::from_bytes(&bytes[head..], num_buckets).unwrap();
                    head += node.as_bytes().len();
                    node
                })
                .collect();

            let table = Self { header, buckets, nodes };
            Ok(table)
        }
    }

    pub fn create_test_flag_table() -> Result<FlagTable> {
        let caches = parse_all_test_flags();
        let packages = group_flags_by_package(caches.iter());
        FlagTable::new("system", &packages)
    }

    #[test]
    // this test point locks down the table creation and each field
    fn test_table_contents() {
        let flag_table = create_test_flag_table();
        assert!(flag_table.is_ok());

        let header: &FlagTableHeader = &flag_table.as_ref().unwrap().header;
        let expected_header = FlagTableHeader {
            version: storage::FILE_VERSION,
            container: String::from("system"),
            file_size: 320,
            num_flags: 8,
            bucket_offset: 30,
            node_offset: 98,
        };
        assert_eq!(header, &expected_header);

        let buckets: &Vec<Option<u32>> = &flag_table.as_ref().unwrap().buckets;
        let expected_bucket: Vec<Option<u32>> = vec![
            Some(98),
            Some(124),
            None,
            None,
            None,
            Some(177),
            None,
            Some(203),
            None,
            Some(261),
            None,
            None,
            None,
            None,
            None,
            Some(293),
            None,
        ];
        assert_eq!(buckets, &expected_bucket);

        let nodes: &Vec<FlagTableNode> = &flag_table.as_ref().unwrap().nodes;
        assert_eq!(nodes.len(), 8);

        assert_eq!(nodes[0], FlagTableNode::new_expected(0, "enabled_ro", 1, 1, None, 0));
        assert_eq!(nodes[1], FlagTableNode::new_expected(0, "enabled_rw", 1, 2, Some(150), 1));
        assert_eq!(nodes[2], FlagTableNode::new_expected(1, "disabled_ro", 1, 0, None, 1));
        assert_eq!(nodes[3], FlagTableNode::new_expected(2, "enabled_ro", 1, 1, None, 5));
        assert_eq!(
            nodes[4],
            FlagTableNode::new_expected(1, "enabled_fixed_ro", 1, 1, Some(235), 7)
        );
        assert_eq!(nodes[5], FlagTableNode::new_expected(1, "enabled_ro", 1, 2, None, 7));
        assert_eq!(nodes[6], FlagTableNode::new_expected(2, "enabled_fixed_ro", 1, 0, None, 9));
        assert_eq!(nodes[7], FlagTableNode::new_expected(0, "disabled_rw", 1, 0, None, 15));
    }

    #[test]
    // this test point locks down the table serialization
    fn test_serialization() {
        let flag_table = create_test_flag_table().unwrap();

        let header: &FlagTableHeader = &flag_table.header;
        let reinterpreted_header = FlagTableHeader::from_bytes(&header.as_bytes());
        assert!(reinterpreted_header.is_ok());
        assert_eq!(header, &reinterpreted_header.unwrap());

        let nodes: &Vec<FlagTableNode> = &flag_table.nodes;
        let num_buckets = storage::get_table_size(header.num_flags).unwrap();
        for node in nodes.iter() {
            let reinterpreted_node = FlagTableNode::from_bytes(&node.as_bytes(), num_buckets);
            assert!(reinterpreted_node.is_ok());
            assert_eq!(node, &reinterpreted_node.unwrap());
        }

        let reinterpreted_table = FlagTable::from_bytes(&flag_table.as_bytes());
        assert!(reinterpreted_table.is_ok());
        assert_eq!(&flag_table, &reinterpreted_table.unwrap());
    }
}
