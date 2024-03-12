#[cfg(not(feature = "cargo"))]
mod aconfig_storage_rust_test {
    use aconfig_storage_read_api::{
        get_boolean_flag_value_impl, get_flag_offset_impl, get_package_offset_impl,
        get_storage_file_version, PackageOffset, ProtoStorageFiles,
    };
    use protobuf::Message;
    use std::fs;
    use std::io::Write;
    use tempfile::NamedTempFile;

    pub fn copy_to_ro_temp_file(source_file: &str) -> NamedTempFile {
        let file = NamedTempFile::new().unwrap();
        fs::copy(source_file, file.path()).unwrap();
        let file_name = file.path().display().to_string();
        let mut perms = fs::metadata(file_name).unwrap().permissions();
        perms.set_readonly(true);
        fs::set_permissions(file.path(), perms.clone()).unwrap();
        file
    }

    fn write_storage_location_file(
        package_table: &NamedTempFile,
        flag_table: &NamedTempFile,
        flag_value: &NamedTempFile,
    ) -> NamedTempFile {
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
            package_table.path().display(),
            flag_table.path().display(),
            flag_value.path().display(),
        );

        let storage_files: ProtoStorageFiles =
            protobuf::text_format::parse_from_str(&text_proto).unwrap();
        let mut binary_proto_bytes = Vec::new();
        storage_files.write_to_vec(&mut binary_proto_bytes).unwrap();
        let mut file = NamedTempFile::new().unwrap();
        file.write_all(&binary_proto_bytes).unwrap();
        file
    }

    #[test]
    fn test_package_offset_query() {
        let package_table = copy_to_ro_temp_file("./package.map");
        let flag_table = copy_to_ro_temp_file("./flag.map");
        let flag_value = copy_to_ro_temp_file("./flag.val");

        let file = write_storage_location_file(&package_table, &flag_table, &flag_value);
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
        let package_table = copy_to_ro_temp_file("./package.map");
        let flag_table = copy_to_ro_temp_file("./flag.map");
        let flag_value = copy_to_ro_temp_file("./flag.val");

        let file = write_storage_location_file(&package_table, &flag_table, &flag_value);
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
        let package_table = copy_to_ro_temp_file("./package.map");
        let flag_table = copy_to_ro_temp_file("./flag.map");
        let flag_value = copy_to_ro_temp_file("./flag.val");

        let file = write_storage_location_file(&package_table, &flag_table, &flag_value);
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
        let package_table = copy_to_ro_temp_file("./package.map");
        let flag_table = copy_to_ro_temp_file("./flag.map");
        let flag_value = copy_to_ro_temp_file("./flag.val");

        let file = write_storage_location_file(&package_table, &flag_table, &flag_value);
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
        let package_table = copy_to_ro_temp_file("./package.map");
        let flag_table = copy_to_ro_temp_file("./flag.map");
        let flag_value = copy_to_ro_temp_file("./flag.val");

        let file = write_storage_location_file(&package_table, &flag_table, &flag_value);
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
        let package_table = copy_to_ro_temp_file("./package.map");
        let flag_table = copy_to_ro_temp_file("./flag.map");
        let flag_value = copy_to_ro_temp_file("./flag.val");

        let file = write_storage_location_file(&package_table, &flag_table, &flag_value);
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

    #[test]
    fn test_storage_version_query() {
        assert_eq!(get_storage_file_version("./package.map").unwrap(), 1);
        assert_eq!(get_storage_file_version("./flag.map").unwrap(), 1);
        assert_eq!(get_storage_file_version("./flag.val").unwrap(), 1);
    }
}
