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

use crate::protos::{
    ProtoAndroidConfig, ProtoFlag, ProtoOverride, ProtoOverrideConfig, ProtoValue,
};

#[derive(Debug, PartialEq, Eq)]
pub struct Value {
    value: bool,
    since: Option<u32>,
}

#[allow(dead_code)] // only used in unit tests
impl Value {
    pub fn new(value: bool, since: u32) -> Value {
        Value { value, since: Some(since) }
    }

    pub fn default(value: bool) -> Value {
        Value { value, since: None }
    }
}

impl TryFrom<ProtoValue> for Value {
    type Error = Error;

    fn try_from(proto: ProtoValue) -> Result<Self, Self::Error> {
        let Some(value) = proto.value else {
            return Err(anyhow!("missing 'value' field"));
        };
        Ok(Value { value, since: proto.since })
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

    pub fn resolve_value(&self, build_id: u32) -> bool {
        let mut value = self.values[0].value;
        for candidate in self.values.iter().skip(1) {
            let since = candidate.since.expect("invariant: non-defaults values have Some(since)");
            if since <= build_id {
                value = candidate.value;
            }
        }
        value
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
        Ok(Override { id, value })
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
            values: vec![Value::default(false), Value::new(true, 8)],
        };

        let s = r#"
        id: "1234"
        description: "Description of the flag"
        value {
            value: false
        }
        value {
            value: true
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
        }
        "#;
        let error = Flag::try_from_text_proto(s).unwrap_err();
        assert!(format!("{:?}", error).contains("Message not initialized"));

        let s = r#"
        id: "a"
        description: "Description of the flag"
        value {
            value: true
        }
        value {
            value: true
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
                values: vec![Value::default(true)],
            },
            Flag {
                id: "b".to_owned(),
                description: "B".to_owned(),
                values: vec![Value::default(false)],
            },
        ];

        let s = r#"
        flag {
            id: "a"
            description: "A"
            value {
                value: true
            }
        }
        flag {
            id: "b"
            description: "B"
            value {
                value: false
            }
        }
        "#;
        let actual = Flag::try_from_text_proto_list(s).unwrap();

        assert_eq!(expected, actual);
    }

    #[test]
    fn test_override_try_from_text_proto_list() {
        let expected = Override { id: "1234".to_owned(), value: true };

        let s = r#"
        id: "1234"
        value: true
        "#;
        let actual = Override::try_from_text_proto(s).unwrap();

        assert_eq!(expected, actual);
    }

    #[test]
    fn test_resolve_value() {
        let flag = Flag {
            id: "a".to_owned(),
            description: "A".to_owned(),
            values: vec![
                Value::default(true),
                Value::new(false, 10),
                Value::new(true, 20),
                Value::new(false, 30),
            ],
        };
        assert!(flag.resolve_value(0));
        assert!(flag.resolve_value(9));
        assert!(!flag.resolve_value(10));
        assert!(!flag.resolve_value(11));
        assert!(!flag.resolve_value(19));
        assert!(flag.resolve_value(20));
        assert!(flag.resolve_value(21));
        assert!(flag.resolve_value(29));
        assert!(!flag.resolve_value(30));
        assert!(!flag.resolve_value(10_000));
    }
}
