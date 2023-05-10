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

use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use std::io::{Read, Write};

use crate::aconfig::{Flag, FlagState, Override, Permission};
use crate::commands::Source;

#[derive(Serialize, Deserialize, Debug)]
pub struct Tracepoint {
    pub source: Source,
    pub state: FlagState,
    pub permission: Permission,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Item {
    // TODO: duplicating the Cache.namespace as Item.namespace makes the internal representation
    // closer to the proto message `parsed_flag`; hopefully this will enable us to replace the Item
    // struct and use a newtype instead once aconfig has matured. Until then, namespace should
    // really be a Cow<String>.
    pub namespace: String,
    pub name: String,
    pub description: String,
    pub state: FlagState,
    pub permission: Permission,
    pub trace: Vec<Tracepoint>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Cache {
    build_id: u32,
    namespace: String,
    items: Vec<Item>,
}

impl Cache {
    pub fn new(build_id: u32, namespace: String) -> Cache {
        Cache { build_id, namespace, items: vec![] }
    }

    pub fn read_from_reader(reader: impl Read) -> Result<Cache> {
        serde_json::from_reader(reader).map_err(|e| e.into())
    }

    pub fn write_to_writer(&self, writer: impl Write) -> Result<()> {
        serde_json::to_writer(writer, self).map_err(|e| e.into())
    }

    pub fn add_flag(&mut self, source: Source, flag: Flag) -> Result<()> {
        if self.items.iter().any(|item| item.name == flag.name) {
            return Err(anyhow!(
                "failed to add flag {} from {}: flag already defined",
                flag.name,
                source,
            ));
        }
        let (state, permission) = flag.resolve(self.build_id);
        self.items.push(Item {
            namespace: self.namespace.clone(),
            name: flag.name.clone(),
            description: flag.description,
            state,
            permission,
            trace: vec![Tracepoint { source, state, permission }],
        });
        Ok(())
    }

    pub fn add_override(&mut self, source: Source, override_: Override) -> Result<()> {
        if override_.namespace != self.namespace {
            // TODO: print warning?
            return Ok(());
        }
        let Some(existing_item) = self.items.iter_mut().find(|item| item.name == override_.name) else {
            return Err(anyhow!("failed to override flag {}: unknown flag", override_.name));
        };
        existing_item.state = override_.state;
        existing_item.permission = override_.permission;
        existing_item.trace.push(Tracepoint {
            source,
            state: override_.state,
            permission: override_.permission,
        });
        Ok(())
    }

    pub fn iter(&self) -> impl Iterator<Item = &Item> {
        self.items.iter()
    }

    pub fn into_iter(self) -> impl Iterator<Item = Item> {
        self.items.into_iter()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::aconfig::{FlagState, Permission, Value};

    #[test]
    fn test_add_flag() {
        let mut cache = Cache::new(1, "ns".to_string());
        cache
            .add_flag(
                Source::File("first.txt".to_string()),
                Flag {
                    name: "foo".to_string(),
                    description: "desc".to_string(),
                    values: vec![Value::default(FlagState::Enabled, Permission::ReadOnly)],
                },
            )
            .unwrap();
        let error = cache
            .add_flag(
                Source::File("second.txt".to_string()),
                Flag {
                    name: "foo".to_string(),
                    description: "desc".to_string(),
                    values: vec![Value::default(FlagState::Disabled, Permission::ReadOnly)],
                },
            )
            .unwrap_err();
        assert_eq!(
            &format!("{:?}", error),
            "failed to add flag foo from second.txt: flag already defined"
        );
    }

    #[test]
    fn test_add_override() {
        fn check(cache: &Cache, name: &str, expected: (FlagState, Permission)) -> bool {
            let item = cache.iter().find(|&item| item.name == name).unwrap();
            item.state == expected.0 && item.permission == expected.1
        }

        let mut cache = Cache::new(1, "ns".to_string());
        let error = cache
            .add_override(
                Source::Memory,
                Override {
                    namespace: "ns".to_string(),
                    name: "foo".to_string(),
                    state: FlagState::Enabled,
                    permission: Permission::ReadOnly,
                },
            )
            .unwrap_err();
        assert_eq!(&format!("{:?}", error), "failed to override flag foo: unknown flag");

        cache
            .add_flag(
                Source::File("first.txt".to_string()),
                Flag {
                    name: "foo".to_string(),
                    description: "desc".to_string(),
                    values: vec![Value::default(FlagState::Enabled, Permission::ReadOnly)],
                },
            )
            .unwrap();
        dbg!(&cache);
        assert!(check(&cache, "foo", (FlagState::Enabled, Permission::ReadOnly)));

        cache
            .add_override(
                Source::Memory,
                Override {
                    namespace: "ns".to_string(),
                    name: "foo".to_string(),
                    state: FlagState::Disabled,
                    permission: Permission::ReadWrite,
                },
            )
            .unwrap();
        dbg!(&cache);
        assert!(check(&cache, "foo", (FlagState::Disabled, Permission::ReadWrite)));

        cache
            .add_override(
                Source::Memory,
                Override {
                    namespace: "ns".to_string(),
                    name: "foo".to_string(),
                    state: FlagState::Enabled,
                    permission: Permission::ReadWrite,
                },
            )
            .unwrap();
        assert!(check(&cache, "foo", (FlagState::Enabled, Permission::ReadWrite)));

        // different namespace -> no-op
        cache
            .add_override(
                Source::Memory,
                Override {
                    namespace: "some-other-namespace".to_string(),
                    name: "foo".to_string(),
                    state: FlagState::Enabled,
                    permission: Permission::ReadOnly,
                },
            )
            .unwrap();
        assert!(check(&cache, "foo", (FlagState::Enabled, Permission::ReadWrite)));
    }
}
