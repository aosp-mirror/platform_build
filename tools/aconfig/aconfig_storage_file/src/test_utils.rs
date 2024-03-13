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

use crate::flag_table::{FlagTable, FlagTableHeader, FlagTableNode};
use crate::flag_value::{FlagValueHeader, FlagValueList};
use crate::package_table::{PackageTable, PackageTableHeader, PackageTableNode};
use crate::AconfigStorageError;

use anyhow::anyhow;
use std::io::Write;
use tempfile::NamedTempFile;

pub(crate) fn create_test_package_table() -> PackageTable {
    let header = PackageTableHeader {
        version: 1234,
        container: String::from("system"),
        file_type: 0,
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

pub(crate) fn create_test_flag_table() -> FlagTable {
    let header = FlagTableHeader {
        version: 1234,
        container: String::from("system"),
        file_type: 1,
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

pub(crate) fn create_test_flag_value_list() -> FlagValueList {
    let header = FlagValueHeader {
        version: 1234,
        container: String::from("system"),
        file_type: 2,
        file_size: 34,
        num_flags: 8,
        boolean_value_offset: 26,
    };
    let booleans: Vec<bool> = vec![false, true, false, false, true, true, false, true];
    FlagValueList { header, booleans }
}

pub(crate) fn write_bytes_to_temp_file(bytes: &[u8]) -> Result<NamedTempFile, AconfigStorageError> {
    let mut file = NamedTempFile::new().map_err(|_| {
        AconfigStorageError::FileCreationFail(anyhow!("Failed to create temp file"))
    })?;
    let _ = file.write_all(&bytes);
    Ok(file)
}
