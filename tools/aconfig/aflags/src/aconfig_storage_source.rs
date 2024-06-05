use crate::{Flag, FlagPermission, FlagSource, FlagValue, ValuePickedFrom};
use anyhow::{anyhow, Result};

use std::fs::File;
use std::io::Read;

pub struct AconfigStorageSource {}

use aconfig_storage_file::protos::ProtoStorageFiles;

static STORAGE_INFO_FILE_PATH: &str = "/metadata/aconfig/persistent_storage_file_records.pb";

impl FlagSource for AconfigStorageSource {
    fn list_flags() -> Result<Vec<Flag>> {
        let mut result = Vec::new();

        let mut file = File::open(STORAGE_INFO_FILE_PATH)?;
        let mut bytes = Vec::new();
        file.read_to_end(&mut bytes)?;
        let storage_file_info: ProtoStorageFiles = protobuf::Message::parse_from_bytes(&bytes)?;

        for file_info in storage_file_info.files {
            let package_map =
                file_info.package_map.ok_or(anyhow!("storage file is missing package map"))?;
            let flag_map = file_info.flag_map.ok_or(anyhow!("storage file is missing flag map"))?;
            let flag_val = file_info.flag_val.ok_or(anyhow!("storage file is missing flag val"))?;
            let container =
                file_info.container.ok_or(anyhow!("storage file is missing container"))?;

            for listed_flag in aconfig_storage_file::list_flags(&package_map, &flag_map, &flag_val)?
            {
                result.push(Flag {
                    name: listed_flag.flag_name,
                    package: listed_flag.package_name,
                    value: FlagValue::try_from(listed_flag.flag_value.as_str())?,
                    container: container.to_string(),

                    // TODO(b/324436145): delete namespace field once DeviceConfig isn't in CLI.
                    namespace: "-".to_string(),

                    // TODO(b/324436145): Populate with real values once API is available.
                    staged_value: None,
                    permission: FlagPermission::ReadOnly,
                    value_picked_from: ValuePickedFrom::Default,
                });
            }
        }

        Ok(result)
    }

    fn override_flag(_namespace: &str, _qualified_name: &str, _value: &str) -> Result<()> {
        todo!()
    }
}
