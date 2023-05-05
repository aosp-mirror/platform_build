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

use crate::protos::{
    ProtoAndroidConfig, ProtoFlag, ProtoOverride, ProtoOverrideConfig, ProtoPermission, ProtoValue,
};

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize, Clone, Copy)]
pub enum Permission {
    ReadOnly,
    ReadWrite,
}

impl TryFrom<EnumOrUnknown<ProtoPermission>> for Permission {
    type Error = Error;

    fn try_from(proto: EnumOrUnknown<ProtoPermission>) -> Result<Self, Self::Error> {
        match ProtoPermission::from_i32(proto.value()) {
            Some(ProtoPermission::READ_ONLY) => Ok(Permission::ReadOnly),
            Some(ProtoPermission::READ_WRITE) => Ok(Permission::ReadWrite),
            None => Err(anyhow!("unknown permission enum value {}", proto.value())),
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct Value {
    value: bool,
    permission: Permission,
    since: Option<u32>,
}

#[allow(dead_code)] // only used in unit tests
impl Value {
    pub fn new(value: bool, permission: Permission, since: u32) -> Value {
        Value { value, permission, since: Some(since) }
    }

    pub fn default(value: bool, permission: Permission) -> Value {
        Value { value, permission, since: None }
    }
}

impl TryFrom<ProtoValue> for Value {
    type Error = Error;

    fn try_from(proto: ProtoValue) -> Result<Self, Self::Error> {
        let Some(value) = proto.value else {
            return Err(anyhow!("missing 'value' field"));
        };
        let Some(proto_permission) = proto.permission else {
            return Err(anyhow!("missing 'permission' field"));
        };
        let permission = proto_permission.try_into()?;
        Ok(Value { value, permission, since: proto.since })
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct Flag {
    pub id: String,
    pub description: String,

    // ordered by Value.since; guaranteed to contain at least one item (the default value, with
    // since == None)
    pub values: Vec<Value>,
}

impl Flag {
    #[allow(dead_code)] // only used in unit tests
    pub fn try_from_text_proto(text_proto: &str) -> Result<Flag> {
        let proto: ProtoFlag = crate::protos::try_from_text_proto(text_proto)
            .with_context(|| text_proto.to_owned())?;
        proto.try_into()
    }

    pub fn try_from_text_proto_list(text_proto: &str) -> Result<Vec<Flag>> {
        let proto: ProtoAndroidConfig = crate::protos::try_from_text_proto(text_proto)
            .with_context(|| text_proto.to_owned())?;
        proto.flag.into_iter().map(|proto_flag| proto_flag.try_into()).collect()
    }

    pub fn resolve(&self, build_id: u32) -> (bool, Permission) {
        let mut value = self.values[0].value;
        let mut permission = self.values[0].permission;
        for candidate in self.values.iter().skip(1) {
            let since = candidate.since.expect("invariant: non-defaults values have Some(since)");
            if since <= build_id {
                value = candidate.value;
                permission = candidate.permission;
            }
        }
        (value, permission)
    }
}

impl TryFrom<ProtoFlag> for Flag {
    type Error = Error;

    fn try_from(proto: ProtoFlag) -> Result<Self, Self::Error> {
        let Some(id) = proto.id else {
            return Err(anyhow!("missing 'id' field"));
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
                    None => format!("flag {}: multiple default values", id),
                    Some(x) => format!("flag {}: multiple values for since={}", id, x),
                };
                return Err(anyhow!(msg));
            }
            values.push(v);
        }
        values.sort_by_key(|v| v.since);

        Ok(Flag { id, description, values })
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct Override {
    pub id: String,
    pub value: bool,
    pub permission: Permission,
}

impl Override {
    #[allow(dead_code)] // only used in unit tests
    pub fn try_from_text_proto(text_proto: &str) -> Result<Override> {
        let proto: ProtoOverride = crate::protos::try_from_text_proto(text_proto)?;
        proto.try_into()
    }

    pub fn try_from_text_proto_list(text_proto: &str) -> Result<Vec<Override>> {
        let proto: ProtoOverrideConfig = crate::protos::try_from_text_proto(text_proto)?;
        proto.override_.into_iter().map(|proto_flag| proto_flag.try_into()).collect()
    }
}

impl TryFrom<ProtoOverride> for Override {
    type Error = Error;

    fn try_from(proto: ProtoOverride) -> Result<Self, Self::Error> {
        let Some(id) = proto.id else {
            return Err(anyhow!("missing 'id' field"));
        };
        let Some(value) = proto.value else {
            return Err(anyhow!("missing 'value' field"));
        };
        let Some(proto_permission) = proto.permission else {
            return Err(anyhow!("missing 'permission' field"));
        };
        let permission = proto_permission.try_into()?;
        Ok(Override { id, value, permission })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_flag_try_from_text_proto() {
        let expected = Flag {
            id: "1234".to_owned(),
            description: "Description of the flag".to_owned(),
            values: vec![
                Value::default(false, Permission::ReadOnly),
                Value::new(true, Permission::ReadWrite, 8),
            ],
        };

        let s = r#"
        id: "1234"
        description: "Description of the flag"
        value {
            value: false
            permission: READ_ONLY
        }
        value {
            value: true
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
        id: "a"
        description: "Description of the flag"
        "#;
        let error = Flag::try_from_text_proto(s).unwrap_err();
        assert_eq!(format!("{:?}", error), "missing 'value' field");

        let s = r#"
        description: "Description of the flag"
        value {
            value: true
            permission: READ_ONLY
        }
        "#;
        let error = Flag::try_from_text_proto(s).unwrap_err();
        assert!(format!("{:?}", error).contains("Message not initialized"));

        let s = r#"
        id: "a"
        description: "Description of the flag"
        value {
            value: true
            permission: READ_ONLY
        }
        value {
            value: true
            permission: READ_ONLY
        }
        "#;
        let error = Flag::try_from_text_proto(s).unwrap_err();
        assert_eq!(format!("{:?}", error), "flag a: multiple default values");
    }

    #[test]
    fn test_flag_try_from_text_proto_list() {
        let expected = vec![
            Flag {
                id: "a".to_owned(),
                description: "A".to_owned(),
                values: vec![Value::default(true, Permission::ReadOnly)],
            },
            Flag {
                id: "b".to_owned(),
                description: "B".to_owned(),
                values: vec![Value::default(false, Permission::ReadWrite)],
            },
        ];

        let s = r#"
        flag {
            id: "a"
            description: "A"
            value {
                value: true
                permission: READ_ONLY
            }
        }
        flag {
            id: "b"
            description: "B"
            value {
                value: false
                permission: READ_WRITE
            }
        }
        "#;
        let actual = Flag::try_from_text_proto_list(s).unwrap();

        assert_eq!(expected, actual);
    }

    #[test]
    fn test_override_try_from_text_proto_list() {
        let expected =
            Override { id: "1234".to_owned(), value: true, permission: Permission::ReadOnly };

        let s = r#"
        id: "1234"
        value: true
        permission: READ_ONLY
        "#;
        let actual = Override::try_from_text_proto(s).unwrap();

        assert_eq!(expected, actual);
    }

    #[test]
    fn test_flag_resolve() {
        let flag = Flag {
            id: "a".to_owned(),
            description: "A".to_owned(),
            values: vec![
                Value::default(false, Permission::ReadOnly),
                Value::new(false, Permission::ReadWrite, 10),
                Value::new(true, Permission::ReadOnly, 20),
                Value::new(true, Permission::ReadWrite, 30),
            ],
        };
        assert_eq!((false, Permission::ReadOnly), flag.resolve(0));
        assert_eq!((false, Permission::ReadOnly), flag.resolve(9));
        assert_eq!((false, Permission::ReadWrite), flag.resolve(10));
        assert_eq!((false, Permission::ReadWrite), flag.resolve(11));
        assert_eq!((false, Permission::ReadWrite), flag.resolve(19));
        assert_eq!((true, Permission::ReadOnly), flag.resolve(20));
        assert_eq!((true, Permission::ReadOnly), flag.resolve(21));
        assert_eq!((true, Permission::ReadOnly), flag.resolve(29));
        assert_eq!((true, Permission::ReadWrite), flag.resolve(30));
        assert_eq!((true, Permission::ReadWrite), flag.resolve(10_000));
    }
}
