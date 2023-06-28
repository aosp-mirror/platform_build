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

use crate::codegen;
use crate::commands::OutputFile;
use crate::protos::{ProtoFlagPermission, ProtoFlagState, ProtoParsedFlag};

pub fn generate_cpp_code<'a, I>(package: &str, parsed_flags_iter: I) -> Result<OutputFile>
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

    #[test]
    fn test_generate_cpp_code() {
        let parsed_flags = crate::test::parse_test_flags();
        let generated =
            generate_cpp_code(crate::test::TEST_PACKAGE, parsed_flags.parsed_flag.iter()).unwrap();
        assert_eq!("aconfig/com_android_aconfig_test.h", format!("{}", generated.path.display()));
        let expected = r#"
#ifndef com_android_aconfig_test_HEADER_H
#define com_android_aconfig_test_HEADER_H
#include <server_configurable_flags/get_flags.h>

using namespace server_configurable_flags;

namespace com::android::aconfig::test {
    static const bool disabled_ro() {
        return false;
    }

    static const bool disabled_rw() {
        return GetServerConfigurableFlag(
            "aconfig_test",
            "com.android.aconfig.test.disabled_rw",
            "false") == "true";
    }

    static const bool enabled_ro() {
        return true;
    }

    static const bool enabled_rw() {
        return GetServerConfigurableFlag(
            "aconfig_test",
            "com.android.aconfig.test.enabled_rw",
            "true") == "true";
    }
}
#endif
"#;
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                expected,
                &String::from_utf8(generated.contents).unwrap()
            )
        );
    }
}
