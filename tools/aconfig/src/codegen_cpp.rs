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
        for_prod: codegen_mode == CodegenMode::Production,
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
        FileSpec {
            name: &format!("{}_flag_provider.h", header),
            template: match codegen_mode {
                CodegenMode::Production => {
                    include_str!("../templates/cpp_prod_flag_provider.template")
                }
                CodegenMode::Test => include_str!("../templates/cpp_test_flag_provider.template"),
            },
            dir: "",
        },
        FileSpec {
            name: &format!("{}_c.h", header),
            template: include_str!("../templates/c_exported_header.template"),
            dir: "include",
        },
        FileSpec {
            name: &format!("{}_c.cc", header),
            template: include_str!("../templates/c_source_file.template"),
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
    pub for_prod: bool,
    pub class_elements: Vec<ClassElement>,
}

#[derive(Serialize)]
pub struct ClassElement {
    pub readwrite: bool,
    pub default_value: String,
    pub flag_name: String,
    pub uppercase_flag_name: String,
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
        uppercase_flag_name: pf.name().to_string().to_ascii_uppercase(),
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
#ifndef com_android_aconfig_test_HEADER_H
#define com_android_aconfig_test_HEADER_H

#include <string>
#include <memory>

namespace com::android::aconfig::test {
class flag_provider_interface {
public:

    virtual ~flag_provider_interface() = default;

    virtual bool disabled_ro() = 0;

    virtual bool disabled_rw() = 0;

    virtual bool enabled_ro() = 0;

    virtual bool enabled_rw() = 0;

    virtual void override_flag(std::string const&, bool) {}

    virtual void reset_overrides() {}
};

extern std::unique_ptr<flag_provider_interface> provider_;

extern std::string const DISABLED_RO;
extern std::string const DISABLED_RW;
extern std::string const ENABLED_RO;
extern std::string const ENABLED_RW;

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

inline void override_flag(std::string const& name, bool val) {
    return provider_->override_flag(name, val);
}

inline void reset_overrides() {
    return provider_->reset_overrides();
}

}
#endif
"#;

    const EXPORTED_TEST_HEADER_EXPECTED: &str = r#"
#ifndef com_android_aconfig_test_HEADER_H
#define com_android_aconfig_test_HEADER_H

#include <string>
#include <memory>

namespace com::android::aconfig::test {
class flag_provider_interface {
public:

    virtual ~flag_provider_interface() = default;

    virtual bool disabled_ro() = 0;

    virtual bool disabled_rw() = 0;

    virtual bool enabled_ro() = 0;

    virtual bool enabled_rw() = 0;

    virtual void override_flag(std::string const&, bool) {}

    virtual void reset_overrides() {}
};

extern std::unique_ptr<flag_provider_interface> provider_;

extern std::string const DISABLED_RO;
extern std::string const DISABLED_RW;
extern std::string const ENABLED_RO;
extern std::string const ENABLED_RW;

inline bool disabled_ro() {
    return provider_->disabled_ro();
}

inline bool disabled_rw() {
    return provider_->disabled_rw();
}

inline bool enabled_ro() {
    return provider_->enabled_ro();
}

inline bool enabled_rw() {
    return provider_->enabled_rw();
}

inline void override_flag(std::string const& name, bool val) {
    return provider_->override_flag(name, val);
}

inline void reset_overrides() {
    return provider_->reset_overrides();
}

}
#endif
"#;

    const PROD_FLAG_PROVIDER_HEADER_EXPECTED: &str = r#"
#ifndef com_android_aconfig_test_flag_provider_HEADER_H
#define com_android_aconfig_test_flag_provider_HEADER_H

#include "com_android_aconfig_test.h"
#include <server_configurable_flags/get_flags.h>
using namespace server_configurable_flags;

namespace com::android::aconfig::test {
class flag_provider : public flag_provider_interface {
public:

    virtual bool disabled_ro() override {
        return false;
    }

    virtual bool disabled_rw() override {
        return GetServerConfigurableFlag(
            "aconfig_test",
            "com.android.aconfig.test.disabled_rw",
            "false") == "true";
    }

    virtual bool enabled_ro() override {
        return true;
    }

    virtual bool enabled_rw() override {
        return GetServerConfigurableFlag(
            "aconfig_test",
            "com.android.aconfig.test.enabled_rw",
            "true") == "true";
    }
};
}
#endif
"#;

    const TEST_FLAG_PROVIDER_HEADER_EXPECTED: &str = r#"
#ifndef com_android_aconfig_test_flag_provider_HEADER_H
#define com_android_aconfig_test_flag_provider_HEADER_H

#include "com_android_aconfig_test.h"
#include <server_configurable_flags/get_flags.h>
using namespace server_configurable_flags;

#include <unordered_map>
#include <unordered_set>
#include <cassert>

namespace com::android::aconfig::test {
class flag_provider : public flag_provider_interface {
private:
    std::unordered_map<std::string, bool> overrides_;
    std::unordered_set<std::string> flag_names_;

public:

    flag_provider()
        : overrides_(),
          flag_names_() {
        flag_names_.insert(DISABLED_RO);
        flag_names_.insert(DISABLED_RW);
        flag_names_.insert(ENABLED_RO);
        flag_names_.insert(ENABLED_RW);
    }

