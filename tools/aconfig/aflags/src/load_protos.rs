use crate::{Flag, FlagPermission, FlagValue, ValuePickedFrom};
use aconfig_protos::ProtoFlagPermission as ProtoPermission;
use aconfig_protos::ProtoFlagState as ProtoState;
use aconfig_protos::ProtoParsedFlag;
use aconfig_protos::ProtoParsedFlags;
use anyhow::Result;
use std::fs;
use std::path::Path;

// TODO(b/329875578): use container field directly instead of inferring.
fn infer_container(path: &Path) -> String {
    let path_str = path.to_string_lossy();
    path_str
        .strip_prefix("/apex/")
        .or_else(|| path_str.strip_prefix('/'))
        .unwrap_or(&path_str)
        .strip_suffix("/etc/aconfig_flags.pb")
        .unwrap_or(&path_str)
        .to_string()
}

fn convert_parsed_flag(path: &Path, flag: &ProtoParsedFlag) -> Flag {
    let namespace = flag.namespace().to_string();
    let package = flag.package().to_string();
    let name = flag.name().to_string();

    let value = match flag.state() {
        ProtoState::ENABLED => FlagValue::Enabled,
        ProtoState::DISABLED => FlagValue::Disabled,
    };

    let permission = match flag.permission() {
        ProtoPermission::READ_ONLY => FlagPermission::ReadOnly,
        ProtoPermission::READ_WRITE => FlagPermission::ReadWrite,
    };

    Flag {
        namespace,
        package,
        name,
        container: infer_container(path),
        value,
        staged_value: None,
        permission,
        value_picked_from: ValuePickedFrom::Default,
    }
}

pub(crate) fn load() -> Result<Vec<Flag>> {
    let mut result = Vec::new();

    let paths = aconfig_device_paths::parsed_flags_proto_paths()?;
    for path in paths {
        let Ok(bytes) = fs::read(&path) else {
            eprintln!("warning: failed to read {:?}", path);
            continue;
        };
        let parsed_flags: ProtoParsedFlags = protobuf::Message::parse_from_bytes(&bytes)?;
        for flag in parsed_flags.parsed_flag {
            // TODO(b/334954748): enforce one-container-per-flag invariant.
            result.push(convert_parsed_flag(&path, &flag));
        }
    }
    Ok(result)
}

pub(crate) fn list_containers() -> Result<Vec<String>> {
    Ok(aconfig_device_paths::parsed_flags_proto_paths()?
        .into_iter()
        .map(|p| infer_container(&p))
        .collect())
}
