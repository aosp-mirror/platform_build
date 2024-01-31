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
    get_table_size, PackageTable, PackageTableHeader, PackageTableNode, FILE_VERSION,
};

use crate::storage::FlagPackage;

fn new_header(container: &str, num_packages: u32) -> PackageTableHeader {
    PackageTableHeader {
        version: FILE_VERSION,
        container: String::from(container),
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
            boolean_offset: package.boolean_offset,
            next_offset: None,
        };
        let bucket_index = PackageTableNode::find_bucket_index(package.package_name, num_buckets);
        Self { node, bucket_index }
    }
}

pub fn create_package_table(container: &str, packages: &[FlagPackage]) -> Result<PackageTable> {
    // create table
    let num_packages = packages.len() as u32;
    let num_buckets = get_table_size(num_packages)?;
    let mut header = new_header(container, num_packages);
    let mut buckets = vec![None; num_buckets as usize];
    let mut node_wrappers: Vec<_> =
        packages.iter().map(|pkg| PackageTableNodeWrapper::new(pkg, num_buckets)).collect();

    // initialize all header fields
    header.bucket_offset = header.as_bytes().len() as u32;
    header.node_offset = header.bucket_offset + num_buckets * 4;
    header.file_size = header.node_offset
        + node_wrappers.iter().map(|x| x.node.as_bytes().len()).sum::<usize>() as u32;

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
        offset += node_wrappers[i].node.as_bytes().len() as u32;

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
    use super::*;
    use crate::storage::{group_flags_by_package, tests::parse_all_test_flags};

    pub fn create_test_package_table() -> Result<PackageTable> {
        let caches = parse_all_test_flags();
        let packages = group_flags_by_package(caches.iter());
        create_package_table("system", &packages)
    }

    #[test]
    // this test point locks down the table creation and each field
    fn test_table_contents() {
        let package_table = create_test_package_table();
        assert!(package_table.is_ok());

        let header: &PackageTableHeader = &package_table.as_ref().unwrap().header;
        let expected_header = PackageTableHeader {
            version: FILE_VERSION,
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
        };
        assert_eq!(nodes[0], first_node_expected);
        let second_node_expected = PackageTableNode {
            package_name: String::from("com.android.aconfig.storage.test_1"),
            package_id: 0,
            boolean_offset: 0,
            next_offset: Some(158),
        };
        assert_eq!(nodes[1], second_node_expected);
        let third_node_expected = PackageTableNode {
            package_name: String::from("com.android.aconfig.storage.test_4"),
            package_id: 2,
            boolean_offset: 6,
            next_offset: None,
        };
        assert_eq!(nodes[2], third_node_expected);
    }
}
