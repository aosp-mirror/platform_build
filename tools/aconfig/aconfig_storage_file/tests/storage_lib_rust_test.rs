#[cfg(not(feature = "cargo"))]
mod aconfig_storage_rust_test {
    use aconfig_storage_file::{
        get_boolean_flag_value_impl, get_flag_offset_impl, get_package_offset_impl, PackageOffset,
        ProtoStorageFiles,
    };
    use protobuf::Message;
    use std::io::Write;
    use tempfile::NamedTempFile;

    fn write_storage_location_file() -> NamedTempFile {
        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: "./tests/tmp.ro.package.map"
    flag_map: "./tests/tmp.ro.flag.map"
    flag_val: "./tests/tmp.ro.flag.val"
    timestamp: 12345
}
"#;
        let storage_files: ProtoStorageFiles =
            protobuf::text_format::parse_from_str(text_proto).unwrap();
        let mut binary_proto_bytes = Vec::new();
        storage_files.write_to_vec(&mut binary_proto_bytes).unwrap();
        let mut file = NamedTempFile::new().unwrap();
        file.write_all(&binary_proto_bytes).unwrap();
        file
    }

    #[test]
    fn test_package_offset_query() {
        let file = write_storage_location_file();
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

        let package_offset = get_package_offset_impl(
            &file_full_path,
            "system",
            "com.android.aconfig.storage.test_3",
        )
        .unwrap();
        assert_eq!(package_offset, None);
    }

    #[test]
    fn test_invalid_package_offset_query() {
        let file = write_storage_location_file();
        let file_full_path = file.path().display().to_string();

        let package_offset_option = get_package_offset_impl(
            &file_full_path,
            "system",
            "com.android.aconfig.storage.test_3",
        )
        .unwrap();
        assert_eq!(package_offset_option, None);

        let err = get_package_offset_impl(
            &file_full_path,
            "vendor",
            "com.android.aconfig.storage.test_1",
        )
        .unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "StorageFileNotFound(Storage file does not exist for vendor)"
        );
    }

    #[test]
    fn test_flag_offset_query() {
        let file = write_storage_location_file();
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
    fn test_invalid_flag_offset_query() {
        let file = write_storage_location_file();
        let file_full_path = file.path().display().to_string();

        let flag_offset_option =
            get_flag_offset_impl(&file_full_path, "system", 0, "none_exist").unwrap();
        assert_eq!(flag_offset_option, None);

        let flag_offset_option =
            get_flag_offset_impl(&file_full_path, "system", 3, "enabled_ro").unwrap();
        assert_eq!(flag_offset_option, None);

        let err = get_flag_offset_impl(&file_full_path, "vendor", 0, "enabled_ro").unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "StorageFileNotFound(Storage file does not exist for vendor)"
        );
    }

    #[test]
    fn test_boolean_flag_value_query() {
        let file = write_storage_location_file();
        let file_full_path = file.path().display().to_string();

        let baseline: Vec<bool> = vec![false; 8];
        for (offset, expected_value) in baseline.into_iter().enumerate() {
            let flag_value =
                get_boolean_flag_value_impl(&file_full_path, "system", offset as u32).unwrap();
            assert_eq!(flag_value, expected_value);
        }
    }

    #[test]
    fn test_invalid_boolean_flag_value_query() {
        let file = write_storage_location_file();
        let file_full_path = file.path().display().to_string();

        let err = get_boolean_flag_value_impl(&file_full_path, "vendor", 0u32).unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "StorageFileNotFound(Storage file does not exist for vendor)"
        );

        let err = get_boolean_flag_value_impl(&file_full_path, "system", 8u32).unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "InvalidStorageFileOffset(Flag value offset goes beyond the end of the file.)"
        );
    }
}
