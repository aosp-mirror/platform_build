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

use crate::protos::{ParsedFlagExt, ProtoFlagMetadata, ProtoFlagState, ProtoTracepoint};
use crate::protos::{ProtoParsedFlag, ProtoParsedFlags};
use anyhow::Result;
use protobuf::Message;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DumpFormat {
    Protobuf,
    Textproto,
    Custom(String),
}

impl TryFrom<&str> for DumpFormat {
    type Error = anyhow::Error;

    fn try_from(value: &str) -> std::result::Result<Self, Self::Error> {
        match value {
            // protobuf formats
            "protobuf" => Ok(Self::Protobuf),
            "textproto" => Ok(Self::Textproto),

            // old formats now implemented as aliases to custom format
            "text" => Ok(Self::Custom(
                "{fully_qualified_name} [{container}]: {permission} + {state}".to_owned(),
            )),
            "verbose" => Ok(Self::Custom(
                "{fully_qualified_name} [{container}]: {permission} + {state} ({trace:paths})"
                    .to_owned(),
            )),
            "bool" => Ok(Self::Custom("{fully_qualified_name}={state:bool}".to_owned())),

            // custom format
            _ => Ok(Self::Custom(value.to_owned())),
        }
    }
}

pub fn dump_parsed_flags<I>(parsed_flags_iter: I, format: DumpFormat) -> Result<Vec<u8>>
where
    I: Iterator<Item = ProtoParsedFlag>,
{
    let mut output = Vec::new();
    match format {
        DumpFormat::Protobuf => {
            let parsed_flags =
                ProtoParsedFlags { parsed_flag: parsed_flags_iter.collect(), ..Default::default() };
            parsed_flags.write_to_vec(&mut output)?;
        }
        DumpFormat::Textproto => {
            let parsed_flags =
                ProtoParsedFlags { parsed_flag: parsed_flags_iter.collect(), ..Default::default() };
            let s = protobuf::text_format::print_to_string_pretty(&parsed_flags);
            output.extend_from_slice(s.as_bytes());
        }
        DumpFormat::Custom(format) => {
            for flag in parsed_flags_iter {
                dump_custom_format(&flag, &format, &mut output);
            }
        }
    }
    Ok(output)
}

fn dump_custom_format(flag: &ProtoParsedFlag, format: &str, output: &mut Vec<u8>) {
    fn format_trace(trace: &[ProtoTracepoint]) -> String {
        trace
            .iter()
            .map(|tracepoint| {
                format!(
                    "{}: {:?} + {:?}",
                    tracepoint.source(),
                    tracepoint.permission(),
                    tracepoint.state()
                )
            })
            .collect::<Vec<_>>()
            .join(", ")
    }

    fn format_trace_paths(trace: &[ProtoTracepoint]) -> String {
        trace.iter().map(|tracepoint| tracepoint.source()).collect::<Vec<_>>().join(", ")
    }

    fn format_metadata(metadata: &ProtoFlagMetadata) -> String {
        format!("{:?}", metadata.purpose())
    }

    let mut str = format
        // ProtoParsedFlag fields
        .replace("{package}", flag.package())
        .replace("{name}", flag.name())
        .replace("{namespace}", flag.namespace())
        .replace("{description}", flag.description())
        .replace("{bug}", &flag.bug.join(", "))
        .replace("{state}", &format!("{:?}", flag.state()))
        .replace("{state:bool}", &format!("{}", flag.state() == ProtoFlagState::ENABLED))
        .replace("{permission}", &format!("{:?}", flag.permission()))
        .replace("{trace}", &format_trace(&flag.trace))
        .replace("{trace:paths}", &format_trace_paths(&flag.trace))
        .replace("{is_fixed_read_only}", &format!("{}", flag.is_fixed_read_only()))
        .replace("{is_exported}", &format!("{}", flag.is_exported()))
        .replace("{container}", flag.container())
        .replace("{metadata}", &format_metadata(&flag.metadata))
        // ParsedFlagExt functions
        .replace("{fully_qualified_name}", &flag.fully_qualified_name());
    str.push('\n');
    output.extend_from_slice(str.as_bytes());
}

pub type DumpPredicate = dyn Fn(&ProtoParsedFlag) -> bool;

