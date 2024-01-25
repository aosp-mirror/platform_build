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
use aconfig_protos::ProtoFlagState;
use crate::storage::{self, FlagPackage};
use anyhow::{anyhow, Result};

#[derive(PartialEq, Debug)]
pub struct FlagValueHeader {
    pub version: u32,
    pub container: String,
    pub file_size: u32,
    pub num_flags: u32,
    pub boolean_value_offset: u32,
}

impl FlagValueHeader {
    fn new(container: &str, num_flags: u32) -> Self {
        Self {
            version: storage::FILE_VERSION,
            container: String::from(container),
            file_size: 0,
            num_flags,
            boolean_value_offset: 0,
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
        result.extend_from_slice(&self.boolean_value_offset.to_le_bytes());
        result
    }
}

#[derive(PartialEq, Debug)]
pub struct FlagValueList {
    pub header: FlagValueHeader,
    pub booleans: Vec<bool>,
}

impl FlagValueList {
    pub fn new(container: &str, packages: &[FlagPackage]) -> Result<Self> {
        // create list
        let num_flags = packages.iter().map(|pkg| pkg.boolean_flags.len() as u32).sum();

        let mut list = Self {
            header: FlagValueHeader::new(container, num_flags),
            booleans: vec![false; num_flags as usize],
        };

        for pkg in packages.iter() {
            let start_offset = pkg.boolean_offset as usize;
            let flag_ids = assign_flag_ids(pkg.package_name, pkg.boolean_flags.iter().copied())?;
            for pf in pkg.boolean_flags.iter() {
                let fid = flag_ids
                    .get(pf.name())
                    .ok_or(anyhow!(format!("missing flag id for {}", pf.name())))?;

                list.booleans[start_offset + (*fid as usize)] =
                    pf.state() == ProtoFlagState::ENABLED;
            }
        }

        // initialize all header fields
        list.header.boolean_value_offset = list.header.as_bytes().len() as u32;
        list.header.file_size = list.header.boolean_value_offset + num_flags;

        Ok(list)
    }

    pub fn as_bytes(&self) -> Vec<u8> {
        [
            self.header.as_bytes(),
            self.booleans
                .iter()
                .map(|&v| u8::from(v).to_le_bytes())
                .collect::<Vec<_>>()
                .concat(),
        ]
        .concat()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::{
        group_flags_by_package, tests::parse_all_test_flags, tests::read_str_from_bytes,
        tests::read_u32_from_bytes, tests::read_u8_from_bytes,
    };

    impl FlagValueHeader {
        // test only method to deserialize back into the header struct
        fn from_bytes(bytes: &[u8]) -> Result<Self> {
            let mut head = 0;
            Ok(Self {
                version: read_u32_from_bytes(bytes, &mut head)?,
                container: read_str_from_bytes(bytes, &mut head)?,
                file_size: read_u32_from_bytes(bytes, &mut head)?,
                num_flags: read_u32_from_bytes(bytes, &mut head)?,
                boolean_value_offset: read_u32_from_bytes(bytes, &mut head)?,
            })
        }
    }

    impl FlagValueList {
        // test only method to deserialize back into the flag value struct
        fn from_bytes(bytes: &[u8]) -> Result<Self> {
            let header = FlagValueHeader::from_bytes(bytes)?;
            let num_flags = header.num_flags;
            let mut head = header.as_bytes().len();
            let booleans = (0..num_flags)
                .map(|_| read_u8_from_bytes(bytes, &mut head).unwrap() == 1)
                .collect();
            let list = Self { header, booleans };
            Ok(list)
        }
    }

    pub fn create_test_flag_value_list() -> Result<FlagValueList> {
        let caches = parse_all_test_flags();
        let packages = group_flags_by_package(caches.iter());
        FlagValueList::new("system", &packages)
    }

    #[test]
    // this test point locks down the flag value creation and each field
    fn test_list_contents() {
        let flag_value_list = create_test_flag_value_list();
        assert!(flag_value_list.is_ok());

        let header: &FlagValueHeader = &flag_value_list.as_ref().unwrap().header;
        let expected_header = FlagValueHeader {
            version: storage::FILE_VERSION,
            container: String::from("system"),
            file_size: 34,
            num_flags: 8,
            boolean_value_offset: 26,
        };
        assert_eq!(header, &expected_header);

        let booleans: &Vec<bool> = &flag_value_list.as_ref().unwrap().booleans;
        let expected_booleans: Vec<bool> = vec![false; header.num_flags as usize];
        assert_eq!(booleans, &expected_booleans);
    }

    #[test]
    // this test point locks down the value list serialization
    fn test_serialization() {
        let flag_value_list = create_test_flag_value_list().unwrap();

        let header: &FlagValueHeader = &flag_value_list.header;
        let reinterpreted_header = FlagValueHeader::from_bytes(&header.as_bytes());
        assert!(reinterpreted_header.is_ok());
        assert_eq!(header, &reinterpreted_header.unwrap());

        let reinterpreted_value_list = FlagValueList::from_bytes(&flag_value_list.as_bytes());
        assert!(reinterpreted_value_list.is_ok());
        assert_eq!(&flag_value_list, &reinterpreted_value_list.unwrap());
    }
}
