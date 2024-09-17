/*
 * Copyright (C) 2023 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

use anyhow::{bail, ensure, Context, Result};
use itertools::Itertools;
use protobuf::Message;
use std::collections::{BTreeMap, HashMap};
use std::hash::Hasher;
use std::io::Read;
use std::path::PathBuf;

use crate::codegen::cpp::generate_cpp_code;
use crate::codegen::java::generate_java_code;
use crate::codegen::rust::generate_rust_code;
use crate::codegen::CodegenMode;
use crate::dump::{DumpFormat, DumpPredicate};
use crate::storage::generate_storage_file;
use aconfig_protos::{
    ParsedFlagExt, ProtoFlagMetadata, ProtoFlagPermission, ProtoFlagState, ProtoParsedFlag,
    ProtoParsedFlags, ProtoTracepoint,
};
use aconfig_storage_file::sip_hasher13::SipHasher13;
use aconfig_storage_file::StorageFileType;

pub struct Input {
    pub source: String,
    pub reader: Box<dyn Read>,
}

impl Input {
    fn try_parse_flags(&mut self) -> Result<ProtoParsedFlags> {
        let mut buffer = Vec::new();
        self.reader
            .read_to_end(&mut buffer)
            .with_context(|| format!("failed to read {}", self.source))?;
        aconfig_protos::parsed_flags::try_from_binary_proto(&buffer)
            .with_context(|| self.error_context())
    }

    fn error_context(&self) -> String {
        format!("failed to parse {}", self.source)
    }
}

pub struct OutputFile {
    pub path: PathBuf, // relative to some root directory only main knows about
    pub contents: Vec<u8>,
}

pub const DEFAULT_FLAG_STATE: ProtoFlagState = ProtoFlagState::DISABLED;
pub const DEFAULT_FLAG_PERMISSION: ProtoFlagPermission = ProtoFlagPermission::READ_WRITE;

pub fn parse_flags(
    package: &str,
    container: Option<&str>,
    declarations: Vec<Input>,
    values: Vec<Input>,
    default_permission: ProtoFlagPermission,
) -> Result<Vec<u8>> {
    let mut parsed_flags = ProtoParsedFlags::new();

    for mut input in declarations {
        let mut contents = String::new();
        input
            .reader
            .read_to_string(&mut contents)
            .with_context(|| format!("failed to read {}", input.source))?;

        let mut flag_declarations =
            aconfig_protos::flag_declarations::try_from_text_proto(&contents)
                .with_context(|| input.error_context())?;

        // system_ext flags should be treated as system flags as we are combining /system_ext
        // and /system as one container
        // TODO: remove this logic when we start enforcing that system_ext cannot be set as
        // container in aconfig declaration files.
        if flag_declarations.container() == "system_ext" {
            flag_declarations.set_container(String::from("system"));
        }

        ensure!(
            package == flag_declarations.package(),
            "failed to parse {}: expected package {}, got {}",
            input.source,
            package,
            flag_declarations.package()
        );
        if let Some(c) = container {
            ensure!(
                c == flag_declarations.container(),
                "failed to parse {}: expected container {}, got {}",
                input.source,
                c,
                flag_declarations.container()
            );
        }
        for mut flag_declaration in flag_declarations.flag.into_iter() {
            aconfig_protos::flag_declaration::verify_fields(&flag_declaration)
                .with_context(|| input.error_context())?;

            // create ParsedFlag using FlagDeclaration and default values
            let mut parsed_flag = ProtoParsedFlag::new();
            if let Some(c) = container {
                parsed_flag.set_container(c.to_string());
            }
            parsed_flag.set_package(package.to_string());
            parsed_flag.set_name(flag_declaration.take_name());
            parsed_flag.set_namespace(flag_declaration.take_namespace());
            parsed_flag.set_description(flag_declaration.take_description());
            parsed_flag.bug.append(&mut flag_declaration.bug);
            parsed_flag.set_state(DEFAULT_FLAG_STATE);
            let flag_permission = if flag_declaration.is_fixed_read_only() {
                ProtoFlagPermission::READ_ONLY
            } else {
                default_permission
            };
            parsed_flag.set_permission(flag_permission);
            parsed_flag.set_is_fixed_read_only(flag_declaration.is_fixed_read_only());
            parsed_flag.set_is_exported(flag_declaration.is_exported());
            let mut tracepoint = ProtoTracepoint::new();
            tracepoint.set_source(input.source.clone());
            tracepoint.set_state(DEFAULT_FLAG_STATE);
            tracepoint.set_permission(flag_permission);
            parsed_flag.trace.push(tracepoint);

            let mut metadata = ProtoFlagMetadata::new();
            let purpose = flag_declaration.metadata.purpose();
            metadata.set_purpose(purpose);
            parsed_flag.metadata = Some(metadata).into();

            // verify ParsedFlag looks reasonable
            aconfig_protos::parsed_flag::verify_fields(&parsed_flag)?;

            // verify ParsedFlag can be added
            ensure!(
                parsed_flags.parsed_flag.iter().all(|other| other.name() != parsed_flag.name()),
                "failed to declare flag {} from {}: flag already declared",
                parsed_flag.name(),
                input.source
            );

            // add ParsedFlag to ParsedFlags
            parsed_flags.parsed_flag.push(parsed_flag);
        }
    }

    for mut input in values {
        let mut contents = String::new();
        input
            .reader
            .read_to_string(&mut contents)
            .with_context(|| format!("failed to read {}", input.source))?;
        let flag_values = aconfig_protos::flag_values::try_from_text_proto(&contents)
            .with_context(|| input.error_context())?;
        for flag_value in flag_values.flag_value.into_iter() {
            aconfig_protos::flag_value::verify_fields(&flag_value)
                .with_context(|| input.error_context())?;

            let Some(parsed_flag) = parsed_flags
                .parsed_flag
                .iter_mut()
                .find(|pf| pf.package() == flag_value.package() && pf.name() == flag_value.name())
            else {
                // (silently) skip unknown flags
                continue;
            };

            ensure!(
                !parsed_flag.is_fixed_read_only()
                    || flag_value.permission() == ProtoFlagPermission::READ_ONLY,
                "failed to set permission of flag {}, since this flag is fixed read only flag",
                flag_value.name()
            );

            parsed_flag.set_state(flag_value.state());
            parsed_flag.set_permission(flag_value.permission());
            let mut tracepoint = ProtoTracepoint::new();
            tracepoint.set_source(input.source.clone());
            tracepoint.set_state(flag_value.state());
            tracepoint.set_permission(flag_value.permission());
            parsed_flag.trace.push(tracepoint);
        }
    }

    // Create a sorted parsed_flags
    aconfig_protos::parsed_flags::sort_parsed_flags(&mut parsed_flags);
    aconfig_protos::parsed_flags::verify_fields(&parsed_flags)?;
    let mut output = Vec::new();
    parsed_flags.write_to_vec(&mut output)?;
    Ok(output)
}

pub fn create_java_lib(
    mut input: Input,
    codegen_mode: CodegenMode,
    allow_instrumentation: bool,
) -> Result<Vec<OutputFile>> {
    let parsed_flags = input.try_parse_flags()?;
    let modified_parsed_flags = modify_parsed_flags_based_on_mode(parsed_flags, codegen_mode)?;
    let Some(package) = find_unique_package(&modified_parsed_flags) else {
        bail!("no parsed flags, or the parsed flags use different packages");
    };
    let package = package.to_string();
    let flag_ids = assign_flag_ids(&package, modified_parsed_flags.iter())?;
    generate_java_code(
        &package,
        modified_parsed_flags.into_iter(),
        codegen_mode,
        flag_ids,
        allow_instrumentation,
    )
}

pub fn create_cpp_lib(
    mut input: Input,
    codegen_mode: CodegenMode,
    allow_instrumentation: bool,
) -> Result<Vec<OutputFile>> {
    // TODO(327420679): Enable export mode for native flag library
    ensure!(
        codegen_mode != CodegenMode::Exported,
        "Exported mode for generated c/c++ flag library is disabled"
    );
    let parsed_flags = input.try_parse_flags()?;
    let modified_parsed_flags = modify_parsed_flags_based_on_mode(parsed_flags, codegen_mode)?;
    let Some(package) = find_unique_package(&modified_parsed_flags) else {
        bail!("no parsed flags, or the parsed flags use different packages");
    };
    let package = package.to_string();
    let flag_ids = assign_flag_ids(&package, modified_parsed_flags.iter())?;
    generate_cpp_code(
        &package,
        modified_parsed_flags.into_iter(),
        codegen_mode,
        flag_ids,
        allow_instrumentation,
    )
}

pub fn create_rust_lib(
    mut input: Input,
    codegen_mode: CodegenMode,
    allow_instrumentation: bool,
) -> Result<OutputFile> {
    // // TODO(327420679): Enable export mode for native flag library
    ensure!(
        codegen_mode != CodegenMode::Exported,
        "Exported mode for generated rust flag library is disabled"
    );
    let parsed_flags = input.try_parse_flags()?;
    let modified_parsed_flags = modify_parsed_flags_based_on_mode(parsed_flags, codegen_mode)?;
    let Some(package) = find_unique_package(&modified_parsed_flags) else {
        bail!("no parsed flags, or the parsed flags use different packages");
    };
    let package = package.to_string();
    let flag_ids = assign_flag_ids(&package, modified_parsed_flags.iter())?;
    generate_rust_code(
        &package,
        flag_ids,
        modified_parsed_flags.into_iter(),
        codegen_mode,
        allow_instrumentation,
    )
}

pub fn create_storage(
    caches: Vec<Input>,
    container: &str,
    file: &StorageFileType,
) -> Result<Vec<u8>> {
    let parsed_flags_vec: Vec<ProtoParsedFlags> =
        caches.into_iter().map(|mut input| input.try_parse_flags()).collect::<Result<Vec<_>>>()?;
    generate_storage_file(container, parsed_flags_vec.iter(), file)
}

pub fn create_device_config_defaults(mut input: Input) -> Result<Vec<u8>> {
    let parsed_flags = input.try_parse_flags()?;
    let mut output = Vec::new();
    for parsed_flag in parsed_flags
        .parsed_flag
        .into_iter()
        .filter(|pf| pf.permission() == ProtoFlagPermission::READ_WRITE)
    {
        let line = format!(
            "{}:{}={}\n",
            parsed_flag.namespace(),
            parsed_flag.fully_qualified_name(),
            match parsed_flag.state() {
                ProtoFlagState::ENABLED => "enabled",
                ProtoFlagState::DISABLED => "disabled",
            }
        );
        output.extend_from_slice(line.as_bytes());
    }
    Ok(output)
}

pub fn create_device_config_sysprops(mut input: Input) -> Result<Vec<u8>> {
    let parsed_flags = input.try_parse_flags()?;
    let mut output = Vec::new();
    for parsed_flag in parsed_flags
        .parsed_flag
        .into_iter()
        .filter(|pf| pf.permission() == ProtoFlagPermission::READ_WRITE)
    {
        let line = format!(
            "persist.device_config.{}={}\n",
            parsed_flag.fully_qualified_name(),
            match parsed_flag.state() {
                ProtoFlagState::ENABLED => "true",
                ProtoFlagState::DISABLED => "false",
            }
        );
        output.extend_from_slice(line.as_bytes());
    }
    Ok(output)
}

pub fn dump_parsed_flags(
    mut input: Vec<Input>,
    format: DumpFormat,
    filters: &[&str],
    dedup: bool,
) -> Result<Vec<u8>> {
    let individually_parsed_flags: Result<Vec<ProtoParsedFlags>> =
        input.iter_mut().map(|i| i.try_parse_flags()).collect();
    let parsed_flags: ProtoParsedFlags =
        aconfig_protos::parsed_flags::merge(individually_parsed_flags?, dedup)?;
    let filters: Vec<Box<DumpPredicate>> = if filters.is_empty() {
        vec![Box::new(|_| true)]
    } else {
        filters
            .iter()
            .map(|f| crate::dump::create_filter_predicate(f))
            .collect::<Result<Vec<_>>>()?
    };
    crate::dump::dump_parsed_flags(
        parsed_flags.parsed_flag.into_iter().filter(|flag| filters.iter().any(|p| p(flag))),
        format,
    )
}

fn find_unique_package(parsed_flags: &[ProtoParsedFlag]) -> Option<&str> {
    let package = parsed_flags.first().map(|pf| pf.package())?;
    if parsed_flags.iter().any(|pf| pf.package() != package) {
        return None;
    }
    Some(package)
}

pub fn modify_parsed_flags_based_on_mode(
    parsed_flags: ProtoParsedFlags,
    codegen_mode: CodegenMode,
) -> Result<Vec<ProtoParsedFlag>> {
    fn exported_mode_flag_modifier(mut parsed_flag: ProtoParsedFlag) -> ProtoParsedFlag {
        parsed_flag.set_state(ProtoFlagState::DISABLED);
        parsed_flag.set_permission(ProtoFlagPermission::READ_WRITE);
        parsed_flag.set_is_fixed_read_only(false);
        parsed_flag
    }

    fn force_read_only_mode_flag_modifier(mut parsed_flag: ProtoParsedFlag) -> ProtoParsedFlag {
        parsed_flag.set_permission(ProtoFlagPermission::READ_ONLY);
        parsed_flag
    }

    let modified_parsed_flags: Vec<_> = match codegen_mode {
        CodegenMode::Exported => parsed_flags
            .parsed_flag
            .into_iter()
            .filter(|pf| pf.is_exported())
            .map(exported_mode_flag_modifier)
            .collect(),
        CodegenMode::ForceReadOnly => parsed_flags
            .parsed_flag
            .into_iter()
            .filter(|pf| !pf.is_exported())
            .map(force_read_only_mode_flag_modifier)
            .collect(),
        CodegenMode::Production | CodegenMode::Test => {
            parsed_flags.parsed_flag.into_iter().collect()
        }
    };
    if modified_parsed_flags.is_empty() {
        bail!("{codegen_mode} library contains no {codegen_mode} flags");
    }

    Ok(modified_parsed_flags)
}

pub fn assign_flag_ids<'a, I>(package: &str, parsed_flags_iter: I) -> Result<HashMap<String, u16>>
where
    I: Iterator<Item = &'a ProtoParsedFlag> + Clone,
{
    assert!(parsed_flags_iter.clone().tuple_windows().all(|(a, b)| a.name() <= b.name()));
    let mut flag_ids = HashMap::new();
    for (id_to_assign, pf) in (0_u32..).zip(parsed_flags_iter) {
        if package != pf.package() {
            return Err(anyhow::anyhow!("encountered a flag not in current package"));
        }

        // put a cap on how many flags a package can contain to 65535
        if id_to_assign > u16::MAX as u32 {
            return Err(anyhow::anyhow!("the number of flags in a package cannot exceed 65535"));
        }

        flag_ids.insert(pf.name().to_string(), id_to_assign as u16);
    }
    Ok(flag_ids)
}

#[allow(dead_code)] // TODO: b/316357686 - Use fingerprint in codegen to
                    // protect hardcoded offset reads.
pub fn compute_flag_offsets_fingerprint(flags_map: &HashMap<String, u16>) -> Result<u64> {
    let mut hasher = SipHasher13::new();

    // Need to sort to ensure the data is added to the hasher in the same order
    // each run.
    let sorted_map: BTreeMap<&String, &u16> = flags_map.iter().collect();

    for (flag, offset) in sorted_map {
        // See https://docs.rs/siphasher/latest/siphasher/#note for use of write
        // over write_i16. Similarly, use to_be_bytes rather than to_ne_bytes to
        // ensure consistency.
        hasher.write(flag.as_bytes());
        hasher.write(&offset.to_be_bytes());
    }
    Ok(hasher.finish())
}

#[cfg(test)]
mod tests {
    use super::*;
    use aconfig_protos::ProtoFlagPurpose;

    #[test]
    fn test_offset_fingerprint() {
        let parsed_flags = crate::test::parse_test_flags();
        let package = find_unique_package(&parsed_flags.parsed_flag).unwrap().to_string();
        let flag_ids = assign_flag_ids(&package, parsed_flags.parsed_flag.iter()).unwrap();
        let expected_fingerprint = 10709892481002252132u64;

        let hash_result = compute_flag_offsets_fingerprint(&flag_ids);

        assert_eq!(hash_result.unwrap(), expected_fingerprint);
    }

    #[test]
    fn test_parse_flags() {
        let parsed_flags = crate::test::parse_test_flags(); // calls parse_flags
        aconfig_protos::parsed_flags::verify_fields(&parsed_flags).unwrap();

        let enabled_ro =
            parsed_flags.parsed_flag.iter().find(|pf| pf.name() == "enabled_ro").unwrap();
        assert!(aconfig_protos::parsed_flag::verify_fields(enabled_ro).is_ok());
        assert_eq!("com.android.aconfig.test", enabled_ro.package());
        assert_eq!("enabled_ro", enabled_ro.name());
        assert_eq!("This flag is ENABLED + READ_ONLY", enabled_ro.description());
        assert_eq!(ProtoFlagState::ENABLED, enabled_ro.state());
        assert_eq!(ProtoFlagPermission::READ_ONLY, enabled_ro.permission());
        assert_eq!(ProtoFlagPurpose::PURPOSE_BUGFIX, enabled_ro.metadata.purpose());
        assert_eq!(3, enabled_ro.trace.len());
        assert!(!enabled_ro.is_fixed_read_only());
        assert_eq!("tests/test.aconfig", enabled_ro.trace[0].source());
        assert_eq!(ProtoFlagState::DISABLED, enabled_ro.trace[0].state());
        assert_eq!(ProtoFlagPermission::READ_WRITE, enabled_ro.trace[0].permission());
        assert_eq!("tests/first.values", enabled_ro.trace[1].source());
        assert_eq!(ProtoFlagState::DISABLED, enabled_ro.trace[1].state());
        assert_eq!(ProtoFlagPermission::READ_WRITE, enabled_ro.trace[1].permission());
        assert_eq!("tests/second.values", enabled_ro.trace[2].source());
        assert_eq!(ProtoFlagState::ENABLED, enabled_ro.trace[2].state());
        assert_eq!(ProtoFlagPermission::READ_ONLY, enabled_ro.trace[2].permission());

        assert_eq!(9, parsed_flags.parsed_flag.len());
        for pf in parsed_flags.parsed_flag.iter() {
            if pf.name().starts_with("enabled_fixed_ro") {
                continue;
            }
            let first = pf.trace.first().unwrap();
            assert_eq!(DEFAULT_FLAG_STATE, first.state());
            assert_eq!(DEFAULT_FLAG_PERMISSION, first.permission());

            let last = pf.trace.last().unwrap();
            assert_eq!(pf.state(), last.state());
            assert_eq!(pf.permission(), last.permission());
        }

        let enabled_fixed_ro =
            parsed_flags.parsed_flag.iter().find(|pf| pf.name() == "enabled_fixed_ro").unwrap();
        assert!(enabled_fixed_ro.is_fixed_read_only());
        assert_eq!(ProtoFlagState::ENABLED, enabled_fixed_ro.state());
        assert_eq!(ProtoFlagPermission::READ_ONLY, enabled_fixed_ro.permission());
        assert_eq!(2, enabled_fixed_ro.trace.len());
        assert_eq!(ProtoFlagPermission::READ_ONLY, enabled_fixed_ro.trace[0].permission());
        assert_eq!(ProtoFlagPermission::READ_ONLY, enabled_fixed_ro.trace[1].permission());
    }

    #[test]
    fn test_parse_flags_setting_default() {
        let first_flag = r#"
        package: "com.first"
        flag {
            name: "first"
            namespace: "first_ns"
            description: "This is the description of the first flag."
            bug: "123"
        }
        "#;
        let declaration =
            vec![Input { source: "momery".to_string(), reader: Box::new(first_flag.as_bytes()) }];
        let value: Vec<Input> = vec![];

        let flags_bytes = crate::commands::parse_flags(
            "com.first",
            None,
            declaration,
            value,
            ProtoFlagPermission::READ_ONLY,
        )
        .unwrap();
        let parsed_flags =
            aconfig_protos::parsed_flags::try_from_binary_proto(&flags_bytes).unwrap();
        assert_eq!(1, parsed_flags.parsed_flag.len());
        let parsed_flag = parsed_flags.parsed_flag.first().unwrap();
        assert_eq!(ProtoFlagState::DISABLED, parsed_flag.state());
        assert_eq!(ProtoFlagPermission::READ_ONLY, parsed_flag.permission());
    }

    #[test]
    fn test_parse_flags_package_mismatch_between_declaration_and_command_line() {
        let first_flag = r#"
        package: "com.declaration.package"
        container: "first.container"
        flag {
            name: "first"
            namespace: "first_ns"
            description: "This is the description of the first flag."
            bug: "123"
        }
        "#;
        let declaration =
            vec![Input { source: "memory".to_string(), reader: Box::new(first_flag.as_bytes()) }];

        let value: Vec<Input> = vec![];

        let error = crate::commands::parse_flags(
            "com.argument.package",
            Some("first.container"),
            declaration,
            value,
            ProtoFlagPermission::READ_WRITE,
        )
        .unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            "failed to parse memory: expected package com.argument.package, got com.declaration.package"
        );
    }

    #[test]
    fn test_parse_flags_container_mismatch_between_declaration_and_command_line() {
        let first_flag = r#"
        package: "com.first"
        container: "declaration.container"
        flag {
            name: "first"
            namespace: "first_ns"
            description: "This is the description of the first flag."
            bug: "123"
        }
        "#;
        let declaration =
            vec![Input { source: "memory".to_string(), reader: Box::new(first_flag.as_bytes()) }];

        let value: Vec<Input> = vec![];

        let error = crate::commands::parse_flags(
            "com.first",
            Some("argument.container"),
            declaration,
            value,
            ProtoFlagPermission::READ_WRITE,
        )
        .unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            "failed to parse memory: expected container argument.container, got declaration.container"
        );
    }

    #[test]
    fn test_parse_flags_override_fixed_read_only() {
        let first_flag = r#"
        package: "com.first"
        container: "com.first.container"
        flag {
            name: "first"
            namespace: "first_ns"
            description: "This is the description of the first flag."
            bug: "123"
            is_fixed_read_only: true
        }
        "#;
        let declaration =
            vec![Input { source: "memory".to_string(), reader: Box::new(first_flag.as_bytes()) }];

        let first_flag_value = r#"
        flag_value {
            package: "com.first"
            name: "first"
            state: DISABLED
            permission: READ_WRITE
        }
        "#;
        let value = vec![Input {
            source: "memory".to_string(),
            reader: Box::new(first_flag_value.as_bytes()),
        }];
        let error = crate::commands::parse_flags(
            "com.first",
            Some("com.first.container"),
            declaration,
            value,
            ProtoFlagPermission::READ_WRITE,
        )
        .unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            "failed to set permission of flag first, since this flag is fixed read only flag"
        );
    }

    #[test]
    fn test_parse_flags_metadata() {
        let metadata_flag = r#"
        package: "com.first"
        flag {
            name: "first"
            namespace: "first_ns"
            description: "This is the description of this feature flag."
            bug: "123"
            metadata {
                purpose: PURPOSE_FEATURE
            }
        }
        "#;
        let declaration = vec![Input {
            source: "memory".to_string(),
            reader: Box::new(metadata_flag.as_bytes()),
        }];
        let value: Vec<Input> = vec![];

        let flags_bytes = crate::commands::parse_flags(
            "com.first",
            None,
            declaration,
            value,
            ProtoFlagPermission::READ_ONLY,
        )
        .unwrap();
        let parsed_flags =
            aconfig_protos::parsed_flags::try_from_binary_proto(&flags_bytes).unwrap();
        assert_eq!(1, parsed_flags.parsed_flag.len());
        let parsed_flag = parsed_flags.parsed_flag.first().unwrap();
        assert_eq!(ProtoFlagPurpose::PURPOSE_FEATURE, parsed_flag.metadata.purpose());
    }

    #[test]
    fn test_create_device_config_defaults() {
        let input = parse_test_flags_as_input();
        let bytes = create_device_config_defaults(input).unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert_eq!("aconfig_test:com.android.aconfig.test.disabled_rw=disabled\naconfig_test:com.android.aconfig.test.disabled_rw_exported=disabled\nother_namespace:com.android.aconfig.test.disabled_rw_in_other_namespace=disabled\naconfig_test:com.android.aconfig.test.enabled_rw=enabled\n", text);
    }

    #[test]
    fn test_create_device_config_sysprops() {
        let input = parse_test_flags_as_input();
        let bytes = create_device_config_sysprops(input).unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert_eq!("persist.device_config.com.android.aconfig.test.disabled_rw=false\npersist.device_config.com.android.aconfig.test.disabled_rw_exported=false\npersist.device_config.com.android.aconfig.test.disabled_rw_in_other_namespace=false\npersist.device_config.com.android.aconfig.test.enabled_rw=true\n", text);
    }

    #[test]
    fn test_dump() {
        let input = parse_test_flags_as_input();
        let bytes = dump_parsed_flags(
            vec![input],
            DumpFormat::Custom("{fully_qualified_name}".to_string()),
            &[],
            false,
        )
        .unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert!(text.contains("com.android.aconfig.test.disabled_ro"));
    }

    #[test]
    fn test_dump_textproto_format_dedup() {
        let input = parse_test_flags_as_input();
        let input2 = parse_test_flags_as_input();
        let bytes =
            dump_parsed_flags(vec![input, input2], DumpFormat::Textproto, &[], true).unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                crate::test::TEST_FLAGS_TEXTPROTO.trim(),
                text.trim()
            )
        );
    }

    fn parse_test_flags_as_input() -> Input {
        let parsed_flags = crate::test::parse_test_flags();
        let binary_proto = parsed_flags.write_to_bytes().unwrap();
        let cursor = std::io::Cursor::new(binary_proto);
        let reader = Box::new(cursor);
        Input { source: "test.data".to_string(), reader }
    }

    #[test]
    fn test_modify_parsed_flags_based_on_mode_prod() {
        let parsed_flags = crate::test::parse_test_flags();
        let p_parsed_flags =
            modify_parsed_flags_based_on_mode(parsed_flags.clone(), CodegenMode::Production)
                .unwrap();
        assert_eq!(parsed_flags.parsed_flag.len(), p_parsed_flags.len());
        for (i, item) in p_parsed_flags.iter().enumerate() {
            assert!(parsed_flags.parsed_flag[i].eq(item));
        }
    }

    #[test]
    fn test_modify_parsed_flags_based_on_mode_exported() {
        let parsed_flags = crate::test::parse_test_flags();
        let p_parsed_flags =
            modify_parsed_flags_based_on_mode(parsed_flags, CodegenMode::Exported).unwrap();
        assert_eq!(3, p_parsed_flags.len());
        for flag in p_parsed_flags.iter() {
            assert_eq!(ProtoFlagState::DISABLED, flag.state());
            assert_eq!(ProtoFlagPermission::READ_WRITE, flag.permission());
            assert!(!flag.is_fixed_read_only());
            assert!(flag.is_exported());
        }

        let mut parsed_flags = crate::test::parse_test_flags();
        parsed_flags.parsed_flag.retain(|pf| !pf.is_exported());
        let error =
            modify_parsed_flags_based_on_mode(parsed_flags, CodegenMode::Exported).unwrap_err();
        assert_eq!("exported library contains no exported flags", format!("{:?}", error));
    }

    #[test]
    fn test_assign_flag_ids() {
        let parsed_flags = crate::test::parse_test_flags();
        let package = find_unique_package(&parsed_flags.parsed_flag).unwrap().to_string();
        let flag_ids = assign_flag_ids(&package, parsed_flags.parsed_flag.iter()).unwrap();
        let expected_flag_ids = HashMap::from([
            (String::from("disabled_ro"), 0_u16),
            (String::from("disabled_rw"), 1_u16),
            (String::from("disabled_rw_exported"), 2_u16),
            (String::from("disabled_rw_in_other_namespace"), 3_u16),
            (String::from("enabled_fixed_ro"), 4_u16),
            (String::from("enabled_fixed_ro_exported"), 5_u16),
            (String::from("enabled_ro"), 6_u16),
            (String::from("enabled_ro_exported"), 7_u16),
            (String::from("enabled_rw"), 8_u16),
        ]);
        assert_eq!(flag_ids, expected_flag_ids);
    }

    #[test]
    fn test_modify_parsed_flags_based_on_mode_force_read_only() {
        let parsed_flags = crate::test::parse_test_flags();
        let p_parsed_flags =
            modify_parsed_flags_based_on_mode(parsed_flags.clone(), CodegenMode::ForceReadOnly)
                .unwrap();
        assert_eq!(6, p_parsed_flags.len());
        for pf in p_parsed_flags {
            assert_eq!(ProtoFlagPermission::READ_ONLY, pf.permission());
        }

        let mut parsed_flags = crate::test::parse_test_flags();
        parsed_flags.parsed_flag.retain_mut(|pf| pf.is_exported());
        let error = modify_parsed_flags_based_on_mode(parsed_flags, CodegenMode::ForceReadOnly)
            .unwrap_err();
        assert_eq!(
            "force-read-only library contains no force-read-only flags",
            format!("{:?}", error)
        );
    }
}