#[allow(unused)]
pub fn create_filter_predicate(filter: &str) -> Result<Box<DumpPredicate>> {
    todo!();
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::protos::ProtoParsedFlags;
    use crate::test::parse_test_flags;
    use protobuf::Message;

    fn parse_enabled_ro_flag() -> ProtoParsedFlag {
        parse_test_flags().parsed_flag.into_iter().find(|pf| pf.name() == "enabled_ro").unwrap()
    }

    #[test]
    fn test_dumpformat_from_str() {
        // supported format types
        assert_eq!(DumpFormat::try_from("protobuf").unwrap(), DumpFormat::Protobuf);
        assert_eq!(DumpFormat::try_from("textproto").unwrap(), DumpFormat::Textproto);
        assert_eq!(
            DumpFormat::try_from("foobar").unwrap(),
            DumpFormat::Custom("foobar".to_owned())
        );
    }

    #[test]
    fn test_dump_parsed_flags_protobuf_format() {
        let expected = protobuf::text_format::parse_from_str::<ProtoParsedFlags>(
            crate::test::TEST_FLAGS_TEXTPROTO,
        )
        .unwrap()
        .write_to_bytes()
        .unwrap();
        let parsed_flags = parse_test_flags();
        let actual =
            dump_parsed_flags(parsed_flags.parsed_flag.into_iter(), DumpFormat::Protobuf).unwrap();
        assert_eq!(expected, actual);
    }

    #[test]
    fn test_dump_parsed_flags_textproto_format() {
        let parsed_flags = parse_test_flags();
        let bytes =
            dump_parsed_flags(parsed_flags.parsed_flag.into_iter(), DumpFormat::Textproto).unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert_eq!(crate::test::TEST_FLAGS_TEXTPROTO.trim(), text.trim());
    }

    #[test]
    fn test_dump_parsed_flags_custom_format() {
        macro_rules! assert_dump_parsed_flags_custom_format_contains {
            ($format:expr, $expected:expr) => {
                let parsed_flags = parse_test_flags();
                let bytes = dump_parsed_flags(
                    parsed_flags.parsed_flag.into_iter(),
                    $format.try_into().unwrap(),
                )
                .unwrap();
                let text = std::str::from_utf8(&bytes).unwrap();
                assert!(text.contains($expected));
            };
        }

        // custom format
        assert_dump_parsed_flags_custom_format_contains!(
            "{fully_qualified_name}={permission} + {state}",
            "com.android.aconfig.test.enabled_ro=READ_ONLY + ENABLED"
        );

        // aliases
        assert_dump_parsed_flags_custom_format_contains!(
            "text",
            "com.android.aconfig.test.enabled_ro [system]: READ_ONLY + ENABLED"
        );
        assert_dump_parsed_flags_custom_format_contains!(
            "verbose",
            "com.android.aconfig.test.enabled_ro [system]: READ_ONLY + ENABLED (tests/test.aconfig, tests/first.values, tests/second.values)"
        );
        assert_dump_parsed_flags_custom_format_contains!(
            "bool",
            "com.android.aconfig.test.enabled_ro=true"
        );
    }

    #[test]
    fn test_dump_custom_format() {
        macro_rules! assert_custom_format {
            ($format:expr, $expected:expr) => {
                let flag = parse_enabled_ro_flag();
                let mut bytes = vec![];
                dump_custom_format(&flag, $format, &mut bytes);
                let text = std::str::from_utf8(&bytes).unwrap();
                assert_eq!(text, $expected);
            };
        }

        assert_custom_format!("{package}", "com.android.aconfig.test\n");
        assert_custom_format!("{name}", "enabled_ro\n");
        assert_custom_format!("{namespace}", "aconfig_test\n");
        assert_custom_format!("{description}", "This flag is ENABLED + READ_ONLY\n");
        assert_custom_format!("{bug}", "abc\n");
        assert_custom_format!("{state}", "ENABLED\n");
        assert_custom_format!("{state:bool}", "true\n");
        assert_custom_format!("{permission}", "READ_ONLY\n");
        assert_custom_format!("{trace}", "tests/test.aconfig: READ_WRITE + DISABLED, tests/first.values: READ_WRITE + DISABLED, tests/second.values: READ_ONLY + ENABLED\n");
        assert_custom_format!(
            "{trace:paths}",
            "tests/test.aconfig, tests/first.values, tests/second.values\n"
        );
        assert_custom_format!("{is_fixed_read_only}", "false\n");
        assert_custom_format!("{is_exported}", "false\n");
        assert_custom_format!("{container}", "system\n");
        assert_custom_format!("{metadata}", "PURPOSE_BUGFIX\n");

        assert_custom_format!("name={name}|state={state}", "name=enabled_ro|state=ENABLED\n");
        assert_custom_format!("{state}{state}{state}", "ENABLEDENABLEDENABLED\n");
    }
}
