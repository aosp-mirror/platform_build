use crate::{Flag, FlagPermission, FlagSource, FlagValue, ValuePickedFrom};
use anyhow::{anyhow, Result};

use std::collections::HashMap;
use std::fs::File;
use std::io::Read;

pub struct AconfigStorageSource {}

use aconfig_storage_file::protos::ProtoStorageFileInfo;
use aconfig_storage_file::protos::ProtoStorageFiles;
use aconfig_storage_file::FlagValueAndInfoSummary;

static STORAGE_INFO_FILE_PATH: &str = "/metadata/aconfig/storage_records.pb";

fn read_default_values(file_info: ProtoStorageFileInfo) -> Result<HashMap<String, FlagValue>> {
    let package_map =
        file_info.package_map.ok_or(anyhow!("storage file is missing package map"))?;
    let flag_map = file_info.flag_map.ok_or(anyhow!("storage file is missing flag map"))?;
    let flag_val = file_info.flag_val.ok_or(anyhow!("storage file is missing flag val"))?;

    let mut result = HashMap::new();
    for listed_flag in aconfig_storage_file::list_flags(&package_map, &flag_map, &flag_val)? {
        let value = FlagValue::try_from(listed_flag.flag_value.as_str())?;
        result.insert(listed_flag.package_name + &listed_flag.flag_name, value);
    }
    Ok(result)
}

fn read_next_boot_values(
    listed_flags: &[FlagValueAndInfoSummary],
) -> Result<HashMap<String, FlagValue>> {
    let mut result = HashMap::new();
    for flag in listed_flags {
        result.insert(
            flag.package_name.clone() + &flag.flag_name,
            FlagValue::try_from(flag.flag_value.as_str())?,
        );
    }
    Ok(result)
}

fn reconcile(
    default_values: HashMap<String, FlagValue>,
    next_boot_values: HashMap<String, FlagValue>,
    flags_current_boot: &[FlagValueAndInfoSummary],
    container: &str,
) -> Result<Vec<Flag>> {
    let mut result = Vec::new();
    for listed_flag in flags_current_boot {
        let default_value = default_values
            .get(&(listed_flag.package_name.clone() + &listed_flag.flag_name))
            .copied();

        let name = listed_flag.flag_name.clone();
        let package = listed_flag.package_name.clone();
        let value = FlagValue::try_from(listed_flag.flag_value.as_str())?;
        let container = container.to_string();
        let staged_value = next_boot_values
            .get(&(listed_flag.package_name.clone() + &listed_flag.flag_name))
            .filter(|&v| value != *v)
            .copied();
        let permission = if listed_flag.is_readwrite {
            FlagPermission::ReadWrite
        } else {
            FlagPermission::ReadOnly
        };
        let value_picked_from = if listed_flag.has_local_override {
            ValuePickedFrom::Local
        } else if Some(value) == default_value {
            ValuePickedFrom::Default
        } else {
            ValuePickedFrom::Server
        };

        result.push(Flag {
            name,
            package,
            value,
            container,
            staged_value,
            permission,
            value_picked_from,

            // TODO(b/324436145): delete namespace field once DeviceConfig isn't in CLI.
            namespace: "-".to_string(),
        });
    }
    Ok(result)
}

impl FlagSource for AconfigStorageSource {
    fn list_flags() -> Result<Vec<Flag>> {
        let mut result = Vec::new();

        let mut file = File::open(STORAGE_INFO_FILE_PATH)?;
        let mut bytes = Vec::new();
        file.read_to_end(&mut bytes)?;
        let storage_file_info: ProtoStorageFiles = protobuf::Message::parse_from_bytes(&bytes)?;

        for file_info in storage_file_info.files {
            let default_values = read_default_values(file_info.clone())?;

            let container =
                file_info.container.ok_or(anyhow!("storage file is missing container"))?;
            let package_map = format!("/metadata/aconfig/maps/{container}.package.map");
            let flag_map = format!("/metadata/aconfig/maps/{container}.flag.map");
            let flag_info = format!("/metadata/aconfig/boot/{container}.info");

            let flag_val_current_boot = format!("/metadata/aconfig/boot/{container}.val");
            let flag_val_next_boot = format!("/metadata/aconfig/flags/{container}.val");

            let flags_next_boot = aconfig_storage_file::list_flags_with_info(
                &package_map,
                &flag_map,
                &flag_val_next_boot,
                &flag_info,
            )?;
            let flags_current_boot = aconfig_storage_file::list_flags_with_info(
                &package_map,
                &flag_map,
                &flag_val_current_boot,
                &flag_info,
            )?;

            let next_boot_values = read_next_boot_values(&flags_next_boot)?;
            let processed_flags =
                reconcile(default_values, next_boot_values, &flags_current_boot, &container)?;

            result.extend(processed_flags);
        }

        Ok(result)
    }

    fn override_flag(_namespace: &str, _qualified_name: &str, _value: &str) -> Result<()> {
        todo!()
    }
}
