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

use anyhow::{anyhow, bail, Context, Error, Result};
use protobuf::{Enum, EnumOrUnknown};
use serde::{Deserialize, Serialize};

use crate::cache::{Cache, Item, Tracepoint};
use crate::protos::{
    ProtoFlagDeclaration, ProtoFlagDeclarations, ProtoFlagPermission, ProtoFlagState,
    ProtoFlagValue, ProtoFlagValues, ProtoParsedFlag, ProtoParsedFlags, ProtoTracepoint,
};

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize, Clone, Copy)]
pub enum FlagState {
    Enabled,
    Disabled,
}

impl TryFrom<EnumOrUnknown<ProtoFlagState>> for FlagState {
    type Error = Error;

    fn try_from(proto: EnumOrUnknown<ProtoFlagState>) -> Result<Self, Self::Error> {
        match ProtoFlagState::from_i32(proto.value()) {
            Some(ProtoFlagState::ENABLED) => Ok(FlagState::Enabled),
            Some(ProtoFlagState::DISABLED) => Ok(FlagState::Disabled),
            None => Err(anyhow!("unknown flag state enum value {}", proto.value())),
        }
    }
}

impl From<FlagState> for ProtoFlagState {
    fn from(state: FlagState) -> Self {
        match state {
            FlagState::Enabled => ProtoFlagState::ENABLED,
            FlagState::Disabled => ProtoFlagState::DISABLED,
        }
    }
}

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize, Clone, Copy)]
pub enum Permission {
    ReadOnly,
    ReadWrite,
}

impl TryFrom<EnumOrUnknown<ProtoFlagPermission>> for Permission {
    type Error = Error;

    fn try_from(proto: EnumOrUnknown<ProtoFlagPermission>) -> Result<Self, Self::Error> {
        match ProtoFlagPermission::from_i32(proto.value()) {
            Some(ProtoFlagPermission::READ_ONLY) => Ok(Permission::ReadOnly),
            Some(ProtoFlagPermission::READ_WRITE) => Ok(Permission::ReadWrite),
            None => Err(anyhow!("unknown permission enum value {}", proto.value())),
        }
    }
}

