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

//! `aconfig_protos` is a crate for the protos defined for aconfig
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
    pub use aconfig_rust_proto::aconfig::flag_metadata::Flag_purpose as ProtoFlagPurpose;
    pub use aconfig_rust_proto::aconfig::Flag_declaration as ProtoFlagDeclaration;
    pub use aconfig_rust_proto::aconfig::Flag_declarations as ProtoFlagDeclarations;
    pub use aconfig_rust_proto::aconfig::Flag_metadata as ProtoFlagMetadata;
    pub use aconfig_rust_proto::aconfig::Flag_permission as ProtoFlagPermission;
    pub use aconfig_rust_proto::aconfig::Flag_state as ProtoFlagState;
    pub use aconfig_rust_proto::aconfig::Flag_value as ProtoFlagValue;
    pub use aconfig_rust_proto::aconfig::Flag_values as ProtoFlagValues;
    pub use aconfig_rust_proto::aconfig::Parsed_flag as ProtoParsedFlag;
    pub use aconfig_rust_proto::aconfig::Parsed_flags as ProtoParsedFlags;
    pub use aconfig_rust_proto::aconfig::Tracepoint as ProtoTracepoint;
}

// ---- When building with cargo ----
#[cfg(feature = "cargo")]
mod auto_generated {
    // include! statements should be avoided (because they import file contents verbatim), but
    // because this is only used during local development, and only if using cargo instead of the
    // Android tool-chain, we allow it
    include!(concat!(env!("OUT_DIR"), "/aconfig_proto/mod.rs"));
    pub use aconfig::flag_metadata::Flag_purpose as ProtoFlagPurpose;
    pub use aconfig::Flag_declaration as ProtoFlagDeclaration;
    pub use aconfig::Flag_declarations as ProtoFlagDeclarations;
    pub use aconfig::Flag_metadata as ProtoFlagMetadata;
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

/// Path to proto file
const ACONFIG_PROTO_PATH: &str = "//build/make/tools/aconfig/aconfig_protos/protos/aconfig.proto";

/// Check if the name identifier is valid
pub fn is_valid_name_ident(s: &str) -> bool {
    // Identifiers must match [a-z][a-z0-9_]*, except consecutive underscores are not allowed
    if s.contains("__") {
        return false;
    }
    let mut chars = s.chars();
    let Some(first) = chars.next() else {
        return false;
    };
    if !first.is_ascii_lowercase() {
        return false;
    }
    chars.all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '_')
}

/// Check if the package identifier is valid
pub fn is_valid_package_ident(s: &str) -> bool {
    if !s.contains('.') {
        return false;
    }
    s.split('.').all(is_valid_name_ident)
}

/// Check if the container identifier is valid
pub fn is_valid_container_ident(s: &str) -> bool {
    s.split('.').all(is_valid_name_ident)
}

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

/// Utility module for flag_declaration proto
pub mod flag_declaration {
    use super::*;
    use anyhow::ensure;

    /// Ensure the proto instance is valid by checking its fields
    pub fn verify_fields(pdf: &ProtoFlagDeclaration) -> Result<()> {
        ensure_required_fields!("flag declaration", pdf, "name", "namespace", "description");

        ensure!(
            is_valid_name_ident(pdf.name()),
            "bad flag declaration: bad name {} expected snake_case string; \
        see {ACONFIG_PROTO_PATH} for details",
            pdf.name()
        );
        ensure!(
            is_valid_name_ident(pdf.namespace()),
            "bad flag declaration: bad namespace {} expected snake_case string; \
        see {ACONFIG_PROTO_PATH} for details",
            pdf.namespace()
        );
        ensure!(!pdf.description().is_empty(), "bad flag declaration: empty description");
        ensure!(pdf.bug.len() == 1, "bad flag declaration: exactly one bug required");

        Ok(())
    }
}

/// Utility module for flag_declarations proto
pub mod flag_declarations {
    use super::*;
    use anyhow::ensure;

    /// Construct a proto instance from a textproto string content
    pub fn try_from_text_proto(s: &str) -> Result<ProtoFlagDeclarations> {
        let pdf: ProtoFlagDeclarations = super::try_from_text_proto(s)?;
        verify_fields(&pdf)?;
        Ok(pdf)
    }

