#[cfg(not(feature = "cargo"))]
mod aconfig_storage_rust_test {
    use aconfig_storage_file::protos::storage_record_pb::write_proto_to_temp_file;
    use aconfig_storage_file::{FlagInfoBit, FlagValueType, StorageFileType, StoredFlagType};
    use aconfig_storage_read_api::{
        get_boolean_flag_value, get_flag_attribute, get_flag_read_context,
        get_package_read_context, get_storage_file_version, mapped_file::get_mapped_file,
        PackageReadContext,
    };
    use std::fs;
    use tempfile::NamedTempFile;

    pub fn copy_to_temp_file(source_file: &str) -> NamedTempFile {
        let file = NamedTempFile::new().unwrap();
        fs::copy(source_file, file.path()).unwrap();
        file
    }

    fn create_test_storage_files() -> [NamedTempFile; 5] {
        let package_map = copy_to_temp_file("./package.map");
        let flag_map = copy_to_temp_file("./flag.map");
        let flag_val = copy_to_temp_file("./flag.val");
        let flag_info = copy_to_temp_file("./flag.info");

        let text_proto = format!(
            r#"
files {{
    version: 0
    container: "mockup"
    package_map: "{}"
    flag_map: "{}"
    flag_val: "{}"
    flag_info: "{}"
    timestamp: 12345
}}
"#,
            package_map.path().display(),
            flag_map.path().display(),
            flag_val.path().display(),
            flag_info.path().display()
        );
        let pb_file = write_proto_to_temp_file(&text_proto).unwrap();
        [package_map, flag_map, flag_val, flag_info, pb_file]
    }

    #[test]
    fn test_unavailable_stoarge() {
        let [_package_map, _flag_map, _flag_val, _flag_info, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let err = unsafe {
            get_mapped_file(&pb_file_path, "vendor", StorageFileType::PackageMap).unwrap_err()
        };
        assert_eq!(
            format!("{:?}", err),
            "StorageFileNotFound(Storage file does not exist for vendor)"
        );
    }

    #[test]
    fn test_package_context_query() {
        let [_package_map, _flag_map, _flag_val, _flag_info, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let package_mapped_file = unsafe {
            get_mapped_file(&pb_file_path, "mockup", StorageFileType::PackageMap).unwrap()
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
        let [_package_map, _flag_map, _flag_val, _flag_info, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let package_mapped_file = unsafe {
            get_mapped_file(&pb_file_path, "mockup", StorageFileType::PackageMap).unwrap()
        };

        let package_context_option =
            get_package_read_context(&package_mapped_file, "com.android.aconfig.storage.test_3")
                .unwrap();
        assert_eq!(package_context_option, None);
    }

    #[test]
    fn test_flag_context_query() {
        let [_package_map, _flag_map, _flag_val, _flag_info, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_mapped_file =
            unsafe { get_mapped_file(&pb_file_path, "mockup", StorageFileType::FlagMap).unwrap() };

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
        let [_package_map, _flag_map, _flag_val, _flag_info, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_mapped_file =
            unsafe { get_mapped_file(&pb_file_path, "mockup", StorageFileType::FlagMap).unwrap() };
        let flag_context_option =
            get_flag_read_context(&flag_mapped_file, 0, "none_exist").unwrap();
        assert_eq!(flag_context_option, None);

        let flag_context_option =
            get_flag_read_context(&flag_mapped_file, 3, "enabled_ro").unwrap();
        assert_eq!(flag_context_option, None);
    }

    #[test]
    fn test_boolean_flag_value_query() {
        let [_package_map, _flag_map, _flag_val, _flag_info, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_value_file =
            unsafe { get_mapped_file(&pb_file_path, "mockup", StorageFileType::FlagVal).unwrap() };
        let baseline: Vec<bool> = vec![false, true, true, false, true, true, true, true];
        for (offset, expected_value) in baseline.into_iter().enumerate() {
            let flag_value = get_boolean_flag_value(&flag_value_file, offset as u32).unwrap();
            assert_eq!(flag_value, expected_value);
        }
    }

    #[test]
    fn test_invalid_boolean_flag_value_query() {
        let [_package_map, _flag_map, _flag_val, _flag_info, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_value_file =
            unsafe { get_mapped_file(&pb_file_path, "mockup", StorageFileType::FlagVal).unwrap() };
        let err = get_boolean_flag_value(&flag_value_file, 8u32).unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "InvalidStorageFileOffset(Flag value offset goes beyond the end of the file.)"
        );
    }

    #[test]
    fn test_flag_info_query() {
        let [_package_map, _flag_map, _flag_val, _flag_info, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_info_file =
            unsafe { get_mapped_file(&pb_file_path, "mockup", StorageFileType::FlagInfo).unwrap() };
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
        let [_package_map, _flag_map, _flag_val, _flag_info, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_info_file =
            unsafe { get_mapped_file(&pb_file_path, "mockup", StorageFileType::FlagInfo).unwrap() };
        let err = get_flag_attribute(&flag_info_file, FlagValueType::Boolean, 8u32).unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "InvalidStorageFileOffset(Flag info offset goes beyond the end of the file.)"
        );
    }

    #[test]
    fn test_storage_version_query() {
        assert_eq!(get_storage_file_version("./package.map").unwrap(), 1);
        assert_eq!(get_storage_file_version("./flag.map").unwrap(), 1);
        assert_eq!(get_storage_file_version("./flag.val").unwrap(), 1);
        assert_eq!(get_storage_file_version("./flag.info").unwrap(), 1);
    }
}
