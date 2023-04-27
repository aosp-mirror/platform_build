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
pub struct Value {
    pub value: bool,
    pub source: Source,
}

#[derive(Serialize, Deserialize)]
pub struct Item {
    pub id: String,
    pub description: String,
    pub values: Vec<Value>,
}

#[derive(Serialize, Deserialize)]
pub struct Cache {
    items: Vec<Item>,
}

impl Cache {
    pub fn new() -> Cache {
        Cache { items: vec![] }
    }

    pub fn read_from_reader(reader: impl Read) -> Result<Cache> {
        serde_json::from_reader(reader).map_err(|e| e.into())
    }

    pub fn write_to_writer(&self, writer: impl Write) -> Result<()> {
        serde_json::to_writer(writer, self).map_err(|e| e.into())
    }

    pub fn add_flag(&mut self, source: Source, flag: Flag) -> Result<()> {
        if let Some(existing_item) = self.items.iter().find(|&item| item.id == flag.id) {
            return Err(anyhow!(
                "failed to add flag {} from {}: already added from {}",
                flag.id,
                source,
                existing_item.values.first().unwrap().source
            ));
        }
        self.items.push(Item {
            id: flag.id.clone(),
            description: flag.description.clone(),
            values: vec![Value { value: flag.value, source }],
        });
        Ok(())
    }

    pub fn add_override(&mut self, source: Source, override_: Override) -> Result<()> {
        let Some(existing_item) = self.items.iter_mut().find(|item| item.id == override_.id) else {
            return Err(anyhow!("failed to override flag {}: unknown flag", override_.id));
        };
        existing_item.values.push(Value { value: override_.value, source });
        Ok(())
    }

    pub fn iter(&self) -> impl Iterator<Item = &Item> {
        self.items.iter()
    }
}

impl Item {
    pub fn value(&self) -> bool {
        self.values.last().unwrap().value
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add_flag() {
        let mut cache = Cache::new();
        cache
            .add_flag(
                Source::File("first.txt".to_string()),
                Flag { id: "foo".to_string(), description: "desc".to_string(), value: true },
            )
            .unwrap();
        let error = cache
            .add_flag(
                Source::File("second.txt".to_string()),
                Flag { id: "foo".to_string(), description: "desc".to_string(), value: false },
            )
            .unwrap_err();
        assert_eq!(
            &format!("{:?}", error),
            "failed to add flag foo from second.txt: already added from first.txt"
        );
    }

    #[test]
    fn test_add_override() {
        fn get_value(cache: &Cache, id: &str) -> bool {
            cache.iter().find(|&item| item.id == id).unwrap().value()
        }

        let mut cache = Cache::new();
        let error = cache
            .add_override(Source::Memory, Override { id: "foo".to_string(), value: false })
            .unwrap_err();
        assert_eq!(&format!("{:?}", error), "failed to override flag foo: unknown flag");

        cache
            .add_flag(
                Source::File("first.txt".to_string()),
                Flag { id: "foo".to_string(), description: "desc".to_string(), value: true },
            )
            .unwrap();
        assert!(get_value(&cache, "foo"));

        cache
            .add_override(Source::Memory, Override { id: "foo".to_string(), value: false })
            .unwrap();
        assert!(!get_value(&cache, "foo"));

        cache
            .add_override(Source::Memory, Override { id: "foo".to_string(), value: true })
            .unwrap();
        assert!(get_value(&cache, "foo"));
    }
}
