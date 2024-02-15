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
use aconfig_protos::ProtoFlagState;
use aconfig_storage_file::{FlagValueHeader, FlagValueList, FILE_VERSION};
use anyhow::{anyhow, Result};

fn new_header(container: &str, num_flags: u32) -> FlagValueHeader {
    FlagValueHeader {
        version: FILE_VERSION,
        container: String::from(container),
        file_size: 0,
        num_flags,
        boolean_value_offset: 0,
    }
}

pub fn create_flag_value(container: &str, packages: &[FlagPackage]) -> Result<FlagValueList> {
    // create list
    let num_flags = packages.iter().map(|pkg| pkg.boolean_flags.len() as u32).sum();

    let mut list = FlagValueList {
        header: new_header(container, num_flags),
        booleans: vec![false; num_flags as usize],
    };

    for pkg in packages.iter() {
        let start_offset = pkg.boolean_offset as usize;
        let flag_ids = assign_flag_ids(pkg.package_name, pkg.boolean_flags.iter().copied())?;
        for pf in pkg.boolean_flags.iter() {
            let fid = flag_ids
                .get(pf.name())
                .ok_or(anyhow!(format!("missing flag id for {}", pf.name())))?;

            list.booleans[start_offset + (*fid as usize)] = pf.state() == ProtoFlagState::ENABLED;
        }
    }

    // initialize all header fields
    list.header.boolean_value_offset = list.header.as_bytes().len() as u32;
    list.header.file_size = list.header.boolean_value_offset + num_flags;

    Ok(list)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::{group_flags_by_package, tests::parse_all_test_flags};

    pub fn create_test_flag_value_list() -> Result<FlagValueList> {
        let caches = parse_all_test_flags();
        let packages = group_flags_by_package(caches.iter());
        create_flag_value("system", &packages)
    }

    #[test]
    // this test point locks down the flag value creation and each field
    fn test_list_contents() {
        let flag_value_list = create_test_flag_value_list();
        assert!(flag_value_list.is_ok());

        let header: &FlagValueHeader = &flag_value_list.as_ref().unwrap().header;
        let expected_header = FlagValueHeader {
            version: FILE_VERSION,
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
}
