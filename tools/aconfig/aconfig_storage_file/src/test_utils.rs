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

use crate::flag_info::{FlagInfoHeader, FlagInfoList, FlagInfoNode};
use crate::flag_table::{FlagTable, FlagTableHeader, FlagTableNode};
use crate::flag_value::{FlagValueHeader, FlagValueList};
use crate::package_table::{PackageTable, PackageTableHeader, PackageTableNode};
use crate::{AconfigStorageError, StorageFileType, StoredFlagType};

use anyhow::anyhow;
use std::io::Write;
use tempfile::NamedTempFile;

pub fn create_test_package_table(version: u32) -> PackageTable {
    let header = PackageTableHeader {
        version: version,
        container: String::from("mockup"),
        file_type: StorageFileType::PackageMap as u8,
        file_size: match version {
            1 => 209,
            2 => 233,
            _ => panic!("Unsupported version."),
        },
        num_packages: 3,
        bucket_offset: 31,
        node_offset: 59,
    };
    let buckets: Vec<Option<u32>> = match version {
        1 => vec![Some(59), None, None, Some(109), None, None, None],
        2 => vec![Some(59), None, None, Some(117), None, None, None],
        _ => panic!("Unsupported version."),
    };
    let first_node = PackageTableNode {
        package_name: String::from("com.android.aconfig.storage.test_2"),
        package_id: 1,
        fingerprint: match version {
            1 => 0,
            2 => 4431940502274857964u64,
            _ => panic!("Unsupported version."),
        },
        boolean_start_index: 3,
        next_offset: None,
    };
    let second_node = PackageTableNode {
        package_name: String::from("com.android.aconfig.storage.test_1"),
        package_id: 0,
        fingerprint: match version {
            1 => 0,
            2 => 15248948510590158086u64,
            _ => panic!("Unsupported version."),
        },
        boolean_start_index: 0,
        next_offset: match version {
            1 => Some(159),
            2 => Some(175),
            _ => panic!("Unsupported version."),
        },
    };
    let third_node = PackageTableNode {
        package_name: String::from("com.android.aconfig.storage.test_4"),
        package_id: 2,
        fingerprint: match version {
            1 => 0,
            2 => 16233229917711622375u64,
            _ => panic!("Unsupported version."),
        },
        boolean_start_index: 6,
        next_offset: None,
    };
    let nodes = vec![first_node, second_node, third_node];
    PackageTable { header, buckets, nodes }
}

impl FlagTableNode {
    // create test baseline, syntactic sugar
    fn new_expected(
        package_id: u32,
        flag_name: &str,
        flag_type: u16,
        flag_index: u16,
        next_offset: Option<u32>,
    ) -> Self {
        Self {
            package_id,
            flag_name: flag_name.to_string(),
            flag_type: StoredFlagType::try_from(flag_type).unwrap(),
            flag_index,
            next_offset,
        }
    }
}

pub fn create_test_flag_table(version: u32) -> FlagTable {
    let header = FlagTableHeader {
        version: version,
        container: String::from("mockup"),
        file_type: StorageFileType::FlagMap as u8,
        file_size: 321,
        num_flags: 8,
        bucket_offset: 31,
        node_offset: 99,
    };
    let buckets: Vec<Option<u32>> = vec![
        Some(99),
        Some(125),
        None,
        None,
        None,
        None,
        Some(177),
        Some(204),
        None,
        Some(262),
        None,
        None,
        None,
        None,
        None,
        Some(294),
        None,
    ];
    let nodes = vec![
        FlagTableNode::new_expected(0, "enabled_ro", 1, 1, None),
        FlagTableNode::new_expected(0, "enabled_rw", 0, 2, Some(151)),
        FlagTableNode::new_expected(2, "enabled_rw", 0, 1, None),
        FlagTableNode::new_expected(1, "disabled_rw", 0, 0, None),
        FlagTableNode::new_expected(1, "enabled_fixed_ro", 2, 1, Some(236)),
        FlagTableNode::new_expected(1, "enabled_ro", 1, 2, None),
        FlagTableNode::new_expected(2, "enabled_fixed_ro", 2, 0, None),
        FlagTableNode::new_expected(0, "disabled_rw", 0, 0, None),
    ];
    FlagTable { header, buckets, nodes }
}

pub fn create_test_flag_value_list(version: u32) -> FlagValueList {
    let header = FlagValueHeader {
        version: version,
        container: String::from("mockup"),
        file_type: StorageFileType::FlagVal as u8,
        file_size: 35,
        num_flags: 8,
        boolean_value_offset: 27,
    };
    let booleans: Vec<bool> = vec![false, true, true, false, true, true, true, true];
    FlagValueList { header, booleans }
}

pub fn create_test_flag_info_list(version: u32) -> FlagInfoList {
    let header = FlagInfoHeader {
        version: version,
        container: String::from("mockup"),
        file_type: StorageFileType::FlagInfo as u8,
        file_size: 35,
        num_flags: 8,
        boolean_flag_offset: 27,
    };
    let is_flag_rw = [true, false, true, true, false, false, false, true];
    let nodes = is_flag_rw.iter().map(|&rw| FlagInfoNode::create(rw)).collect();
    FlagInfoList { header, nodes }
}

pub fn write_bytes_to_temp_file(bytes: &[u8]) -> Result<NamedTempFile, AconfigStorageError> {
    let mut file = NamedTempFile::new().map_err(|_| {
        AconfigStorageError::FileCreationFail(anyhow!("Failed to create temp file"))
    })?;
    let _ = file.write_all(&bytes);
    Ok(file)
}
