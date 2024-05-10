#[cfg(not(feature = "cargo"))]
mod aconfig_storage_write_api_test {
    use aconfig_storage_file::{FlagInfoBit, FlagValueType};
    use aconfig_storage_read_api::flag_info_query::find_flag_attribute;
    use aconfig_storage_read_api::flag_value_query::find_boolean_flag_value;
    use aconfig_storage_write_api::{
        map_mutable_storage_file, set_boolean_flag_value, set_flag_has_local_override,
        set_flag_has_server_override,
    };

    use std::fs::{self, File};
    use std::io::Read;
    use tempfile::NamedTempFile;

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
        let flag_value_path = flag_value_file.path().display().to_string();

        // SAFETY:
        // The safety here is ensured as only this single threaded test process will
        // write to this file
        let mut file = unsafe { map_mutable_storage_file(&flag_value_path).unwrap() };
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
    /// Test to lock down flag has server override update api
    fn test_set_flag_has_server_override() {
        let flag_info_file = copy_to_temp_rw_file("./flag.info");
        let flag_info_path = flag_info_file.path().display().to_string();

        // SAFETY:
        // The safety here is ensured as only this single threaded test process will
        // write to this file
        let mut file = unsafe { map_mutable_storage_file(&flag_info_path).unwrap() };
        for i in 0..8 {
            set_flag_has_server_override(&mut file, FlagValueType::Boolean, i, true).unwrap();
            let attribute =
                get_flag_attribute_at_offset(&flag_info_path, FlagValueType::Boolean, i);
            assert!((attribute & (FlagInfoBit::HasServerOverride as u8)) != 0);
            set_flag_has_server_override(&mut file, FlagValueType::Boolean, i, false).unwrap();
            let attribute =
                get_flag_attribute_at_offset(&flag_info_path, FlagValueType::Boolean, i);
            assert!((attribute & (FlagInfoBit::HasServerOverride as u8)) == 0);
        }
    }

    #[test]
    /// Test to lock down flag has local override update api
    fn test_set_flag_has_local_override() {
        let flag_info_file = copy_to_temp_rw_file("./flag.info");
        let flag_info_path = flag_info_file.path().display().to_string();

        // SAFETY:
        // The safety here is ensured as only this single threaded test process will
        // write to this file
        let mut file = unsafe { map_mutable_storage_file(&flag_info_path).unwrap() };
        for i in 0..8 {
            set_flag_has_local_override(&mut file, FlagValueType::Boolean, i, true).unwrap();
            let attribute =
                get_flag_attribute_at_offset(&flag_info_path, FlagValueType::Boolean, i);
            assert!((attribute & (FlagInfoBit::HasLocalOverride as u8)) != 0);
            set_flag_has_local_override(&mut file, FlagValueType::Boolean, i, false).unwrap();
            let attribute =
                get_flag_attribute_at_offset(&flag_info_path, FlagValueType::Boolean, i);
            assert!((attribute & (FlagInfoBit::HasLocalOverride as u8)) == 0);
        }
    }
}
