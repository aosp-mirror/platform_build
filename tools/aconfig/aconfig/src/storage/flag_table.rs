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
use crate::storage::FlagPackage;
use aconfig_storage_file::{
    get_table_size, FlagTable, FlagTableHeader, FlagTableNode, FILE_VERSION,
};
use anyhow::{anyhow, Result};

fn new_header(container: &str, num_flags: u32) -> FlagTableHeader {
    FlagTableHeader {
        version: FILE_VERSION,
        container: String::from(container),
        file_size: 0,
        num_flags,
        bucket_offset: 0,
        node_offset: 0,
    }
}

fn new_node(
    package_id: u32,
    flag_name: &str,
    flag_type: u16,
    flag_id: u16,
    num_buckets: u32,
) -> FlagTableNode {
    let bucket_index = FlagTableNode::find_bucket_index(package_id, flag_name, num_buckets);
    FlagTableNode {
        package_id,
        flag_name: flag_name.to_string(),
        flag_type,
        flag_id,
        next_offset: None,
        bucket_index,
    }
}

fn create_nodes(package: &FlagPackage, num_buckets: u32) -> Result<Vec<FlagTableNode>> {
    let flag_ids = assign_flag_ids(package.package_name, package.boolean_flags.iter().copied())?;
    package
        .boolean_flags
        .iter()
        .map(|&pf| {
            let fid = flag_ids
                .get(pf.name())
                .ok_or(anyhow!(format!("missing flag id for {}", pf.name())))?;
            // all flags are boolean value at the moment, thus using the last bit. When more
            // flag value types are supported, flag value type information should come from the
            // parsed flag, and we will set the flag_type bit mask properly.
            let flag_type = 1;
            Ok(new_node(package.package_id, pf.name(), flag_type, *fid, num_buckets))
        })
        .collect::<Result<Vec<_>>>()
}

pub fn create_flag_table(container: &str, packages: &[FlagPackage]) -> Result<FlagTable> {
    // create table
    let num_flags = packages.iter().map(|pkg| pkg.boolean_flags.len() as u32).sum();
    let num_buckets = get_table_size(num_flags)?;

    let mut table = FlagTable {
        header: new_header(container, num_flags),
        buckets: vec![None; num_buckets as usize],
        nodes: packages
            .iter()
            .map(|pkg| create_nodes(pkg, num_buckets))
            .collect::<Result<Vec<_>>>()?
            .concat(),
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

    // create test baseline, syntactic sugar
    fn new_expected_node(
        package_id: u32,
        flag_name: &str,
        flag_type: u16,
        flag_id: u16,
        next_offset: Option<u32>,
        bucket_index: u32,
    ) -> FlagTableNode {
        FlagTableNode {
            package_id,
            flag_name: flag_name.to_string(),
            flag_type,
            flag_id,
            next_offset,
            bucket_index,
        }
    }

    fn create_test_flag_table() -> Result<FlagTable> {
        let caches = parse_all_test_flags();
        let packages = group_flags_by_package(caches.iter());
        create_flag_table("system", &packages)
    }

    #[test]
    // this test point locks down the table creation and each field
    fn test_table_contents() {
        let flag_table = create_test_flag_table();
        assert!(flag_table.is_ok());

        let header: &FlagTableHeader = &flag_table.as_ref().unwrap().header;
        let expected_header = FlagTableHeader {
            version: FILE_VERSION,
            container: String::from("system"),
            file_size: 320,
            num_flags: 8,
            bucket_offset: 30,
            node_offset: 98,
        };
        assert_eq!(header, &expected_header);

        let buckets: &Vec<Option<u32>> = &flag_table.as_ref().unwrap().buckets;
        let expected_bucket: Vec<Option<u32>> = vec![
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
        assert_eq!(buckets, &expected_bucket);

        let nodes: &Vec<FlagTableNode> = &flag_table.as_ref().unwrap().nodes;
        assert_eq!(nodes.len(), 8);

        assert_eq!(nodes[0], new_expected_node(0, "enabled_ro", 1, 1, None, 0));
        assert_eq!(nodes[1], new_expected_node(0, "enabled_rw", 1, 2, Some(150), 1));
        assert_eq!(nodes[2], new_expected_node(1, "disabled_ro", 1, 0, None, 1));
        assert_eq!(nodes[3], new_expected_node(2, "enabled_ro", 1, 1, None, 5));
        assert_eq!(nodes[4], new_expected_node(1, "enabled_fixed_ro", 1, 1, Some(235), 7));
        assert_eq!(nodes[5], new_expected_node(1, "enabled_ro", 1, 2, None, 7));
        assert_eq!(nodes[6], new_expected_node(2, "enabled_fixed_ro", 1, 0, None, 9));
        assert_eq!(nodes[7], new_expected_node(0, "disabled_rw", 1, 0, None, 15));
    }
}
