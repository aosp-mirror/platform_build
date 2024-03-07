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

//! `aconfig_storage_read_api` is a crate that defines read apis to read flags from storage
//! files. It provides four apis to interface with storage files:
//!
//! 1, function to get package flag value start offset
//! pub fn get_package_offset(container: &str, package: &str) -> `Result<Option<PackageOffset>>>`
//!
//! 2, function to get flag offset within a specific package
//! pub fn get_flag_offset(container: &str, package_id: u32, flag: &str) -> `Result<Option<u16>>>`
//!
//! 3, function to get the actual flag value given the global offset (combined package and
//! flag offset).
//! pub fn get_boolean_flag_value(container: &str, offset: u32) -> `Result<bool>`
//!
//! 4, function to get storage file version without mmapping the file.
//! pub fn get_storage_file_version(file_path: &str) -> Result<u32, AconfigStorageError>
//!
//! Note these are low level apis that are expected to be only used in auto generated flag
//! apis. DO NOT DIRECTLY USE THESE APIS IN YOUR SOURCE CODE. For auto generated flag apis
//! please refer to the g3doc go/android-flags

pub mod flag_table_query;
pub mod flag_value_query;
pub mod mapped_file;
pub mod package_table_query;

#[cfg(test)]
mod test_utils;

pub use aconfig_storage_file::{
    protos::ProtoStorageFiles, read_u32_from_bytes, AconfigStorageError, StorageFileSelection,
    FILE_VERSION,
};
pub use flag_table_query::FlagOffset;
pub use package_table_query::PackageOffset;

use flag_table_query::find_flag_offset;
use flag_value_query::find_boolean_flag_value;
use mapped_file::get_mapped_file;
use package_table_query::find_package_offset;

use anyhow::anyhow;
use std::fs::File;
use std::io::Read;

/// Storage file location pb file
pub const STORAGE_LOCATION_FILE: &str = "/metadata/aconfig/available_storage_file_records.pb";

/// Get package start offset implementation
pub fn get_package_offset_impl(
    pb_file: &str,
    container: &str,
    package: &str,
) -> Result<Option<PackageOffset>, AconfigStorageError> {
    let mapped_file = get_mapped_file(pb_file, container, StorageFileSelection::PackageMap)?;
    find_package_offset(&mapped_file, package)
}

/// Get flag offset implementation
pub fn get_flag_offset_impl(
    pb_file: &str,
    container: &str,
    package_id: u32,
    flag: &str,
) -> Result<Option<FlagOffset>, AconfigStorageError> {
    let mapped_file = get_mapped_file(pb_file, container, StorageFileSelection::FlagMap)?;
    find_flag_offset(&mapped_file, package_id, flag)
}

/// Get boolean flag value implementation
pub fn get_boolean_flag_value_impl(
    pb_file: &str,
    container: &str,
    offset: u32,
) -> Result<bool, AconfigStorageError> {
    let mapped_file = get_mapped_file(pb_file, container, StorageFileSelection::FlagVal)?;
    find_boolean_flag_value(&mapped_file, offset)
}

/// Get storage file version number
///
/// This function would read the first four bytes of the file and interpret it as the
/// version number of the file. There are unit tests in aconfig_storage_file crate to
/// lock down that for all storage files, the first four bytes will be the version
/// number of the storage file
pub fn get_storage_file_version(file_path: &str) -> Result<u32, AconfigStorageError> {
    let mut file = File::open(file_path).map_err(|errmsg| {
        AconfigStorageError::FileReadFail(anyhow!("Failed to open file {}: {}", file_path, errmsg))
    })?;
    let mut buffer = [0; 4];
    file.read(&mut buffer).map_err(|errmsg| {
        AconfigStorageError::FileReadFail(anyhow!(
            "Failed to read 4 bytes from file {}: {}",
            file_path,
            errmsg
        ))
    })?;
    let mut head = 0;
    read_u32_from_bytes(&buffer, &mut head)
}

/// Get package start offset for flags given the container and package name.
///
/// This function would map the corresponding package map file if has not been mapped yet,
/// and then look for the target package in this mapped file.
///
/// If a package is found, it returns Ok(Some(PackageOffset))
/// If a package is not found, it returns Ok(None)
/// If errors out such as no such package map file is found, it returns an Err(errmsg)
pub fn get_package_offset(
    container: &str,
    package: &str,
) -> Result<Option<PackageOffset>, AconfigStorageError> {
    get_package_offset_impl(STORAGE_LOCATION_FILE, container, package)
}

