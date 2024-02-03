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

use aconfig_protos::{
    ParsedFlagExt, ProtoFlagMetadata, ProtoFlagPermission, ProtoFlagState, ProtoTracepoint,
};
use aconfig_protos::{ProtoParsedFlag, ProtoParsedFlags};
use anyhow::{anyhow, bail, Context, Result};
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

pub fn create_filter_predicate(filter: &str) -> Result<Box<DumpPredicate>> {
    let predicates = filter
        .split('+')
        .map(|sub_filter| create_filter_predicate_single(sub_filter))
        .collect::<Result<Vec<_>>>()?;
    Ok(Box::new(move |flag| predicates.iter().all(|p| p(flag))))
}

fn create_filter_predicate_single(filter: &str) -> Result<Box<DumpPredicate>> {
    fn enum_from_str<T>(expected: &[T], s: &str) -> Result<T>
    where
        T: std::fmt::Debug + Copy,
    {
        for candidate in expected.iter() {
            if s == format!("{:?}", candidate) {
                return Ok(*candidate);
            }
        }
        let expected =
            expected.iter().map(|state| format!("{:?}", state)).collect::<Vec<_>>().join(", ");
        bail!("\"{s}\": not a valid flag state, expected one of {expected}");
    }

    let error_msg = format!("\"{filter}\": filter syntax error");
    let (what, arg) = filter.split_once(':').ok_or_else(|| anyhow!(error_msg.clone()))?;
    match what {
        "package" => {
            let expected = arg.to_owned();
            Ok(Box::new(move |flag: &ProtoParsedFlag| flag.package() == expected))
        }
        "name" => {
            let expected = arg.to_owned();
            Ok(Box::new(move |flag: &ProtoParsedFlag| flag.name() == expected))
        }
        "namespace" => {
            let expected = arg.to_owned();
            Ok(Box::new(move |flag: &ProtoParsedFlag| flag.namespace() == expected))
        }
        // description: not supported yet
        "bug" => {
            let expected = arg.to_owned();
            Ok(Box::new(move |flag: &ProtoParsedFlag| flag.bug.join(", ") == expected))
        }
        "state" => {
            let expected = enum_from_str(&[ProtoFlagState::ENABLED, ProtoFlagState::DISABLED], arg)
                .context(error_msg)?;
            Ok(Box::new(move |flag: &ProtoParsedFlag| flag.state() == expected))
        }
        "permission" => {
            let expected = enum_from_str(
                &[ProtoFlagPermission::READ_ONLY, ProtoFlagPermission::READ_WRITE],
                arg,
            )
            .context(error_msg)?;
            Ok(Box::new(move |flag: &ProtoParsedFlag| flag.permission() == expected))
        }
        // trace: not supported yet
        "is_fixed_read_only" => {
            let expected: bool = arg.parse().context(error_msg)?;
            Ok(Box::new(move |flag: &ProtoParsedFlag| flag.is_fixed_read_only() == expected))
        }
        "is_exported" => {
            let expected: bool = arg.parse().context(error_msg)?;
            Ok(Box::new(move |flag: &ProtoParsedFlag| flag.is_exported() == expected))
        }
        "container" => {
            let expected = arg.to_owned();
            Ok(Box::new(move |flag: &ProtoParsedFlag| flag.container() == expected))
        }
        // metadata: not supported yet
        "fully_qualified_name" => {
            let expected = arg.to_owned();
            Ok(Box::new(move |flag: &ProtoParsedFlag| flag.fully_qualified_name() == expected))
        }
        _ => Err(anyhow!(error_msg)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test::parse_test_flags;
    use aconfig_protos::ProtoParsedFlags;
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

    #[test]
    fn test_create_filter_predicate() {
        macro_rules! assert_create_filter_predicate {
            ($filter:expr, $expected:expr) => {
                let parsed_flags = parse_test_flags();
                let predicate = create_filter_predicate($filter).unwrap();
                let mut filtered_flags: Vec<String> = parsed_flags
                    .parsed_flag
                    .into_iter()
                    .filter(predicate)
                    .map(|flag| flag.fully_qualified_name())
                    .collect();
                filtered_flags.sort();
                assert_eq!(&filtered_flags, $expected);
            };
        }

        assert_create_filter_predicate!(
            "package:com.android.aconfig.test",
            &[
                "com.android.aconfig.test.disabled_ro",
                "com.android.aconfig.test.disabled_rw",
                "com.android.aconfig.test.disabled_rw_exported",
                "com.android.aconfig.test.disabled_rw_in_other_namespace",
                "com.android.aconfig.test.enabled_fixed_ro",
                "com.android.aconfig.test.enabled_fixed_ro_exported",
                "com.android.aconfig.test.enabled_ro",
                "com.android.aconfig.test.enabled_ro_exported",
                "com.android.aconfig.test.enabled_rw",
            ]
        );
        assert_create_filter_predicate!(
            "name:disabled_rw",
            &["com.android.aconfig.test.disabled_rw"]
        );
        assert_create_filter_predicate!(
            "namespace:other_namespace",
            &["com.android.aconfig.test.disabled_rw_in_other_namespace"]
        );
        // description: not supported yet
        assert_create_filter_predicate!("bug:123", &["com.android.aconfig.test.disabled_ro",]);
        assert_create_filter_predicate!(
            "state:ENABLED",
            &[
                "com.android.aconfig.test.enabled_fixed_ro",
                "com.android.aconfig.test.enabled_fixed_ro_exported",
                "com.android.aconfig.test.enabled_ro",
                "com.android.aconfig.test.enabled_ro_exported",
                "com.android.aconfig.test.enabled_rw",
            ]
        );
        assert_create_filter_predicate!(
            "permission:READ_ONLY",
            &[
                "com.android.aconfig.test.disabled_ro",
                "com.android.aconfig.test.enabled_fixed_ro",
                "com.android.aconfig.test.enabled_fixed_ro_exported",
                "com.android.aconfig.test.enabled_ro",
                "com.android.aconfig.test.enabled_ro_exported",
            ]
        );
        // trace: not supported yet
        assert_create_filter_predicate!(
            "is_fixed_read_only:true",
            &[
                "com.android.aconfig.test.enabled_fixed_ro",
                "com.android.aconfig.test.enabled_fixed_ro_exported",
            ]
        );
        assert_create_filter_predicate!(
            "is_exported:true",
            &[
                "com.android.aconfig.test.disabled_rw_exported",
                "com.android.aconfig.test.enabled_fixed_ro_exported",
                "com.android.aconfig.test.enabled_ro_exported",
            ]
        );
        assert_create_filter_predicate!(
            "container:system",
            &[
                "com.android.aconfig.test.disabled_ro",
                "com.android.aconfig.test.disabled_rw",
                "com.android.aconfig.test.disabled_rw_exported",
                "com.android.aconfig.test.disabled_rw_in_other_namespace",
                "com.android.aconfig.test.enabled_fixed_ro",
                "com.android.aconfig.test.enabled_fixed_ro_exported",
                "com.android.aconfig.test.enabled_ro",
                "com.android.aconfig.test.enabled_ro_exported",
                "com.android.aconfig.test.enabled_rw",
            ]
        );
        // metadata: not supported yet

        // synthesized fields
        assert_create_filter_predicate!(
            "fully_qualified_name:com.android.aconfig.test.disabled_rw",
            &["com.android.aconfig.test.disabled_rw"]
        );

        // multiple sub filters
        assert_create_filter_predicate!(
            "permission:READ_ONLY+state:ENABLED",
            &[
                "com.android.aconfig.test.enabled_fixed_ro",
                "com.android.aconfig.test.enabled_fixed_ro_exported",
                "com.android.aconfig.test.enabled_ro",
                "com.android.aconfig.test.enabled_ro_exported",
            ]
        );
    }
}
