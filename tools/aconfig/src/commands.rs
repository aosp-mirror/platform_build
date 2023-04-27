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

use anyhow::{Context, Result};
use clap::ValueEnum;
use serde::{Deserialize, Serialize};
use std::fmt;
use std::io::Read;

use crate::aconfig::{Flag, Override};
use crate::cache::Cache;

#[derive(Clone, Serialize, Deserialize)]
pub enum Source {
    #[allow(dead_code)] // only used in unit tests
    Memory,
    File(String),
}

impl fmt::Display for Source {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Self::Memory => write!(f, "<memory>"),
            Self::File(path) => write!(f, "{}", path),
        }
    }
}

pub struct Input {
    pub source: Source,
    pub reader: Box<dyn Read>,
}

pub fn create_cache(aconfigs: Vec<Input>, overrides: Vec<Input>) -> Result<Cache> {
    let mut cache = Cache::new();

    for mut input in aconfigs {
        let mut contents = String::new();
        input.reader.read_to_string(&mut contents)?;
        let flags = Flag::try_from_text_proto_list(&contents)
            .with_context(|| format!("Failed to parse {}", input.source))?;
        for flag in flags {
            cache.add_flag(input.source.clone(), flag)?;
        }
    }

    for mut input in overrides {
        let mut contents = String::new();
        input.reader.read_to_string(&mut contents)?;
        let overrides = Override::try_from_text_proto_list(&contents)
            .with_context(|| format!("Failed to parse {}", input.source))?;
        for override_ in overrides {
            cache.add_override(input.source.clone(), override_)?;
        }
    }

    Ok(cache)
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
pub enum Format {
    Text,
    Debug,
}

pub fn dump_cache(cache: Cache, format: Format) -> Result<()> {
    match format {
        Format::Text => {
            for item in cache.iter() {
                println!("{}: {}", item.id, item.value());
            }
        }
        Format::Debug => {
            for item in cache.iter() {
                println!("{}: {}", item.id, item.value());
                for value in &item.values {
                    println!("    {}: {}", value.source, value.value);
                }
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_cache() {
        let s = r#"
        flag {
            id: "a"
            description: "Description of a"
            value: true
        }
        "#;
        let aconfigs = vec![Input { source: Source::Memory, reader: Box::new(s.as_bytes()) }];
        let o = r#"
        override {
            id: "a"
            value: false
        }
        "#;
        let overrides = vec![Input { source: Source::Memory, reader: Box::new(o.as_bytes()) }];
        let cache = create_cache(aconfigs, overrides).unwrap();
        let value = cache.iter().find(|&item| item.id == "a").unwrap().value();
        assert!(!value);
    }
}
