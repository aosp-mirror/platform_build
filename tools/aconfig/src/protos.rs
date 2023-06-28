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

// When building with the Android tool-chain
//
//   - an external crate `aconfig_protos` will be generated
//   - the feature "cargo" will be disabled
//
// When building with cargo
//
//   - a local sub-module will be generated in OUT_DIR and included in this file
//   - the feature "cargo" will be enabled
//
// This module hides these differences from the rest of aconfig.

// ---- When building with the Android tool-chain ----
#[cfg(not(feature = "cargo"))]
mod auto_generated {
    pub use aconfig_protos::aconfig::Flag_declaration as ProtoFlagDeclaration;
    pub use aconfig_protos::aconfig::Flag_declarations as ProtoFlagDeclarations;
    pub use aconfig_protos::aconfig::Flag_permission as ProtoFlagPermission;
    pub use aconfig_protos::aconfig::Flag_state as ProtoFlagState;
    pub use aconfig_protos::aconfig::Flag_value as ProtoFlagValue;
    pub use aconfig_protos::aconfig::Flag_values as ProtoFlagValues;
    pub use aconfig_protos::aconfig::Parsed_flag as ProtoParsedFlag;
    pub use aconfig_protos::aconfig::Parsed_flags as ProtoParsedFlags;
    pub use aconfig_protos::aconfig::Tracepoint as ProtoTracepoint;
}

// ---- When building with cargo ----
#[cfg(feature = "cargo")]
mod auto_generated {
    // include! statements should be avoided (because they import file contents verbatim), but
    // because this is only used during local development, and only if using cargo instead of the
    // Android tool-chain, we allow it
    include!(concat!(env!("OUT_DIR"), "/aconfig_proto/mod.rs"));
    pub use aconfig::Flag_declaration as ProtoFlagDeclaration;
    pub use aconfig::Flag_declarations as ProtoFlagDeclarations;
    pub use aconfig::Flag_permission as ProtoFlagPermission;
    pub use aconfig::Flag_state as ProtoFlagState;
    pub use aconfig::Flag_value as ProtoFlagValue;
    pub use aconfig::Flag_values as ProtoFlagValues;
    pub use aconfig::Parsed_flag as ProtoParsedFlag;
    pub use aconfig::Parsed_flags as ProtoParsedFlags;
    pub use aconfig::Tracepoint as ProtoTracepoint;
}

// ---- Common for both the Android tool-chain and cargo ----
pub use auto_generated::*;

use anyhow::Result;
use paste::paste;

fn try_from_text_proto<T>(s: &str) -> Result<T>
where
    T: protobuf::MessageFull,
{
    protobuf::text_format::parse_from_str(s).map_err(|e| e.into())
}

macro_rules! ensure_required_fields {
    ($type:expr, $struct:expr, $($field:expr),+) => {
        $(
        paste! {
            ensure!($struct.[<has_ $field>](), "bad {}: missing {}", $type, $field);
        }
        )+
    };
}

pub mod flag_declaration {
    use super::*;
    use crate::codegen;
    use anyhow::ensure;

    pub fn verify_fields(pdf: &ProtoFlagDeclaration) -> Result<()> {
        ensure_required_fields!("flag declaration", pdf, "name", "namespace", "description");

        ensure!(codegen::is_valid_name_ident(pdf.name()), "bad flag declaration: bad name");
        ensure!(codegen::is_valid_name_ident(pdf.namespace()), "bad flag declaration: bad name");
        ensure!(!pdf.description().is_empty(), "bad flag declaration: empty description");

        // ProtoFlagDeclaration.bug: Vec<String>: may be empty, no checks needed

        Ok(())
    }
}

pub mod flag_declarations {
    use super::*;
    use crate::codegen;
    use anyhow::ensure;

    pub fn try_from_text_proto(s: &str) -> Result<ProtoFlagDeclarations> {
        let pdf: ProtoFlagDeclarations = super::try_from_text_proto(s)?;
        verify_fields(&pdf)?;
        Ok(pdf)
    }

    pub fn verify_fields(pdf: &ProtoFlagDeclarations) -> Result<()> {
        ensure_required_fields!("flag declarations", pdf, "package");

        ensure!(
            codegen::is_valid_package_ident(pdf.package()),
            "bad flag declarations: bad package"
        );
        for flag_declaration in pdf.flag.iter() {
            super::flag_declaration::verify_fields(flag_declaration)?;
        }

        Ok(())
    }
}

pub mod flag_value {
    use super::*;
    use crate::codegen;
    use anyhow::ensure;

    pub fn verify_fields(fv: &ProtoFlagValue) -> Result<()> {
        ensure_required_fields!("flag value", fv, "package", "name", "state", "permission");

        ensure!(codegen::is_valid_package_ident(fv.package()), "bad flag value: bad package");
        ensure!(codegen::is_valid_name_ident(fv.name()), "bad flag value: bad name");

        Ok(())
    }
}