    /// Ensure the proto instance is valid by checking its fields
    pub fn verify_fields(pdf: &ProtoFlagDeclarations) -> Result<()> {
        ensure_required_fields!("flag declarations", pdf, "package");
        // TODO(b/312769710): Make the container field required.
        ensure!(
            is_valid_package_ident(pdf.package()),
            "bad flag declarations: bad package {} expected snake_case strings delimited by dots; \
        see {ACONFIG_PROTO_PATH} for details",
            pdf.package()
        );
        ensure!(
            !pdf.has_container() || is_valid_container_ident(pdf.container()),
            "bad flag declarations: bad container"
        );
        for flag_declaration in pdf.flag.iter() {
            super::flag_declaration::verify_fields(flag_declaration)?;
        }

        Ok(())
    }
}

/// Utility module for flag_value proto
pub mod flag_value {
    use super::*;
    use anyhow::ensure;

    /// Ensure the proto instance is valid by checking its fields
    pub fn verify_fields(fv: &ProtoFlagValue) -> Result<()> {
        ensure_required_fields!("flag value", fv, "package", "name", "state", "permission");

        ensure!(
            is_valid_package_ident(fv.package()),
            "bad flag value: bad package {} expected snake_case strings delimited by dots; \
        see {ACONFIG_PROTO_PATH} for details",
            fv.package()
        );
        ensure!(
            is_valid_name_ident(fv.name()),
            "bad flag value: bad name {} expected snake_case string; \
        see {ACONFIG_PROTO_PATH} for details",
            fv.name()
        );

        Ok(())
    }
}

/// Utility module for flag_values proto
pub mod flag_values {
    use super::*;

    /// Construct a proto instance from a textproto string content
    pub fn try_from_text_proto(s: &str) -> Result<ProtoFlagValues> {
        let pfv: ProtoFlagValues = super::try_from_text_proto(s)?;
        verify_fields(&pfv)?;
        Ok(pfv)
    }

    /// Ensure the proto instance is valid by checking its fields
    pub fn verify_fields(pfv: &ProtoFlagValues) -> Result<()> {
        for flag_value in pfv.flag_value.iter() {
            super::flag_value::verify_fields(flag_value)?;
        }
        Ok(())
    }
}

/// Utility module for flag_permission proto enum
pub mod flag_permission {
    use super::*;
    use anyhow::bail;

    /// Construct a flag permission proto enum from string
    pub fn parse_from_str(permission: &str) -> Result<ProtoFlagPermission> {
        match permission.to_ascii_lowercase().as_str() {
            "read_write" => Ok(ProtoFlagPermission::READ_WRITE),
            "read_only" => Ok(ProtoFlagPermission::READ_ONLY),
            _ => bail!("Permission needs to be read_only or read_write."),
        }
    }

    /// Serialize flag permission proto enum to string
    pub fn to_string(permission: &ProtoFlagPermission) -> &str {
        match permission {
            ProtoFlagPermission::READ_WRITE => "read_write",
            ProtoFlagPermission::READ_ONLY => "read_only",
        }
    }
}

/// Utility module for tracepoint proto
pub mod tracepoint {
    use super::*;
    use anyhow::ensure;

    /// Ensure the proto instance is valid by checking its fields
    pub fn verify_fields(tp: &ProtoTracepoint) -> Result<()> {
        ensure_required_fields!("tracepoint", tp, "source", "state", "permission");

        ensure!(!tp.source().is_empty(), "bad tracepoint: empty source");

        Ok(())
    }
}

/// Utility module for parsed_flag proto
pub mod parsed_flag {
    use super::*;
    use anyhow::ensure;

    /// Ensure the proto instance is valid by checking its fields
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

        ensure!(
            is_valid_package_ident(pf.package()),
            "bad parsed flag: bad package {} expected snake_case strings delimited by dots; \
        see {ACONFIG_PROTO_PATH} for details",
            pf.package()
        );
        ensure!(
            !pf.has_container() || is_valid_container_ident(pf.container()),
            "bad parsed flag: bad container"
        );
        ensure!(
            is_valid_name_ident(pf.name()),
            "bad parsed flag: bad name {} expected snake_case string; \
        see {ACONFIG_PROTO_PATH} for details",
            pf.name()
        );
        ensure!(
            is_valid_name_ident(pf.namespace()),
            "bad parsed flag: bad namespace {} expected snake_case string; \
        see {ACONFIG_PROTO_PATH} for details",
            pf.namespace()
        );
        ensure!(!pf.description().is_empty(), "bad parsed flag: empty description");
        ensure!(!pf.trace.is_empty(), "bad parsed flag: empty trace");
        for tp in pf.trace.iter() {
            super::tracepoint::verify_fields(tp)?;
        }
        ensure!(pf.bug.len() == 1, "bad flag declaration: exactly one bug required");
        if pf.is_fixed_read_only() {
            ensure!(
                pf.permission() == ProtoFlagPermission::READ_ONLY,
                "bad parsed flag: flag is is_fixed_read_only but permission is not READ_ONLY"
            );
            for tp in pf.trace.iter() {
                ensure!(tp.permission() == ProtoFlagPermission::READ_ONLY,
                "bad parsed flag: flag is is_fixed_read_only but a tracepoint's permission is not READ_ONLY"
                );
            }
        }