impl From<Permission> for ProtoFlagPermission {
    fn from(permission: Permission) -> Self {
        match permission {
            Permission::ReadOnly => ProtoFlagPermission::READ_ONLY,
            Permission::ReadWrite => ProtoFlagPermission::READ_WRITE,
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct FlagDeclaration {
    pub name: String,
    pub description: String,
}

impl FlagDeclaration {
    #[allow(dead_code)] // only used in unit tests
    pub fn try_from_text_proto(text_proto: &str) -> Result<FlagDeclaration> {
        let proto: ProtoFlagDeclaration = crate::protos::try_from_text_proto(text_proto)
            .with_context(|| text_proto.to_owned())?;
        proto.try_into()
    }
}

impl TryFrom<ProtoFlagDeclaration> for FlagDeclaration {
    type Error = Error;

    fn try_from(proto: ProtoFlagDeclaration) -> Result<Self, Self::Error> {
        let Some(name) = proto.name else {
            bail!("missing 'name' field");
        };
        let Some(description) = proto.description else {
            bail!("missing 'description' field");
        };
        Ok(FlagDeclaration { name, description })
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct FlagDeclarations {
    pub namespace: String,
    pub flags: Vec<FlagDeclaration>,
}

impl FlagDeclarations {
    pub fn try_from_text_proto(text_proto: &str) -> Result<FlagDeclarations> {
        let proto: ProtoFlagDeclarations = crate::protos::try_from_text_proto(text_proto)
            .with_context(|| text_proto.to_owned())?;
        let Some(namespace) = proto.namespace else {
            bail!("missing 'namespace' field");
        };
        let mut flags = vec![];
        for proto_flag in proto.flag.into_iter() {
            flags.push(proto_flag.try_into()?);
        }
        Ok(FlagDeclarations { namespace, flags })
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct FlagValue {
    pub namespace: String,
    pub name: String,
    pub state: FlagState,
    pub permission: Permission,
}

impl FlagValue {
    #[allow(dead_code)] // only used in unit tests
    pub fn try_from_text_proto(text_proto: &str) -> Result<FlagValue> {
        let proto: ProtoFlagValue = crate::protos::try_from_text_proto(text_proto)?;
        proto.try_into()
    }

    pub fn try_from_text_proto_list(text_proto: &str) -> Result<Vec<FlagValue>> {
        let proto: ProtoFlagValues = crate::protos::try_from_text_proto(text_proto)?;
        proto.flag_value.into_iter().map(|proto_flag| proto_flag.try_into()).collect()
    }
}

impl TryFrom<ProtoFlagValue> for FlagValue {
    type Error = Error;

    fn try_from(proto: ProtoFlagValue) -> Result<Self, Self::Error> {
        let Some(namespace) = proto.namespace else {
            bail!("missing 'namespace' field");
        };
        let Some(name) = proto.name else {
            bail!("missing 'name' field");
        };
        let Some(proto_state) = proto.state else {
            bail!("missing 'state' field");
        };
        let state = proto_state.try_into()?;
        let Some(proto_permission) = proto.permission else {
            bail!("missing 'permission' field");
        };
        let permission = proto_permission.try_into()?;
        Ok(FlagValue { namespace, name, state, permission })
    }
}

impl From<Cache> for ProtoParsedFlags {
    fn from(cache: Cache) -> Self {
        let mut proto = ProtoParsedFlags::new();
        for item in cache.into_iter() {
            proto.parsed_flag.push(item.into());
        }
        proto
    }
}

impl From<Item> for ProtoParsedFlag {
    fn from(item: Item) -> Self {
        let mut proto = crate::protos::ProtoParsedFlag::new();
        proto.set_namespace(item.namespace.to_owned());
        proto.set_name(item.name.clone());
        proto.set_description(item.description.clone());
        proto.set_state(item.state.into());
        proto.set_permission(item.permission.into());
        for trace in item.trace.into_iter() {
            proto.trace.push(trace.into());
        }
        proto
    }
}

impl From<Tracepoint> for ProtoTracepoint {
    fn from(tracepoint: Tracepoint) -> Self {
        let mut proto = ProtoTracepoint::new();
        proto.set_source(format!("{}", tracepoint.source));
        proto.set_state(tracepoint.state.into());
        proto.set_permission(tracepoint.permission.into());
        proto
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_flag_try_from_text_proto() {
        let expected = FlagDeclaration {
            name: "1234".to_owned(),
            description: "Description of the flag".to_owned(),
        };

        let s = r#"
        name: "1234"
        description: "Description of the flag"
        "#;
        let actual = FlagDeclaration::try_from_text_proto(s).unwrap();

        assert_eq!(expected, actual);
    }

    #[test]
    fn test_flag_try_from_text_proto_bad_input() {
        let s = r#"
        name: "a"
        "#;
        let error = FlagDeclaration::try_from_text_proto(s).unwrap_err();
        assert!(format!("{:?}", error).contains("Message not initialized"));

        let s = r#"
        description: "Description of the flag"
        "#;
        let error = FlagDeclaration::try_from_text_proto(s).unwrap_err();
        assert!(format!("{:?}", error).contains("Message not initialized"));
    }

    #[test]
    fn test_namespace_try_from_text_proto() {
        let expected = FlagDeclarations {
            namespace: "ns".to_owned(),
            flags: vec![
                FlagDeclaration { name: "a".to_owned(), description: "A".to_owned() },
                FlagDeclaration { name: "b".to_owned(), description: "B".to_owned() },
            ],
        };

        let s = r#"
        namespace: "ns"
        flag {
            name: "a"
            description: "A"
        }
        flag {
            name: "b"
            description: "B"
        }
        "#;
        let actual = FlagDeclarations::try_from_text_proto(s).unwrap();

        assert_eq!(expected, actual);
    }

    #[test]
    fn test_flag_declaration_try_from_text_proto_list() {
        let expected = FlagValue {
            namespace: "ns".to_owned(),
            name: "1234".to_owned(),
            state: FlagState::Enabled,
            permission: Permission::ReadOnly,
        };

        let s = r#"
        namespace: "ns"
        name: "1234"
        state: ENABLED
        permission: READ_ONLY
        "#;
        let actual = FlagValue::try_from_text_proto(s).unwrap();

        assert_eq!(expected, actual);
    }
}
