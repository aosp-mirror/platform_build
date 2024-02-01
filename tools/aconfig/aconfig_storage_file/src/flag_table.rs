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

use crate::AconfigStorageError::{self, BytesParseFail, HigherStorageFileVersion};
use crate::{get_bucket_index, read_str_from_bytes, read_u16_from_bytes, read_u32_from_bytes};
use anyhow::anyhow;
pub type FlagOffset = u16;

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
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AconfigStorageError> {
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
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AconfigStorageError> {
        let mut head = 0;
        let node = Self {
            package_id: read_u32_from_bytes(bytes, &mut head)?,
            flag_name: read_str_from_bytes(bytes, &mut head)?,
            flag_type: read_u16_from_bytes(bytes, &mut head)?,
            flag_id: read_u16_from_bytes(bytes, &mut head)?,
            next_offset: match read_u32_from_bytes(bytes, &mut head)? {
                0 => None,
                val => Some(val),
            },
        };
        Ok(node)
    }

    /// Calculate node bucket index
    pub fn find_bucket_index(package_id: u32, flag_name: &str, num_buckets: u32) -> u32 {
        let full_flag_name = package_id.to_string() + "/" + flag_name;
        get_bucket_index(&full_flag_name, num_buckets)
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
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AconfigStorageError> {
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
                let node = FlagTableNode::from_bytes(&bytes[head..])?;
                head += node.as_bytes().len();
                Ok(node)
            })
            .collect::<Result<Vec<_>, AconfigStorageError>>()
            .map_err(|errmsg| BytesParseFail(anyhow!("fail to parse flag table: {}", errmsg)))?;

        let table = Self { header, buckets, nodes };
        Ok(table)
    }
}

/// Query flag within package offset
pub fn find_flag_offset(
    buf: &[u8],
    package_id: u32,
    flag: &str,
) -> Result<Option<FlagOffset>, AconfigStorageError> {
    let interpreted_header = FlagTableHeader::from_bytes(buf)?;
    if interpreted_header.version > crate::FILE_VERSION {
        return Err(HigherStorageFileVersion(anyhow!(
            "Cannot read storage file with a higher version of {} with lib version {}",
            interpreted_header.version,
            crate::FILE_VERSION
        )));
    }

    let num_buckets = (interpreted_header.node_offset - interpreted_header.bucket_offset) / 4;
    let bucket_index = FlagTableNode::find_bucket_index(package_id, flag, num_buckets);

    let mut pos = (interpreted_header.bucket_offset + 4 * bucket_index) as usize;
    let mut flag_node_offset = read_u32_from_bytes(buf, &mut pos)? as usize;
    if flag_node_offset < interpreted_header.node_offset as usize
        || flag_node_offset >= interpreted_header.file_size as usize
    {
        return Ok(None);
    }

    loop {
        let interpreted_node = FlagTableNode::from_bytes(&buf[flag_node_offset..])?;
        if interpreted_node.package_id == package_id && interpreted_node.flag_name == flag {
            return Ok(Some(interpreted_node.flag_id));
        }
        match interpreted_node.next_offset {
            Some(offset) => flag_node_offset = offset as usize,
            None => return Ok(None),
        }
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
        ) -> Self {
            Self { package_id, flag_name: flag_name.to_string(), flag_type, flag_id, next_offset }
        }
    }

    pub fn create_test_flag_table() -> FlagTable {
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
            FlagTableNode::new_expected(0, "enabled_ro", 1, 1, None),
            FlagTableNode::new_expected(0, "enabled_rw", 1, 2, Some(150)),
            FlagTableNode::new_expected(1, "disabled_ro", 1, 0, None),
            FlagTableNode::new_expected(2, "enabled_ro", 1, 1, None),
            FlagTableNode::new_expected(1, "enabled_fixed_ro", 1, 1, Some(235)),
            FlagTableNode::new_expected(1, "enabled_ro", 1, 2, None),
            FlagTableNode::new_expected(2, "enabled_fixed_ro", 1, 0, None),
            FlagTableNode::new_expected(0, "disabled_rw", 1, 0, None),
        ];
        FlagTable { header, buckets, nodes }
    }

    #[test]
    // this test point locks down the table serialization
    fn test_serialization() {
        let flag_table = create_test_flag_table();

        let header: &FlagTableHeader = &flag_table.header;
        let reinterpreted_header = FlagTableHeader::from_bytes(&header.as_bytes());
        assert!(reinterpreted_header.is_ok());
        assert_eq!(header, &reinterpreted_header.unwrap());

        let nodes: &Vec<FlagTableNode> = &flag_table.nodes;
        for node in nodes.iter() {
            let reinterpreted_node = FlagTableNode::from_bytes(&node.as_bytes()).unwrap();
            assert_eq!(node, &reinterpreted_node);
        }

        let reinterpreted_table = FlagTable::from_bytes(&flag_table.as_bytes());
        assert!(reinterpreted_table.is_ok());
        assert_eq!(&flag_table, &reinterpreted_table.unwrap());
    }

    #[test]
    // this test point locks down table query
    fn test_flag_query() {
        let flag_table = create_test_flag_table().as_bytes();
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
                find_flag_offset(&flag_table[..], package_id, flag_name).unwrap().unwrap();
            assert_eq!(flag_offset, expected_offset);
        }
    }

    #[test]
    // this test point locks down table query of a non exist flag
    fn test_not_existed_flag_query() {
        let flag_table = create_test_flag_table().as_bytes();
        let flag_offset = find_flag_offset(&flag_table[..], 1, "disabled_fixed_ro").unwrap();
        assert_eq!(flag_offset, None);
        let flag_offset = find_flag_offset(&flag_table[..], 2, "disabled_rw").unwrap();
        assert_eq!(flag_offset, None);
    }

    #[test]
    // this test point locks down query error when file has a higher version
    fn test_higher_version_storage_file() {
        let mut table = create_test_flag_table();
        table.header.version = crate::FILE_VERSION + 1;
        let flag_table = table.as_bytes();
        let error = find_flag_offset(&flag_table[..], 0, "enabled_ro").unwrap_err();
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
