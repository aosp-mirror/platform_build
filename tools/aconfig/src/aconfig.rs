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

use anyhow::{anyhow, Context, Error, Result};
use protobuf::{Enum, EnumOrUnknown};
use serde::{Deserialize, Serialize};

use crate::cache::{Cache, Item, Tracepoint};
use crate::protos::{
    ProtoFlagDefinition, ProtoFlagDefinitionValue, ProtoFlagOverride, ProtoFlagOverrides,
    ProtoFlagPermission, ProtoFlagState, ProtoNamespace, ProtoParsedFlag, ProtoParsedFlags,
    ProtoTracepoint,
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
pub struct Value {
    state: FlagState,
    permission: Permission,
    since: Option<u32>,
}

#[allow(dead_code)] // only used in unit tests
impl Value {
    pub fn new(state: FlagState, permission: Permission, since: u32) -> Value {
        Value { state, permission, since: Some(since) }
    }

    pub fn default(state: FlagState, permission: Permission) -> Value {
        Value { state, permission, since: None }
    }
}

impl TryFrom<ProtoFlagDefinitionValue> for Value {
    type Error = Error;

    fn try_from(proto: ProtoFlagDefinitionValue) -> Result<Self, Self::Error> {
        let Some(proto_state) = proto.state else {
            return Err(anyhow!("missing 'state' field"));
        };
        let state = proto_state.try_into()?;
        let Some(proto_permission) = proto.permission else {
            return Err(anyhow!("missing 'permission' field"));
        };
        let permission = proto_permission.try_into()?;
        Ok(Value { state, permission, since: proto.since })
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct Flag {
    pub name: String,
    pub description: String,

    // ordered by Value.since; guaranteed to contain at least one item (the default value, with
    // since == None)
    pub values: Vec<Value>,
}

impl Flag {
    #[allow(dead_code)] // only used in unit tests
    pub fn try_from_text_proto(text_proto: &str) -> Result<Flag> {
        let proto: ProtoFlagDefinition = crate::protos::try_from_text_proto(text_proto)
            .with_context(|| text_proto.to_owned())?;
        proto.try_into()
    }

    pub fn resolve(&self, build_id: u32) -> (FlagState, Permission) {
        let mut state = self.values[0].state;
        let mut permission = self.values[0].permission;
        for candidate in self.values.iter().skip(1) {
            let since = candidate.since.expect("invariant: non-defaults values have Some(since)");
            if since <= build_id {
                state = candidate.state;
                permission = candidate.permission;
            }
        }
        (state, permission)
    }
}

impl TryFrom<ProtoFlagDefinition> for Flag {
    type Error = Error;

    fn try_from(proto: ProtoFlagDefinition) -> Result<Self, Self::Error> {
        let Some(name) = proto.name else {
            return Err(anyhow!("missing 'name' field"));
        };
        let Some(description) = proto.description else {
            return Err(anyhow!("missing 'description' field"));
        };
        if proto.value.is_empty() {
            return Err(anyhow!("missing 'value' field"));
        }

        let mut values: Vec<Value> = vec![];
        for proto_value in proto.value.into_iter() {
            let v: Value = proto_value.try_into()?;
            if values.iter().any(|w| v.since == w.since) {
                let msg = match v.since {
                    None => format!("flag {}: multiple default values", name),
                    Some(x) => format!("flag {}: multiple values for since={}", name, x),
                };
                return Err(anyhow!(msg));
            }
            values.push(v);
        }
        values.sort_by_key(|v| v.since);

        Ok(Flag { name, description, values })
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct Namespace {
    pub namespace: String,
    pub flags: Vec<Flag>,
}

impl Namespace {
    pub fn try_from_text_proto(text_proto: &str) -> Result<Namespace> {
        let proto: ProtoNamespace = crate::protos::try_from_text_proto(text_proto)
            .with_context(|| text_proto.to_owned())?;
        let Some(namespace) = proto.namespace else {
            return Err(anyhow!("missing 'namespace' field"));
        };
        let mut flags = vec![];
        for proto_flag in proto.flag.into_iter() {
            flags.push(proto_flag.try_into()?);
        }
        Ok(Namespace { namespace, flags })
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct Override {
    pub namespace: String,
    pub name: String,
    pub state: FlagState,
    pub permission: Permission,
}

impl Override {
    #[allow(dead_code)] // only used in unit tests
    pub fn try_from_text_proto(text_proto: &str) -> Result<Override> {
        let proto: ProtoFlagOverride = crate::protos::try_from_text_proto(text_proto)?;
        proto.try_into()
    }

    pub fn try_from_text_proto_list(text_proto: &str) -> Result<Vec<Override>> {
        let proto: ProtoFlagOverrides = crate::protos::try_from_text_proto(text_proto)?;
        proto.flag_override.into_iter().map(|proto_flag| proto_flag.try_into()).collect()
    }
}

impl TryFrom<ProtoFlagOverride> for Override {
    type Error = Error;

    fn try_from(proto: ProtoFlagOverride) -> Result<Self, Self::Error> {
        let Some(namespace) = proto.namespace else {
            return Err(anyhow!("missing 'namespace' field"));
        };
        let Some(name) = proto.name else {
            return Err(anyhow!("missing 'name' field"));
        };
        let Some(proto_state) = proto.state else {
            return Err(anyhow!("missing 'state' field"));
        };
        let state = proto_state.try_into()?;
        let Some(proto_permission) = proto.permission else {
            return Err(anyhow!("missing 'permission' field"));
        };
        let permission = proto_permission.try_into()?;
        Ok(Override { namespace, name, state, permission })
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
        let expected = Flag {
            name: "1234".to_owned(),
            description: "Description of the flag".to_owned(),
            values: vec![
                Value::default(FlagState::Disabled, Permission::ReadOnly),
                Value::new(FlagState::Enabled, Permission::ReadWrite, 8),
            ],
        };

        let s = r#"
        name: "1234"
        description: "Description of the flag"
        value {
            state: DISABLED
            permission: READ_ONLY
        }
        value {
            state: ENABLED
            permission: READ_WRITE
            since: 8
        }
        "#;
        let actual = Flag::try_from_text_proto(s).unwrap();

        assert_eq!(expected, actual);
    }

    #[test]
    fn test_flag_try_from_text_proto_bad_input() {
        let s = r#"
        name: "a"
        description: "Description of the flag"
        "#;
        let error = Flag::try_from_text_proto(s).unwrap_err();
        assert_eq!(format!("{:?}", error), "missing 'value' field");

        let s = r#"
        description: "Description of the flag"
        value {
            state: ENABLED
            permission: READ_ONLY
        }
        "#;
        let error = Flag::try_from_text_proto(s).unwrap_err();
        assert!(format!("{:?}", error).contains("Message not initialized"));

        let s = r#"
        name: "a"
        description: "Description of the flag"
        value {
            state: ENABLED
            permission: READ_ONLY
        }
        value {
            state: ENABLED
            permission: READ_ONLY
        }
        "#;
        let error = Flag::try_from_text_proto(s).unwrap_err();
        assert_eq!(format!("{:?}", error), "flag a: multiple default values");
    }

    #[test]
    fn test_namespace_try_from_text_proto() {
        let expected = Namespace {
            namespace: "ns".to_owned(),
            flags: vec![
                Flag {
                    name: "a".to_owned(),
                    description: "A".to_owned(),
                    values: vec![Value::default(FlagState::Enabled, Permission::ReadOnly)],
                },
                Flag {
                    name: "b".to_owned(),
                    description: "B".to_owned(),
                    values: vec![Value::default(FlagState::Disabled, Permission::ReadWrite)],
                },
            ],
        };

        let s = r#"
        namespace: "ns"
        flag {
            name: "a"
            description: "A"
            value {
                state: ENABLED
                permission: READ_ONLY
            }
        }
        flag {
            name: "b"
            description: "B"
            value {
                state: DISABLED
                permission: READ_WRITE
            }
        }
        "#;
        let actual = Namespace::try_from_text_proto(s).unwrap();

        assert_eq!(expected, actual);
    }

    #[test]
    fn test_override_try_from_text_proto_list() {
        let expected = Override {
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
        let actual = Override::try_from_text_proto(s).unwrap();

        assert_eq!(expected, actual);
    }

    #[test]
    fn test_flag_resolve() {
        let flag = Flag {
            name: "a".to_owned(),
            description: "A".to_owned(),
            values: vec![
                Value::default(FlagState::Disabled, Permission::ReadOnly),
                Value::new(FlagState::Disabled, Permission::ReadWrite, 10),
                Value::new(FlagState::Enabled, Permission::ReadOnly, 20),
                Value::new(FlagState::Enabled, Permission::ReadWrite, 30),
            ],
        };
        assert_eq!((FlagState::Disabled, Permission::ReadOnly), flag.resolve(0));
        assert_eq!((FlagState::Disabled, Permission::ReadOnly), flag.resolve(9));
        assert_eq!((FlagState::Disabled, Permission::ReadWrite), flag.resolve(10));
        assert_eq!((FlagState::Disabled, Permission::ReadWrite), flag.resolve(11));
        assert_eq!((FlagState::Disabled, Permission::ReadWrite), flag.resolve(19));
        assert_eq!((FlagState::Enabled, Permission::ReadOnly), flag.resolve(20));
        assert_eq!((FlagState::Enabled, Permission::ReadOnly), flag.resolve(21));
        assert_eq!((FlagState::Enabled, Permission::ReadOnly), flag.resolve(29));
        assert_eq!((FlagState::Enabled, Permission::ReadWrite), flag.resolve(30));
        assert_eq!((FlagState::Enabled, Permission::ReadWrite), flag.resolve(10_000));
    }
}
