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
//! 1, function to get package read context
//! pub fn get_packager_read_context(container: &str, package: &str)
//! -> `Result<Option<PackageReadContext>>>`
//!
//! 2, function to get flag read context
//! pub fn get_flag_read_context(container: &str, package_id: u32, flag: &str)
//! -> `Result<Option<FlagReadContext>>>`
//!
//! 3, function to get the actual flag value given the global index (combined package and
//! flag index).
//! pub fn get_boolean_flag_value(container: &str, offset: u32) -> `Result<bool>`
//!
//! 4, function to get storage file version without mmapping the file.
//! pub fn get_storage_file_version(file_path: &str) -> Result<u32, AconfigStorageError>
//!
//! Note these are low level apis that are expected to be only used in auto generated flag
//! apis. DO NOT DIRECTLY USE THESE APIS IN YOUR SOURCE CODE. For auto generated flag apis
//! please refer to the g3doc go/android-flags

pub mod flag_info_query;
pub mod flag_table_query;
pub mod flag_value_query;
pub mod mapped_file;
pub mod package_table_query;

pub use aconfig_storage_file::{AconfigStorageError, FlagValueType, StorageFileType};
pub use flag_table_query::FlagReadContext;
pub use mapped_file::map_file;
pub use package_table_query::PackageReadContext;

use aconfig_storage_file::read_u32_from_bytes;
use flag_info_query::find_flag_attribute;
use flag_table_query::find_flag_read_context;
use flag_value_query::find_boolean_flag_value;
use package_table_query::find_package_read_context;

use anyhow::anyhow;
pub use memmap2::Mmap;
use std::fs::File;
use std::io::Read;

/// Storage file location
pub const STORAGE_LOCATION: &str = "/metadata/aconfig";

/// Get read only mapped storage files.
///
/// \input container: the flag package container
/// \input file_type: stoarge file type enum
/// \return a result of read only mapped file
///
/// # Safety
///
/// The memory mapped file may have undefined behavior if there are writes to this
/// file after being mapped. Ensure no writes can happen to this file while this
/// mapping stays alive.
pub unsafe fn get_mapped_storage_file(
    container: &str,
    file_type: StorageFileType,
) -> Result<Mmap, AconfigStorageError> {
    unsafe { crate::mapped_file::get_mapped_file(STORAGE_LOCATION, container, file_type) }
}

/// Get package read context for a specific package.
///
/// \input file: mapped package file
/// \input package: package name
///
/// \return
/// If a package is found, it returns Ok(Some(PackageReadContext))
/// If a package is not found, it returns Ok(None)
/// If errors out, it returns an Err(errmsg)
pub fn get_package_read_context(
    file: &Mmap,
    package: &str,
) -> Result<Option<PackageReadContext>, AconfigStorageError> {
    find_package_read_context(file, package)
}

/// Get flag read context for a specific flag.
///
/// \input file: mapped flag file
/// \input package_id: package id obtained from package mapping file
/// \input flag: flag name
///
/// \return
/// If a flag is found, it returns Ok(Some(FlagReadContext))
/// If a flag is not found, it returns Ok(None)
/// If errors out, it returns an Err(errmsg)
pub fn get_flag_read_context(
    file: &Mmap,
    package_id: u32,
    flag: &str,
) -> Result<Option<FlagReadContext>, AconfigStorageError> {
    find_flag_read_context(file, package_id, flag)
}