/// Get flag offset within a package given the container name, package id and flag name.
///
/// This function would map the corresponding flag map file if has not been mapped yet,
/// and then look for the target flag in this mapped file.
///
/// If a flag is found, it returns Ok(Some(u16))
/// If a flag is not found, it returns Ok(None)
/// If errors out such as no such flag map file is found, it returns an Err(errmsg)
pub fn get_flag_offset(
    container: &str,
    package_id: u32,
    flag: &str,
) -> Result<Option<FlagOffset>, AconfigStorageError> {
    get_flag_offset_impl(STORAGE_LOCATION_FILE, container, package_id, flag)
}

/// Get the boolean flag value given the container name and flag global offset
///
/// This function would map the corresponding flag value file if has not been mapped yet,
/// and then look for the target flag value at the specified offset.
///
/// If flag value file is successfully mapped and the provide offset is valid, it returns
/// the boolean flag value, otherwise it returns the error message.
pub fn get_boolean_flag_value(container: &str, offset: u32) -> Result<bool, AconfigStorageError> {
    get_boolean_flag_value_impl(STORAGE_LOCATION_FILE, container, offset)
}

// *************************************** //
// CC INTERLOP
// *************************************** //

// Exported rust data structure and methods, c++ code will be generated
#[cxx::bridge]
mod ffi {
    // Storage file version query return for cc interlop
    pub struct VersionNumberQueryCXX {
        pub query_success: bool,
        pub error_message: String,
        pub version_number: u32,
    }

    // Package table query return for cc interlop
    pub struct PackageOffsetQueryCXX {
        pub query_success: bool,
        pub error_message: String,
        pub package_exists: bool,
        pub package_id: u32,
        pub boolean_offset: u32,
    }

    // Flag table query return for cc interlop
    pub struct FlagOffsetQueryCXX {
        pub query_success: bool,
        pub error_message: String,
        pub flag_exists: bool,
        pub flag_offset: u16,
    }

    // Flag value query return for cc interlop
    pub struct BooleanFlagValueQueryCXX {
        pub query_success: bool,
        pub error_message: String,
        pub flag_value: bool,
    }

    // Rust export to c++
    extern "Rust" {
        pub fn get_package_offset_cxx_impl(
            pb_file: &str,
            container: &str,
            package: &str,
        ) -> PackageOffsetQueryCXX;

        pub fn get_flag_offset_cxx_impl(
            pb_file: &str,
            container: &str,
            package_id: u32,
            flag: &str,
        ) -> FlagOffsetQueryCXX;

        pub fn get_boolean_flag_value_cxx_impl(
            pb_file: &str,
            container: &str,
            offset: u32,
        ) -> BooleanFlagValueQueryCXX;

        pub fn get_storage_file_version_cxx(file_path: &str) -> VersionNumberQueryCXX;

        pub fn get_package_offset_cxx(container: &str, package: &str) -> PackageOffsetQueryCXX;

        pub fn get_flag_offset_cxx(
            container: &str,
            package_id: u32,
            flag: &str,
        ) -> FlagOffsetQueryCXX;

        pub fn get_boolean_flag_value_cxx(container: &str, offset: u32)
            -> BooleanFlagValueQueryCXX;
    }
}

/// Implement the package offset interlop return type, create from actual package offset api return type
impl ffi::PackageOffsetQueryCXX {
    pub(crate) fn new(offset_result: Result<Option<PackageOffset>, AconfigStorageError>) -> Self {
        match offset_result {
            Ok(offset_opt) => match offset_opt {
                Some(offset) => Self {
                    query_success: true,
                    error_message: String::from(""),
                    package_exists: true,
                    package_id: offset.package_id,
                    boolean_offset: offset.boolean_offset,
                },
                None => Self {
                    query_success: true,
                    error_message: String::from(""),
                    package_exists: false,
                    package_id: 0,
                    boolean_offset: 0,
                },
            },
            Err(errmsg) => Self {
                query_success: false,
                error_message: format!("{:?}", errmsg),
                package_exists: false,
                package_id: 0,
                boolean_offset: 0,
            },
        }
    }
}