    virtual bool disabled_ro() override {
        auto it = overrides_.find(DISABLED_RO);
        if (it != overrides_.end()) {
            return it->second;
        } else {
            return false;
        }
    }

    virtual bool disabled_rw() override {
        auto it = overrides_.find(DISABLED_RW);
        if (it != overrides_.end()) {
            return it->second;
        } else {
            return GetServerConfigurableFlag(
                "aconfig_test",
                "com.android.aconfig.test.disabled_rw",
                "false") == "true";
        }
    }

    virtual bool enabled_ro() override {
        auto it = overrides_.find(ENABLED_RO);
        if (it != overrides_.end()) {
            return it->second;
        } else {
            return true;
        }
    }

    virtual bool enabled_rw() override {
        auto it = overrides_.find(ENABLED_RW);
        if (it != overrides_.end()) {
            return it->second;
        } else {
            return GetServerConfigurableFlag(
                "aconfig_test",
                "com.android.aconfig.test.enabled_rw",
                "true") == "true";
        }
    }

    virtual void override_flag(std::string const& flag, bool val) override {
        assert(flag_names_.count(flag));
        overrides_[flag] = val;
    }

    virtual void reset_overrides() override {
        overrides_.clear();
    }
};
}
#endif
"#;

    const SOURCE_FILE_EXPECTED: &str = r#"
#include "com_android_aconfig_test.h"
#include "com_android_aconfig_test_flag_provider.h"

namespace com::android::aconfig::test {

    std::string const DISABLED_RO = "com.android.aconfig.test.disabled_ro";
    std::string const DISABLED_RW = "com.android.aconfig.test.disabled_rw";
    std::string const ENABLED_RO = "com.android.aconfig.test.enabled_ro";
    std::string const ENABLED_RW = "com.android.aconfig.test.enabled_rw";

    std::unique_ptr<flag_provider_interface> provider_ =
        std::make_unique<flag_provider>();
}
"#;

    const C_EXPORTED_HEADER_EXPECTED: &str = r#"
#ifndef com_android_aconfig_test_c_HEADER_H
#define com_android_aconfig_test_c_HEADER_H

#ifdef __cplusplus
extern "C" {
#endif

extern const char* com_android_aconfig_test_DISABLED_RO;
extern const char* com_android_aconfig_test_DISABLED_RW;
extern const char* com_android_aconfig_test_ENABLED_RO;
extern const char* com_android_aconfig_test_ENABLED_RW;

bool com_android_aconfig_test_disabled_ro();

bool com_android_aconfig_test_disabled_rw();

bool com_android_aconfig_test_enabled_ro();

bool com_android_aconfig_test_enabled_rw();

void com_android_aconfig_test_override_flag(const char* name, bool val);

void com_android_aconfig_test_reset_overrides();

#ifdef __cplusplus
}
#endif
#endif
"#;

    const C_SOURCE_FILE_EXPECTED: &str = r#"
#include "com_android_aconfig_test_c.h"
#include "com_android_aconfig_test.h"
#include <string>

const char* com_android_aconfig_test_DISABLED_RO = "com.android.aconfig.test.disabled_ro";
const char* com_android_aconfig_test_DISABLED_RW = "com.android.aconfig.test.disabled_rw";
const char* com_android_aconfig_test_ENABLED_RO = "com.android.aconfig.test.enabled_ro";
const char* com_android_aconfig_test_ENABLED_RW = "com.android.aconfig.test.enabled_rw";

bool com_android_aconfig_test_disabled_ro() {
    return com::android::aconfig::test::disabled_ro();
}

bool com_android_aconfig_test_disabled_rw() {
    return com::android::aconfig::test::disabled_rw();
}

bool com_android_aconfig_test_enabled_ro() {
    return com::android::aconfig::test::enabled_ro();
}

bool com_android_aconfig_test_enabled_rw() {
    return com::android::aconfig::test::enabled_rw();
}

void com_android_aconfig_test_override_flag(const char* name, bool val) {
    com::android::aconfig::test::override_flag(std::string(name), val);
}

void com_android_aconfig_test_reset_overrides() {
    com::android::aconfig::test::reset_overrides();
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

        target_file_path = String::from("com_android_aconfig_test_flag_provider.h");
        assert!(generated_files_map.contains_key(&target_file_path));
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                match mode {
                    CodegenMode::Production => PROD_FLAG_PROVIDER_HEADER_EXPECTED,
                    CodegenMode::Test => TEST_FLAG_PROVIDER_HEADER_EXPECTED,
                },
                generated_files_map.get(&target_file_path).unwrap()
            )
        );

        target_file_path = String::from("com_android_aconfig_test.cc");
        assert!(generated_files_map.contains_key(&target_file_path));
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                SOURCE_FILE_EXPECTED,
                generated_files_map.get(&target_file_path).unwrap()
            )
        );

        target_file_path = String::from("include/com_android_aconfig_test_c.h");
        assert!(generated_files_map.contains_key(&target_file_path));
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                C_EXPORTED_HEADER_EXPECTED,
                generated_files_map.get(&target_file_path).unwrap()
            )
        );

        target_file_path = String::from("com_android_aconfig_test_c.cc");
        assert!(generated_files_map.contains_key(&target_file_path));
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                C_SOURCE_FILE_EXPECTED,
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
