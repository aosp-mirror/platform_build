#[cfg(not(feature = "cargo"))]
mod aconfig_storage_write_api_test {
    use aconfig_storage_file::protos::ProtoStorageFiles;
    use aconfig_storage_file::{FlagInfoBit, FlagValueType, StorageFileType};
    use aconfig_storage_read_api::flag_info_query::find_flag_attribute;
    use aconfig_storage_read_api::flag_value_query::find_boolean_flag_value;
    use aconfig_storage_write_api::{
        mapped_file::get_mapped_file, set_boolean_flag_value, set_flag_has_override,
        set_flag_is_sticky,
    };

    use protobuf::Message;
    use std::fs::{self, File};
    use std::io::{Read, Write};
    use tempfile::NamedTempFile;

    /// Write storage location record pb to a temp file
    fn write_storage_record_file(flag_val: &str, flag_info: &str) -> NamedTempFile {
        let text_proto = format!(
            r#"
files {{
    version: 0
    container: "mockup"
    package_map: "some_package_map"
    flag_map: "some_flag_map"
    flag_val: "{}"
    flag_info: "{}"
    timestamp: 12345
}}
"#,
            flag_val, flag_info
        );
        let storage_files: ProtoStorageFiles =
            protobuf::text_format::parse_from_str(&text_proto).unwrap();
        let mut binary_proto_bytes = Vec::new();
        storage_files.write_to_vec(&mut binary_proto_bytes).unwrap();
        let mut file = NamedTempFile::new().unwrap();
        file.write_all(&binary_proto_bytes).unwrap();
        file
    }

    /// Create temp file copy
    fn copy_to_temp_rw_file(source_file: &str) -> NamedTempFile {
        let file = NamedTempFile::new().unwrap();
        fs::copy(source_file, file.path()).unwrap();
        file
    }

    /// Get boolean flag value from offset
    fn get_boolean_flag_value_at_offset(file: &str, offset: u32) -> bool {
        let mut f = File::open(file).unwrap();
        let mut bytes = Vec::new();
        f.read_to_end(&mut bytes).unwrap();
        find_boolean_flag_value(&bytes, offset).unwrap()
    }

    /// Get flag attribute at offset
    fn get_flag_attribute_at_offset(file: &str, value_type: FlagValueType, offset: u32) -> u8 {
        let mut f = File::open(file).unwrap();
        let mut bytes = Vec::new();
        f.read_to_end(&mut bytes).unwrap();
        find_flag_attribute(&bytes, value_type, offset).unwrap()
    }

    #[test]
    /// Test to lock down flag value update api
    fn test_boolean_flag_value_update() {
        let flag_value_file = copy_to_temp_rw_file("./flag.val");
        let flag_info_file = copy_to_temp_rw_file("./flag.info");
        let flag_value_path = flag_value_file.path().display().to_string();
        let flag_info_path = flag_info_file.path().display().to_string();
        let record_pb_file = write_storage_record_file(&flag_value_path, &flag_info_path);
        let record_pb_path = record_pb_file.path().display().to_string();

        // SAFETY:
        // The safety here is ensured as only this single threaded test process will
        // write to this file
        let mut file = unsafe {
            get_mapped_file(&record_pb_path, "mockup", StorageFileType::FlagVal).unwrap()
        };
        for i in 0..8 {
            set_boolean_flag_value(&mut file, i, true).unwrap();
            let value = get_boolean_flag_value_at_offset(&flag_value_path, i);
            assert!(value);

            set_boolean_flag_value(&mut file, i, false).unwrap();
            let value = get_boolean_flag_value_at_offset(&flag_value_path, i);
            assert!(!value);
        }
    }

    #[test]
    /// Test to lock down flag is sticky update api
    fn test_set_flag_is_sticky() {
        let flag_value_file = copy_to_temp_rw_file("./flag.val");
        let flag_info_file = copy_to_temp_rw_file("./flag.info");
        let flag_value_path = flag_value_file.path().display().to_string();
        let flag_info_path = flag_info_file.path().display().to_string();
        let record_pb_file = write_storage_record_file(&flag_value_path, &flag_info_path);
        let record_pb_path = record_pb_file.path().display().to_string();

        // SAFETY:
        // The safety here is ensured as only this single threaded test process will
        // write to this file
        let mut file = unsafe {
            get_mapped_file(&record_pb_path, "mockup", StorageFileType::FlagInfo).unwrap()
        };
        for i in 0..8 {
            set_flag_is_sticky(&mut file, FlagValueType::Boolean, i, true).unwrap();
            let attribute =
                get_flag_attribute_at_offset(&flag_info_path, FlagValueType::Boolean, i);
            assert!((attribute & (FlagInfoBit::IsSticky as u8)) != 0);
            set_flag_is_sticky(&mut file, FlagValueType::Boolean, i, false).unwrap();
            let attribute =
                get_flag_attribute_at_offset(&flag_info_path, FlagValueType::Boolean, i);
            assert!((attribute & (FlagInfoBit::IsSticky as u8)) == 0);
        }
    }

    #[test]
    /// Test to lock down flag is sticky update api
    fn test_set_flag_has_override() {
        let flag_value_file = copy_to_temp_rw_file("./flag.val");
        let flag_info_file = copy_to_temp_rw_file("./flag.info");
        let flag_value_path = flag_value_file.path().display().to_string();
        let flag_info_path = flag_info_file.path().display().to_string();
        let record_pb_file = write_storage_record_file(&flag_value_path, &flag_info_path);
        let record_pb_path = record_pb_file.path().display().to_string();

        // SAFETY:
        // The safety here is ensured as only this single threaded test process will
        // write to this file
        let mut file = unsafe {
            get_mapped_file(&record_pb_path, "mockup", StorageFileType::FlagInfo).unwrap()
        };
        for i in 0..8 {
            set_flag_has_override(&mut file, FlagValueType::Boolean, i, true).unwrap();
            let attribute =
                get_flag_attribute_at_offset(&flag_info_path, FlagValueType::Boolean, i);
            assert!((attribute & (FlagInfoBit::HasOverride as u8)) != 0);
            set_flag_has_override(&mut file, FlagValueType::Boolean, i, false).unwrap();
            let attribute =
                get_flag_attribute_at_offset(&flag_info_path, FlagValueType::Boolean, i);
            assert!((attribute & (FlagInfoBit::HasOverride as u8)) == 0);
        }
    }
}