/// Implement the flag offset interlop return type, create from actual flag offset api return type
impl ffi::FlagOffsetQueryCXX {
    pub(crate) fn new(offset_result: Result<Option<FlagOffset>, AconfigStorageError>) -> Self {
        match offset_result {
            Ok(offset_opt) => match offset_opt {
                Some(offset) => Self {
                    query_success: true,
                    error_message: String::from(""),
                    flag_exists: true,
                    flag_offset: offset,
                },
                None => Self {
                    query_success: true,
                    error_message: String::from(""),
                    flag_exists: false,
                    flag_offset: 0,
                },
            },
            Err(errmsg) => Self {
                query_success: false,
                error_message: format!("{:?}", errmsg),
                flag_exists: false,
                flag_offset: 0,
            },
        }
    }
}

/// Implement the flag value interlop return type, create from actual flag value api return type
impl ffi::BooleanFlagValueQueryCXX {
    pub(crate) fn new(value_result: Result<bool, AconfigStorageError>) -> Self {
        match value_result {
            Ok(value) => {
                Self { query_success: true, error_message: String::from(""), flag_value: value }
            }
            Err(errmsg) => Self {
                query_success: false,
                error_message: format!("{:?}", errmsg),
                flag_value: false,
            },
        }
    }
}

/// Implement the storage version number interlop return type, create from actual version number
/// api return type
impl ffi::VersionNumberQueryCXX {
    pub(crate) fn new(version_result: Result<u32, AconfigStorageError>) -> Self {
        match version_result {
            Ok(version) => Self {
                query_success: true,
                error_message: String::from(""),
                version_number: version,
            },
            Err(errmsg) => Self {
                query_success: false,
                error_message: format!("{:?}", errmsg),
                version_number: 0,
            },
        }
    }
}

/// Get package start offset impl cc interlop
pub fn get_package_offset_cxx_impl(
    pb_file: &str,
    container: &str,
    package: &str,
) -> ffi::PackageOffsetQueryCXX {
    ffi::PackageOffsetQueryCXX::new(get_package_offset_impl(pb_file, container, package))
}

/// Get flag start offset impl cc interlop
pub fn get_flag_offset_cxx_impl(
    pb_file: &str,
    container: &str,
    package_id: u32,
    flag: &str,
) -> ffi::FlagOffsetQueryCXX {
    ffi::FlagOffsetQueryCXX::new(get_flag_offset_impl(pb_file, container, package_id, flag))
}

/// Get boolean flag value impl cc interlop
pub fn get_boolean_flag_value_cxx_impl(
    pb_file: &str,
    container: &str,
    offset: u32,
) -> ffi::BooleanFlagValueQueryCXX {
    ffi::BooleanFlagValueQueryCXX::new(get_boolean_flag_value_impl(pb_file, container, offset))
}

/// Get storage version number cc interlop
pub fn get_storage_file_version_cxx(file_path: &str) -> ffi::VersionNumberQueryCXX {
    ffi::VersionNumberQueryCXX::new(get_storage_file_version(file_path))
}

/// Get package start offset cc interlop
pub fn get_package_offset_cxx(container: &str, package: &str) -> ffi::PackageOffsetQueryCXX {
    ffi::PackageOffsetQueryCXX::new(get_package_offset(container, package))
}

/// Get flag start offset cc interlop
pub fn get_flag_offset_cxx(
    container: &str,
    package_id: u32,
    flag: &str,
) -> ffi::FlagOffsetQueryCXX {
    ffi::FlagOffsetQueryCXX::new(get_flag_offset(container, package_id, flag))
}