pub mod flag_values {
    use super::*;

    pub fn try_from_text_proto(s: &str) -> Result<ProtoFlagValues> {
        let pfv: ProtoFlagValues = super::try_from_text_proto(s)?;
        verify_fields(&pfv)?;
        Ok(pfv)
    }

    pub fn verify_fields(pfv: &ProtoFlagValues) -> Result<()> {
        for flag_value in pfv.flag_value.iter() {
            super::flag_value::verify_fields(flag_value)?;
        }
        Ok(())
    }
}

pub mod tracepoint {
    use super::*;
    use anyhow::ensure;

    pub fn verify_fields(tp: &ProtoTracepoint) -> Result<()> {
        ensure_required_fields!("tracepoint", tp, "source", "state", "permission");

        ensure!(!tp.source().is_empty(), "bad tracepoint: empty source");

        Ok(())
    }
}

pub mod parsed_flag {
    use super::*;
    use crate::codegen;
    use anyhow::ensure;

    pub fn verify_fields(pf: &ProtoParsedFlag) -> Result<()> {
        ensure_required_fields!(
            "parsed flag",
            pf,
            "package",
            "name",
            "namespace",
            "description",
            "state",
            "permission"
        );

        ensure!(codegen::is_valid_package_ident(pf.package()), "bad parsed flag: bad package");
        ensure!(codegen::is_valid_name_ident(pf.name()), "bad parsed flag: bad name");
        ensure!(codegen::is_valid_name_ident(pf.namespace()), "bad parsed flag: bad namespace");
        ensure!(!pf.description().is_empty(), "bad parsed flag: empty description");
        ensure!(!pf.trace.is_empty(), "bad parsed flag: empty trace");
        for tp in pf.trace.iter() {
            super::tracepoint::verify_fields(tp)?;
        }

        // ProtoParsedFlag.bug: Vec<String>: may be empty, no checks needed

        Ok(())
    }
}

pub mod parsed_flags {
    use super::*;
    use anyhow::bail;
    use std::cmp::Ordering;

    pub fn try_from_binary_proto(bytes: &[u8]) -> Result<ProtoParsedFlags> {
        let message: ProtoParsedFlags = protobuf::Message::parse_from_bytes(bytes)?;
        verify_fields(&message)?;
        Ok(message)
    }

    pub fn verify_fields(pf: &ProtoParsedFlags) -> Result<()> {
        let mut previous: Option<&ProtoParsedFlag> = None;
        for parsed_flag in pf.parsed_flag.iter() {
            if let Some(prev) = previous {
                let a = create_sorting_key(prev);
                let b = create_sorting_key(parsed_flag);
                match a.cmp(&b) {
                    Ordering::Less => {}
                    Ordering::Equal => bail!("bad parsed flags: duplicate flag {}", a),
                    Ordering::Greater => {
                        bail!("bad parsed flags: not sorted: {} comes before {}", a, b)
                    }
                }
            }
            super::parsed_flag::verify_fields(parsed_flag)?;
            previous = Some(parsed_flag);
        }
        Ok(())
    }

    pub fn merge(parsed_flags: Vec<ProtoParsedFlags>) -> Result<ProtoParsedFlags> {
        let mut merged = ProtoParsedFlags::new();
        for mut pfs in parsed_flags.into_iter() {
            merged.parsed_flag.append(&mut pfs.parsed_flag);
        }
        merged.parsed_flag.sort_by_cached_key(create_sorting_key);
        verify_fields(&merged)?;
        Ok(merged)
    }