/// Get the boolean flag value.
///
/// \input file: a byte slice, can be either &Mmap or &MapMut
/// \input index: boolean flag offset
///
/// \return
/// If the provide offset is valid, it returns the boolean flag value, otherwise it
/// returns the error message.
pub fn get_boolean_flag_value(file: &[u8], index: u32) -> Result<bool, AconfigStorageError> {
    find_boolean_flag_value(file, index)
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

/// Get the flag attribute.
///
/// \input file: a byte slice, can be either &Mmap or &MapMut
/// \input flag_type: flag value type
/// \input flag_index: flag index
///
/// \return
/// If the provide offset is valid, it returns the flag attribute bitfiled, otherwise it
/// returns the error message.
pub fn get_flag_attribute(
    file: &[u8],
    flag_type: FlagValueType,
    flag_index: u32,
) -> Result<u8, AconfigStorageError> {
    find_flag_attribute(file, flag_type, flag_index)
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
    pub struct PackageReadContextQueryCXX {
        pub query_success: bool,
        pub error_message: String,
        pub package_exists: bool,
        pub package_id: u32,
        pub boolean_start_index: u32,
    }

    // Flag table query return for cc interlop
    pub struct FlagReadContextQueryCXX {
        pub query_success: bool,
        pub error_message: String,
        pub flag_exists: bool,
        pub flag_type: u16,
        pub flag_index: u16,
    }

    // Flag value query return for cc interlop
    pub struct BooleanFlagValueQueryCXX {
        pub query_success: bool,
        pub error_message: String,
        pub flag_value: bool,
    }

    // Flag info query return for cc interlop
    pub struct FlagAttributeQueryCXX {
        pub query_success: bool,
        pub error_message: String,
        pub flag_attribute: u8,
    }

    // Rust export to c++
    extern "Rust" {
        pub fn get_storage_file_version_cxx(file_path: &str) -> VersionNumberQueryCXX;

        pub fn get_package_read_context_cxx(
            file: &[u8],
            package: &str,
        ) -> PackageReadContextQueryCXX;

        pub fn get_flag_read_context_cxx(
            file: &[u8],
            package_id: u32,
            flag: &str,
        ) -> FlagReadContextQueryCXX;

        pub fn get_boolean_flag_value_cxx(file: &[u8], offset: u32) -> BooleanFlagValueQueryCXX;

        pub fn get_flag_attribute_cxx(
            file: &[u8],
            flag_type: u16,
            flag_index: u32,
        ) -> FlagAttributeQueryCXX;
    }
}

/// Implement the package offset interlop return type, create from actual package offset api return type
impl ffi::PackageReadContextQueryCXX {
    pub(crate) fn new(
        offset_result: Result<Option<PackageReadContext>, AconfigStorageError>,
    ) -> Self {
        match offset_result {
            Ok(offset_opt) => match offset_opt {
                Some(offset) => Self {
                    query_success: true,
                    error_message: String::from(""),
                    package_exists: true,
                    package_id: offset.package_id,
                    boolean_start_index: offset.boolean_start_index,
                },
                None => Self {
                    query_success: true,
                    error_message: String::from(""),
                    package_exists: false,
                    package_id: 0,
                    boolean_start_index: 0,
                },
            },
            Err(errmsg) => Self {
                query_success: false,
                error_message: format!("{:?}", errmsg),
                package_exists: false,
                package_id: 0,
                boolean_start_index: 0,
            },
        }
    }
}

/// Implement the flag offset interlop return type, create from actual flag offset api return type
impl ffi::FlagReadContextQueryCXX {
    pub(crate) fn new(offset_result: Result<Option<FlagReadContext>, AconfigStorageError>) -> Self {
        match offset_result {
            Ok(offset_opt) => match offset_opt {
                Some(offset) => Self {
                    query_success: true,
                    error_message: String::from(""),
                    flag_exists: true,
                    flag_type: offset.flag_type as u16,
                    flag_index: offset.flag_index,
                },
                None => Self {
                    query_success: true,
                    error_message: String::from(""),
                    flag_exists: false,
                    flag_type: 0u16,
                    flag_index: 0u16,
                },
            },
            Err(errmsg) => Self {
                query_success: false,
                error_message: format!("{:?}", errmsg),
                flag_exists: false,
                flag_type: 0u16,
                flag_index: 0u16,
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

/// Implement the flag info interlop return type, create from actual flag info api return type
impl ffi::FlagAttributeQueryCXX {
    pub(crate) fn new(info_result: Result<u8, AconfigStorageError>) -> Self {
        match info_result {
            Ok(info) => {
                Self { query_success: true, error_message: String::from(""), flag_attribute: info }
            }
            Err(errmsg) => Self {
                query_success: false,
                error_message: format!("{:?}", errmsg),
                flag_attribute: 0u8,
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

/// Get package read context cc interlop
pub fn get_package_read_context_cxx(file: &[u8], package: &str) -> ffi::PackageReadContextQueryCXX {
    ffi::PackageReadContextQueryCXX::new(find_package_read_context(file, package))
}

/// Get flag read context cc interlop
pub fn get_flag_read_context_cxx(
    file: &[u8],
    package_id: u32,
    flag: &str,
) -> ffi::FlagReadContextQueryCXX {
    ffi::FlagReadContextQueryCXX::new(find_flag_read_context(file, package_id, flag))
}

/// Get boolean flag value cc interlop
pub fn get_boolean_flag_value_cxx(file: &[u8], offset: u32) -> ffi::BooleanFlagValueQueryCXX {
    ffi::BooleanFlagValueQueryCXX::new(find_boolean_flag_value(file, offset))
}

/// Get flag attribute cc interlop
pub fn get_flag_attribute_cxx(
    file: &[u8],
    flag_type: u16,
    flag_index: u32,
) -> ffi::FlagAttributeQueryCXX {
    match FlagValueType::try_from(flag_type) {
        Ok(value_type) => {
            ffi::FlagAttributeQueryCXX::new(find_flag_attribute(file, value_type, flag_index))
        }
        Err(errmsg) => ffi::FlagAttributeQueryCXX::new(Err(errmsg)),
    }
}

/// Get storage version number cc interlop
pub fn get_storage_file_version_cxx(file_path: &str) -> ffi::VersionNumberQueryCXX {
    ffi::VersionNumberQueryCXX::new(get_storage_file_version(file_path))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::mapped_file::get_mapped_file;
    use aconfig_storage_file::{FlagInfoBit, StoredFlagType};
    use rand::Rng;
    use std::fs;

    fn create_test_storage_files() -> String {
        let mut rng = rand::thread_rng();
        let number: u32 = rng.gen();
        let storage_dir = String::from("/tmp/") + &number.to_string();
        if std::fs::metadata(&storage_dir).is_ok() {
            fs::remove_dir_all(&storage_dir).unwrap();
        }
        let maps_dir = storage_dir.clone() + "/maps";
        let boot_dir = storage_dir.clone() + "/boot";
        fs::create_dir(&storage_dir).unwrap();
        fs::create_dir(&maps_dir).unwrap();
        fs::create_dir(&boot_dir).unwrap();

        let package_map = storage_dir.clone() + "/maps/mockup.package.map";
        let flag_map = storage_dir.clone() + "/maps/mockup.flag.map";
        let flag_val = storage_dir.clone() + "/boot/mockup.val";
        let flag_info = storage_dir.clone() + "/boot/mockup.info";
        fs::copy("./tests/data/v1/package.map", &package_map).unwrap();
        fs::copy("./tests/data/v1/flag.map", &flag_map).unwrap();
        fs::copy("./tests/data/v1/flag.val", &flag_val).unwrap();
        fs::copy("./tests/data/v1/flag.info", &flag_info).unwrap();

        return storage_dir;
    }

    #[test]
    // this test point locks down flag package read context query
    fn test_package_context_query() {
        let storage_dir = create_test_storage_files();
        let package_mapped_file = unsafe {
            get_mapped_file(&storage_dir, "mockup", StorageFileType::PackageMap).unwrap()
        };

        let package_context =
            get_package_read_context(&package_mapped_file, "com.android.aconfig.storage.test_1")
                .unwrap()
                .unwrap();
        let expected_package_context = PackageReadContext { package_id: 0, boolean_start_index: 0 };
        assert_eq!(package_context, expected_package_context);

        let package_context =
            get_package_read_context(&package_mapped_file, "com.android.aconfig.storage.test_2")
                .unwrap()
                .unwrap();
        let expected_package_context = PackageReadContext { package_id: 1, boolean_start_index: 3 };
        assert_eq!(package_context, expected_package_context);

        let package_context =
            get_package_read_context(&package_mapped_file, "com.android.aconfig.storage.test_4")
                .unwrap()
                .unwrap();
        let expected_package_context = PackageReadContext { package_id: 2, boolean_start_index: 6 };
        assert_eq!(package_context, expected_package_context);
    }

    #[test]
    // this test point locks down flag read context query
    fn test_flag_context_query() {
        let storage_dir = create_test_storage_files();
        let flag_mapped_file =
            unsafe { get_mapped_file(&storage_dir, "mockup", StorageFileType::FlagMap).unwrap() };

        let baseline = vec![
            (0, "enabled_ro", StoredFlagType::ReadOnlyBoolean, 1u16),
            (0, "enabled_rw", StoredFlagType::ReadWriteBoolean, 2u16),
            (2, "enabled_rw", StoredFlagType::ReadWriteBoolean, 1u16),
            (1, "disabled_rw", StoredFlagType::ReadWriteBoolean, 0u16),
            (1, "enabled_fixed_ro", StoredFlagType::FixedReadOnlyBoolean, 1u16),
            (1, "enabled_ro", StoredFlagType::ReadOnlyBoolean, 2u16),
            (2, "enabled_fixed_ro", StoredFlagType::FixedReadOnlyBoolean, 0u16),
            (0, "disabled_rw", StoredFlagType::ReadWriteBoolean, 0u16),
        ];
        for (package_id, flag_name, flag_type, flag_index) in baseline.into_iter() {
            let flag_context =
                get_flag_read_context(&flag_mapped_file, package_id, flag_name).unwrap().unwrap();
            assert_eq!(flag_context.flag_type, flag_type);
            assert_eq!(flag_context.flag_index, flag_index);
        }
    }

    #[test]
    // this test point locks down flag value query
    fn test_flag_value_query() {
        let storage_dir = create_test_storage_files();
        let flag_value_file =
            unsafe { get_mapped_file(&storage_dir, "mockup", StorageFileType::FlagVal).unwrap() };
        let baseline: Vec<bool> = vec![false, true, true, false, true, true, true, true];
        for (offset, expected_value) in baseline.into_iter().enumerate() {
            let flag_value = get_boolean_flag_value(&flag_value_file, offset as u32).unwrap();
            assert_eq!(flag_value, expected_value);
        }
    }

    #[test]
    // this test point locks donw flag info query
    fn test_flag_info_query() {
        let storage_dir = create_test_storage_files();
        let flag_info_file =
            unsafe { get_mapped_file(&storage_dir, "mockup", StorageFileType::FlagInfo).unwrap() };
        let is_rw: Vec<bool> = vec![true, false, true, true, false, false, false, true];
        for (offset, expected_value) in is_rw.into_iter().enumerate() {
            let attribute =
                get_flag_attribute(&flag_info_file, FlagValueType::Boolean, offset as u32).unwrap();
            assert_eq!((attribute & FlagInfoBit::IsReadWrite as u8) != 0u8, expected_value);
            assert!((attribute & FlagInfoBit::HasServerOverride as u8) == 0u8);
            assert!((attribute & FlagInfoBit::HasLocalOverride as u8) == 0u8);
        }
    }

    #[test]
    // this test point locks down flag storage file version number query api
    fn test_storage_version_query() {
        assert_eq!(get_storage_file_version("./tests/data/v1/package.map").unwrap(), 1);
        assert_eq!(get_storage_file_version("./tests/data/v1/flag.map").unwrap(), 1);
        assert_eq!(get_storage_file_version("./tests/data/v1/flag.val").unwrap(), 1);
        assert_eq!(get_storage_file_version("./tests/data/v1/flag.info").unwrap(), 1);
    }
}