/// Get boolean flag value cc interlop
pub fn get_boolean_flag_value_cxx(container: &str, offset: u32) -> ffi::BooleanFlagValueQueryCXX {
    ffi::BooleanFlagValueQueryCXX::new(get_boolean_flag_value(container, offset))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::TestStorageFileSet;
    use aconfig_storage_file::protos::storage_record_pb::write_proto_to_temp_file;

    fn create_test_storage_files(read_only: bool) -> TestStorageFileSet {
        TestStorageFileSet::new(
            "./tests/package.map",
            "./tests/flag.map",
            "./tests/flag.val",
            read_only,
        )
        .unwrap()
    }

    #[test]
    // this test point locks down flag package offset query
    fn test_package_offset_query() {
        let ro_files = create_test_storage_files(true);
        let text_proto = format!(
            r#"
files {{
    version: 0
    container: "system"
    package_map: "{}"
    flag_map: "{}"
    flag_val: "{}"
    timestamp: 12345
}}
"#,
            ro_files.package_map.name, ro_files.flag_map.name, ro_files.flag_val.name
        );

        let file = write_proto_to_temp_file(&text_proto).unwrap();
        let file_full_path = file.path().display().to_string();
        let package_offset = get_package_offset_impl(
            &file_full_path,
            "system",
            "com.android.aconfig.storage.test_1",
        )
        .unwrap()
        .unwrap();
        let expected_package_offset = PackageOffset { package_id: 0, boolean_offset: 0 };
        assert_eq!(package_offset, expected_package_offset);

        let package_offset = get_package_offset_impl(
            &file_full_path,
            "system",
            "com.android.aconfig.storage.test_2",
        )
        .unwrap()
        .unwrap();
        let expected_package_offset = PackageOffset { package_id: 1, boolean_offset: 3 };
        assert_eq!(package_offset, expected_package_offset);

        let package_offset = get_package_offset_impl(
            &file_full_path,
            "system",
            "com.android.aconfig.storage.test_4",
        )
        .unwrap()
        .unwrap();
        let expected_package_offset = PackageOffset { package_id: 2, boolean_offset: 6 };
        assert_eq!(package_offset, expected_package_offset);
    }

    #[test]
    // this test point locks down flag offset query
    fn test_flag_offset_query() {
        let ro_files = create_test_storage_files(true);
        let text_proto = format!(
            r#"
files {{
    version: 0
    container: "system"
    package_map: "{}"
    flag_map: "{}"
    flag_val: "{}"
    timestamp: 12345
}}
"#,
            ro_files.package_map.name, ro_files.flag_map.name, ro_files.flag_val.name
        );

        let file = write_proto_to_temp_file(&text_proto).unwrap();
        let file_full_path = file.path().display().to_string();
        let baseline = vec![
            (0, "enabled_ro", 1u16),
            (0, "enabled_rw", 2u16),
            (1, "disabled_ro", 0u16),
            (2, "enabled_ro", 1u16),
            (1, "enabled_fixed_ro", 1u16),
            (1, "enabled_ro", 2u16),
            (2, "enabled_fixed_ro", 0u16),
            (0, "disabled_rw", 0u16),
        ];
        for (package_id, flag_name, expected_offset) in baseline.into_iter() {
            let flag_offset =
                get_flag_offset_impl(&file_full_path, "system", package_id, flag_name)
                    .unwrap()
                    .unwrap();
            assert_eq!(flag_offset, expected_offset);
        }
    }

    #[test]
    // this test point locks down flag offset query
    fn test_flag_value_query() {
        let ro_files = create_test_storage_files(true);
        let text_proto = format!(
            r#"
files {{
    version: 0
    container: "system"
    package_map: "{}"
    flag_map: "{}"
    flag_val: "{}"
    timestamp: 12345
}}
"#,
            ro_files.package_map.name, ro_files.flag_map.name, ro_files.flag_val.name
        );

        let file = write_proto_to_temp_file(&text_proto).unwrap();
        let file_full_path = file.path().display().to_string();
        let baseline: Vec<bool> = vec![false; 8];
        for (offset, expected_value) in baseline.into_iter().enumerate() {
            let flag_value =
                get_boolean_flag_value_impl(&file_full_path, "system", offset as u32).unwrap();
            assert_eq!(flag_value, expected_value);
        }
    }

    #[test]
    // this test point locks down flag storage file version number query api
    fn test_storage_version_query() {
        let _ro_files = create_test_storage_files(true);
        assert_eq!(get_storage_file_version("./tests/package.map").unwrap(), 1);
        assert_eq!(get_storage_file_version("./tests/flag.map").unwrap(), 1);
        assert_eq!(get_storage_file_version("./tests/flag.val").unwrap(), 1);
    }
}