        Ok(())
    }

    /// Get the file path of the corresponding flag declaration
    pub fn path_to_declaration(pf: &ProtoParsedFlag) -> &str {
        debug_assert!(!pf.trace.is_empty());
        pf.trace[0].source()
    }
}

/// Utility module for parsed_flags proto
pub mod parsed_flags {
    use super::*;
    use anyhow::bail;
    use std::cmp::Ordering;

    /// Construct a proto instance from a binary proto bytes
    pub fn try_from_binary_proto(bytes: &[u8]) -> Result<ProtoParsedFlags> {
        let message: ProtoParsedFlags = protobuf::Message::parse_from_bytes(bytes)?;
        verify_fields(&message)?;
        Ok(message)
    }

    /// Ensure the proto instance is valid by checking its fields
    pub fn verify_fields(pf: &ProtoParsedFlags) -> Result<()> {
        use crate::parsed_flag::path_to_declaration;

        let mut previous: Option<&ProtoParsedFlag> = None;
        for parsed_flag in pf.parsed_flag.iter() {
            if let Some(prev) = previous {
                let a = create_sorting_key(prev);
                let b = create_sorting_key(parsed_flag);
                match a.cmp(&b) {
                    Ordering::Less => {}
                    Ordering::Equal => bail!(
                        "bad parsed flags: duplicate flag {} (defined in {} and {})",
                        a,
                        path_to_declaration(prev),
                        path_to_declaration(parsed_flag)
                    ),
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

    /// Merge multipe parsed_flags proto
    pub fn merge(parsed_flags: Vec<ProtoParsedFlags>, dedup: bool) -> Result<ProtoParsedFlags> {
        let mut merged = ProtoParsedFlags::new();
        for mut pfs in parsed_flags.into_iter() {
            merged.parsed_flag.append(&mut pfs.parsed_flag);
        }
        merged.parsed_flag.sort_by_cached_key(create_sorting_key);
        if dedup {
            // Deduplicate identical protobuf messages.  Messages with the same sorting key but
            // different fields (including the path to the original source file) will not be
            // deduplicated and trigger an error in verify_fields.
            merged.parsed_flag.dedup();
        }
        verify_fields(&merged)?;
        Ok(merged)
    }

    /// Sort parsed flags
    pub fn sort_parsed_flags(pf: &mut ProtoParsedFlags) {
        pf.parsed_flag.sort_by_key(create_sorting_key);
    }

    fn create_sorting_key(pf: &ProtoParsedFlag) -> String {
        pf.fully_qualified_name()
    }
}

/// ParsedFlagExt trait
pub trait ParsedFlagExt {
    /// Return the fully qualified name
    fn fully_qualified_name(&self) -> String;
}

impl ParsedFlagExt for ProtoParsedFlag {
    fn fully_qualified_name(&self) -> String {
        format!("{}.{}", self.package(), self.name())
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
container: "system"
flag {
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    bug: "123"
    is_exported: true
}
flag {
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
    bug: "abc"
    is_fixed_read_only: true
}
"#,
        )
        .unwrap();
        assert_eq!(flag_declarations.package(), "com.foo.bar");
        assert_eq!(flag_declarations.container(), "system");
        let first = flag_declarations.flag.iter().find(|pf| pf.name() == "first").unwrap();
        assert_eq!(first.name(), "first");
        assert_eq!(first.namespace(), "first_ns");
        assert_eq!(first.description(), "This is the description of the first flag.");
        assert_eq!(first.bug, vec!["123"]);
        assert!(!first.is_fixed_read_only());
        assert!(first.is_exported());
        let second = flag_declarations.flag.iter().find(|pf| pf.name() == "second").unwrap();
        assert_eq!(second.name(), "second");
        assert_eq!(second.namespace(), "second_ns");
        assert_eq!(second.description(), "This is the description of the second flag.");
        assert_eq!(second.bug, vec!["abc"]);
        assert!(second.is_fixed_read_only());
        assert!(!second.is_exported());

        // valid input: missing container in flag declarations is supported
        let flag_declarations = flag_declarations::try_from_text_proto(
            r#"
package: "com.foo.bar"
flag {
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    bug: "123"
}
"#,
        )
        .unwrap();
        assert_eq!(flag_declarations.container(), "");
        assert!(!flag_declarations.has_container());

        // bad input: missing package in flag declarations
        let error = flag_declarations::try_from_text_proto(
            r#"
container: "system"
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
container: "system"
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
container: "system"
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
container: "system"
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

        // bad input: no bug entries in flag declaration
        let error = flag_declarations::try_from_text_proto(
            r#"
package: "com.foo.bar"
container: "system"
flag {
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
}
"#,
        )
        .unwrap_err();
        assert!(format!("{:?}", error).contains("bad flag declaration: exactly one bug required"));

        // bad input: multiple bug entries in flag declaration
        let error = flag_declarations::try_from_text_proto(
            r#"
package: "com.foo.bar"
container: "system"
flag {
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    bug: "123"
    bug: "abc"
}
"#,
        )
        .unwrap_err();
        assert!(format!("{:?}", error).contains("bad flag declaration: exactly one bug required"));

        // bad input: invalid container name in flag declaration
        let error = flag_declarations::try_from_text_proto(
            r#"
package: "com.foo.bar"
container: "__bad_bad_container.com"
flag {
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    bug: "123"
    bug: "abc"
}
"#,
        )
        .unwrap_err();
        assert!(format!("{:?}", error).contains("bad flag declarations: bad container"));

        // TODO(b/312769710): Verify error when container is missing.
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
    bug: "SOME_BUG"
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    container: "system"
}
parsed_flag {
    package: "com.second"
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
    bug: "SOME_BUG"
    state: ENABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    trace {
        source: "flags.values"
        state: ENABLED
        permission: READ_ONLY
    }
    is_fixed_read_only: true
    container: "system"
}
"#;
        let parsed_flags = try_from_binary_proto_from_text_proto(text_proto).unwrap();
        assert_eq!(parsed_flags.parsed_flag.len(), 2);
        let second = parsed_flags.parsed_flag.iter().find(|fv| fv.name() == "second").unwrap();
        assert_eq!(second.package(), "com.second");
        assert_eq!(second.name(), "second");
        assert_eq!(second.namespace(), "second_ns");
        assert_eq!(second.description(), "This is the description of the second flag.");
        assert_eq!(second.bug, vec!["SOME_BUG"]);
        assert_eq!(second.state(), ProtoFlagState::ENABLED);
        assert_eq!(second.permission(), ProtoFlagPermission::READ_ONLY);
        assert_eq!(2, second.trace.len());
        assert_eq!(second.trace[0].source(), "flags.declarations");
        assert_eq!(second.trace[0].state(), ProtoFlagState::DISABLED);
        assert_eq!(second.trace[0].permission(), ProtoFlagPermission::READ_ONLY);
        assert_eq!(second.trace[1].source(), "flags.values");
        assert_eq!(second.trace[1].state(), ProtoFlagState::ENABLED);
        assert_eq!(second.trace[1].permission(), ProtoFlagPermission::READ_ONLY);
        assert!(second.is_fixed_read_only());

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
    container: "system"
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
    container: "system"
}
"#;
        let error = try_from_binary_proto_from_text_proto(text_proto).unwrap_err();
        assert_eq!(format!("{:?}", error), "bad parsed flag: missing namespace");

        // bad input: parsed_flag not sorted by package
        let text_proto = r#"
parsed_flag {
    package: "bbb.bbb"
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    bug: ""
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    container: "system"
}
parsed_flag {
    package: "aaa.aaa"
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
    bug: ""
    state: ENABLED
    permission: READ_WRITE
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    container: "system"
}
"#;
        let error = try_from_binary_proto_from_text_proto(text_proto).unwrap_err();
        assert_eq!(
            format!("{:?}", error),
            "bad parsed flags: not sorted: bbb.bbb.first comes before aaa.aaa.second"
        );

        // bad input: parsed_flag not sorted by name
        let text_proto = r#"
parsed_flag {
    package: "com.foo"
    name: "bbb"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    bug: ""
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    container: "system"
}
parsed_flag {
    package: "com.foo"
    name: "aaa"
    namespace: "second_ns"
    description: "This is the description of the second flag."
    bug: ""
    state: ENABLED
    permission: READ_WRITE
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    container: "system"
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
    bug: ""
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    container: "system"
}
parsed_flag {
    package: "com.foo"
    name: "bar"
    namespace: "second_ns"
    description: "This is the description of the second flag."
    bug: ""
    state: ENABLED
    permission: READ_WRITE
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    container: "system"
}
"#;
        let error = try_from_binary_proto_from_text_proto(text_proto).unwrap_err();
        assert_eq!(format!("{:?}", error), "bad parsed flags: duplicate flag com.foo.bar (defined in flags.declarations and flags.declarations)");
    }

    #[test]
    fn test_parsed_flag_path_to_declaration() {
        let text_proto = r#"
parsed_flag {
    package: "com.foo"
    name: "bar"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    bug: "b/12345678"
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    trace {
        source: "flags.values"
        state: ENABLED
        permission: READ_ONLY
    }
    container: "system"
}
"#;
        let parsed_flags = try_from_binary_proto_from_text_proto(text_proto).unwrap();
        let parsed_flag = &parsed_flags.parsed_flag[0];
        assert_eq!(crate::parsed_flag::path_to_declaration(parsed_flag), "flags.declarations");
    }

    #[test]
    fn test_parsed_flags_merge() {
        let text_proto = r#"
parsed_flag {
    package: "com.first"
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    bug: "a"
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    container: "system"
}
parsed_flag {
    package: "com.second"
    name: "second"
    namespace: "second_ns"
    description: "This is the description of the second flag."
    bug: "b"
    state: ENABLED
    permission: READ_WRITE
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    container: "system"
}
"#;
        let expected = try_from_binary_proto_from_text_proto(text_proto).unwrap();

        let text_proto = r#"
parsed_flag {
    package: "com.first"
    name: "first"
    namespace: "first_ns"
    description: "This is the description of the first flag."
    bug: "a"
    state: DISABLED
    permission: READ_ONLY
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    container: "system"
}
"#;
        let first = try_from_binary_proto_from_text_proto(text_proto).unwrap();

        let text_proto = r#"
parsed_flag {
    package: "com.second"
    name: "second"
    namespace: "second_ns"
    bug: "b"
    description: "This is the description of the second flag."
    state: ENABLED
    permission: READ_WRITE
    trace {
        source: "flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
    container: "system"
}
"#;
        let second = try_from_binary_proto_from_text_proto(text_proto).unwrap();

        let text_proto = r#"
parsed_flag {
    package: "com.second"
    name: "second"
    namespace: "second_ns"
    bug: "b"
    description: "This is the description of the second flag."
    state: ENABLED
    permission: READ_WRITE
    trace {
        source: "duplicate/flags.declarations"
        state: DISABLED
        permission: READ_ONLY
    }
}
"#;
        let second_duplicate = try_from_binary_proto_from_text_proto(text_proto).unwrap();

        // bad cases

        // two of the same flag with dedup disabled
        let error = parsed_flags::merge(vec![first.clone(), first.clone()], false).unwrap_err();
        assert_eq!(format!("{:?}", error), "bad parsed flags: duplicate flag com.first.first (defined in flags.declarations and flags.declarations)");

        // two conflicting flags with dedup disabled
        let error =
            parsed_flags::merge(vec![second.clone(), second_duplicate.clone()], false).unwrap_err();
        assert_eq!(format!("{:?}", error), "bad parsed flags: duplicate flag com.second.second (defined in flags.declarations and duplicate/flags.declarations)");

        // two conflicting flags with dedup enabled
        let error =
            parsed_flags::merge(vec![second.clone(), second_duplicate.clone()], true).unwrap_err();
        assert_eq!(format!("{:?}", error), "bad parsed flags: duplicate flag com.second.second (defined in flags.declarations and duplicate/flags.declarations)");

        // valid cases
        assert!(parsed_flags::merge(vec![], false).unwrap().parsed_flag.is_empty());
        assert!(parsed_flags::merge(vec![], true).unwrap().parsed_flag.is_empty());
        assert_eq!(first, parsed_flags::merge(vec![first.clone()], false).unwrap());
        assert_eq!(first, parsed_flags::merge(vec![first.clone()], true).unwrap());
        assert_eq!(
            expected,
            parsed_flags::merge(vec![first.clone(), second.clone()], false).unwrap()
        );
        assert_eq!(
            expected,
            parsed_flags::merge(vec![first.clone(), second.clone()], true).unwrap()
        );
        assert_eq!(
            expected,
            parsed_flags::merge(vec![second.clone(), first.clone()], false).unwrap()
        );
        assert_eq!(
            expected,
            parsed_flags::merge(vec![second.clone(), first.clone()], true).unwrap()
        );

        // two identical flags with dedup enabled
        assert_eq!(first, parsed_flags::merge(vec![first.clone(), first.clone()], true).unwrap());
    }
}
