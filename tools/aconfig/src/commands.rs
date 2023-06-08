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

use crate::aconfig::{FlagDeclarations, FlagState, FlagValue, Permission};
use crate::cache::{Cache, CacheBuilder, Item};
use crate::codegen_cpp::generate_cpp_code;
use crate::codegen_java::generate_java_code;
use crate::codegen_rust::generate_rust_code;
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

pub fn create_cache(package: &str, declarations: Vec<Input>, values: Vec<Input>) -> Result<Cache> {
    let mut builder = CacheBuilder::new(package.to_owned())?;

    for mut input in declarations {
        let mut contents = String::new();
        input.reader.read_to_string(&mut contents)?;
        let dec_list = FlagDeclarations::try_from_text_proto(&contents)
            .with_context(|| format!("Failed to parse {}", input.source))?;
        ensure!(
            package == dec_list.package,
            "Failed to parse {}: expected package {}, got {}",
            input.source,
            package,
            dec_list.package
        );
        for d in dec_list.flags.into_iter() {
            builder.add_flag_declaration(input.source.clone(), d)?;
        }
    }

    for mut input in values {
        let mut contents = String::new();
        input.reader.read_to_string(&mut contents)?;
        let values_list = FlagValue::try_from_text_proto_list(&contents)
            .with_context(|| format!("Failed to parse {}", input.source))?;
        for v in values_list {
            // TODO: warn about flag values that do not take effect?
            let _ = builder.add_flag_value(input.source.clone(), v);
        }
    }

    Ok(builder.build())
}

pub fn create_java_lib(cache: Cache) -> Result<OutputFile> {
    generate_java_code(&cache)
}

pub fn create_cpp_lib(cache: Cache) -> Result<OutputFile> {
    generate_cpp_code(&cache)
}

pub fn create_rust_lib(cache: Cache) -> Result<OutputFile> {
    generate_rust_code(&cache)
}

pub fn create_device_config_defaults(caches: Vec<Cache>) -> Result<Vec<u8>> {
    let mut output = Vec::new();
    for item in sort_and_iter_items(caches).filter(|item| item.permission == Permission::ReadWrite)
    {
        let line = format!(
            "{}:{}.{}={}\n",
            item.namespace,
            item.package,
            item.name,
            match item.state {
                FlagState::Enabled => "enabled",
                FlagState::Disabled => "disabled",
            }
        );
        output.extend_from_slice(line.as_bytes());
    }
    Ok(output)
}