    fn create_sorting_key(pf: &ProtoParsedFlag) -> String {
        format!("{}.{}", pf.package(), pf.name())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_flag_declarations_try_from_text_proto() {
        // valid input
        let flag_declarations = flag_declarations::try_from_text_proto(
            r#"
package: "com.foo.bar"
flag {
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    bug: "123"
    bug: "abc"
}
flag {
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
}
"#,
        )
        .unwrap();
        assert_eq!(flag_declarations.package(), "com.foo.bar");
        let first = flag_declarations.flag.iter().find(|pf| pf.name() == "first").unwrap();
        assert_eq!(first.name(), "first");
        assert_eq!(first.namespace(), "first_ns");
        assert_eq!(first.description(), "This is the description of the first flag.");
        assert_eq!(first.bug.len(), 2);
        assert_eq!(first.bug[0], "123");
        assert_eq!(first.bug[1], "abc");
        let second = flag_declarations.flag.iter().find(|pf| pf.name() == "second").unwrap();
        assert_eq!(second.name(), "second");
        assert_eq!(second.namespace(), "second_ns");
        assert_eq!(second.description(), "This is the description of the second flag.");
        assert_eq!(second.bug.len(), 0);

        // bad input: missing package in flag declarations
        let error = flag_declarations::try_from_text_proto(
            r#"
flag {
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
}
flag {
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
}
"#,
        )
        .unwrap_err();
        assert_eq!(format!("{:?}", error), "bad flag declarations: missing package");

        // bad input: missing namespace in flag declaration
        let error = flag_declarations::try_from_text_proto(
            r#"
package: "com.foo.bar"
flag {
    name: "first"
    description: "This is the description of the first flag."
}
flag {
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
}
"#,
        )
        .unwrap_err();
        assert_eq!(format!("{:?}", error), "bad flag declaration: missing namespace");

        // bad input: bad package name in flag declarations
        let error = flag_declarations::try_from_text_proto(
            r#"
package: "_com.FOO__BAR"
flag {
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
}
flag {
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
}
"#,
        )
        .unwrap_err();
        assert!(format!("{:?}", error).contains("bad flag declarations: bad package"));

        // bad input: bad name in flag declaration
        let error = flag_declarations::try_from_text_proto(
            r#"
package: "com.foo.bar"
flag {
    name: "FIRST"
    namespace: "first_ns"
    description: "This is the description of the first flag."
}
flag {
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
}
"#,
        )
        .unwrap_err();
        assert!(format!("{:?}", error).contains("bad flag declaration: bad name"));
    }

    #[test]
    fn test_flag_values_try_from_text_proto() {
        // valid input
        let flag_values = flag_values::try_from_text_proto(
            r#"
flag_value {
    package: "com.first"
    name: "first"
    state: DISABLED
    permission: READ_ONLY
}
flag_value {
    package: "com.second"
    name: "second"
    state: ENABLED
    permission: READ_WRITE
}
"#,
        )
        .unwrap();
        let first = flag_values.flag_value.iter().find(|fv| fv.name() == "first").unwrap();
        assert_eq!(first.package(), "com.first");
        assert_eq!(first.name(), "first");
        assert_eq!(first.state(), ProtoFlagState::DISABLED);
        assert_eq!(first.permission(), ProtoFlagPermission::READ_ONLY);
        let second = flag_values.flag_value.iter().find(|fv| fv.name() == "second").unwrap();
        assert_eq!(second.package(), "com.second");
        assert_eq!(second.name(), "second");
        assert_eq!(second.state(), ProtoFlagState::ENABLED);
        assert_eq!(second.permission(), ProtoFlagPermission::READ_WRITE);

        // bad input: bad package in flag value
        let error = flag_values::try_from_text_proto(
            r#"
flag_value {
    package: "COM.FIRST"
    name: "first"
    state: DISABLED
    permission: READ_ONLY
}
"#,
        )
        .unwrap_err();
        assert!(format!("{:?}", error).contains("bad flag value: bad package"));

        // bad input: bad name in flag value
        let error = flag_values::try_from_text_proto(
            r#"
flag_value {
    package: "com.first"
    name: "FIRST"
    state: DISABLED
    permission: READ_ONLY
}
"#,
        )
        .unwrap_err();
        assert!(format!("{:?}", error).contains("bad flag value: bad name"));

        // bad input: missing state in flag value
        let error = flag_values::try_from_text_proto(
            r#"
flag_value {
    package: "com.first"
    name: "first"
    permission: READ_ONLY
}
"#,
        )
        .unwrap_err();
        assert_eq!(format!("{:?}", error), "bad flag value: missing state");

        // bad input: missing permission in flag value
        let error = flag_values::try_from_text_proto(
            r#"
flag_value {
    package: "com.first"
    name: "first"
    state: DISABLED
}
"#,
        )
        .unwrap_err();
        assert_eq!(format!("{:?}", error), "bad flag value: missing permission");
    }

    fn try_from_binary_proto_from_text_proto(text_proto: &str) -> Result<ProtoParsedFlags> {
        use protobuf::Message;

        let parsed_flags: ProtoParsedFlags = try_from_text_proto(text_proto)?;
        let mut binary_proto = Vec::new();
        parsed_flags.write_to_vec(&mut binary_proto)?;
        parsed_flags::try_from_binary_proto(&binary_proto)
    }

    #[test]
    fn test_parsed_flags_try_from_text_proto() {
        // valid input
        let text_proto = r#"
parsed_flag {
    package: "com.first"
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
parsed_flag {
    package: "com.second"
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
    state: ENABLED
    permission: READ_WRITE
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    trace {
        source: "flags.values"
        state: ENABLED
        permission: READ_WRITE
    }
}
"#;
        let parsed_flags = try_from_binary_proto_from_text_proto(text_proto).unwrap();
        assert_eq!(parsed_flags.parsed_flag.len(), 2);
        let second = parsed_flags.parsed_flag.iter().find(|fv| fv.name() == "second").unwrap();
        assert_eq!(second.package(), "com.second");
        assert_eq!(second.name(), "second");
        assert_eq!(second.namespace(), "second_ns");
        assert_eq!(second.description(), "This is the description of the second flag.");
        assert_eq!(second.state(), ProtoFlagState::ENABLED);
        assert_eq!(second.permission(), ProtoFlagPermission::READ_WRITE);
        assert_eq!(2, second.trace.len());
        assert_eq!(second.trace[0].source(), "flags.declarations");
        assert_eq!(second.trace[0].state(), ProtoFlagState::DISABLED);
        assert_eq!(second.trace[0].permission(), ProtoFlagPermission::READ_ONLY);
        assert_eq!(second.trace[1].source(), "flags.values");
        assert_eq!(second.trace[1].state(), ProtoFlagState::ENABLED);
        assert_eq!(second.trace[1].permission(), ProtoFlagPermission::READ_WRITE);

        // valid input: empty
        let parsed_flags = try_from_binary_proto_from_text_proto("").unwrap();
        assert!(parsed_flags.parsed_flag.is_empty());

        // bad input: empty trace
        let text_proto = r#"
parsed_flag {
    package: "com.first"
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    state: DISABLED
    permission: READ_ONLY
}
"#;
        let error = try_from_binary_proto_from_text_proto(text_proto).unwrap_err();
        assert_eq!(format!("{:?}", error), "bad parsed flag: empty trace");

        // bad input: missing namespace in parsed_flag
        let text_proto = r#"
parsed_flag {
    package: "com.first"
    name: "first"
    description: "This is the description of the first flag."
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
"#;
        let error = try_from_binary_proto_from_text_proto(text_proto).unwrap_err();
        assert_eq!(format!("{:?}", error), "bad parsed flag: missing namespace");

        // bad input: parsed_flag not sorted by package
        let text_proto = r#"
parsed_flag {
    package: "bbb"
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
parsed_flag {
    package: "aaa"
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
    state: ENABLED
    permission: READ_WRITE
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
"#;
        let error = try_from_binary_proto_from_text_proto(text_proto).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            "bad parsed flags: not sorted: bbb.first comes before aaa.second"
        );

        // bad input: parsed_flag not sorted by name
        let text_proto = r#"
parsed_flag {
    package: "com.foo"
    name: "bbb"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
parsed_flag {
    package: "com.foo"
    name: "aaa"
    namespace: "second_ns"
    description: "This is the description of the second flag."
    state: ENABLED
    permission: READ_WRITE
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
"#;
        let error = try_from_binary_proto_from_text_proto(text_proto).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            "bad parsed flags: not sorted: com.foo.bbb comes before com.foo.aaa"
        );

        // bad input: duplicate flags
        let text_proto = r#"
parsed_flag {
    package: "com.foo"
    name: "bar"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
parsed_flag {
    package: "com.foo"
    name: "bar"
    namespace: "second_ns"
    description: "This is the description of the second flag."
    state: ENABLED
    permission: READ_WRITE
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
"#;
        let error = try_from_binary_proto_from_text_proto(text_proto).unwrap_err();
        assert_eq!(format!("{:?}", error), "bad parsed flags: duplicate flag com.foo.bar");
    }

    #[test]
    fn test_parsed_flags_merge() {
        let text_proto = r#"
parsed_flag {
    package: "com.first"
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
parsed_flag {
    package: "com.second"
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
    state: ENABLED
    permission: READ_WRITE
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
"#;
        let expected = try_from_binary_proto_from_text_proto(text_proto).unwrap();

        let text_proto = r#"
parsed_flag {
    package: "com.first"
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
"#;
        let first = try_from_binary_proto_from_text_proto(text_proto).unwrap();

        let text_proto = r#"
parsed_flag {
    package: "com.second"
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
    state: ENABLED
    permission: READ_WRITE
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
"#;
        let second = try_from_binary_proto_from_text_proto(text_proto).unwrap();

        // bad cases
        let error = parsed_flags::merge(vec![first.clone(), first.clone()]).unwrap_err();
        assert_eq!(format!("{:?}", error), "bad parsed flags: duplicate flag com.first.first");

        // valid cases
        assert!(parsed_flags::merge(vec![]).unwrap().parsed_flag.is_empty());
        assert_eq!(first, parsed_flags::merge(vec![first.clone()]).unwrap());
        assert_eq!(expected, parsed_flags::merge(vec![first.clone(), second.clone()]).unwrap());
        assert_eq!(expected, parsed_flags::merge(vec![second, first]).unwrap());
    }
}
