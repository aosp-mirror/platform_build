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
use clap::ValueEnum;
use protobuf::Message;
use std::io::Read;
use std::path::PathBuf;

use crate::codegen_cpp::generate_cpp_code;
use crate::codegen_java::generate_java_code;
use crate::codegen_rust::generate_rust_code;
use crate::protos::{
    ProtoFlagPermission, ProtoFlagState, ProtoParsedFlag, ProtoParsedFlags, ProtoTracepoint,
};

pub struct Input {
    pub source: String,
    pub reader: Box<dyn Read>,
}

impl Input {
    fn try_parse_flags(&mut self) -> Result<ProtoParsedFlags> {
        let mut buffer = Vec::new();
        self.reader.read_to_end(&mut buffer)?;
        crate::protos::parsed_flags::try_from_binary_proto(&buffer)
    }
}

pub struct OutputFile {
    pub path: PathBuf, // relative to some root directory only main knows about
    pub contents: Vec<u8>,
}

const DEFAULT_FLAG_STATE: ProtoFlagState = ProtoFlagState::DISABLED;
const DEFAULT_FLAG_PERMISSION: ProtoFlagPermission = ProtoFlagPermission::READ_WRITE;

pub fn parse_flags(package: &str, declarations: Vec<Input>, values: Vec<Input>) -> Result<Vec<u8>> {
    let mut parsed_flags = ProtoParsedFlags::new();

    for mut input in declarations {
        let mut contents = String::new();
        input.reader.read_to_string(&mut contents)?;

        let flag_declarations = crate::protos::flag_declarations::try_from_text_proto(&contents)
            .with_context(|| format!("Failed to parse {}", input.source))?;
        ensure!(
            package == flag_declarations.package(),
            "Failed to parse {}: expected package {}, got {}",
            input.source,
            package,
            flag_declarations.package()
        );
        for mut flag_declaration in flag_declarations.flag.into_iter() {
            crate::protos::flag_declaration::verify_fields(&flag_declaration)
                .with_context(|| format!("Failed to parse {}", input.source))?;

            // create ParsedFlag using FlagDeclaration and default values
            let mut parsed_flag = ProtoParsedFlag::new();
            parsed_flag.set_package(package.to_string());
            parsed_flag.set_name(flag_declaration.take_name());
            parsed_flag.set_namespace(flag_declaration.take_namespace());
            parsed_flag.set_description(flag_declaration.take_description());
            parsed_flag.bug.append(&mut flag_declaration.bug);
            parsed_flag.set_state(DEFAULT_FLAG_STATE);
            parsed_flag.set_permission(DEFAULT_FLAG_PERMISSION);
            let mut tracepoint = ProtoTracepoint::new();
            tracepoint.set_source(input.source.clone());
            tracepoint.set_state(DEFAULT_FLAG_STATE);
            tracepoint.set_permission(DEFAULT_FLAG_PERMISSION);
            parsed_flag.trace.push(tracepoint);

            // verify ParsedFlag looks reasonable
            crate::protos::parsed_flag::verify_fields(&parsed_flag)?;

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
        input.reader.read_to_string(&mut contents)?;
        let flag_values = crate::protos::flag_values::try_from_text_proto(&contents)
            .with_context(|| format!("Failed to parse {}", input.source))?;
        for flag_value in flag_values.flag_value.into_iter() {
            crate::protos::flag_value::verify_fields(&flag_value)
                .with_context(|| format!("Failed to parse {}", input.source))?;

            let Some(parsed_flag) = parsed_flags.parsed_flag.iter_mut().find(|pf| pf.package() == flag_value.package() && pf.name() == flag_value.name()) else {
                // (silently) skip unknown flags
                continue;
            };

            parsed_flag.set_state(flag_value.state());
            parsed_flag.set_permission(flag_value.permission());
            let mut tracepoint = ProtoTracepoint::new();
            tracepoint.set_source(input.source.clone());
            tracepoint.set_state(flag_value.state());
            tracepoint.set_permission(flag_value.permission());
            parsed_flag.trace.push(tracepoint);
        }
    }

    crate::protos::parsed_flags::verify_fields(&parsed_flags)?;
    let mut output = Vec::new();
    parsed_flags.write_to_vec(&mut output)?;
    Ok(output)
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
pub enum CodegenMode {
    Production,
    Test,
}

pub fn create_java_lib(mut input: Input, codegen_mode: CodegenMode) -> Result<Vec<OutputFile>> {
    let parsed_flags = input.try_parse_flags()?;
    let Some(package) = find_unique_package(&parsed_flags) else {
        bail!("no parsed flags, or the parsed flags use different packages");
    };
    generate_java_code(package, parsed_flags.parsed_flag.iter(), codegen_mode)
}

pub fn create_cpp_lib(mut input: Input) -> Result<OutputFile> {
    let parsed_flags = input.try_parse_flags()?;
    let Some(package) = find_unique_package(&parsed_flags) else {
        bail!("no parsed flags, or the parsed flags use different packages");
    };
    generate_cpp_code(package, parsed_flags.parsed_flag.iter())
}

pub fn create_rust_lib(mut input: Input) -> Result<OutputFile> {
    let parsed_flags = input.try_parse_flags()?;
    let Some(package) = find_unique_package(&parsed_flags) else {
        bail!("no parsed flags, or the parsed flags use different packages");
    };
    generate_rust_code(package, parsed_flags.parsed_flag.iter())
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
            "{}:{}.{}={}\n",
            parsed_flag.namespace(),
            parsed_flag.package(),
            parsed_flag.name(),
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
            "persist.device_config.{}.{}={}\n",
            parsed_flag.package(),
            parsed_flag.name(),
            match parsed_flag.state() {
                ProtoFlagState::ENABLED => "true",
                ProtoFlagState::DISABLED => "false",
            }
        );
        output.extend_from_slice(line.as_bytes());
    }
    Ok(output)
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
pub enum DumpFormat {
    Text,
    Debug,
    Protobuf,
    Textproto,
}

pub fn dump_parsed_flags(mut input: Vec<Input>, format: DumpFormat) -> Result<Vec<u8>> {
    let individually_parsed_flags: Result<Vec<ProtoParsedFlags>> =
        input.iter_mut().map(|i| i.try_parse_flags()).collect();
    let parsed_flags: ProtoParsedFlags =
        crate::protos::parsed_flags::merge(individually_parsed_flags?)?;

    let mut output = Vec::new();
    match format {
        DumpFormat::Text => {
            for parsed_flag in parsed_flags.parsed_flag.into_iter() {
                let line = format!(
                    "{}/{}: {:?} {:?}\n",
                    parsed_flag.package(),
                    parsed_flag.name(),
                    parsed_flag.state(),
                    parsed_flag.permission()
                );
                output.extend_from_slice(line.as_bytes());
            }
        }
        DumpFormat::Debug => {
            for parsed_flag in parsed_flags.parsed_flag.into_iter() {
                let line = format!("{:#?}\n", parsed_flag);
                output.extend_from_slice(line.as_bytes());
            }
        }
        DumpFormat::Protobuf => {
            parsed_flags.write_to_vec(&mut output)?;
        }
        DumpFormat::Textproto => {
            let s = protobuf::text_format::print_to_string_pretty(&parsed_flags);
            output.extend_from_slice(s.as_bytes());
        }
    }
    Ok(output)
}

fn find_unique_package(parsed_flags: &ProtoParsedFlags) -> Option<&str> {
    let Some(package) = parsed_flags.parsed_flag.first().map(|pf| pf.package()) else {
        return None;
    };
    if parsed_flags.parsed_flag.iter().any(|pf| pf.package() != package) {
        return None;
    }
    Some(package)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_flags() {
        let parsed_flags = crate::test::parse_test_flags(); // calls parse_flags
        crate::protos::parsed_flags::verify_fields(&parsed_flags).unwrap();

        let enabled_ro =
            parsed_flags.parsed_flag.iter().find(|pf| pf.name() == "enabled_ro").unwrap();
        assert!(crate::protos::parsed_flag::verify_fields(enabled_ro).is_ok());
        assert_eq!("com.android.aconfig.test", enabled_ro.package());
        assert_eq!("enabled_ro", enabled_ro.name());
        assert_eq!("This flag is ENABLED + READ_ONLY", enabled_ro.description());
        assert_eq!(ProtoFlagState::ENABLED, enabled_ro.state());
        assert_eq!(ProtoFlagPermission::READ_ONLY, enabled_ro.permission());
        assert_eq!(3, enabled_ro.trace.len());
        assert_eq!("tests/test.aconfig", enabled_ro.trace[0].source());
        assert_eq!(ProtoFlagState::DISABLED, enabled_ro.trace[0].state());
        assert_eq!(ProtoFlagPermission::READ_WRITE, enabled_ro.trace[0].permission());
        assert_eq!("tests/first.values", enabled_ro.trace[1].source());
        assert_eq!(ProtoFlagState::DISABLED, enabled_ro.trace[1].state());
        assert_eq!(ProtoFlagPermission::READ_WRITE, enabled_ro.trace[1].permission());
        assert_eq!("tests/second.values", enabled_ro.trace[2].source());
        assert_eq!(ProtoFlagState::ENABLED, enabled_ro.trace[2].state());
        assert_eq!(ProtoFlagPermission::READ_ONLY, enabled_ro.trace[2].permission());

        assert_eq!(4, parsed_flags.parsed_flag.len());
        for pf in parsed_flags.parsed_flag.iter() {
            let first = pf.trace.first().unwrap();
            assert_eq!(DEFAULT_FLAG_STATE, first.state());
            assert_eq!(DEFAULT_FLAG_PERMISSION, first.permission());

            let last = pf.trace.last().unwrap();
            assert_eq!(pf.state(), last.state());
            assert_eq!(pf.permission(), last.permission());
        }
    }

    #[test]
    fn test_create_device_config_defaults() {
        let input = parse_test_flags_as_input();
        let bytes = create_device_config_defaults(input).unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert_eq!("aconfig_test:com.android.aconfig.test.disabled_rw=disabled\naconfig_test:com.android.aconfig.test.enabled_rw=enabled\n", text);
    }

    #[test]
    fn test_create_device_config_sysprops() {
        let input = parse_test_flags_as_input();
        let bytes = create_device_config_sysprops(input).unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert_eq!("persist.device_config.com.android.aconfig.test.disabled_rw=false\npersist.device_config.com.android.aconfig.test.enabled_rw=true\n", text);
    }

    #[test]
    fn test_dump_text_format() {
        let input = parse_test_flags_as_input();
        let bytes = dump_parsed_flags(vec![input], DumpFormat::Text).unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert!(text.contains("com.android.aconfig.test/disabled_ro: DISABLED READ_ONLY"));
    }

    #[test]
    fn test_dump_protobuf_format() {
        let expected = protobuf::text_format::parse_from_str::<ProtoParsedFlags>(
            crate::test::TEST_FLAGS_TEXTPROTO,
        )
        .unwrap()
        .write_to_bytes()
        .unwrap();

        let input = parse_test_flags_as_input();
        let actual = dump_parsed_flags(vec![input], DumpFormat::Protobuf).unwrap();

        assert_eq!(expected, actual);
    }

    #[test]
    fn test_dump_textproto_format() {
        let input = parse_test_flags_as_input();
        let bytes = dump_parsed_flags(vec![input], DumpFormat::Textproto).unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert_eq!(crate::test::TEST_FLAGS_TEXTPROTO.trim(), text.trim());
    }

    fn parse_test_flags_as_input() -> Input {
        let parsed_flags = crate::test::parse_test_flags();
        let binary_proto = parsed_flags.write_to_bytes().unwrap();
        let cursor = std::io::Cursor::new(binary_proto);
        let reader = Box::new(cursor);
        Input { source: "test.data".to_string(), reader }
    }
}
