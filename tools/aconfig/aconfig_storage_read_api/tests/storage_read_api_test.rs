#[cfg(not(feature = "cargo"))]
mod aconfig_storage_rust_test {
    use aconfig_storage_file::{FlagInfoBit, FlagValueType, StorageFileType, StoredFlagType};
    use aconfig_storage_read_api::{
        get_boolean_flag_value, get_flag_attribute, get_flag_read_context,
        get_package_read_context, get_storage_file_version, mapped_file::get_mapped_file,
        PackageReadContext,
    };
    use rand::Rng;
    use std::fs;

    fn create_test_storage_files(version: u32) -> String {
        let mut rng = rand::thread_rng();
        let number: u32 = rng.gen();
        let storage_dir = String::from("/tmp/") + &number.to_string();
        if std::fs::metadata(&storage_dir).is_ok() {
            fs::remove_dir_all(&storage_dir).unwrap();
        }
        let maps_dir = storage_dir.clone() + "/maps";
        let boot_dir = storage_dir.clone() + "/boot";
        fs::create_dir(&storage_dir).unwrap();
        fs::create_dir(maps_dir).unwrap();
        fs::create_dir(boot_dir).unwrap();

        let package_map = storage_dir.clone() + "/maps/mockup.package.map";
        let flag_map = storage_dir.clone() + "/maps/mockup.flag.map";
        let flag_val = storage_dir.clone() + "/boot/mockup.val";
        let flag_info = storage_dir.clone() + "/boot/mockup.info";
        fs::copy(format!("./data/v{0}/package_v{0}.map", version), package_map).unwrap();
        fs::copy(format!("./data/v{0}/flag_v{0}.map", version), flag_map).unwrap();
        fs::copy(format!("./data/v{}/flag_v{0}.val", version), flag_val).unwrap();
        fs::copy(format!("./data/v{}/flag_v{0}.info", version), flag_info).unwrap();

        storage_dir
    }

    #[test]
    fn test_unavailable_storage() {
        let storage_dir = create_test_storage_files(1);
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let err = unsafe {
            get_mapped_file(&storage_dir, "vendor", StorageFileType::PackageMap).unwrap_err()
        };
        assert_eq!(
            format!("{:?}", err),
            format!(
                "StorageFileNotFound(storage file {}/maps/vendor.package.map does not exist)",
                storage_dir
            )
        );
    }

    #[test]
    fn test_package_context_query() {
        let storage_dir = create_test_storage_files(1);
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
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
    fn test_none_exist_package_context_query() {
        let storage_dir = create_test_storage_files(1);
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let package_mapped_file = unsafe {
            get_mapped_file(&storage_dir, "mockup", StorageFileType::PackageMap).unwrap()
        };

        let package_context_option =
            get_package_read_context(&package_mapped_file, "com.android.aconfig.storage.test_3")
                .unwrap();
        assert_eq!(package_context_option, None);
    }

    #[test]
    fn test_flag_context_query() {
        let storage_dir = create_test_storage_files(1);
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
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
    fn test_none_exist_flag_context_query() {
        let storage_dir = create_test_storage_files(1);
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_mapped_file =
            unsafe { get_mapped_file(&storage_dir, "mockup", StorageFileType::FlagMap).unwrap() };
        let flag_context_option =
            get_flag_read_context(&flag_mapped_file, 0, "none_exist").unwrap();
        assert_eq!(flag_context_option, None);

        let flag_context_option =
            get_flag_read_context(&flag_mapped_file, 3, "enabled_ro").unwrap();
        assert_eq!(flag_context_option, None);
    }

    #[test]
    fn test_boolean_flag_value_query() {
        let storage_dir = create_test_storage_files(1);
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_value_file =
            unsafe { get_mapped_file(&storage_dir, "mockup", StorageFileType::FlagVal).unwrap() };
        let baseline: Vec<bool> = vec![false, true, true, false, true, true, true, true];
        for (offset, expected_value) in baseline.into_iter().enumerate() {
            let flag_value = get_boolean_flag_value(&flag_value_file, offset as u32).unwrap();
            assert_eq!(flag_value, expected_value);
        }
    }

    #[test]
    fn test_invalid_boolean_flag_value_query() {
        let storage_dir = create_test_storage_files(1);
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_value_file =
            unsafe { get_mapped_file(&storage_dir, "mockup", StorageFileType::FlagVal).unwrap() };
        let err = get_boolean_flag_value(&flag_value_file, 8u32).unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "InvalidStorageFileOffset(Flag value offset goes beyond the end of the file.)"
        );
    }

    #[test]
    fn test_flag_info_query() {
        let storage_dir = create_test_storage_files(1);
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_info_file =
            unsafe { get_mapped_file(&storage_dir, "mockup", StorageFileType::FlagInfo).unwrap() };
        let is_rw: Vec<bool> = vec![true, false, true, true, false, false, false, true];
        for (offset, expected_value) in is_rw.into_iter().enumerate() {
            let attribute =
                get_flag_attribute(&flag_info_file, FlagValueType::Boolean, offset as u32).unwrap();
            assert!((attribute & FlagInfoBit::HasServerOverride as u8) == 0u8);
            assert_eq!((attribute & FlagInfoBit::IsReadWrite as u8) != 0u8, expected_value);
            assert!((attribute & FlagInfoBit::HasLocalOverride as u8) == 0u8);
        }
    }

    #[test]
    fn test_invalid_boolean_flag_info_query() {
        let storage_dir = create_test_storage_files(1);
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_info_file =
            unsafe { get_mapped_file(&storage_dir, "mockup", StorageFileType::FlagInfo).unwrap() };
        let err = get_flag_attribute(&flag_info_file, FlagValueType::Boolean, 8u32).unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "InvalidStorageFileOffset(Flag info offset goes beyond the end of the file.)"
        );
    }

    #[test]
    fn test_storage_version_query_v1() {
        assert_eq!(get_storage_file_version("./data/v1/package_v1.map").unwrap(), 1);
        assert_eq!(get_storage_file_version("./data/v1/flag_v1.map").unwrap(), 1);
        assert_eq!(get_storage_file_version("./data/v1/flag_v1.val").unwrap(), 1);
        assert_eq!(get_storage_file_version("./data/v1/flag_v1.info").unwrap(), 1);
    }

    #[test]
    fn test_storage_version_query_v2() {
        assert_eq!(get_storage_file_version("./data/v2/package_v2.map").unwrap(), 2);
        assert_eq!(get_storage_file_version("./data/v2/flag_v2.map").unwrap(), 2);
        assert_eq!(get_storage_file_version("./data/v2/flag_v2.val").unwrap(), 2);
        assert_eq!(get_storage_file_version("./data/v2/flag_v2.info").unwrap(), 2);
    }
}
