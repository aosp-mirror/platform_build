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

use crate::codegen;
use crate::commands::{CodegenMode, OutputFile};
use crate::protos::{ProtoFlagPermission, ProtoFlagState, ProtoParsedFlag};

pub fn generate_rust_code<'a, I>(
    package: &str,
    parsed_flags_iter: I,
    codegen_mode: CodegenMode,
) -> Result<OutputFile>
where
    I: Iterator<Item = &'a ProtoParsedFlag>,
{
    let template_flags: Vec<TemplateParsedFlag> =
        parsed_flags_iter.map(|pf| TemplateParsedFlag::new(package, pf)).collect();
    let has_readwrite = template_flags.iter().any(|item| item.readwrite);
    let context = TemplateContext {
        package: package.to_string(),
        template_flags,
        modules: package.split('.').map(|s| s.to_string()).collect::<Vec<_>>(),
        has_readwrite,
    };
    let mut template = TinyTemplate::new();
    template.add_template(
        "rust_code_gen",
        match codegen_mode {
            CodegenMode::Production => include_str!("../../templates/rust_prod.template"),
            CodegenMode::Test => include_str!("../../templates/rust_test.template"),
            CodegenMode::Exported => {
                todo!("exported mode not yet supported for rust, see b/313894653.")
            }
        },
    )?;
    let contents = template.render("rust_code_gen", &context)?;
    let path = ["src", "lib.rs"].iter().collect();
    Ok(OutputFile { contents: contents.into(), path })
}

#[derive(Serialize)]
struct TemplateContext {
    pub package: String,
    pub template_flags: Vec<TemplateParsedFlag>,
    pub modules: Vec<String>,
    pub has_readwrite: bool,
}

#[derive(Serialize)]
struct TemplateParsedFlag {
    pub readwrite: bool,
    pub default_value: String,
    pub name: String,
    pub device_config_namespace: String,
    pub device_config_flag: String,
}

