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
use std::path::PathBuf;
use tinytemplate::TinyTemplate;

use crate::codegen;
use crate::commands::{CodegenMode, OutputFile};
use crate::protos::{ProtoFlagPermission, ProtoFlagState, ProtoParsedFlag};

pub fn generate_cpp_code<'a, I>(
    package: &str,
    parsed_flags_iter: I,
    codegen_mode: CodegenMode,
) -> Result<Vec<OutputFile>>
where
    I: Iterator<Item = &'a ProtoParsedFlag>,
{
    let class_elements: Vec<ClassElement> =
        parsed_flags_iter.map(|pf| create_class_element(package, pf)).collect();
    let readwrite = class_elements.iter().any(|item| item.readwrite);
    let header = package.replace('.', "_");
    let cpp_namespace = package.replace('.', "::");
    ensure!(codegen::is_valid_name_ident(&header));
    let context = Context {
        header: header.clone(),
        cpp_namespace,
        package: package.to_string(),
        readwrite,
        for_test: codegen_mode == CodegenMode::Test,
        class_elements,
    };

    let files = [
        FileSpec {
            name: &format!("{}.h", header),
            template: include_str!("../templates/cpp_exported_header.template"),
            dir: "include",
        },
        FileSpec {
            name: &format!("{}.cc", header),
            template: include_str!("../templates/cpp_source_file.template"),
            dir: "",
        },
    ];
    files.iter().map(|file| generate_file(file, &context)).collect()
}

pub fn generate_file(file: &FileSpec, context: &Context) -> Result<OutputFile> {
    let mut template = TinyTemplate::new();
    template.add_template(file.name, file.template)?;
    let contents = template.render(file.name, &context)?;
    let path: PathBuf = [&file.dir, &file.name].iter().collect();
    Ok(OutputFile { contents: contents.into(), path })
}

#[derive(Serialize)]
pub struct FileSpec<'a> {
    pub name: &'a str,
    pub template: &'a str,
    pub dir: &'a str,
}

#[derive(Serialize)]
pub struct Context {
    pub header: String,
    pub cpp_namespace: String,
    pub package: String,
    pub readwrite: bool,
    pub for_test: bool,
    pub class_elements: Vec<ClassElement>,
}

#[derive(Serialize)]
pub struct ClassElement {
    pub readwrite: bool,
    pub default_value: String,
    pub flag_name: String,
    pub device_config_namespace: String,
    pub device_config_flag: String,
}

