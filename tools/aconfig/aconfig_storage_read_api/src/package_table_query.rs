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

//! package table query module defines the package table file read from mapped bytes

use crate::{AconfigStorageError, FILE_VERSION};
use aconfig_storage_file::{
    package_table::PackageTableHeader, package_table::PackageTableNode, read_u32_from_bytes,
};
use anyhow::anyhow;

/// Package table query return
#[derive(PartialEq, Debug)]
pub struct PackageOffset {
    pub package_id: u32,
    pub boolean_offset: u32,
}

/// Query package id and start offset
pub fn find_package_offset(
    buf: &[u8],
    package: &str,
) -> Result<Option<PackageOffset>, AconfigStorageError> {
    let interpreted_header = PackageTableHeader::from_bytes(buf)?;
    if interpreted_header.version > FILE_VERSION {
        return Err(AconfigStorageError::HigherStorageFileVersion(anyhow!(
            "Cannot read storage file with a higher version of {} with lib version {}",
            interpreted_header.version,
            FILE_VERSION
        )));
    }

    let num_buckets = (interpreted_header.node_offset - interpreted_header.bucket_offset) / 4;
    let bucket_index = PackageTableNode::find_bucket_index(package, num_buckets);

    let mut pos = (interpreted_header.bucket_offset + 4 * bucket_index) as usize;
    let mut package_node_offset = read_u32_from_bytes(buf, &mut pos)? as usize;
    if package_node_offset < interpreted_header.node_offset as usize
        || package_node_offset >= interpreted_header.file_size as usize
    {
        return Ok(None);
    }

    loop {
        let interpreted_node = PackageTableNode::from_bytes(&buf[package_node_offset..])?;
        if interpreted_node.package_name == package {
            return Ok(Some(PackageOffset {
                package_id: interpreted_node.package_id,
                boolean_offset: interpreted_node.boolean_offset,
            }));
        }
        match interpreted_node.next_offset {
            Some(offset) => package_node_offset = offset as usize,
            None => return Ok(None),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use aconfig_storage_file::{PackageTable, StorageFileType};

    pub fn create_test_package_table() -> PackageTable {
        let header = PackageTableHeader {
            version: crate::FILE_VERSION,
            container: String::from("system"),
            file_type: StorageFileType::PackageMap as u8,
            file_size: 209,
            num_packages: 3,
            bucket_offset: 31,
            node_offset: 59,
        };
        let buckets: Vec<Option<u32>> = vec![Some(59), None, None, Some(109), None, None, None];
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
            next_offset: Some(159),
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

    #[test]
    // this test point locks down table query
    fn test_package_query() {
        let package_table = create_test_package_table().as_bytes();
        let package_offset =
            find_package_offset(&package_table[..], "com.android.aconfig.storage.test_1")
                .unwrap()
                .unwrap();
        let expected_package_offset = PackageOffset { package_id: 0, boolean_offset: 0 };
        assert_eq!(package_offset, expected_package_offset);
        let package_offset =
            find_package_offset(&package_table[..], "com.android.aconfig.storage.test_2")
                .unwrap()
                .unwrap();
        let expected_package_offset = PackageOffset { package_id: 1, boolean_offset: 3 };
        assert_eq!(package_offset, expected_package_offset);
        let package_offset =
            find_package_offset(&package_table[..], "com.android.aconfig.storage.test_4")
                .unwrap()
                .unwrap();
        let expected_package_offset = PackageOffset { package_id: 2, boolean_offset: 6 };
        assert_eq!(package_offset, expected_package_offset);
    }

    #[test]
    // this test point locks down table query of a non exist package
    fn test_not_existed_package_query() {
        // this will land at an empty bucket
        let package_table = create_test_package_table().as_bytes();
        let package_offset =
            find_package_offset(&package_table[..], "com.android.aconfig.storage.test_3").unwrap();
        assert_eq!(package_offset, None);
        // this will land at the end of a linked list
        let package_offset =
            find_package_offset(&package_table[..], "com.android.aconfig.storage.test_5").unwrap();
        assert_eq!(package_offset, None);
    }

    #[test]
    // this test point locks down query error when file has a higher version
    fn test_higher_version_storage_file() {
        let mut table = create_test_package_table();
        table.header.version = crate::FILE_VERSION + 1;
        let package_table = table.as_bytes();
        let error = find_package_offset(&package_table[..], "com.android.aconfig.storage.test_1")
            .unwrap_err();
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