impl TemplateParsedFlag {
    #[allow(clippy::nonminimal_bool)]
    fn new(package: &str, pf: &ProtoParsedFlag) -> Self {
        let template = TemplateParsedFlag {
            readwrite: pf.permission() == ProtoFlagPermission::READ_WRITE,
            default_value: match pf.state() {
                ProtoFlagState::ENABLED => "true".to_string(),
                ProtoFlagState::DISABLED => "false".to_string(),
            },
            name: pf.name().to_string(),
            device_config_namespace: pf.namespace().to_string(),
            device_config_flag: codegen::create_device_config_ident(package, pf.name())
                .expect("values checked at flag parse time"),
        };
        template
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const PROD_EXPECTED: &str = r#"
//! codegenerated rust flag lib

/// flag provider
pub struct FlagProvider;

lazy_static::lazy_static! {
    /// flag value cache for disabled_rw
    static ref CACHED_disabled_rw: bool = flags_rust::GetServerConfigurableFlag(
        "aconfig_flags.aconfig_test",
        "com.android.aconfig.test.disabled_rw",
        "false") == "true";

    /// flag value cache for disabled_rw_exported
    static ref CACHED_disabled_rw_exported: bool = flags_rust::GetServerConfigurableFlag(
        "aconfig_flags.aconfig_test",
        "com.android.aconfig.test.disabled_rw_exported",
        "false") == "true";

    /// flag value cache for disabled_rw_in_other_namespace
    static ref CACHED_disabled_rw_in_other_namespace: bool = flags_rust::GetServerConfigurableFlag(
        "aconfig_flags.other_namespace",
        "com.android.aconfig.test.disabled_rw_in_other_namespace",
        "false") == "true";

    /// flag value cache for enabled_rw
    static ref CACHED_enabled_rw: bool = flags_rust::GetServerConfigurableFlag(
        "aconfig_flags.aconfig_test",
        "com.android.aconfig.test.enabled_rw",
        "true") == "true";

}

impl FlagProvider {
    /// query flag disabled_ro
    pub fn disabled_ro(&self) -> bool {
        false
    }

    /// query flag disabled_rw
    pub fn disabled_rw(&self) -> bool {
        *CACHED_disabled_rw
    }

    /// query flag disabled_rw_exported
    pub fn disabled_rw_exported(&self) -> bool {
        *CACHED_disabled_rw_exported
    }

    /// query flag disabled_rw_in_other_namespace
    pub fn disabled_rw_in_other_namespace(&self) -> bool {
        *CACHED_disabled_rw_in_other_namespace
    }

    /// query flag enabled_fixed_ro
    pub fn enabled_fixed_ro(&self) -> bool {
        true
    }

    /// query flag enabled_ro
    pub fn enabled_ro(&self) -> bool {
        true
    }

    /// query flag enabled_ro_exported
    pub fn enabled_ro_exported(&self) -> bool {
        true
    }

    /// query flag enabled_rw
    pub fn enabled_rw(&self) -> bool {
        *CACHED_enabled_rw
    }
}

/// flag provider
pub static PROVIDER: FlagProvider = FlagProvider;

/// query flag disabled_ro
#[inline(always)]
pub fn disabled_ro() -> bool {
    false
}

/// query flag disabled_rw
#[inline(always)]
pub fn disabled_rw() -> bool {
    PROVIDER.disabled_rw()
}

/// query flag disabled_rw_exported
#[inline(always)]
pub fn disabled_rw_exported() -> bool {
    PROVIDER.disabled_rw_exported()
}

/// query flag disabled_rw_in_other_namespace
#[inline(always)]
pub fn disabled_rw_in_other_namespace() -> bool {
    PROVIDER.disabled_rw_in_other_namespace()
}

/// query flag enabled_fixed_ro
#[inline(always)]
pub fn enabled_fixed_ro() -> bool {
    true
}

/// query flag enabled_ro
#[inline(always)]
pub fn enabled_ro() -> bool {
    true
}

/// query flag enabled_ro_exported
#[inline(always)]
pub fn enabled_ro_exported() -> bool {
    true
}

/// query flag enabled_rw
#[inline(always)]
pub fn enabled_rw() -> bool {
    PROVIDER.enabled_rw()
}
"#;

    const TEST_EXPECTED: &str = r#"
//! codegenerated rust flag lib

use std::collections::BTreeMap;
use std::sync::Mutex;

/// flag provider
pub struct FlagProvider {
    overrides: BTreeMap<&'static str, bool>,
}

impl FlagProvider {
    /// query flag disabled_ro
    pub fn disabled_ro(&self) -> bool {
        self.overrides.get("disabled_ro").copied().unwrap_or(
            false
        )
    }

    /// set flag disabled_ro
    pub fn set_disabled_ro(&mut self, val: bool) {
        self.overrides.insert("disabled_ro", val);
    }

    /// query flag disabled_rw
    pub fn disabled_rw(&self) -> bool {
        self.overrides.get("disabled_rw").copied().unwrap_or(
            flags_rust::GetServerConfigurableFlag(
                "aconfig_flags.aconfig_test",
                "com.android.aconfig.test.disabled_rw",
                "false") == "true"
        )
    }

    /// set flag disabled_rw
    pub fn set_disabled_rw(&mut self, val: bool) {
        self.overrides.insert("disabled_rw", val);
    }

    /// query flag disabled_rw_exported
    pub fn disabled_rw_exported(&self) -> bool {
        self.overrides.get("disabled_rw_exported").copied().unwrap_or(
            flags_rust::GetServerConfigurableFlag(
                "aconfig_flags.aconfig_test",
                "com.android.aconfig.test.disabled_rw_exported",
                "false") == "true"
        )
    }

    /// set flag disabled_rw_exported
    pub fn set_disabled_rw_exported(&mut self, val: bool) {
        self.overrides.insert("disabled_rw_exported", val);
    }

    /// query flag disabled_rw_in_other_namespace
    pub fn disabled_rw_in_other_namespace(&self) -> bool {
        self.overrides.get("disabled_rw_in_other_namespace").copied().unwrap_or(
            flags_rust::GetServerConfigurableFlag(
                "aconfig_flags.other_namespace",
                "com.android.aconfig.test.disabled_rw_in_other_namespace",
                "false") == "true"
        )
    }

    /// set flag disabled_rw_in_other_namespace
    pub fn set_disabled_rw_in_other_namespace(&mut self, val: bool) {
        self.overrides.insert("disabled_rw_in_other_namespace", val);
    }

    /// query flag enabled_fixed_ro
    pub fn enabled_fixed_ro(&self) -> bool {
        self.overrides.get("enabled_fixed_ro").copied().unwrap_or(
            true
        )
    }

    /// set flag enabled_fixed_ro
    pub fn set_enabled_fixed_ro(&mut self, val: bool) {
        self.overrides.insert("enabled_fixed_ro", val);
    }

    /// query flag enabled_ro
    pub fn enabled_ro(&self) -> bool {
        self.overrides.get("enabled_ro").copied().unwrap_or(
            true
        )
    }

    /// set flag enabled_ro
    pub fn set_enabled_ro(&mut self, val: bool) {
        self.overrides.insert("enabled_ro", val);
    }

    /// query flag enabled_ro_exported
    pub fn enabled_ro_exported(&self) -> bool {
        self.overrides.get("enabled_ro_exported").copied().unwrap_or(
            true
        )
    }

    /// set flag enabled_ro_exported
    pub fn set_enabled_ro_exported(&mut self, val: bool) {
        self.overrides.insert("enabled_ro_exported", val);
    }

    /// query flag enabled_rw
    pub fn enabled_rw(&self) -> bool {
        self.overrides.get("enabled_rw").copied().unwrap_or(
            flags_rust::GetServerConfigurableFlag(
                "aconfig_flags.aconfig_test",
                "com.android.aconfig.test.enabled_rw",
                "true") == "true"
        )
    }

    /// set flag enabled_rw
    pub fn set_enabled_rw(&mut self, val: bool) {
        self.overrides.insert("enabled_rw", val);
    }

    /// clear all flag overrides
    pub fn reset_flags(&mut self) {
        self.overrides.clear();
    }
}

/// flag provider
pub static PROVIDER: Mutex<FlagProvider> = Mutex::new(
    FlagProvider {overrides: BTreeMap::new()}
);

/// query flag disabled_ro
#[inline(always)]
pub fn disabled_ro() -> bool {
    PROVIDER.lock().unwrap().disabled_ro()
}

/// set flag disabled_ro
#[inline(always)]
pub fn set_disabled_ro(val: bool) {
    PROVIDER.lock().unwrap().set_disabled_ro(val);
}

/// query flag disabled_rw
#[inline(always)]
pub fn disabled_rw() -> bool {
    PROVIDER.lock().unwrap().disabled_rw()
}

/// set flag disabled_rw
#[inline(always)]
pub fn set_disabled_rw(val: bool) {
    PROVIDER.lock().unwrap().set_disabled_rw(val);
}

/// query flag disabled_rw_exported
#[inline(always)]
pub fn disabled_rw_exported() -> bool {
    PROVIDER.lock().unwrap().disabled_rw_exported()
}

/// set flag disabled_rw_exported
#[inline(always)]
pub fn set_disabled_rw_exported(val: bool) {
    PROVIDER.lock().unwrap().set_disabled_rw_exported(val);
}

/// query flag disabled_rw_in_other_namespace
#[inline(always)]
pub fn disabled_rw_in_other_namespace() -> bool {
    PROVIDER.lock().unwrap().disabled_rw_in_other_namespace()
}

/// set flag disabled_rw_in_other_namespace
#[inline(always)]
pub fn set_disabled_rw_in_other_namespace(val: bool) {
    PROVIDER.lock().unwrap().set_disabled_rw_in_other_namespace(val);
}

/// query flag enabled_fixed_ro
#[inline(always)]
pub fn enabled_fixed_ro() -> bool {
    PROVIDER.lock().unwrap().enabled_fixed_ro()
}

/// set flag enabled_fixed_ro
#[inline(always)]
pub fn set_enabled_fixed_ro(val: bool) {
    PROVIDER.lock().unwrap().set_enabled_fixed_ro(val);
}

/// query flag enabled_ro
#[inline(always)]
pub fn enabled_ro() -> bool {
    PROVIDER.lock().unwrap().enabled_ro()
}

/// set flag enabled_ro
#[inline(always)]
pub fn set_enabled_ro(val: bool) {
    PROVIDER.lock().unwrap().set_enabled_ro(val);
}

/// query flag enabled_ro_exported
#[inline(always)]
pub fn enabled_ro_exported() -> bool {
    PROVIDER.lock().unwrap().enabled_ro_exported()
}

/// set flag enabled_ro_exported
#[inline(always)]
pub fn set_enabled_ro_exported(val: bool) {
    PROVIDER.lock().unwrap().set_enabled_ro_exported(val);
}

/// query flag enabled_rw
#[inline(always)]
pub fn enabled_rw() -> bool {
    PROVIDER.lock().unwrap().enabled_rw()
}

/// set flag enabled_rw
#[inline(always)]
pub fn set_enabled_rw(val: bool) {
    PROVIDER.lock().unwrap().set_enabled_rw(val);
}

/// clear all flag override
pub fn reset_flags() {
    PROVIDER.lock().unwrap().reset_flags()
}
"#;

    fn test_generate_rust_code(mode: CodegenMode) {
        let parsed_flags = crate::test::parse_test_flags();
        let generated =
            generate_rust_code(crate::test::TEST_PACKAGE, parsed_flags.parsed_flag.iter(), mode)
                .unwrap();
        assert_eq!("src/lib.rs", format!("{}", generated.path.display()));
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                match mode {
                    CodegenMode::Production => PROD_EXPECTED,
                    CodegenMode::Test => TEST_EXPECTED,
                    CodegenMode::Exported =>
                        todo!("exported mode not yet supported for rust, see b/313894653."),
                },
                &String::from_utf8(generated.contents).unwrap()
            )
        );
    }

    #[test]
    fn test_generate_rust_code_for_prod() {
        test_generate_rust_code(CodegenMode::Production);
    }

    #[test]
    fn test_generate_rust_code_for_test() {
        test_generate_rust_code(CodegenMode::Test);
    }
}
