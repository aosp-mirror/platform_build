/*
* Copyright (C) 2025 The Android Open Source Project
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
//! Functions to extract finalized flag information from
//! /prebuilts/sdk/#/finalized-flags.txt.
//! These functions are very specific to that file setup as well as the format
//! of the files (just a list of the fully-qualified flag names).
//! There are also some helper functions for local building using cargo. These
//! functions are only invoked via cargo for quick local testing and will not
//! be used during actual soong building. They are marked as such.
use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::io::{self, BufRead};

/// Just the fully qualified flag name (package_name.flag_name).
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct FinalizedFlag {
    /// Name of the flag.
    pub flag_name: String,
    /// Name of the package.
    pub package_name: String,
}

/// API level in which the flag was finalized.
#[derive(Copy, Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct ApiLevel(pub i32);

/// API level of the extended flags file of version 35
pub const EXTENDED_FLAGS_35_APILEVEL: ApiLevel = ApiLevel(35);

/// Contains all flags finalized for a given API level.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct FinalizedFlagMap(HashMap<ApiLevel, HashSet<FinalizedFlag>>);

impl FinalizedFlagMap {
    /// Creates a new, empty instance.
    pub fn new() -> Self {
        Self(HashMap::new())
    }

    /// Convenience method for is_empty on the underlying map.
    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }

    /// Returns the API level in which the flag was finalized .
    pub fn get_finalized_level(&self, flag: &FinalizedFlag) -> Option<ApiLevel> {
        for (api_level, flags_for_level) in &self.0 {
            if flags_for_level.contains(flag) {
                return Some(*api_level);
            }
        }
        None
    }

    /// Insert the flag into the map for the given level if the flag is not
    /// present in the map already - for *any* level (not just the one given).
    pub fn insert_if_new(&mut self, level: ApiLevel, flag: FinalizedFlag) {
        if self.contains(&flag) {
            return;
        }
        self.0.entry(level).or_default().insert(flag);
    }

    fn contains(&self, flag: &FinalizedFlag) -> bool {
        self.0.values().any(|flags_set| flags_set.contains(flag))
    }
}

const EXTENDED_FLAGS_LIST_35: &str = "extended_flags_list_35.txt";

/// Converts a string to an int. Will parse to int even if the string is "X.0".
/// Returns error for "X.1".
fn str_to_api_level(numeric_string: &str) -> Result<ApiLevel> {
    let float_value = numeric_string.parse::<f64>()?;

    if float_value.fract() == 0.0 {
        Ok(ApiLevel(float_value as i32))
    } else {
        Err(anyhow!("Numeric string is float, can't parse to int."))
    }
}

/// For each file, extracts the qualified flag names into a FinalizedFlag, then
/// enters them in a map at the API level corresponding to their directory.
/// Ex: /prebuilts/sdk/35/finalized-flags.txt -> {36, [flag1, flag2]}.
pub fn read_files_to_map_using_path(flag_files: Vec<String>) -> Result<FinalizedFlagMap> {
    let mut data_map = FinalizedFlagMap::new();

    for flag_file in flag_files {
        // Split /path/sdk/<int.int>/finalized-flags.txt -> ['/path/sdk', 'int.int', 'finalized-flags.txt'].
        let flag_file_split: Vec<String> =
            flag_file.clone().rsplitn(3, '/').map(|s| s.to_string()).collect();

        if &flag_file_split[0] != "finalized-flags.txt" {
            return Err(anyhow!("Provided incorrect file, must be finalized-flags.txt"));
        }

        let api_level_string = &flag_file_split[1];

        // For now, skip any directory with full API level, e.g. "36.1". The
        // finalized flag files each contain all flags finalized *up to* that
        // level (including prior levels), so skipping intermediate levels means
        // the flags will be included at the next full number.
        // TODO: b/378936061 - Support full SDK version.
        // In the future, we should error if provided a non-numeric directory.
        let Ok(api_level) = str_to_api_level(api_level_string) else {
            continue;
        };

        let file = fs::File::open(&flag_file)?;

        io::BufReader::new(file).lines().for_each(|flag| {
            let flag =
                flag.unwrap_or_else(|_| panic!("Failed to read line from file {}", flag_file));
            let finalized_flag = build_finalized_flag(&flag)
                .unwrap_or_else(|_| panic!("cannot build finalized flag {}", flag));
            data_map.insert_if_new(api_level, finalized_flag);
        });
    }

    Ok(data_map)
}

/// Read the qualified flag names into a FinalizedFlag set
pub fn read_extend_file_to_map_using_path(extened_file: String) -> Result<HashSet<FinalizedFlag>> {
    let (_, file_name) =
        extened_file.rsplit_once('/').ok_or(anyhow!("Invalid file: '{}'", extened_file))?;
    if file_name != EXTENDED_FLAGS_LIST_35 {
        return Err(anyhow!("Provided incorrect file, must be {}", EXTENDED_FLAGS_LIST_35));
    }
    let file = fs::File::open(extened_file)?;
    let extended_flags = io::BufReader::new(file)
        .lines()
        .map(|flag| {
            let flag = flag.expect("Failed to read line from extended file");
            build_finalized_flag(&flag)
                .unwrap_or_else(|_| panic!("cannot build finalized flag {}", flag))
        })
        .collect::<HashSet<FinalizedFlag>>();
    Ok(extended_flags)
}

fn build_finalized_flag(qualified_flag_name: &String) -> Result<FinalizedFlag> {
    // Split the qualified flag name into package and flag name:
    // com.my.package.name.my_flag_name -> ('com.my.package.name', 'my_flag_name')
    let (package_name, flag_name) = qualified_flag_name
        .rsplit_once('.')
        .ok_or(anyhow!("Invalid qualified flag name format: '{}'", qualified_flag_name))?;

    Ok(FinalizedFlag { flag_name: flag_name.to_string(), package_name: package_name.to_string() })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;
    use std::io::Write;
    use tempfile::tempdir;

    const FLAG_FILE_NAME: &str = "finalized-flags.txt";

    // Creates some flags for testing.
    fn create_test_flags() -> Vec<FinalizedFlag> {
        vec![
            FinalizedFlag { flag_name: "name1".to_string(), package_name: "package1".to_string() },
            FinalizedFlag { flag_name: "name2".to_string(), package_name: "package2".to_string() },
            FinalizedFlag { flag_name: "name3".to_string(), package_name: "package3".to_string() },
        ]
    }

    // Writes the fully qualified flag names in the given file.
    fn add_flags_to_file(flag_file: &mut File, flags: &[FinalizedFlag]) {
        for flag in flags {
            let _unused = writeln!(flag_file, "{}.{}", flag.package_name, flag.flag_name);
        }
    }

    #[test]
    fn test_read_flags_one_file() {
        let flags = create_test_flags();

        // Create the file <temp_dir>/35/finalized-flags.txt.
        let temp_dir = tempdir().unwrap();
        let mut file_path = temp_dir.path().to_path_buf();
        file_path.push("35");
        fs::create_dir_all(&file_path).unwrap();
        file_path.push(FLAG_FILE_NAME);
        let mut file = File::create(&file_path).unwrap();

        // Write all flags to the file.
        add_flags_to_file(&mut file, &[flags[0].clone(), flags[1].clone()]);
        let flag_file_path = file_path.to_string_lossy().to_string();

        // Convert to map.
        let map = read_files_to_map_using_path(vec![flag_file_path]).unwrap();

        assert_eq!(map.0.len(), 1);
        assert!(map.0.get(&ApiLevel(35)).unwrap().contains(&flags[0]));
        assert!(map.0.get(&ApiLevel(35)).unwrap().contains(&flags[1]));
    }

    #[test]
    fn test_read_flags_two_files() {
        let flags = create_test_flags();

        // Create the file <temp_dir>/35/finalized-flags.txt and for 36.
        let temp_dir = tempdir().unwrap();
        let mut file_path1 = temp_dir.path().to_path_buf();
        file_path1.push("35");
        fs::create_dir_all(&file_path1).unwrap();
        file_path1.push(FLAG_FILE_NAME);
        let mut file1 = File::create(&file_path1).unwrap();

        let mut file_path2 = temp_dir.path().to_path_buf();
        file_path2.push("36");
        fs::create_dir_all(&file_path2).unwrap();
        file_path2.push(FLAG_FILE_NAME);
        let mut file2 = File::create(&file_path2).unwrap();

        // Write all flags to the files.
        add_flags_to_file(&mut file1, &[flags[0].clone()]);
        add_flags_to_file(&mut file2, &[flags[0].clone(), flags[1].clone(), flags[2].clone()]);
        let flag_file_path1 = file_path1.to_string_lossy().to_string();
        let flag_file_path2 = file_path2.to_string_lossy().to_string();

        // Convert to map.
        let map = read_files_to_map_using_path(vec![flag_file_path1, flag_file_path2]).unwrap();

        // Assert there are two API levels, 35 and 36.
        assert_eq!(map.0.len(), 2);
        assert!(map.0.get(&ApiLevel(35)).unwrap().contains(&flags[0]));

        // 36 should not have the first flag in the set, as it was finalized in
        // an earlier API level.
        assert!(map.0.get(&ApiLevel(36)).unwrap().contains(&flags[1]));
        assert!(map.0.get(&ApiLevel(36)).unwrap().contains(&flags[2]));
    }

    #[test]
    fn test_read_flags_full_numbers() {
        let flags = create_test_flags();

        // Create the file <temp_dir>/35/finalized-flags.txt and for 36.
        let temp_dir = tempdir().unwrap();
        let mut file_path1 = temp_dir.path().to_path_buf();
        file_path1.push("35.0");
        fs::create_dir_all(&file_path1).unwrap();
        file_path1.push(FLAG_FILE_NAME);
        let mut file1 = File::create(&file_path1).unwrap();

        let mut file_path2 = temp_dir.path().to_path_buf();
        file_path2.push("36.0");
        fs::create_dir_all(&file_path2).unwrap();
        file_path2.push(FLAG_FILE_NAME);
        let mut file2 = File::create(&file_path2).unwrap();

        // Write all flags to the files.
        add_flags_to_file(&mut file1, &[flags[0].clone()]);
        add_flags_to_file(&mut file2, &[flags[0].clone(), flags[1].clone(), flags[2].clone()]);
        let flag_file_path1 = file_path1.to_string_lossy().to_string();
        let flag_file_path2 = file_path2.to_string_lossy().to_string();

        // Convert to map.
        let map = read_files_to_map_using_path(vec![flag_file_path1, flag_file_path2]).unwrap();

        assert_eq!(map.0.len(), 2);
        assert!(map.0.get(&ApiLevel(35)).unwrap().contains(&flags[0]));
        assert!(map.0.get(&ApiLevel(36)).unwrap().contains(&flags[1]));
        assert!(map.0.get(&ApiLevel(36)).unwrap().contains(&flags[2]));
    }

    #[test]
    fn test_read_flags_fractions_round_up() {
        let flags = create_test_flags();

        // Create the file <temp_dir>/35/finalized-flags.txt and for 36.
        let temp_dir = tempdir().unwrap();
        let mut file_path1 = temp_dir.path().to_path_buf();
        file_path1.push("35.1");
        fs::create_dir_all(&file_path1).unwrap();
        file_path1.push(FLAG_FILE_NAME);
        let mut file1 = File::create(&file_path1).unwrap();

        let mut file_path2 = temp_dir.path().to_path_buf();
        file_path2.push("36.0");
        fs::create_dir_all(&file_path2).unwrap();
        file_path2.push(FLAG_FILE_NAME);
        let mut file2 = File::create(&file_path2).unwrap();

        // Write all flags to the files.
        add_flags_to_file(&mut file1, &[flags[0].clone()]);
        add_flags_to_file(&mut file2, &[flags[0].clone(), flags[1].clone(), flags[2].clone()]);
        let flag_file_path1 = file_path1.to_string_lossy().to_string();
        let flag_file_path2 = file_path2.to_string_lossy().to_string();

        // Convert to map.
        let map = read_files_to_map_using_path(vec![flag_file_path1, flag_file_path2]).unwrap();

        // No flags were added in 35. All 35.1 flags were rolled up to 36.
        assert_eq!(map.0.len(), 1);
        assert!(!map.0.contains_key(&ApiLevel(35)));
        assert!(map.0.get(&ApiLevel(36)).unwrap().contains(&flags[0]));
        assert!(map.0.get(&ApiLevel(36)).unwrap().contains(&flags[1]));
        assert!(map.0.get(&ApiLevel(36)).unwrap().contains(&flags[2]));
    }

    #[test]
    fn test_read_flags_non_numeric() {
        let flags = create_test_flags();

        // Create the file <temp_dir>/35/finalized-flags.txt.
        let temp_dir = tempdir().unwrap();
        let mut file_path = temp_dir.path().to_path_buf();
        file_path.push("35");
        fs::create_dir_all(&file_path).unwrap();
        file_path.push(FLAG_FILE_NAME);
        let mut flag_file = File::create(&file_path).unwrap();

        let mut invalid_path = temp_dir.path().to_path_buf();
        invalid_path.push("sdk-annotations");
        fs::create_dir_all(&invalid_path).unwrap();
        invalid_path.push(FLAG_FILE_NAME);
        File::create(&invalid_path).unwrap();

        // Write all flags to the file.
        add_flags_to_file(&mut flag_file, &[flags[0].clone(), flags[1].clone()]);
        let flag_file_path = file_path.to_string_lossy().to_string();

        // Convert to map.
        let map = read_files_to_map_using_path(vec![
            flag_file_path,
            invalid_path.to_string_lossy().to_string(),
        ])
        .unwrap();

        // No set should be created for sdk-annotations.
        assert_eq!(map.0.len(), 1);
        assert!(map.0.get(&ApiLevel(35)).unwrap().contains(&flags[0]));
        assert!(map.0.get(&ApiLevel(35)).unwrap().contains(&flags[1]));
    }

    #[test]
    fn test_read_flags_wrong_file_err() {
        let flags = create_test_flags();

        // Create the file <temp_dir>/35/finalized-flags.txt.
        let temp_dir = tempdir().unwrap();
        let mut file_path = temp_dir.path().to_path_buf();
        file_path.push("35");
        fs::create_dir_all(&file_path).unwrap();
        file_path.push(FLAG_FILE_NAME);
        let mut flag_file = File::create(&file_path).unwrap();

        let mut pre_flag_path = temp_dir.path().to_path_buf();
        pre_flag_path.push("18");
        fs::create_dir_all(&pre_flag_path).unwrap();
        pre_flag_path.push("some_random_file.txt");
        File::create(&pre_flag_path).unwrap();

        // Write all flags to the file.
        add_flags_to_file(&mut flag_file, &[flags[0].clone(), flags[1].clone()]);
        let flag_file_path = file_path.to_string_lossy().to_string();

        // Convert to map.
        let map = read_files_to_map_using_path(vec![
            flag_file_path,
            pre_flag_path.to_string_lossy().to_string(),
        ]);

        assert!(map.is_err());
    }

    #[test]
    fn test_flags_map_insert_if_new() {
        let flags = create_test_flags();
        let mut map = FinalizedFlagMap::new();
        let l35 = ApiLevel(35);
        let l36 = ApiLevel(36);

        map.insert_if_new(l35, flags[0].clone());
        map.insert_if_new(l35, flags[1].clone());
        map.insert_if_new(l35, flags[2].clone());
        map.insert_if_new(l36, flags[0].clone());

        assert!(map.0.get(&l35).unwrap().contains(&flags[0]));
        assert!(map.0.get(&l35).unwrap().contains(&flags[1]));
        assert!(map.0.get(&l35).unwrap().contains(&flags[2]));
        assert!(!map.0.contains_key(&l36));
    }

    #[test]
    fn test_flags_map_get_level() {
        let flags = create_test_flags();
        let mut map = FinalizedFlagMap::new();
        let l35 = ApiLevel(35);
        let l36 = ApiLevel(36);

        map.insert_if_new(l35, flags[0].clone());
        map.insert_if_new(l36, flags[1].clone());

        assert_eq!(map.get_finalized_level(&flags[0]).unwrap(), l35);
        assert_eq!(map.get_finalized_level(&flags[1]).unwrap(), l36);
    }

    #[test]
    fn test_read_flag_from_extended_file() {
        let flags = create_test_flags();

        // Create the file <temp_dir>/35/extended_flags_list_35.txt
        let temp_dir = tempdir().unwrap();
        let mut file_path = temp_dir.path().to_path_buf();
        file_path.push("35");
        fs::create_dir_all(&file_path).unwrap();
        file_path.push(EXTENDED_FLAGS_LIST_35);
        let mut file = File::create(&file_path).unwrap();

        // Write all flags to the file.
        add_flags_to_file(&mut file, &[flags[0].clone(), flags[1].clone()]);

        let flags_set =
            read_extend_file_to_map_using_path(file_path.to_string_lossy().to_string()).unwrap();
        assert_eq!(flags_set.len(), 2);
        assert!(flags_set.contains(&flags[0]));
        assert!(flags_set.contains(&flags[1]));
    }

    #[test]
    fn test_read_flag_from_wrong_extended_file_err() {
        let flags = create_test_flags();

        // Create the file <temp_dir>/35/extended_flags_list.txt
        let temp_dir = tempdir().unwrap();
        let mut file_path = temp_dir.path().to_path_buf();
        file_path.push("35");
        fs::create_dir_all(&file_path).unwrap();
        file_path.push("extended_flags_list.txt");
        let mut file = File::create(&file_path).unwrap();

        // Write all flags to the file.
        add_flags_to_file(&mut file, &[flags[0].clone(), flags[1].clone()]);

        let err = read_extend_file_to_map_using_path(file_path.to_string_lossy().to_string())
            .unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "Provided incorrect file, must be extended_flags_list_35.txt"
        );
    }
}
