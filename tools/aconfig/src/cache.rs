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

use crate::aconfig::{Flag, Override};
use crate::commands::Source;

#[derive(Serialize, Deserialize)]
pub struct Item {
    pub id: String,
    pub description: String,
    pub value: bool,
    pub debug: Vec<String>,
}

#[derive(Serialize, Deserialize)]
pub struct Cache {
    build_id: u32,
    items: Vec<Item>,
}

impl Cache {
    pub fn new(build_id: u32) -> Cache {
        Cache { build_id, items: vec![] }
    }

    pub fn read_from_reader(reader: impl Read) -> Result<Cache> {
        serde_json::from_reader(reader).map_err(|e| e.into())
    }

    pub fn write_to_writer(&self, writer: impl Write) -> Result<()> {
        serde_json::to_writer(writer, self).map_err(|e| e.into())
    }

    pub fn add_flag(&mut self, source: Source, flag: Flag) -> Result<()> {
        if self.items.iter().any(|item| item.id == flag.id) {
            return Err(anyhow!(
                "failed to add flag {} from {}: flag already defined",
                flag.id,
                source,
            ));
        }
        let value = flag.resolve_value(self.build_id);
        self.items.push(Item {
            id: flag.id.clone(),
            description: flag.description,
            value,
            debug: vec![format!("{}:{}", source, value)],
        });
        Ok(())
    }

    pub fn add_override(&mut self, source: Source, override_: Override) -> Result<()> {
        let Some(existing_item) = self.items.iter_mut().find(|item| item.id == override_.id) else {
            return Err(anyhow!("failed to override flag {}: unknown flag", override_.id));
        };
        existing_item.value = override_.value;
        existing_item.debug.push(format!("{}:{}", source, override_.value));
        Ok(())
    }

    pub fn iter(&self) -> impl Iterator<Item = &Item> {
        self.items.iter()
    }
}

impl Item {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::aconfig::Value;

    #[test]
    fn test_add_flag() {
        let mut cache = Cache::new(1);
        cache
            .add_flag(
                Source::File("first.txt".to_string()),
                Flag {
                    id: "foo".to_string(),
                    description: "desc".to_string(),
                    values: vec![Value::default(true)],
                },
            )
            .unwrap();
        let error = cache
            .add_flag(
                Source::File("second.txt".to_string()),
                Flag {
                    id: "foo".to_string(),
                    description: "desc".to_string(),
                    values: vec![Value::default(false)],
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
        fn check_value(cache: &Cache, id: &str, expected: bool) -> bool {
            cache.iter().find(|&item| item.id == id).unwrap().value == expected
        }

        let mut cache = Cache::new(1);
        let error = cache
            .add_override(Source::Memory, Override { id: "foo".to_string(), value: true })
            .unwrap_err();
        assert_eq!(&format!("{:?}", error), "failed to override flag foo: unknown flag");

        cache
            .add_flag(
                Source::File("first.txt".to_string()),
                Flag {
                    id: "foo".to_string(),
                    description: "desc".to_string(),
                    values: vec![Value::default(true)],
                },
            )
            .unwrap();
        assert!(check_value(&cache, "foo", true));

        cache
            .add_override(Source::Memory, Override { id: "foo".to_string(), value: false })
            .unwrap();
        assert!(check_value(&cache, "foo", false));

        cache
            .add_override(Source::Memory, Override { id: "foo".to_string(), value: true })
            .unwrap();
        assert!(check_value(&cache, "foo", true));
    }
}
