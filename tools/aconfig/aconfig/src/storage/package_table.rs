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

use anyhow::Result;

use aconfig_storage_file::{
    get_table_size, PackageTable, PackageTableHeader, PackageTableNode, StorageFileType,
};

use crate::storage::FlagPackage;

fn new_header(container: &str, num_packages: u32, version: u32) -> PackageTableHeader {
    PackageTableHeader {
        version,
        container: String::from(container),
        file_type: StorageFileType::PackageMap as u8,
        file_size: 0,
        num_packages,
        bucket_offset: 0,
        node_offset: 0,
    }
}

// a struct that contains PackageTableNode and a bunch of other information to help
// package table creation
#[derive(PartialEq, Debug)]
struct PackageTableNodeWrapper {
    pub node: PackageTableNode,
    pub bucket_index: u32,
}

impl PackageTableNodeWrapper {
    fn new(package: &FlagPackage, num_buckets: u32) -> Self {
        let node = PackageTableNode {
            package_name: String::from(package.package_name),
            package_id: package.package_id,
            fingerprint: package.fingerprint,
            boolean_start_index: package.boolean_start_index,
            next_offset: None,
        };
        let bucket_index = PackageTableNode::find_bucket_index(package.package_name, num_buckets);
        Self { node, bucket_index }
    }
}

pub fn create_package_table(
    container: &str,
    packages: &[FlagPackage],
    version: u32,
) -> Result<PackageTable> {
    // create table
    let num_packages = packages.len() as u32;
    let num_buckets = get_table_size(num_packages)?;
    let mut header = new_header(container, num_packages, version);
    let mut buckets = vec![None; num_buckets as usize];
    let mut node_wrappers: Vec<_> = packages
        .iter()
        .map(|pkg: &FlagPackage<'_>| PackageTableNodeWrapper::new(pkg, num_buckets))
        .collect();

    // initialize all header fields
    header.bucket_offset = header.into_bytes().len() as u32;
    header.node_offset = header.bucket_offset + num_buckets * 4;
    header.file_size = header.node_offset
        + node_wrappers.iter().map(|x| x.node.into_bytes(version).len()).sum::<usize>() as u32;

    // sort node_wrappers by bucket index for efficiency
    node_wrappers.sort_by(|a, b| a.bucket_index.cmp(&b.bucket_index));

    // fill all node offset
    let mut offset = header.node_offset;
    for i in 0..node_wrappers.len() {
        let node_bucket_idx = node_wrappers[i].bucket_index;
        let next_node_bucket_idx = if i + 1 < node_wrappers.len() {
            Some(node_wrappers[i + 1].bucket_index)
        } else {
            None
        };

        if buckets[node_bucket_idx as usize].is_none() {
            buckets[node_bucket_idx as usize] = Some(offset);
        }
        offset += node_wrappers[i].node.into_bytes(version).len() as u32;

        if let Some(index) = next_node_bucket_idx {
            if index == node_bucket_idx {
                node_wrappers[i].node.next_offset = Some(offset);
            }
        }
    }

    let table = PackageTable {
        header,
        buckets,
        nodes: node_wrappers.into_iter().map(|nw| nw.node).collect(),
    };
    Ok(table)
}

#[cfg(test)]
mod tests {
    use aconfig_storage_file::{DEFAULT_FILE_VERSION, MAX_SUPPORTED_FILE_VERSION};

    use super::*;
    use crate::storage::{group_flags_by_package, tests::parse_all_test_flags};

    pub fn create_test_package_table_from_source(version: u32) -> Result<PackageTable> {
        let caches = parse_all_test_flags();
        let packages = group_flags_by_package(caches.iter(), version);
        create_package_table("mockup", &packages, version)
    }

    #[test]
    // this test point locks down the table creation and each field
    fn test_table_contents_default_version() {
        let package_table_result = create_test_package_table_from_source(DEFAULT_FILE_VERSION);
        assert!(package_table_result.is_ok());
        let package_table = package_table_result.unwrap();

        let expected_package_table =
            aconfig_storage_file::test_utils::create_test_package_table(DEFAULT_FILE_VERSION);

        assert_eq!(package_table.header, expected_package_table.header);
        assert_eq!(package_table.buckets, expected_package_table.buckets);
        for (node, expected_node) in
            package_table.nodes.iter().zip(expected_package_table.nodes.iter())
        {
            assert_eq!(node.package_name, expected_node.package_name);
            assert_eq!(node.package_id, expected_node.package_id);
            assert_eq!(node.boolean_start_index, expected_node.boolean_start_index);
            assert_eq!(node.next_offset, expected_node.next_offset);
        }
    }

    #[test]
    // this test point locks down the table creation and each field
    fn test_table_contents_max_version() {
        let package_table_result =
            create_test_package_table_from_source(MAX_SUPPORTED_FILE_VERSION);
        assert!(package_table_result.is_ok());
        let package_table = package_table_result.unwrap();

        let expected_package_table =
            aconfig_storage_file::test_utils::create_test_package_table(MAX_SUPPORTED_FILE_VERSION);

        assert_eq!(package_table.header, expected_package_table.header);
        assert_eq!(package_table.buckets, expected_package_table.buckets);
        for (node, expected_node) in
            package_table.nodes.iter().zip(expected_package_table.nodes.iter())
        {
            assert_eq!(node.package_name, expected_node.package_name);
            assert_eq!(node.package_id, expected_node.package_id);
            assert_eq!(node.boolean_start_index, expected_node.boolean_start_index);
            assert_eq!(node.next_offset, expected_node.next_offset);
        }
    }
}
