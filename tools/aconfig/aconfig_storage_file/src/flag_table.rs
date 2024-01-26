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

//! flag table module defines the flag table file format and methods for serialization
//! and deserialization

use crate::{read_str_from_bytes, read_u16_from_bytes, read_u32_from_bytes};
use anyhow::Result;

/// Flag table header struct
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
    /// Serialize to bytes
    pub fn as_bytes(&self) -> Vec<u8> {
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

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8]) -> Result<Self> {
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

/// Flag table node struct
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
    /// Serialize to bytes
    pub fn as_bytes(&self) -> Vec<u8> {
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

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8], num_buckets: u32) -> Result<Self> {
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
        node.bucket_index = crate::get_bucket_index(&full_flag_name, num_buckets);
        Ok(node)
    }
}

#[derive(PartialEq, Debug)]
pub struct FlagTable {
    pub header: FlagTableHeader,
    pub buckets: Vec<Option<u32>>,
    pub nodes: Vec<FlagTableNode>,
}

/// Flag table struct
impl FlagTable {
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
        let header = FlagTableHeader::from_bytes(bytes)?;
        let num_flags = header.num_flags;
        let num_buckets = crate::get_table_size(num_flags)?;
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

#[cfg(test)]
mod tests {
    use super::*;

    impl FlagTableNode {
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

    pub fn create_test_flag_table() -> Result<FlagTable> {
        let header = FlagTableHeader {
            version: crate::FILE_VERSION,
            container: String::from("system"),
            file_size: 320,
            num_flags: 8,
            bucket_offset: 30,
            node_offset: 98,
        };
        let buckets: Vec<Option<u32>> = vec![
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
        let nodes = vec![
            FlagTableNode::new_expected(0, "enabled_ro", 1, 1, None, 0),
            FlagTableNode::new_expected(0, "enabled_rw", 1, 2, Some(150), 1),
            FlagTableNode::new_expected(1, "disabled_ro", 1, 0, None, 1),
            FlagTableNode::new_expected(2, "enabled_ro", 1, 1, None, 5),
            FlagTableNode::new_expected(1, "enabled_fixed_ro", 1, 1, Some(235), 7),
            FlagTableNode::new_expected(1, "enabled_ro", 1, 2, None, 7),
            FlagTableNode::new_expected(2, "enabled_fixed_ro", 1, 0, None, 9),
            FlagTableNode::new_expected(0, "disabled_rw", 1, 0, None, 15),
        ];
        Ok(FlagTable { header, buckets, nodes })
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
        let num_buckets = crate::get_table_size(header.num_flags).unwrap();
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
