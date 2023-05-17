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

use anyhow::Result;
use serde::Serialize;
use tinytemplate::TinyTemplate;

use crate::aconfig::{FlagState, Permission};
use crate::cache::{Cache, Item};
use crate::commands::OutputFile;

pub fn generate_cpp_code(cache: &Cache) -> Result<OutputFile> {
    let class_elements: Vec<ClassElement> = cache.iter().map(create_class_element).collect();
    let readwrite = class_elements.iter().any(|item| item.readwrite);
    let namespace = cache.namespace().to_lowercase();
    let context = Context { namespace: namespace.clone(), readwrite, class_elements };
    let mut template = TinyTemplate::new();
    template.add_template("cpp_code_gen", include_str!("../templates/cpp.template"))?;
    let contents = template.render("cpp_code_gen", &context)?;
    let path = ["aconfig", &(namespace + ".h")].iter().collect();
    Ok(OutputFile { contents: contents.into(), path })
}

#[derive(Serialize)]
struct Context {
    pub namespace: String,
    pub readwrite: bool,
    pub class_elements: Vec<ClassElement>,
}

#[derive(Serialize)]
struct ClassElement {
    pub readwrite: bool,
    pub default_value: String,
    pub flag_name: String,
}

fn create_class_element(item: &Item) -> ClassElement {
    ClassElement {
        readwrite: item.permission == Permission::ReadWrite,
        default_value: if item.state == FlagState::Enabled {
            "true".to_string()
        } else {
            "false".to_string()
        },
        flag_name: item.name.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::aconfig::{FlagDeclaration, FlagState, FlagValue, Permission};
    use crate::commands::Source;

    #[test]
    fn test_cpp_codegen_build_time_flag_only() {
        let namespace = "my_namespace";
        let mut cache = Cache::new(namespace.to_string()).unwrap();
        cache
            .add_flag_declaration(
                Source::File("aconfig_one.txt".to_string()),
                FlagDeclaration {
                    name: "my_flag_one".to_string(),
                    description: "buildtime disable".to_string(),
                },
            )
            .unwrap();
        cache
            .add_flag_value(
                Source::Memory,
                FlagValue {
                    namespace: namespace.to_string(),
                    name: "my_flag_one".to_string(),
                    state: FlagState::Disabled,
                    permission: Permission::ReadOnly,
                },
            )
            .unwrap();
        cache
            .add_flag_declaration(
                Source::File("aconfig_two.txt".to_string()),
                FlagDeclaration {
                    name: "my_flag_two".to_string(),
                    description: "buildtime enable".to_string(),
                },
            )
            .unwrap();
        cache
            .add_flag_value(
                Source::Memory,
                FlagValue {
                    namespace: namespace.to_string(),
                    name: "my_flag_two".to_string(),
                    state: FlagState::Enabled,
                    permission: Permission::ReadOnly,
                },
            )
            .unwrap();
        let expect_content = r#"#ifndef my_namespace_HEADER_H
        #define my_namespace_HEADER_H
        #include "my_namespace.h"

        namespace my_namespace {

            class my_flag_one {
                public:
                    virtual const bool value() {
                        return false;
                    }
            }

            class my_flag_two {
                public:
                    virtual const bool value() {
                        return true;
                    }
            }

        }
        #endif
        "#;
        let file = generate_cpp_code(&cache).unwrap();
        assert_eq!("aconfig/my_namespace.h", file.path.to_str().unwrap());
        assert_eq!(
            expect_content.replace(' ', ""),
            String::from_utf8(file.contents).unwrap().replace(' ', "")
        );
    }

    #[test]
    fn test_cpp_codegen_runtime_flag() {
        let namespace = "my_namespace";
        let mut cache = Cache::new(namespace.to_string()).unwrap();
        cache
            .add_flag_declaration(
                Source::File("aconfig_one.txt".to_string()),
                FlagDeclaration {
                    name: "my_flag_one".to_string(),
                    description: "buildtime disable".to_string(),
                },
            )
            .unwrap();
        cache
            .add_flag_declaration(
                Source::File("aconfig_two.txt".to_string()),
                FlagDeclaration {
                    name: "my_flag_two".to_string(),
                    description: "runtime enable".to_string(),
                },
            )
            .unwrap();
        cache
            .add_flag_value(
                Source::Memory,
                FlagValue {
                    namespace: namespace.to_string(),
                    name: "my_flag_two".to_string(),
                    state: FlagState::Enabled,
                    permission: Permission::ReadWrite,
                },
            )
            .unwrap();
        let expect_content = r#"#ifndef my_namespace_HEADER_H
        #define my_namespace_HEADER_H
        #include "my_namespace.h"

        #include <server_configurable_flags/get_flags.h>
        using namespace server_configurable_flags;

        namespace my_namespace {

            class my_flag_one {
                public:
                    virtual const bool value() {
                        return GetServerConfigurableFlag(
                            "my_namespace",
                            "my_flag_one",
                            "false") == "true";
                    }
            }

            class my_flag_two {
                public:
                    virtual const bool value() {
                        return GetServerConfigurableFlag(
                            "my_namespace",
                            "my_flag_two",
                            "true") == "true";
                    }
            }

        }
        #endif
        "#;
        let file = generate_cpp_code(&cache).unwrap();
        assert_eq!("aconfig/my_namespace.h", file.path.to_str().unwrap());
        assert_eq!(
            expect_content.replace(' ', ""),
            String::from_utf8(file.contents).unwrap().replace(' ', "")
        );
    }
}
