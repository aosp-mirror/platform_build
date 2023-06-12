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

use anyhow::{ensure, Result};
use serde::Serialize;
use tinytemplate::TinyTemplate;

use crate::aconfig::{FlagState, Permission};
use crate::cache::{Cache, Item};
use crate::codegen;
use crate::commands::OutputFile;

pub fn generate_cpp_code(cache: &Cache) -> Result<OutputFile> {
    let package = cache.package();
    let class_elements: Vec<ClassElement> =
        cache.iter().map(|item| create_class_element(package, item)).collect();
    let readwrite = class_elements.iter().any(|item| item.readwrite);
    let header = package.replace('.', "_");
    let cpp_namespace = package.replace('.', "::");
    ensure!(codegen::is_valid_name_ident(&header));
    let context = Context {
        header: header.clone(),
        cpp_namespace,
        package: package.to_string(),
        readwrite,
        class_elements,
    };
    let mut template = TinyTemplate::new();
    template.add_template("cpp_code_gen", include_str!("../templates/cpp.template"))?;
    let contents = template.render("cpp_code_gen", &context)?;
    let path = ["aconfig", &(header + ".h")].iter().collect();
    Ok(OutputFile { contents: contents.into(), path })
}

#[derive(Serialize)]
struct Context {
    pub header: String,
    pub cpp_namespace: String,
    pub package: String,
    pub readwrite: bool,
    pub class_elements: Vec<ClassElement>,
}

#[derive(Serialize)]
struct ClassElement {
    pub readwrite: bool,
    pub default_value: String,
    pub flag_name: String,
    pub device_config_namespace: String,
    pub device_config_flag: String,
}

fn create_class_element(package: &str, item: &Item) -> ClassElement {
    ClassElement {
        readwrite: item.permission == Permission::ReadWrite,
        default_value: if item.state == FlagState::Enabled {
            "true".to_string()
        } else {
            "false".to_string()
        },
        flag_name: item.name.clone(),
        device_config_namespace: item.namespace.to_string(),
        device_config_flag: codegen::create_device_config_ident(package, &item.name)
            .expect("values checked at cache creation time"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::aconfig::{FlagDeclaration, FlagState, FlagValue, Permission};
    use crate::cache::CacheBuilder;
    use crate::commands::Source;

    #[test]
    fn test_cpp_codegen_build_time_flag_only() {
        let package = "com.example";
        let mut builder = CacheBuilder::new(package.to_string()).unwrap();
        builder
            .add_flag_declaration(
                Source::File("aconfig_one.txt".to_string()),
                FlagDeclaration {
                    name: "my_flag_one".to_string(),
                    namespace: "ns".to_string(),
                    description: "buildtime disable".to_string(),
                },
            )
            .unwrap()
            .add_flag_value(
                Source::Memory,
                FlagValue {
                    package: package.to_string(),
                    name: "my_flag_one".to_string(),
                    state: FlagState::Disabled,
                    permission: Permission::ReadOnly,
                },
            )
            .unwrap()
            .add_flag_declaration(
                Source::File("aconfig_two.txt".to_string()),
                FlagDeclaration {
                    name: "my_flag_two".to_string(),
                    namespace: "ns".to_string(),
                    description: "buildtime enable".to_string(),
                },
            )
            .unwrap()
            .add_flag_value(
                Source::Memory,
                FlagValue {
                    package: package.to_string(),
                    name: "my_flag_two".to_string(),
                    state: FlagState::Enabled,
                    permission: Permission::ReadOnly,
                },
            )
            .unwrap();
        let cache = builder.build();
        let expect_content = r#"#ifndef com_example_HEADER_H
        #define com_example_HEADER_H

        namespace com::example {

            static const bool my_flag_one() {
                return false;
            }

            static const bool my_flag_two() {
                return true;
            }

        }
        #endif
        "#;
        let file = generate_cpp_code(&cache).unwrap();
        assert_eq!("aconfig/com_example.h", file.path.to_str().unwrap());
        assert_eq!(
            expect_content.replace(' ', ""),
            String::from_utf8(file.contents).unwrap().replace(' ', "")
        );
    }

    #[test]
    fn test_cpp_codegen_runtime_flag() {
        let package = "com.example";
        let mut builder = CacheBuilder::new(package.to_string()).unwrap();
        builder
            .add_flag_declaration(
                Source::File("aconfig_one.txt".to_string()),
                FlagDeclaration {
                    name: "my_flag_one".to_string(),
                    namespace: "ns".to_string(),
                    description: "buildtime disable".to_string(),
                },
            )
            .unwrap()
            .add_flag_declaration(
                Source::File("aconfig_two.txt".to_string()),
                FlagDeclaration {
                    name: "my_flag_two".to_string(),
                    namespace: "ns".to_string(),
                    description: "runtime enable".to_string(),
                },
            )
            .unwrap()
            .add_flag_value(
                Source::Memory,
                FlagValue {
                    package: package.to_string(),
                    name: "my_flag_two".to_string(),
                    state: FlagState::Enabled,
                    permission: Permission::ReadWrite,
                },
            )
            .unwrap();
        let cache = builder.build();
        let expect_content = r#"#ifndef com_example_HEADER_H
        #define com_example_HEADER_H

        #include <server_configurable_flags/get_flags.h>
        using namespace server_configurable_flags;

        namespace com::example {

            static const bool my_flag_one() {
                return GetServerConfigurableFlag(
                    "ns",
                    "com.example.my_flag_one",
                    "false") == "true";
            }

            static const bool my_flag_two() {
                return GetServerConfigurableFlag(
                    "ns",
                    "com.example.my_flag_two",
                    "true") == "true";
            }

        }
        #endif
        "#;
        let file = generate_cpp_code(&cache).unwrap();
        assert_eq!("aconfig/com_example.h", file.path.to_str().unwrap());
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                expect_content,
                &String::from_utf8(file.contents).unwrap()
            )
        );
    }
}