pub fn create_device_config_sysprops(caches: Vec<Cache>) -> Result<Vec<u8>> {
    let mut output = Vec::new();
    for item in sort_and_iter_items(caches).filter(|item| item.permission == Permission::ReadWrite)
    {
        let line = format!(
            "persist.device_config.{}.{}={}\n",
            item.package,
            item.name,
            match item.state {
                FlagState::Enabled => "true",
                FlagState::Disabled => "false",
            }
        );
        output.extend_from_slice(line.as_bytes());
    }
    Ok(output)
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
pub enum DumpFormat {
    Text,
    Debug,
    Protobuf,
}

pub fn dump_cache(caches: Vec<Cache>, format: DumpFormat) -> Result<Vec<u8>> {
    let mut output = Vec::new();
    match format {
        DumpFormat::Text => {
            for item in sort_and_iter_items(caches) {
                let line = format!(
                    "{}/{}: {:?} {:?}\n",
                    item.package, item.name, item.state, item.permission
                );
                output.extend_from_slice(line.as_bytes());
            }
        }
        DumpFormat::Debug => {
            for item in sort_and_iter_items(caches) {
                let line = format!("{:#?}\n", item);
                output.extend_from_slice(line.as_bytes());
            }
        }
        DumpFormat::Protobuf => {
            for cache in sort_and_iter_caches(caches) {
                let parsed_flags: ProtoParsedFlags = cache.into();
                parsed_flags.write_to_vec(&mut output)?;
            }
        }
    }
    Ok(output)
}

fn sort_and_iter_items(caches: Vec<Cache>) -> impl Iterator<Item = Item> {
    sort_and_iter_caches(caches).flat_map(|cache| cache.into_iter())
}

fn sort_and_iter_caches(mut caches: Vec<Cache>) -> impl Iterator<Item = Cache> {
    caches.sort_by_cached_key(|cache| cache.package().to_string());
    caches.into_iter()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::aconfig::{FlagState, Permission};

    fn create_test_cache_com_example() -> Cache {
        let s = r#"
        package: "com.example"
        flag {
            name: "a"
            namespace: "ns"
            description: "Description of a"
        }
        flag {
            name: "b"
            namespace: "ns"
            description: "Description of b"
        }
        "#;
        let declarations = vec![Input { source: Source::Memory, reader: Box::new(s.as_bytes()) }];
        let o = r#"
        flag_value {
            package: "com.example"
            name: "a"
            state: DISABLED
            permission: READ_ONLY
        }
        "#;
        let values = vec![Input { source: Source::Memory, reader: Box::new(o.as_bytes()) }];
        create_cache("com.example", declarations, values).unwrap()
    }

    fn create_test_cache_com_other() -> Cache {
        let s = r#"
        package: "com.other"
        flag {
            name: "c"
            namespace: "ns"
            description: "Description of c"
        }
        "#;
        let declarations = vec![Input { source: Source::Memory, reader: Box::new(s.as_bytes()) }];
        let o = r#"
        flag_value {
            package: "com.other"
            name: "c"
            state: DISABLED
            permission: READ_ONLY
        }
        "#;
        let values = vec![Input { source: Source::Memory, reader: Box::new(o.as_bytes()) }];
        create_cache("com.other", declarations, values).unwrap()
    }

    #[test]
    fn test_create_cache() {
        let caches = create_test_cache_com_example(); // calls create_cache
        let item = caches.iter().find(|&item| item.name == "a").unwrap();
        assert_eq!(FlagState::Disabled, item.state);
        assert_eq!(Permission::ReadOnly, item.permission);
    }

    #[test]
    fn test_create_device_config_defaults() {
        let caches = vec![crate::test::create_cache()];
        let bytes = create_device_config_defaults(caches).unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert_eq!("aconfig_test:com.android.aconfig.test.disabled_rw=disabled\naconfig_test:com.android.aconfig.test.enabled_rw=enabled\n", text);
    }

    #[test]
    fn test_create_device_config_sysprops() {
        let caches = vec![crate::test::create_cache()];
        let bytes = create_device_config_sysprops(caches).unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert_eq!("persist.device_config.com.android.aconfig.test.disabled_rw=false\npersist.device_config.com.android.aconfig.test.enabled_rw=true\n", text);
    }

    #[test]
    fn test_dump_text_format() {
        let caches = vec![create_test_cache_com_example()];
        let bytes = dump_cache(caches, DumpFormat::Text).unwrap();
        let text = std::str::from_utf8(&bytes).unwrap();
        assert!(text.contains("a: Disabled"));
    }

    #[test]
    fn test_dump_protobuf_format() {
        use crate::protos::{ProtoFlagPermission, ProtoFlagState, ProtoTracepoint};
        use protobuf::Message;

        let caches = vec![create_test_cache_com_example()];
        let bytes = dump_cache(caches, DumpFormat::Protobuf).unwrap();
        let actual = ProtoParsedFlags::parse_from_bytes(&bytes).unwrap();

        assert_eq!(
            vec!["a".to_string(), "b".to_string()],
            actual.parsed_flag.iter().map(|item| item.name.clone().unwrap()).collect::<Vec<_>>()
        );

        let item =
            actual.parsed_flag.iter().find(|item| item.name == Some("b".to_string())).unwrap();
        assert_eq!(item.package(), "com.example");
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

    #[test]
    fn test_dump_multiple_caches() {
        let caches = vec![create_test_cache_com_example(), create_test_cache_com_other()];
        let bytes = dump_cache(caches, DumpFormat::Protobuf).unwrap();
        let dump = ProtoParsedFlags::parse_from_bytes(&bytes).unwrap();
        assert_eq!(
            dump.parsed_flag
                .iter()
                .map(|parsed_flag| format!("{}/{}", parsed_flag.package(), parsed_flag.name()))
                .collect::<Vec<_>>(),
            vec![
                "com.example/a".to_string(),
                "com.example/b".to_string(),
                "com.other/c".to_string()
            ]
        );

        let caches = vec![create_test_cache_com_other(), create_test_cache_com_example()];
        let bytes = dump_cache(caches, DumpFormat::Protobuf).unwrap();
        let dump_reversed_input = ProtoParsedFlags::parse_from_bytes(&bytes).unwrap();
        assert_eq!(dump, dump_reversed_input);
    }
}
