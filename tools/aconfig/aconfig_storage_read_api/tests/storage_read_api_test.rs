#[cfg(not(feature = "cargo"))]
mod aconfig_storage_rust_test {
    use aconfig_storage_file::protos::storage_record_pb::write_proto_to_temp_file;
    use aconfig_storage_file::StorageFileType;
    use aconfig_storage_read_api::{
        get_boolean_flag_value, get_flag_offset, get_package_offset, get_storage_file_version,
        mapped_file::get_mapped_file, PackageOffset,
    };
    use std::fs;
    use tempfile::NamedTempFile;

    pub fn copy_to_temp_file(source_file: &str) -> NamedTempFile {
        let file = NamedTempFile::new().unwrap();
        fs::copy(source_file, file.path()).unwrap();
        file
    }

    fn create_test_storage_files() -> [NamedTempFile; 4] {
        let package_map = copy_to_temp_file("./package.map");
        let flag_map = copy_to_temp_file("./flag.map");
        let flag_val = copy_to_temp_file("./flag.val");

        let text_proto = format!(
            r#"
files {{
    version: 0
    container: "mockup"
    package_map: "{}"
    flag_map: "{}"
    flag_val: "{}"
    timestamp: 12345
}}
"#,
            package_map.path().display(),
            flag_map.path().display(),
            flag_val.path().display()
        );
        let pb_file = write_proto_to_temp_file(&text_proto).unwrap();
        [package_map, flag_map, flag_val, pb_file]
    }

    #[test]
    fn test_unavailable_stoarge() {
        let [_package_map, _flag_map, _flag_val, pb_file] = create_test_storage_files();
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
    fn test_package_offset_query() {
        let [_package_map, _flag_map, _flag_val, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let package_mapped_file = unsafe {
            get_mapped_file(&pb_file_path, "mockup", StorageFileType::PackageMap).unwrap()
        };

        let package_offset =
            get_package_offset(&package_mapped_file, "com.android.aconfig.storage.test_1")
                .unwrap()
                .unwrap();
        let expected_package_offset = PackageOffset { package_id: 0, boolean_offset: 0 };
        assert_eq!(package_offset, expected_package_offset);

        let package_offset =
            get_package_offset(&package_mapped_file, "com.android.aconfig.storage.test_2")
                .unwrap()
                .unwrap();
        let expected_package_offset = PackageOffset { package_id: 1, boolean_offset: 3 };
        assert_eq!(package_offset, expected_package_offset);

        let package_offset =
            get_package_offset(&package_mapped_file, "com.android.aconfig.storage.test_4")
                .unwrap()
                .unwrap();
        let expected_package_offset = PackageOffset { package_id: 2, boolean_offset: 6 };
        assert_eq!(package_offset, expected_package_offset);
    }

    #[test]
    fn test_none_exist_package_offset_query() {
        let [_package_map, _flag_map, _flag_val, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let package_mapped_file = unsafe {
            get_mapped_file(&pb_file_path, "mockup", StorageFileType::PackageMap).unwrap()
        };

        let package_offset_option =
            get_package_offset(&package_mapped_file, "com.android.aconfig.storage.test_3").unwrap();
        assert_eq!(package_offset_option, None);
    }

    #[test]
    fn test_flag_offset_query() {
        let [_package_map, _flag_map, _flag_val, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_mapped_file =
            unsafe { get_mapped_file(&pb_file_path, "mockup", StorageFileType::FlagMap).unwrap() };

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
                get_flag_offset(&flag_mapped_file, package_id, flag_name).unwrap().unwrap();
            assert_eq!(flag_offset, expected_offset);
        }
    }

    #[test]
    fn test_none_exist_flag_offset_query() {
        let [_package_map, _flag_map, _flag_val, pb_file] = create_test_storage_files();
        let pb_file_path = pb_file.path().display().to_string();
        // SAFETY:
        // The safety here is ensured as the test process will not write to temp storage file
        let flag_mapped_file =
            unsafe { get_mapped_file(&pb_file_path, "mockup", StorageFileType::FlagMap).unwrap() };
        let flag_offset_option = get_flag_offset(&flag_mapped_file, 0, "none_exist").unwrap();
        assert_eq!(flag_offset_option, None);

        let flag_offset_option = get_flag_offset(&flag_mapped_file, 3, "enabled_ro").unwrap();
        assert_eq!(flag_offset_option, None);
    }

    #[test]
    fn test_boolean_flag_value_query() {
        let [_package_map, _flag_map, _flag_val, pb_file] = create_test_storage_files();
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
        let [_package_map, _flag_map, _flag_val, pb_file] = create_test_storage_files();
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
    fn test_storage_version_query() {
        assert_eq!(get_storage_file_version("./package.map").unwrap(), 1);
        assert_eq!(get_storage_file_version("./flag.map").unwrap(), 1);
        assert_eq!(get_storage_file_version("./flag.val").unwrap(), 1);
    }
}
