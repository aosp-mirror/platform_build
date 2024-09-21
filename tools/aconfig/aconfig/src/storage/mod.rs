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

pub mod flag_table;
pub mod flag_value;
pub mod package_table;

use anyhow::{anyhow, Result};
use std::collections::{HashMap, HashSet};

use crate::storage::{
    flag_table::create_flag_table, flag_value::create_flag_value,
    package_table::create_package_table,
};
use aconfig_protos::ProtoParsedFlag;
use aconfig_protos::ProtoParsedFlags;
use aconfig_storage_file::StorageFileType;

pub struct FlagPackage<'a> {
    pub package_name: &'a str,
    pub package_id: u32,
    pub fingerprint: u64,
    pub flag_names: HashSet<&'a str>,
    pub boolean_flags: Vec<&'a ProtoParsedFlag>,
    // The index of the first boolean flag in this aconfig package among all boolean
    // flags in this container.
    pub boolean_start_index: u32,
}

impl<'a> FlagPackage<'a> {
    fn new(package_name: &'a str, package_id: u32) -> Self {
        FlagPackage {
            package_name,
            package_id,
            fingerprint: 0,
            flag_names: HashSet::new(),
            boolean_flags: vec![],
            boolean_start_index: 0,
        }
    }

    fn insert(&mut self, pf: &'a ProtoParsedFlag) {
        if self.flag_names.insert(pf.name()) {
            self.boolean_flags.push(pf);
        }
    }
}

pub fn group_flags_by_package<'a, I>(parsed_flags_vec_iter: I) -> Vec<FlagPackage<'a>>
where
    I: Iterator<Item = &'a ProtoParsedFlags>,
{
    // group flags by package
    let mut packages: Vec<FlagPackage<'a>> = Vec::new();
    let mut package_index: HashMap<&str, usize> = HashMap::new();
    for parsed_flags in parsed_flags_vec_iter {
        for parsed_flag in parsed_flags.parsed_flag.iter() {
            let index = *(package_index.entry(parsed_flag.package()).or_insert(packages.len()));
            if index == packages.len() {
                packages.push(FlagPackage::new(parsed_flag.package(), index as u32));
            }
            packages[index].insert(parsed_flag);
        }
    }

    // cacluate boolean flag start index for each package
    let mut boolean_start_index = 0;
    for p in packages.iter_mut() {
        p.boolean_start_index = boolean_start_index;
        boolean_start_index += p.boolean_flags.len() as u32;

        // TODO: b/316357686 - Calculate fingerprint and add to package.
    }

    packages
}

pub fn generate_storage_file<'a, I>(
    container: &str,
    parsed_flags_vec_iter: I,
    file: &StorageFileType,
) -> Result<Vec<u8>>
where
    I: Iterator<Item = &'a ProtoParsedFlags>,
{
    let packages = group_flags_by_package(parsed_flags_vec_iter);

    match file {
        StorageFileType::PackageMap => {
            let package_table = create_package_table(container, &packages)?;
            Ok(package_table.into_bytes())
        }
        StorageFileType::FlagMap => {
            let flag_table = create_flag_table(container, &packages)?;
            Ok(flag_table.into_bytes())
        }
        StorageFileType::FlagVal => {
            let flag_value = create_flag_value(container, &packages)?;
            Ok(flag_value.into_bytes())
        }
        _ => Err(anyhow!("aconfig does not support the creation of this storage file type")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Input;

    use aconfig_protos::ProtoParsedFlags;

    pub fn parse_all_test_flags() -> Vec<ProtoParsedFlags> {
        let aconfig_files = [
            (
                "com.android.aconfig.storage.test_1",
                "storage_test_1.aconfig",
                include_bytes!("../../tests/storage_test_1.aconfig").as_slice(),
                "storage_test_1.value",
                include_bytes!("../../tests/storage_test_1.values").as_slice(),
            ),
            (
                "com.android.aconfig.storage.test_2",
                "storage_test_2.aconfig",
                include_bytes!("../../tests/storage_test_2.aconfig").as_slice(),
                "storage_test_2.value",
                include_bytes!("../../tests/storage_test_2.values").as_slice(),
            ),
            (
                "com.android.aconfig.storage.test_4",
                "storage_test_4.aconfig",
                include_bytes!("../../tests/storage_test_4.aconfig").as_slice(),
                "storage_test_4.value",
                include_bytes!("../../tests/storage_test_4.values").as_slice(),
            ),
        ];
        aconfig_files
            .into_iter()
            .map(|(pkg, aconfig_file, aconfig_content, value_file, value_content)| {
                let bytes = crate::commands::parse_flags(
                    pkg,
                    Some("system"),
                    vec![Input {
                        source: format!("tests/{}", aconfig_file).to_string(),
                        reader: Box::new(aconfig_content),
                    }],
                    vec![Input {
                        source: format!("tests/{}", value_file).to_string(),
                        reader: Box::new(value_content),
                    }],
                    crate::commands::DEFAULT_FLAG_PERMISSION,
                )
                .unwrap();
                aconfig_protos::parsed_flags::try_from_binary_proto(&bytes).unwrap()
            })
            .collect()
    }

    #[test]
    fn test_flag_package() {
        let caches = parse_all_test_flags();
        let packages = group_flags_by_package(caches.iter());

        for pkg in packages.iter() {
            let pkg_name = pkg.package_name;
            assert_eq!(pkg.flag_names.len(), pkg.boolean_flags.len());
            for pf in pkg.boolean_flags.iter() {
                assert!(pkg.flag_names.contains(pf.name()));
                assert_eq!(pf.package(), pkg_name);
            }
        }

        assert_eq!(packages.len(), 3);

        assert_eq!(packages[0].package_name, "com.android.aconfig.storage.test_1");
        assert_eq!(packages[0].package_id, 0);
        assert_eq!(packages[0].flag_names.len(), 3);
        assert!(packages[0].flag_names.contains("enabled_rw"));
        assert!(packages[0].flag_names.contains("disabled_rw"));
        assert!(packages[0].flag_names.contains("enabled_ro"));
        assert_eq!(packages[0].boolean_start_index, 0);

        assert_eq!(packages[1].package_name, "com.android.aconfig.storage.test_2");
        assert_eq!(packages[1].package_id, 1);
        assert_eq!(packages[1].flag_names.len(), 3);
        assert!(packages[1].flag_names.contains("enabled_ro"));
        assert!(packages[1].flag_names.contains("disabled_rw"));
        assert!(packages[1].flag_names.contains("enabled_fixed_ro"));
        assert_eq!(packages[1].boolean_start_index, 3);

        assert_eq!(packages[2].package_name, "com.android.aconfig.storage.test_4");
        assert_eq!(packages[2].package_id, 2);
        assert_eq!(packages[2].flag_names.len(), 2);
        assert!(packages[2].flag_names.contains("enabled_rw"));
        assert!(packages[2].flag_names.contains("enabled_fixed_ro"));
        assert_eq!(packages[2].boolean_start_index, 6);
    }
}
