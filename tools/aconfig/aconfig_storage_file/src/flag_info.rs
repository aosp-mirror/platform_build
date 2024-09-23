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

//! flag info module defines the flag info file format and methods for serialization
//! and deserialization

use crate::{read_str_from_bytes, read_u32_from_bytes, read_u8_from_bytes};
use crate::{AconfigStorageError, StorageFileType};
use anyhow::anyhow;
use serde::{Deserialize, Serialize};
use std::fmt;

/// Flag info header struct
#[derive(PartialEq, Serialize, Deserialize)]
pub struct FlagInfoHeader {
    pub version: u32,
    pub container: String,
    pub file_type: u8,
    pub file_size: u32,
    pub num_flags: u32,
    pub boolean_flag_offset: u32,
}

/// Implement debug print trait for header
impl fmt::Debug for FlagInfoHeader {
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
            "Num of Flags: {}, Boolean Flag Offset:{}",
            self.num_flags, self.boolean_flag_offset
        )?;
        Ok(())
    }
}

impl FlagInfoHeader {
    /// Serialize to bytes
    pub fn into_bytes(&self) -> Vec<u8> {
        let mut result = Vec::new();
        result.extend_from_slice(&self.version.to_le_bytes());
        let container_bytes = self.container.as_bytes();
        result.extend_from_slice(&(container_bytes.len() as u32).to_le_bytes());
        result.extend_from_slice(container_bytes);
        result.extend_from_slice(&self.file_type.to_le_bytes());
        result.extend_from_slice(&self.file_size.to_le_bytes());
        result.extend_from_slice(&self.num_flags.to_le_bytes());
        result.extend_from_slice(&self.boolean_flag_offset.to_le_bytes());
        result
    }

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AconfigStorageError> {
        let mut head = 0;
        let list = Self {
            version: read_u32_from_bytes(bytes, &mut head)?,
            container: read_str_from_bytes(bytes, &mut head)?,
            file_type: read_u8_from_bytes(bytes, &mut head)?,
            file_size: read_u32_from_bytes(bytes, &mut head)?,
            num_flags: read_u32_from_bytes(bytes, &mut head)?,
            boolean_flag_offset: read_u32_from_bytes(bytes, &mut head)?,
        };
        if list.file_type != StorageFileType::FlagInfo as u8 {
            return Err(AconfigStorageError::BytesParseFail(anyhow!(
                "binary file is not a flag info file"
            )));
        }
        Ok(list)
    }
}

/// bit field for flag info
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum FlagInfoBit {
    HasServerOverride = 1 << 0,
    IsReadWrite = 1 << 1,
    HasLocalOverride = 1 << 2,
}

/// Flag info node struct
#[derive(PartialEq, Clone, Serialize, Deserialize)]
pub struct FlagInfoNode {
    pub attributes: u8,
}

/// Implement debug print trait for node
impl fmt::Debug for FlagInfoNode {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        writeln!(
            f,
            "readwrite: {}, server override: {}, local override: {}",
            self.attributes & (FlagInfoBit::IsReadWrite as u8) != 0,
            self.attributes & (FlagInfoBit::HasServerOverride as u8) != 0,
            self.attributes & (FlagInfoBit::HasLocalOverride as u8) != 0,
        )?;
        Ok(())
    }
}

impl FlagInfoNode {
    /// Serialize to bytes
    pub fn into_bytes(&self) -> Vec<u8> {
        let mut result = Vec::new();
        result.extend_from_slice(&self.attributes.to_le_bytes());
        result
    }

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AconfigStorageError> {
        let mut head = 0;
        let node = Self { attributes: read_u8_from_bytes(bytes, &mut head)? };
        Ok(node)
    }

    /// Create flag info node
    pub fn create(is_flag_rw: bool) -> Self {
        Self { attributes: if is_flag_rw { FlagInfoBit::IsReadWrite as u8 } else { 0u8 } }
    }
}

/// Flag info list struct
#[derive(PartialEq, Serialize, Deserialize)]
pub struct FlagInfoList {
    pub header: FlagInfoHeader,
    pub nodes: Vec<FlagInfoNode>,
}

/// Implement debug print trait for flag info list
impl fmt::Debug for FlagInfoList {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        writeln!(f, "Header:")?;
        write!(f, "{:?}", self.header)?;
        writeln!(f, "Nodes:")?;
        for node in self.nodes.iter() {
            write!(f, "{:?}", node)?;
        }
        Ok(())
    }
}

impl FlagInfoList {
    /// Serialize to bytes
    pub fn into_bytes(&self) -> Vec<u8> {
        [
            self.header.into_bytes(),
            self.nodes.iter().map(|v| v.into_bytes()).collect::<Vec<_>>().concat(),
        ]
        .concat()
    }

    /// Deserialize from bytes
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, AconfigStorageError> {
        let header = FlagInfoHeader::from_bytes(bytes)?;
        let num_flags = header.num_flags;
        let mut head = header.into_bytes().len();
        let nodes = (0..num_flags)
            .map(|_| {
                let node = FlagInfoNode::from_bytes(&bytes[head..])?;
                head += node.into_bytes().len();
                Ok(node)
            })
            .collect::<Result<Vec<_>, AconfigStorageError>>()
            .map_err(|errmsg| {
                AconfigStorageError::BytesParseFail(anyhow!(
                    "fail to parse flag info list: {}",
                    errmsg
                ))
            })?;
        let list = Self { header, nodes };
        Ok(list)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::create_test_flag_info_list;

    #[test]
    // this test point locks down the value list serialization
    fn test_serialization() {
        let flag_info_list = create_test_flag_info_list();

        let header: &FlagInfoHeader = &flag_info_list.header;
        let reinterpreted_header = FlagInfoHeader::from_bytes(&header.into_bytes());
        assert!(reinterpreted_header.is_ok());
        assert_eq!(header, &reinterpreted_header.unwrap());

        let nodes: &Vec<FlagInfoNode> = &flag_info_list.nodes;
        for node in nodes.iter() {
            let reinterpreted_node = FlagInfoNode::from_bytes(&node.into_bytes()).unwrap();
            assert_eq!(node, &reinterpreted_node);
        }

        let flag_info_bytes = flag_info_list.into_bytes();
        let reinterpreted_info_list = FlagInfoList::from_bytes(&flag_info_bytes);
        assert!(reinterpreted_info_list.is_ok());
        assert_eq!(&flag_info_list, &reinterpreted_info_list.unwrap());
        assert_eq!(flag_info_bytes.len() as u32, header.file_size);
    }

    #[test]
    // this test point locks down that version number should be at the top of serialized
    // bytes
    fn test_version_number() {
        let flag_info_list = create_test_flag_info_list();
        let bytes = &flag_info_list.into_bytes();
        let mut head = 0;
        let version = read_u32_from_bytes(bytes, &mut head).unwrap();
        assert_eq!(version, 1);
    }

    #[test]
    // this test point locks down file type check
    fn test_file_type_check() {
        let mut flag_info_list = create_test_flag_info_list();
        flag_info_list.header.file_type = 123u8;
        let error = FlagInfoList::from_bytes(&flag_info_list.into_bytes()).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            format!("BytesParseFail(binary file is not a flag info file)")
        );
    }
}
