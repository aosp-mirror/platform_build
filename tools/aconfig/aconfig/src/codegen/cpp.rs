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

use aconfig_protos::{ProtoFlagPermission, ProtoFlagState, ProtoParsedFlag};

use crate::codegen;
use crate::codegen::CodegenMode;
use crate::commands::OutputFile;

pub fn generate_cpp_code<I>(
    package: &str,
    parsed_flags_iter: I,
    codegen_mode: CodegenMode,
) -> Result<Vec<OutputFile>>
where
    I: Iterator<Item = ProtoParsedFlag>,
{
    let mut readwrite_count = 0;
    let class_elements: Vec<ClassElement> = parsed_flags_iter
        .map(|pf| create_class_element(package, &pf, &mut readwrite_count))
        .collect();
    let readwrite = readwrite_count > 0;
    let has_fixed_read_only = class_elements.iter().any(|item| item.is_fixed_read_only);
    let header = package.replace('.', "_");
    let package_macro = header.to_uppercase();
    let cpp_namespace = package.replace('.', "::");
    ensure!(codegen::is_valid_name_ident(&header));
    let context = Context {
        header: &header,
        package_macro: &package_macro,
        cpp_namespace: &cpp_namespace,
        package,
        has_fixed_read_only,
        readwrite,
        readwrite_count,
        is_test_mode: codegen_mode == CodegenMode::Test,
        class_elements,
    };

    let files = [
        FileSpec {
            name: &format!("{}.h", header),
            template: include_str!("../../templates/cpp_exported_header.template"),
            dir: "include",
        },
        FileSpec {
            name: &format!("{}.cc", header),
            template: include_str!("../../templates/cpp_source_file.template"),
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
pub struct Context<'a> {
    pub header: &'a str,
    pub package_macro: &'a str,
    pub cpp_namespace: &'a str,
    pub package: &'a str,
    pub has_fixed_read_only: bool,
    pub readwrite: bool,
    pub readwrite_count: i32,
    pub is_test_mode: bool,
    pub class_elements: Vec<ClassElement>,
}

#[derive(Serialize)]
pub struct ClassElement {
    pub readwrite_idx: i32,
    pub readwrite: bool,
    pub is_fixed_read_only: bool,
    pub default_value: String,
    pub flag_name: String,
    pub flag_macro: String,
    pub device_config_namespace: String,
    pub device_config_flag: String,
}

fn create_class_element(package: &str, pf: &ProtoParsedFlag, rw_count: &mut i32) -> ClassElement {
    ClassElement {
        readwrite_idx: if pf.permission() == ProtoFlagPermission::READ_WRITE {
            let index = *rw_count;
            *rw_count += 1;
            index
        } else {
            -1
        },
        readwrite: pf.permission() == ProtoFlagPermission::READ_WRITE,
        is_fixed_read_only: pf.is_fixed_read_only(),
        default_value: if pf.state() == ProtoFlagState::ENABLED {
            "true".to_string()
        } else {
            "false".to_string()
        },
        flag_name: pf.name().to_string(),
        flag_macro: pf.name().to_uppercase(),
        device_config_namespace: pf.namespace().to_string(),
        device_config_flag: codegen::create_device_config_ident(package, pf.name())
            .expect("values checked at flag parse time"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use aconfig_protos::ProtoParsedFlags;
    use std::collections::HashMap;

    const EXPORTED_PROD_HEADER_EXPECTED: &str = r#"
#pragma once

#ifndef COM_ANDROID_ACONFIG_TEST
#define COM_ANDROID_ACONFIG_TEST(FLAG) COM_ANDROID_ACONFIG_TEST_##FLAG
#endif

#ifndef COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO
#define COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO true
#endif

#ifndef COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO_EXPORTED
#define COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO_EXPORTED true
#endif

#ifdef __cplusplus

#include <memory>

namespace com::android::aconfig::test {

class flag_provider_interface {
public:
    virtual ~flag_provider_interface() = default;

    virtual bool disabled_ro() = 0;

    virtual bool disabled_rw() = 0;

    virtual bool disabled_rw_exported() = 0;

    virtual bool disabled_rw_in_other_namespace() = 0;

    virtual bool enabled_fixed_ro() = 0;

    virtual bool enabled_fixed_ro_exported() = 0;

    virtual bool enabled_ro() = 0;

    virtual bool enabled_ro_exported() = 0;

    virtual bool enabled_rw() = 0;
};

extern std::unique_ptr<flag_provider_interface> provider_;

inline bool disabled_ro() {
    return false;
}

inline bool disabled_rw() {
    return provider_->disabled_rw();
}

inline bool disabled_rw_exported() {
    return provider_->disabled_rw_exported();
}

inline bool disabled_rw_in_other_namespace() {
    return provider_->disabled_rw_in_other_namespace();
}

inline bool enabled_fixed_ro() {
    return COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO;
}

inline bool enabled_fixed_ro_exported() {
    return COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO_EXPORTED;
}

inline bool enabled_ro() {
    return true;
}

inline bool enabled_ro_exported() {
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

bool com_android_aconfig_test_disabled_rw_exported();

bool com_android_aconfig_test_disabled_rw_in_other_namespace();

bool com_android_aconfig_test_enabled_fixed_ro();

bool com_android_aconfig_test_enabled_fixed_ro_exported();

bool com_android_aconfig_test_enabled_ro();

bool com_android_aconfig_test_enabled_ro_exported();

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

    virtual bool disabled_rw_exported() = 0;

    virtual void disabled_rw_exported(bool val) = 0;

    virtual bool disabled_rw_in_other_namespace() = 0;

    virtual void disabled_rw_in_other_namespace(bool val) = 0;

    virtual bool enabled_fixed_ro() = 0;

    virtual void enabled_fixed_ro(bool val) = 0;

    virtual bool enabled_fixed_ro_exported() = 0;

    virtual void enabled_fixed_ro_exported(bool val) = 0;

    virtual bool enabled_ro() = 0;

    virtual void enabled_ro(bool val) = 0;

    virtual bool enabled_ro_exported() = 0;

    virtual void enabled_ro_exported(bool val) = 0;

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

inline bool disabled_rw_exported() {
    return provider_->disabled_rw_exported();
}

inline void disabled_rw_exported(bool val) {
    provider_->disabled_rw_exported(val);
}

inline bool disabled_rw_in_other_namespace() {
    return provider_->disabled_rw_in_other_namespace();
}

inline void disabled_rw_in_other_namespace(bool val) {
    provider_->disabled_rw_in_other_namespace(val);
}

inline bool enabled_fixed_ro() {
    return provider_->enabled_fixed_ro();
}

inline void enabled_fixed_ro(bool val) {
    provider_->enabled_fixed_ro(val);
}

inline bool enabled_fixed_ro_exported() {
    return provider_->enabled_fixed_ro_exported();
}

inline void enabled_fixed_ro_exported(bool val) {
    provider_->enabled_fixed_ro_exported(val);
}

inline bool enabled_ro() {
    return provider_->enabled_ro();
}

inline void enabled_ro(bool val) {
    provider_->enabled_ro(val);
}

inline bool enabled_ro_exported() {
    return provider_->enabled_ro_exported();
}

inline void enabled_ro_exported(bool val) {
    provider_->enabled_ro_exported(val);
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

bool com_android_aconfig_test_disabled_rw_exported();

void set_com_android_aconfig_test_disabled_rw_exported(bool val);

bool com_android_aconfig_test_disabled_rw_in_other_namespace();

void set_com_android_aconfig_test_disabled_rw_in_other_namespace(bool val);

bool com_android_aconfig_test_enabled_fixed_ro();

void set_com_android_aconfig_test_enabled_fixed_ro(bool val);

bool com_android_aconfig_test_enabled_fixed_ro_exported();

void set_com_android_aconfig_test_enabled_fixed_ro_exported(bool val);

bool com_android_aconfig_test_enabled_ro();

void set_com_android_aconfig_test_enabled_ro(bool val);

bool com_android_aconfig_test_enabled_ro_exported();

void set_com_android_aconfig_test_enabled_ro_exported(bool val);

bool com_android_aconfig_test_enabled_rw();

void set_com_android_aconfig_test_enabled_rw(bool val);

void com_android_aconfig_test_reset_flags();


#ifdef __cplusplus
} // extern "C"
#endif


"#;

    const EXPORTED_EXPORTED_HEADER_EXPECTED: &str = r#"
#pragma once

#ifdef __cplusplus

#include <memory>

namespace com::android::aconfig::test {

class flag_provider_interface {
public:
    virtual ~flag_provider_interface() = default;

    virtual bool disabled_rw_exported() = 0;

    virtual bool enabled_fixed_ro_exported() = 0;

    virtual bool enabled_ro_exported() = 0;
};

extern std::unique_ptr<flag_provider_interface> provider_;

inline bool disabled_rw_exported() {
    return provider_->disabled_rw_exported();
}

inline bool enabled_fixed_ro_exported() {
    return provider_->enabled_fixed_ro_exported();
}

inline bool enabled_ro_exported() {
    return provider_->enabled_ro_exported();
}

}

extern "C" {
#endif // __cplusplus

bool com_android_aconfig_test_disabled_rw_exported();

bool com_android_aconfig_test_enabled_fixed_ro_exported();

bool com_android_aconfig_test_enabled_ro_exported();

#ifdef __cplusplus
} // extern "C"
#endif
"#;

    const EXPORTED_FORCE_READ_ONLY_HEADER_EXPECTED: &str = r#"
#pragma once

#ifndef COM_ANDROID_ACONFIG_TEST
#define COM_ANDROID_ACONFIG_TEST(FLAG) COM_ANDROID_ACONFIG_TEST_##FLAG
#endif

#ifndef COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO
#define COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO true
#endif

#ifdef __cplusplus

#include <memory>

namespace com::android::aconfig::test {

class flag_provider_interface {
public:
    virtual ~flag_provider_interface() = default;

    virtual bool disabled_ro() = 0;

    virtual bool disabled_rw() = 0;

    virtual bool disabled_rw_in_other_namespace() = 0;

    virtual bool enabled_fixed_ro() = 0;

    virtual bool enabled_ro() = 0;

    virtual bool enabled_rw() = 0;
};

extern std::unique_ptr<flag_provider_interface> provider_;

inline bool disabled_ro() {
    return false;
}

inline bool disabled_rw() {
    return false;
}

inline bool disabled_rw_in_other_namespace() {
    return false;
}

inline bool enabled_fixed_ro() {
    return COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO;
}

inline bool enabled_ro() {
    return true;
}

inline bool enabled_rw() {
    return true;
}

}

extern "C" {
#endif // __cplusplus

bool com_android_aconfig_test_disabled_ro();

bool com_android_aconfig_test_disabled_rw();

bool com_android_aconfig_test_disabled_rw_in_other_namespace();

bool com_android_aconfig_test_enabled_fixed_ro();

bool com_android_aconfig_test_enabled_ro();

bool com_android_aconfig_test_enabled_rw();

#ifdef __cplusplus
} // extern "C"
#endif
"#;

    const PROD_SOURCE_FILE_EXPECTED: &str = r#"
#include "com_android_aconfig_test.h"
#include <server_configurable_flags/get_flags.h>
#include <vector>

namespace com::android::aconfig::test {

    class flag_provider : public flag_provider_interface {
        public:

            virtual bool disabled_ro() override {
                return false;
            }

            virtual bool disabled_rw() override {
                if (cache_[0] == -1) {
                    cache_[0] = server_configurable_flags::GetServerConfigurableFlag(
                        "aconfig_flags.aconfig_test",
                        "com.android.aconfig.test.disabled_rw",
                        "false") == "true";
                }
                return cache_[0];
            }

            virtual bool disabled_rw_exported() override {
                if (cache_[1] == -1) {
                    cache_[1] = server_configurable_flags::GetServerConfigurableFlag(
                        "aconfig_flags.aconfig_test",
                        "com.android.aconfig.test.disabled_rw_exported",
                        "false") == "true";
                }
                return cache_[1];
            }

            virtual bool disabled_rw_in_other_namespace() override {
                if (cache_[2] == -1) {
                    cache_[2] = server_configurable_flags::GetServerConfigurableFlag(
                        "aconfig_flags.other_namespace",
                        "com.android.aconfig.test.disabled_rw_in_other_namespace",
                        "false") == "true";
                }
                return cache_[2];
            }

            virtual bool enabled_fixed_ro() override {
                return COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO;
            }

            virtual bool enabled_fixed_ro_exported() override {
                return COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO_EXPORTED;
            }

            virtual bool enabled_ro() override {
                return true;
            }

            virtual bool enabled_ro_exported() override {
                return true;
            }

            virtual bool enabled_rw() override {
                if (cache_[3] == -1) {
                    cache_[3] = server_configurable_flags::GetServerConfigurableFlag(
                        "aconfig_flags.aconfig_test",
                        "com.android.aconfig.test.enabled_rw",
                        "true") == "true";
                }
                return cache_[3];
            }

    private:
        std::vector<int8_t> cache_ = std::vector<int8_t>(4, -1);
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

bool com_android_aconfig_test_disabled_rw_exported() {
    return com::android::aconfig::test::disabled_rw_exported();
}

bool com_android_aconfig_test_disabled_rw_in_other_namespace() {
    return com::android::aconfig::test::disabled_rw_in_other_namespace();
}

bool com_android_aconfig_test_enabled_fixed_ro() {
    return COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO;
}

bool com_android_aconfig_test_enabled_fixed_ro_exported() {
    return COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO_EXPORTED;
}

bool com_android_aconfig_test_enabled_ro() {
    return true;
}

bool com_android_aconfig_test_enabled_ro_exported() {
    return true;
}

bool com_android_aconfig_test_enabled_rw() {
    return com::android::aconfig::test::enabled_rw();
}

"#;

    const TEST_SOURCE_FILE_EXPECTED: &str = r#"
#include "com_android_aconfig_test.h"
#include <server_configurable_flags/get_flags.h>
#include <unordered_map>
#include <string>

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
                      "aconfig_flags.aconfig_test",
                      "com.android.aconfig.test.disabled_rw",
                      "false") == "true";
                }
            }

            virtual void disabled_rw(bool val) override {
                overrides_["disabled_rw"] = val;
            }

            virtual bool disabled_rw_exported() override {
                auto it = overrides_.find("disabled_rw_exported");
                  if (it != overrides_.end()) {
                      return it->second;
                } else {
                  return server_configurable_flags::GetServerConfigurableFlag(
                      "aconfig_flags.aconfig_test",
                      "com.android.aconfig.test.disabled_rw_exported",
                      "false") == "true";
                }
            }

            virtual void disabled_rw_exported(bool val) override {
                overrides_["disabled_rw_exported"] = val;
            }

            virtual bool disabled_rw_in_other_namespace() override {
                auto it = overrides_.find("disabled_rw_in_other_namespace");
                  if (it != overrides_.end()) {
                      return it->second;
                } else {
                  return server_configurable_flags::GetServerConfigurableFlag(
                      "aconfig_flags.other_namespace",
                      "com.android.aconfig.test.disabled_rw_in_other_namespace",
                      "false") == "true";
                }
            }

            virtual void disabled_rw_in_other_namespace(bool val) override {
                overrides_["disabled_rw_in_other_namespace"] = val;
            }

            virtual bool enabled_fixed_ro() override {
                auto it = overrides_.find("enabled_fixed_ro");
                  if (it != overrides_.end()) {
                      return it->second;
                } else {
                  return true;
                }
            }

            virtual void enabled_fixed_ro(bool val) override {
                overrides_["enabled_fixed_ro"] = val;
            }

            virtual bool enabled_fixed_ro_exported() override {
                auto it = overrides_.find("enabled_fixed_ro_exported");
                  if (it != overrides_.end()) {
                      return it->second;
                } else {
                  return true;
                }
            }

            virtual void enabled_fixed_ro_exported(bool val) override {
                overrides_["enabled_fixed_ro_exported"] = val;
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

            virtual bool enabled_ro_exported() override {
                auto it = overrides_.find("enabled_ro_exported");
                  if (it != overrides_.end()) {
                      return it->second;
                } else {
                  return true;
                }
            }

            virtual void enabled_ro_exported(bool val) override {
                overrides_["enabled_ro_exported"] = val;
            }

            virtual bool enabled_rw() override {
                auto it = overrides_.find("enabled_rw");
                  if (it != overrides_.end()) {
                      return it->second;
                } else {
                  return server_configurable_flags::GetServerConfigurableFlag(
                      "aconfig_flags.aconfig_test",
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


bool com_android_aconfig_test_disabled_rw_exported() {
    return com::android::aconfig::test::disabled_rw_exported();
}

void set_com_android_aconfig_test_disabled_rw_exported(bool val) {
    com::android::aconfig::test::disabled_rw_exported(val);
}


bool com_android_aconfig_test_disabled_rw_in_other_namespace() {
    return com::android::aconfig::test::disabled_rw_in_other_namespace();
}

void set_com_android_aconfig_test_disabled_rw_in_other_namespace(bool val) {
    com::android::aconfig::test::disabled_rw_in_other_namespace(val);
}


bool com_android_aconfig_test_enabled_fixed_ro() {
    return com::android::aconfig::test::enabled_fixed_ro();
}

void set_com_android_aconfig_test_enabled_fixed_ro(bool val) {
    com::android::aconfig::test::enabled_fixed_ro(val);
}

bool com_android_aconfig_test_enabled_fixed_ro_exported() {
    return com::android::aconfig::test::enabled_fixed_ro_exported();
}

void set_com_android_aconfig_test_enabled_fixed_ro_exported(bool val) {
    com::android::aconfig::test::enabled_fixed_ro_exported(val);
}

bool com_android_aconfig_test_enabled_ro() {
    return com::android::aconfig::test::enabled_ro();
}


void set_com_android_aconfig_test_enabled_ro(bool val) {
    com::android::aconfig::test::enabled_ro(val);
}


bool com_android_aconfig_test_enabled_ro_exported() {
    return com::android::aconfig::test::enabled_ro_exported();
}


void set_com_android_aconfig_test_enabled_ro_exported(bool val) {
    com::android::aconfig::test::enabled_ro_exported(val);
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

    const EXPORTED_SOURCE_FILE_EXPECTED: &str = r#"
#include "com_android_aconfig_test.h"
#include <server_configurable_flags/get_flags.h>
#include <vector>

namespace com::android::aconfig::test {

    class flag_provider : public flag_provider_interface {
        public:
            virtual bool disabled_rw_exported() override {
                if (cache_[0] == -1) {
                    cache_[0] = server_configurable_flags::GetServerConfigurableFlag(
                        "aconfig_flags.aconfig_test",
                        "com.android.aconfig.test.disabled_rw_exported",
                        "false") == "true";
                }
                return cache_[0];
            }

            virtual bool enabled_fixed_ro_exported() override {
                if (cache_[1] == -1) {
                    cache_[1] = server_configurable_flags::GetServerConfigurableFlag(
                        "aconfig_flags.aconfig_test",
                        "com.android.aconfig.test.enabled_fixed_ro_exported",
                        "false") == "true";
                }
                return cache_[1];
            }

            virtual bool enabled_ro_exported() override {
                if (cache_[2] == -1) {
                    cache_[2] = server_configurable_flags::GetServerConfigurableFlag(
                        "aconfig_flags.aconfig_test",
                        "com.android.aconfig.test.enabled_ro_exported",
                        "false") == "true";
                }
                return cache_[2];
            }

    private:
        std::vector<int8_t> cache_ = std::vector<int8_t>(3, -1);
    };

    std::unique_ptr<flag_provider_interface> provider_ =
        std::make_unique<flag_provider>();
}

bool com_android_aconfig_test_disabled_rw_exported() {
    return com::android::aconfig::test::disabled_rw_exported();
}

bool com_android_aconfig_test_enabled_fixed_ro_exported() {
    return com::android::aconfig::test::enabled_fixed_ro_exported();
}

bool com_android_aconfig_test_enabled_ro_exported() {
    return com::android::aconfig::test::enabled_ro_exported();
}


"#;

    const FORCE_READ_ONLY_SOURCE_FILE_EXPECTED: &str = r#"
#include "com_android_aconfig_test.h"

namespace com::android::aconfig::test {

    class flag_provider : public flag_provider_interface {
        public:

            virtual bool disabled_ro() override {
                return false;
            }

            virtual bool disabled_rw() override {
                return false;
            }

            virtual bool disabled_rw_in_other_namespace() override {
                return false;
            }

            virtual bool enabled_fixed_ro() override {
                return COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO;
            }

            virtual bool enabled_ro() override {
                return true;
            }

            virtual bool enabled_rw() override {
                return true;
            }
    };

    std::unique_ptr<flag_provider_interface> provider_ =
        std::make_unique<flag_provider>();
}

bool com_android_aconfig_test_disabled_ro() {
    return false;
}

bool com_android_aconfig_test_disabled_rw() {
    return false;
}

bool com_android_aconfig_test_disabled_rw_in_other_namespace() {
    return false;
}

bool com_android_aconfig_test_enabled_fixed_ro() {
    return COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO;
}

bool com_android_aconfig_test_enabled_ro() {
    return true;
}

bool com_android_aconfig_test_enabled_rw() {
    return true;
}

"#;

    const READ_ONLY_EXPORTED_PROD_HEADER_EXPECTED: &str = r#"
#pragma once

#ifndef COM_ANDROID_ACONFIG_TEST
#define COM_ANDROID_ACONFIG_TEST(FLAG) COM_ANDROID_ACONFIG_TEST_##FLAG
#endif

#ifndef COM_ANDROID_ACONFIG_TEST_DISABLED_FIXED_RO
#define COM_ANDROID_ACONFIG_TEST_DISABLED_FIXED_RO false
#endif

#ifndef COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO
#define COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO true
#endif

#ifdef __cplusplus

#include <memory>

namespace com::android::aconfig::test {

class flag_provider_interface {
public:
    virtual ~flag_provider_interface() = default;

    virtual bool disabled_fixed_ro() = 0;

    virtual bool disabled_ro() = 0;

    virtual bool enabled_fixed_ro() = 0;

    virtual bool enabled_ro() = 0;
};

extern std::unique_ptr<flag_provider_interface> provider_;

inline bool disabled_fixed_ro() {
    return COM_ANDROID_ACONFIG_TEST_DISABLED_FIXED_RO;
}

inline bool disabled_ro() {
    return false;
}

inline bool enabled_fixed_ro() {
    return COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO;
}

inline bool enabled_ro() {
    return true;
}
}

extern "C" {
#endif // __cplusplus

bool com_android_aconfig_test_disabled_fixed_ro();

bool com_android_aconfig_test_disabled_ro();

bool com_android_aconfig_test_enabled_fixed_ro();

bool com_android_aconfig_test_enabled_ro();

#ifdef __cplusplus
} // extern "C"
#endif
"#;

    const READ_ONLY_PROD_SOURCE_FILE_EXPECTED: &str = r#"
#include "com_android_aconfig_test.h"

namespace com::android::aconfig::test {

    class flag_provider : public flag_provider_interface {
        public:

            virtual bool disabled_fixed_ro() override {
                return COM_ANDROID_ACONFIG_TEST_DISABLED_FIXED_RO;
            }

            virtual bool disabled_ro() override {
                return false;
            }

            virtual bool enabled_fixed_ro() override {
                return COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO;
            }

            virtual bool enabled_ro() override {
                return true;
            }
    };

    std::unique_ptr<flag_provider_interface> provider_ =
        std::make_unique<flag_provider>();
}

bool com_android_aconfig_test_disabled_fixed_ro() {
    return COM_ANDROID_ACONFIG_TEST_DISABLED_FIXED_RO;
}

bool com_android_aconfig_test_disabled_ro() {
    return false;
}

bool com_android_aconfig_test_enabled_fixed_ro() {
    return COM_ANDROID_ACONFIG_TEST_ENABLED_FIXED_RO;
}

bool com_android_aconfig_test_enabled_ro() {
    return true;
}
"#;

    fn test_generate_cpp_code(
        parsed_flags: ProtoParsedFlags,
        mode: CodegenMode,
        expected_header: &str,
        expected_src: &str,
    ) {
        let modified_parsed_flags =
            crate::commands::modify_parsed_flags_based_on_mode(parsed_flags, mode).unwrap();
        let generated =
            generate_cpp_code(crate::test::TEST_PACKAGE, modified_parsed_flags.into_iter(), mode)
                .unwrap();
        let mut generated_files_map = HashMap::new();
        for file in generated {
            generated_files_map.insert(
                String::from(file.path.to_str().unwrap()),
                String::from_utf8(file.contents).unwrap(),
            );
        }

        let mut target_file_path = String::from("include/com_android_aconfig_test.h");
        assert!(generated_files_map.contains_key(&target_file_path));
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                expected_header,
                generated_files_map.get(&target_file_path).unwrap()
            )
        );

        target_file_path = String::from("com_android_aconfig_test.cc");
        assert!(generated_files_map.contains_key(&target_file_path));
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                expected_src,
                generated_files_map.get(&target_file_path).unwrap()
            )
        );
    }

    #[test]
    fn test_generate_cpp_code_for_prod() {
        let parsed_flags = crate::test::parse_test_flags();
        test_generate_cpp_code(
            parsed_flags,
            CodegenMode::Production,
            EXPORTED_PROD_HEADER_EXPECTED,
            PROD_SOURCE_FILE_EXPECTED,
        );
    }

    #[test]
    fn test_generate_cpp_code_for_test() {
        let parsed_flags = crate::test::parse_test_flags();
        test_generate_cpp_code(
            parsed_flags,
            CodegenMode::Test,
            EXPORTED_TEST_HEADER_EXPECTED,
            TEST_SOURCE_FILE_EXPECTED,
        );
    }

    #[test]
    fn test_generate_cpp_code_for_exported() {
        let parsed_flags = crate::test::parse_test_flags();
        test_generate_cpp_code(
            parsed_flags,
            CodegenMode::Exported,
            EXPORTED_EXPORTED_HEADER_EXPECTED,
            EXPORTED_SOURCE_FILE_EXPECTED,
        );
    }

    #[test]
    fn test_generate_cpp_code_for_force_read_only() {
        let parsed_flags = crate::test::parse_test_flags();
        test_generate_cpp_code(
            parsed_flags,
            CodegenMode::ForceReadOnly,
            EXPORTED_FORCE_READ_ONLY_HEADER_EXPECTED,
            FORCE_READ_ONLY_SOURCE_FILE_EXPECTED,
        );
    }

    #[test]
    fn test_generate_cpp_code_for_read_only_prod() {
        let parsed_flags = crate::test::parse_read_only_test_flags();
        test_generate_cpp_code(
            parsed_flags,
            CodegenMode::Production,
            READ_ONLY_EXPORTED_PROD_HEADER_EXPECTED,
            READ_ONLY_PROD_SOURCE_FILE_EXPECTED,
        );
    }
}
