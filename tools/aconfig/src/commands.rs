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

use anyhow::{ensure, Context, Result};
use clap::ValueEnum;
use protobuf::Message;
use serde::{Deserialize, Serialize};
use std::fmt;
use std::io::Read;
use std::path::PathBuf;

use crate::aconfig::{FlagDeclarations, FlagValue};
use crate::cache::Cache;
use crate::codegen_cpp::generate_cpp_code;
use crate::codegen_java::generate_java_code;
use crate::protos::ProtoParsedFlags;

#[derive(Serialize, Deserialize, Clone, Debug)]
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

pub struct OutputFile {
    pub path: PathBuf, // relative to some root directory only main knows about
    pub contents: Vec<u8>,
}

pub fn create_cache(
    namespace: &str,
    declarations: Vec<Input>,
    values: Vec<Input>,
) -> Result<Cache> {
    let mut cache = Cache::new(namespace.to_owned())?;

    for mut input in declarations {
        let mut contents = String::new();
        input.reader.read_to_string(&mut contents)?;
        let dec_list = FlagDeclarations::try_from_text_proto(&contents)
            .with_context(|| format!("Failed to parse {}", input.source))?;
        ensure!(
            namespace == dec_list.namespace,
            "Failed to parse {}: expected namespace {}, got {}",
            input.source,
            namespace,
            dec_list.namespace
        );
        for d in dec_list.flags.into_iter() {
            cache.add_flag_declaration(input.source.clone(), d)?;
        }
    }

    for mut input in values {
        let mut contents = String::new();
        input.reader.read_to_string(&mut contents)?;
        let values_list = FlagValue::try_from_text_proto_list(&contents)
            .with_context(|| format!("Failed to parse {}", input.source))?;
        for v in values_list {
            // TODO: warn about flag values that do not take effect?
            let _ = cache.add_flag_value(input.source.clone(), v);
        }
    }

    Ok(cache)
}

pub fn create_java_lib(cache: &Cache) -> Result<OutputFile> {
    generate_java_code(cache)
}

pub fn create_cpp_lib(cache: &Cache) -> Result<OutputFile> {
    generate_cpp_code(cache)
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
pub enum DumpFormat {
    Text,
    Debug,
    Protobuf,
}

pub fn dump_cache(cache: Cache, format: DumpFormat) -> Result<Vec<u8>> {
    match format {
        DumpFormat::Text => {
            let mut lines = vec![];
            for item in cache.iter() {
                lines.push(format!("{}: {:?}\n", item.name, item.state));
            }
            Ok(lines.concat().into())
        }
        DumpFormat::Debug => {
            let mut lines = vec![];
            for item in cache.iter() {
                lines.push(format!("{:?}\n", item));
            }
            Ok(lines.concat().into())
        }
        DumpFormat::Protobuf => {
            let parsed_flags: ProtoParsedFlags = cache.into();
            let mut output = vec![];
            parsed_flags.write_to_vec(&mut output)?;
            Ok(output)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::aconfig::{FlagState, Permission};

    fn create_test_cache() -> Cache {
        let s = r#"
        namespace: "ns"
        flag {
            name: "a"
            description: "Description of a"
        }
        flag {
            name: "b"
            description: "Description of b"
        }
        "#;
        let declarations = vec![Input { source: Source::Memory, reader: Box::new(s.as_bytes()) }];
        let o = r#"
        flag_value {
            namespace: "ns"
            name: "a"
            state: DISABLED
            permission: READ_ONLY
        }
        "#;
        let values = vec![Input { source: Source::Memory, reader: Box::new(o.as_bytes()) }];
        create_cache("ns", declarations, values).unwrap()
    }

    #[test]
    fn test_create_cache() {
        let cache = create_test_cache(); // calls create_cache
        let item = cache.iter().find(|&item| item.name == "a").unwrap();
        assert_eq!(FlagState::Disabled, item.state);
        assert_eq!(Permission::ReadOnly, item.permission);
    }

    #[test]
    fn test_dump_text_format() {
        let cache = create_test_cache();
        let bytes = dump_cache(cache, DumpFormat::Text).unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert!(text.contains("a: Disabled"));
    }

    #[test]
    fn test_dump_protobuf_format() {
        use crate::protos::{ProtoFlagPermission, ProtoFlagState, ProtoTracepoint};
        use protobuf::Message;

        let cache = create_test_cache();
        let bytes = dump_cache(cache, DumpFormat::Protobuf).unwrap();
        let actual = ProtoParsedFlags::parse_from_bytes(&bytes).unwrap();

        assert_eq!(
            vec!["a".to_string(), "b".to_string()],
            actual.parsed_flag.iter().map(|item| item.name.clone().unwrap()).collect::<Vec<_>>()
        );

        let item =
            actual.parsed_flag.iter().find(|item| item.name == Some("b".to_string())).unwrap();
        assert_eq!(item.namespace(), "ns");
        assert_eq!(item.name(), "b");
        assert_eq!(item.description(), "Description of b");
        assert_eq!(item.state(), ProtoFlagState::DISABLED);
        assert_eq!(item.permission(), ProtoFlagPermission::READ_WRITE);
        let mut tp = ProtoTracepoint::new();
        tp.set_source("<memory>".to_string());
        tp.set_state(ProtoFlagState::DISABLED);
        tp.set_permission(ProtoFlagPermission::READ_WRITE);
        assert_eq!(item.trace, vec![tp]);
    }
}