fn create_class_element(package: &str, pf: &ProtoParsedFlag) -> ClassElement {
    ClassElement {
        readwrite: pf.permission() == ProtoFlagPermission::READ_WRITE,
        default_value: if pf.state() == ProtoFlagState::ENABLED {
            "true".to_string()
        } else {
            "false".to_string()
        },
        flag_name: pf.name().to_string(),
        device_config_namespace: pf.namespace().to_string(),
        device_config_flag: codegen::create_device_config_ident(package, pf.name())
            .expect("values checked at flag parse time"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    const EXPORTED_PROD_HEADER_EXPECTED: &str = r#"
#pragma once

#ifdef __cplusplus

#include <memory>

namespace com::android::aconfig::test {
class flag_provider_interface {
public:
    virtual ~flag_provider_interface() = default;

    virtual bool disabled_ro() = 0;

    virtual bool disabled_rw() = 0;

    virtual bool enabled_ro() = 0;

    virtual bool enabled_rw() = 0;
};

extern std::unique_ptr<flag_provider_interface> provider_;

inline bool disabled_ro() {
    return false;
}

inline bool disabled_rw() {
    return provider_->disabled_rw();
}

inline bool enabled_ro() {
    return true;
}

inline bool enabled_rw() {
    return provider_->enabled_rw();
}

}

extern "C" {
#endif // __cplusplus

bool com_android_aconfig_test_disabled_ro();

bool com_android_aconfig_test_disabled_rw();

bool com_android_aconfig_test_enabled_ro();

bool com_android_aconfig_test_enabled_rw();

#ifdef __cplusplus
} // extern "C"
#endif
"#;

    const EXPORTED_TEST_HEADER_EXPECTED: &str = r#"
#pragma once

#ifdef __cplusplus

#include <memory>

namespace com::android::aconfig::test {

class flag_provider_interface {
public:

    virtual ~flag_provider_interface() = default;

    virtual bool disabled_ro() = 0;

    virtual void disabled_ro(bool val) = 0;

    virtual bool disabled_rw() = 0;

    virtual void disabled_rw(bool val) = 0;

    virtual bool enabled_ro() = 0;

    virtual void enabled_ro(bool val) = 0;

    virtual bool enabled_rw() = 0;

    virtual void enabled_rw(bool val) = 0;

    virtual void reset_flags() {}
};

extern std::unique_ptr<flag_provider_interface> provider_;

inline bool disabled_ro() {
    return provider_->disabled_ro();
}

inline void disabled_ro(bool val) {
    provider_->disabled_ro(val);
}

inline bool disabled_rw() {
    return provider_->disabled_rw();
}

inline void disabled_rw(bool val) {
    provider_->disabled_rw(val);
}

inline bool enabled_ro() {
    return provider_->enabled_ro();
}

inline void enabled_ro(bool val) {
    provider_->enabled_ro(val);
}

inline bool enabled_rw() {
    return provider_->enabled_rw();
}

inline void enabled_rw(bool val) {
    provider_->enabled_rw(val);
}

inline void reset_flags() {
    return provider_->reset_flags();
}

}

extern "C" {
#endif // __cplusplus

bool com_android_aconfig_test_disabled_ro();

void set_com_android_aconfig_test_disabled_ro(bool val);

bool com_android_aconfig_test_disabled_rw();

void set_com_android_aconfig_test_disabled_rw(bool val);

bool com_android_aconfig_test_enabled_ro();

void set_com_android_aconfig_test_enabled_ro(bool val);

bool com_android_aconfig_test_enabled_rw();

void set_com_android_aconfig_test_enabled_rw(bool val);

void com_android_aconfig_test_reset_flags();


#ifdef __cplusplus
} // extern "C"
#endif


"#;

    const PROD_SOURCE_FILE_EXPECTED: &str = r#"
#include "com_android_aconfig_test.h"
#include <server_configurable_flags/get_flags.h>

namespace com::android::aconfig::test {

    class flag_provider : public flag_provider_interface {
        public:

            virtual bool disabled_ro() override {
                return false;
            }

            virtual bool disabled_rw() override {
                return server_configurable_flags::GetServerConfigurableFlag(
                    "aconfig_test",
                    "com.android.aconfig.test.disabled_rw",
                    "false") == "true";
            }

            virtual bool enabled_ro() override {
                return true;
            }

            virtual bool enabled_rw() override {
                return server_configurable_flags::GetServerConfigurableFlag(
                    "aconfig_test",
                    "com.android.aconfig.test.enabled_rw",
                    "true") == "true";
            }

    };

    std::unique_ptr<flag_provider_interface> provider_ =
        std::make_unique<flag_provider>();
}

bool com_android_aconfig_test_disabled_ro() {
    return false;
}

bool com_android_aconfig_test_disabled_rw() {
    return com::android::aconfig::test::disabled_rw();
}

bool com_android_aconfig_test_enabled_ro() {
    return true;
}

bool com_android_aconfig_test_enabled_rw() {
    return com::android::aconfig::test::enabled_rw();
}

"#;

    const TEST_SOURCE_FILE_EXPECTED: &str = r#"
#include "com_android_aconfig_test.h"
#include <server_configurable_flags/get_flags.h>

namespace com::android::aconfig::test {

    class flag_provider : public flag_provider_interface {
        private:
            std::unordered_map<std::string, bool> overrides_;

        public:
            flag_provider()
                : overrides_()
            {}

            virtual bool disabled_ro() override {
                auto it = overrides_.find("disabled_ro");
                  if (it != overrides_.end()) {
                      return it->second;
                } else {
                  return false;
                }
            }

            virtual void disabled_ro(bool val) override {
                overrides_["disabled_ro"] = val;
            }

            virtual bool disabled_rw() override {
                auto it = overrides_.find("disabled_rw");
                  if (it != overrides_.end()) {
                      return it->second;
                } else {
                  return server_configurable_flags::GetServerConfigurableFlag(
                      "aconfig_test",
                      "com.android.aconfig.test.disabled_rw",
                      "false") == "true";
                }
            }

            virtual void disabled_rw(bool val) override {
                overrides_["disabled_rw"] = val;
            }

            virtual bool enabled_ro() override {
                auto it = overrides_.find("enabled_ro");
                  if (it != overrides_.end()) {
                      return it->second;
                } else {
                  return true;
                }
            }

            virtual void enabled_ro(bool val) override {
                overrides_["enabled_ro"] = val;
            }

            virtual bool enabled_rw() override {
                auto it = overrides_.find("enabled_rw");
                  if (it != overrides_.end()) {
                      return it->second;
                } else {
                  return server_configurable_flags::GetServerConfigurableFlag(
                      "aconfig_test",
                      "com.android.aconfig.test.enabled_rw",
                      "true") == "true";
                }
            }

            virtual void enabled_rw(bool val) override {
                overrides_["enabled_rw"] = val;
            }


            virtual void reset_flags() override {
                overrides_.clear();
            }
    };

    std::unique_ptr<flag_provider_interface> provider_ =
        std::make_unique<flag_provider>();
}

bool com_android_aconfig_test_disabled_ro() {
    return com::android::aconfig::test::disabled_ro();
}


void set_com_android_aconfig_test_disabled_ro(bool val) {
    com::android::aconfig::test::disabled_ro(val);
}

bool com_android_aconfig_test_disabled_rw() {
    return com::android::aconfig::test::disabled_rw();
}


void set_com_android_aconfig_test_disabled_rw(bool val) {
    com::android::aconfig::test::disabled_rw(val);
}

bool com_android_aconfig_test_enabled_ro() {
    return com::android::aconfig::test::enabled_ro();
}


void set_com_android_aconfig_test_enabled_ro(bool val) {
    com::android::aconfig::test::enabled_ro(val);
}

bool com_android_aconfig_test_enabled_rw() {
    return com::android::aconfig::test::enabled_rw();
}


void set_com_android_aconfig_test_enabled_rw(bool val) {
    com::android::aconfig::test::enabled_rw(val);
}

void com_android_aconfig_test_reset_flags() {
     com::android::aconfig::test::reset_flags();
}

"#;

    fn test_generate_cpp_code(mode: CodegenMode) {
        let parsed_flags = crate::test::parse_test_flags();
        let generated =
            generate_cpp_code(crate::test::TEST_PACKAGE, parsed_flags.parsed_flag.iter(), mode)
                .unwrap();
        let mut generated_files_map = HashMap::new();
        for file in generated {
            generated_files_map.insert(
                String::from(file.path.to_str().unwrap()),
                String::from_utf8(file.contents.clone()).unwrap(),
            );
        }

        let mut target_file_path = String::from("include/com_android_aconfig_test.h");
        assert!(generated_files_map.contains_key(&target_file_path));
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                match mode {
                    CodegenMode::Production => EXPORTED_PROD_HEADER_EXPECTED,
                    CodegenMode::Test => EXPORTED_TEST_HEADER_EXPECTED,
                },
                generated_files_map.get(&target_file_path).unwrap()
            )
        );

        target_file_path = String::from("com_android_aconfig_test.cc");
        assert!(generated_files_map.contains_key(&target_file_path));
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                match mode {
                    CodegenMode::Production => PROD_SOURCE_FILE_EXPECTED,
                    CodegenMode::Test => TEST_SOURCE_FILE_EXPECTED,
                },
                generated_files_map.get(&target_file_path).unwrap()
            )
        );
    }

    #[test]
    fn test_generate_cpp_code_for_prod() {
        test_generate_cpp_code(CodegenMode::Production);
    }

    #[test]
    fn test_generate_cpp_code_for_test() {
        test_generate_cpp_code(CodegenMode::Test);
    }
}
