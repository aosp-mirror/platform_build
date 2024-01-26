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
    get_bucket_index, get_table_size, PackageTable, PackageTableHeader, PackageTableNode,
    FILE_VERSION,
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

fn new_node(package: &FlagPackage, num_buckets: u32) -> PackageTableNode {
    let bucket_index = get_bucket_index(&package.package_name.to_string(), num_buckets);
    PackageTableNode {
        package_name: String::from(package.package_name),
        package_id: package.package_id,
        boolean_offset: package.boolean_offset,
        next_offset: None,
        bucket_index,
    }
}

pub fn create_package_table(container: &str, packages: &[FlagPackage]) -> Result<PackageTable> {
    // create table
    let num_packages = packages.len() as u32;
    let num_buckets = get_table_size(num_packages)?;
    let mut table = PackageTable {
        header: new_header(container, num_packages),
        buckets: vec![None; num_buckets as usize],
        nodes: packages.iter().map(|pkg| new_node(pkg, num_buckets)).collect(),
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
        let next_node_bucket_idx =
            if i + 1 < table.nodes.len() { Some(table.nodes[i + 1].bucket_index) } else { None };

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
            bucket_index: 0,
        };
        assert_eq!(nodes[0], first_node_expected);
        let second_node_expected = PackageTableNode {
            package_name: String::from("com.android.aconfig.storage.test_1"),
            package_id: 0,
            boolean_offset: 0,
            next_offset: Some(158),
            bucket_index: 3,
        };
        assert_eq!(nodes[1], second_node_expected);
        let third_node_expected = PackageTableNode {
            package_name: String::from("com.android.aconfig.storage.test_4"),
            package_id: 2,
            boolean_offset: 6,
            next_offset: None,
            bucket_index: 3,
        };
        assert_eq!(nodes[2], third_node_expected);
    }
}
