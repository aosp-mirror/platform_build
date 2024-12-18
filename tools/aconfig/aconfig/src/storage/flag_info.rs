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
use aconfig_storage_file::{FlagInfoHeader, FlagInfoList, FlagInfoNode, StorageFileType};
use anyhow::{anyhow, Result};

fn new_header(container: &str, num_flags: u32, version: u32) -> FlagInfoHeader {
    FlagInfoHeader {
        version,
        container: String::from(container),
        file_type: StorageFileType::FlagInfo as u8,
        file_size: 0,
        num_flags,
        boolean_flag_offset: 0,
    }
}

pub fn create_flag_info(
    container: &str,
    packages: &[FlagPackage],
    version: u32,
) -> Result<FlagInfoList> {
    // Exclude system/vendor/product flags that are RO+disabled.
    let mut filtered_packages = packages.to_vec();
    if container == "system" || container == "vendor" || container == "product" {
        for package in filtered_packages.iter_mut() {
            package.boolean_flags.retain(|b| {
                !(b.state == Some(ProtoFlagState::DISABLED.into())
                    && b.permission == Some(ProtoFlagPermission::READ_ONLY.into()))
            });
        }
    }

    let num_flags = filtered_packages.iter().map(|pkg| pkg.boolean_flags.len() as u32).sum();

    let mut is_flag_rw = vec![false; num_flags as usize];
    for pkg in filtered_packages {
        let start_index = pkg.boolean_start_index as usize;
        let flag_ids = assign_flag_ids(pkg.package_name, pkg.boolean_flags.iter().copied())?;
        for pf in pkg.boolean_flags {
            let fid = flag_ids
                .get(pf.name())
                .ok_or(anyhow!(format!("missing flag id for {}", pf.name())))?;
            is_flag_rw[start_index + (*fid as usize)] =
                pf.permission() == ProtoFlagPermission::READ_WRITE;
        }
    }

    let mut list = FlagInfoList {
        header: new_header(container, num_flags, version),
        nodes: is_flag_rw.iter().map(|&rw| FlagInfoNode::create(rw)).collect(),
    };

    // initialize all header fields
    list.header.boolean_flag_offset = list.header.into_bytes().len() as u32;
    let bytes_per_node = FlagInfoNode::create(false).into_bytes().len() as u32;
    list.header.file_size = list.header.boolean_flag_offset + num_flags * bytes_per_node;

    Ok(list)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::{group_flags_by_package, tests::parse_all_test_flags};
    use aconfig_storage_file::DEFAULT_FILE_VERSION;

    pub fn create_test_flag_info_list_from_source() -> Result<FlagInfoList> {
        let caches = parse_all_test_flags();
        let packages = group_flags_by_package(caches.iter(), DEFAULT_FILE_VERSION);
        create_flag_info("mockup", &packages, DEFAULT_FILE_VERSION)
    }

    #[test]
    // this test point locks down the flag info creation and each field
    fn test_list_contents() {
        let flag_info_list = create_test_flag_info_list_from_source();
        assert!(flag_info_list.is_ok());
        let expected_flag_info_list =
            aconfig_storage_file::test_utils::create_test_flag_info_list(DEFAULT_FILE_VERSION);
        assert_eq!(flag_info_list.unwrap(), expected_flag_info_list);
    }
}
