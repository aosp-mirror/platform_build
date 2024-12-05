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
use aconfig_protos::{ProtoFlagPermission, ProtoFlagState};
use aconfig_storage_file::{
    get_table_size, FlagTable, FlagTableHeader, FlagTableNode, StorageFileType, StoredFlagType,
};
use anyhow::{anyhow, Result};

fn new_header(container: &str, num_flags: u32, version: u32) -> FlagTableHeader {
    FlagTableHeader {
        version,
        container: String::from(container),
        file_type: StorageFileType::FlagMap as u8,
        file_size: 0,
        num_flags,
        bucket_offset: 0,
        node_offset: 0,
    }
}

// a struct that contains FlagTableNode and a bunch of other information to help
// flag table creation
#[derive(PartialEq, Debug, Clone)]
struct FlagTableNodeWrapper {
    pub node: FlagTableNode,
    pub bucket_index: u32,
}

impl FlagTableNodeWrapper {
    fn new(
        package_id: u32,
        flag_name: &str,
        flag_type: StoredFlagType,
        flag_index: u16,
        num_buckets: u32,
    ) -> Self {
        let bucket_index = FlagTableNode::find_bucket_index(package_id, flag_name, num_buckets);
        let node = FlagTableNode {
            package_id,
            flag_name: flag_name.to_string(),
            flag_type,
            flag_index,
            next_offset: None,
        };
        Self { node, bucket_index }
    }

    fn create_nodes(package: &FlagPackage, num_buckets: u32) -> Result<Vec<Self>> {
        // Exclude system/vendor/product flags that are RO+disabled.
        let mut filtered_package = package.clone();
        filtered_package.boolean_flags.retain(|f| {
            !((f.container == Some("system".to_string())
                || f.container == Some("vendor".to_string())
                || f.container == Some("product".to_string()))
                && f.permission == Some(ProtoFlagPermission::READ_ONLY.into())
                && f.state == Some(ProtoFlagState::DISABLED.into()))
        });

        let flag_ids =
            assign_flag_ids(package.package_name, filtered_package.boolean_flags.iter().copied())?;
        filtered_package
            .boolean_flags
            .iter()
            .map(|&pf| {
                let fid = flag_ids
                    .get(pf.name())
                    .ok_or(anyhow!(format!("missing flag id for {}", pf.name())))?;
                let flag_type = if pf.is_fixed_read_only() {
                    StoredFlagType::FixedReadOnlyBoolean
                } else {
                    match pf.permission() {
                        ProtoFlagPermission::READ_WRITE => StoredFlagType::ReadWriteBoolean,
                        ProtoFlagPermission::READ_ONLY => StoredFlagType::ReadOnlyBoolean,
                    }
                };
                Ok(Self::new(package.package_id, pf.name(), flag_type, *fid, num_buckets))
            })
            .collect::<Result<Vec<_>>>()
    }
}

pub fn create_flag_table(
    container: &str,
    packages: &[FlagPackage],
    version: u32,
) -> Result<FlagTable> {
    // create table
    let num_flags = packages.iter().map(|pkg| pkg.boolean_flags.len() as u32).sum();
    let num_buckets = get_table_size(num_flags)?;

    let mut header = new_header(container, num_flags, version);
    let mut buckets = vec![None; num_buckets as usize];
    let mut node_wrappers = packages
        .iter()
        .map(|pkg| FlagTableNodeWrapper::create_nodes(pkg, num_buckets))
        .collect::<Result<Vec<_>>>()?
        .concat();

    // initialize all header fields
    header.bucket_offset = header.into_bytes().len() as u32;
    header.node_offset = header.bucket_offset + num_buckets * 4;
    header.file_size = header.node_offset
        + node_wrappers.iter().map(|x| x.node.into_bytes().len()).sum::<usize>() as u32;

    // sort nodes by bucket index for efficiency
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
        offset += node_wrappers[i].node.into_bytes().len() as u32;

        if let Some(index) = next_node_bucket_idx {
            if index == node_bucket_idx {
                node_wrappers[i].node.next_offset = Some(offset);
            }
        }
    }

    let table =
        FlagTable { header, buckets, nodes: node_wrappers.into_iter().map(|nw| nw.node).collect() };

    Ok(table)
}

#[cfg(test)]
mod tests {
    use aconfig_storage_file::DEFAULT_FILE_VERSION;

    use super::*;
    use crate::storage::{group_flags_by_package, tests::parse_all_test_flags};

    fn create_test_flag_table_from_source() -> Result<FlagTable> {
        let caches = parse_all_test_flags();
        let packages = group_flags_by_package(caches.iter(), DEFAULT_FILE_VERSION);
        create_flag_table("mockup", &packages, DEFAULT_FILE_VERSION)
    }

    #[test]
    // this test point locks down the table creation and each field
    fn test_table_contents() {
        let flag_table = create_test_flag_table_from_source();
        assert!(flag_table.is_ok());
        let expected_flag_table =
            aconfig_storage_file::test_utils::create_test_flag_table(DEFAULT_FILE_VERSION);
        assert_eq!(flag_table.unwrap(), expected_flag_table);
    }
}
