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

use aconfig_protos::{ProtoFlagPermission, ProtoFlagState, ProtoParsedFlag};

use std::collections::HashMap;

use crate::codegen;
use crate::codegen::CodegenMode;
use crate::commands::OutputFile;

pub fn generate_rust_code<I>(
    package: &str,
    flag_ids: HashMap<String, u16>,
    parsed_flags_iter: I,
    codegen_mode: CodegenMode,
    allow_instrumentation: bool,
) -> Result<OutputFile>
where
    I: Iterator<Item = ProtoParsedFlag>,
{
    let template_flags: Vec<TemplateParsedFlag> = parsed_flags_iter
        .map(|pf| TemplateParsedFlag::new(package, flag_ids.clone(), &pf))
        .collect();
    let has_readwrite = template_flags.iter().any(|item| item.readwrite);
    let container = (template_flags.first().expect("zero template flags").container).to_string();
    let context = TemplateContext {
        package: package.to_string(),
        template_flags,
        modules: package.split('.').map(|s| s.to_string()).collect::<Vec<_>>(),
        has_readwrite,
        allow_instrumentation,
        container,
    };
    let mut template = TinyTemplate::new();
    template.add_template(
        "rust_code_gen",
        match codegen_mode {
            CodegenMode::Test => include_str!("../../templates/rust_test.template"),
            CodegenMode::Exported | CodegenMode::ForceReadOnly | CodegenMode::Production => {
                include_str!("../../templates/rust.template")
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
    pub allow_instrumentation: bool,
    pub container: String,
}

#[derive(Serialize)]
struct TemplateParsedFlag {
    pub readwrite: bool,
    pub default_value: String,
    pub name: String,
    pub container: String,
    pub flag_offset: u16,
    pub device_config_namespace: String,
    pub device_config_flag: String,
}

impl TemplateParsedFlag {
    #[allow(clippy::nonminimal_bool)]
    fn new(package: &str, flag_offsets: HashMap<String, u16>, pf: &ProtoParsedFlag) -> Self {
        Self {
            readwrite: pf.permission() == ProtoFlagPermission::READ_WRITE,
            default_value: match pf.state() {
                ProtoFlagState::ENABLED => "true".to_string(),
                ProtoFlagState::DISABLED => "false".to_string(),
            },
            name: pf.name().to_string(),
            container: pf.container().to_string(),
            flag_offset: *flag_offsets.get(pf.name()).expect("didnt find package offset :("),
            device_config_namespace: pf.namespace().to_string(),
            device_config_flag: codegen::create_device_config_ident(package, pf.name())
                .expect("values checked at flag parse time"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const PROD_EXPECTED: &str = r#"
//! codegenerated rust flag lib
use aconfig_storage_read_api::{Mmap, AconfigStorageError, StorageFileType, PackageReadContext, get_mapped_storage_file, get_boolean_flag_value, get_package_read_context};
use std::path::Path;
use std::io::Write;
use log::{log, LevelFilter, Level};

static STORAGE_MIGRATION_MARKER_FILE: &str =
    "/metadata/aconfig_test_missions/mission_1";
static MIGRATION_LOG_TAG: &str = "AconfigTestMission1";

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

    /// query flag enabled_fixed_ro_exported
    pub fn enabled_fixed_ro_exported(&self) -> bool {
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

/// query flag enabled_fixed_ro_exported
#[inline(always)]
pub fn enabled_fixed_ro_exported() -> bool {
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

    const PROD_INSTRUMENTED_EXPECTED: &str = r#"
//! codegenerated rust flag lib
use aconfig_storage_read_api::{Mmap, AconfigStorageError, StorageFileType, PackageReadContext, get_mapped_storage_file, get_boolean_flag_value, get_package_read_context};
use std::path::Path;
use std::io::Write;
use log::{log, LevelFilter, Level};

static STORAGE_MIGRATION_MARKER_FILE: &str =
    "/metadata/aconfig_test_missions/mission_1";
static MIGRATION_LOG_TAG: &str = "AconfigTestMission1";

/// flag provider
pub struct FlagProvider;

lazy_static::lazy_static! {

    static ref PACKAGE_OFFSET: Result<Option<u32>, AconfigStorageError> = unsafe {
        get_mapped_storage_file("system", StorageFileType::PackageMap)
        .and_then(|package_map| get_package_read_context(&package_map, "com.android.aconfig.test"))
        .map(|context| context.map(|c| c.boolean_start_index))
    };

    static ref FLAG_VAL_MAP: Result<Mmap, AconfigStorageError> = unsafe {
        get_mapped_storage_file("system", StorageFileType::FlagVal)
    };
    /// flag value cache for disabled_rw

    static ref CACHED_disabled_rw: bool = {
        let result = flags_rust::GetServerConfigurableFlag(
            "aconfig_flags.aconfig_test",
            "com.android.aconfig.test.disabled_rw",
            "false") == "true";

        if Path::new(STORAGE_MIGRATION_MARKER_FILE).exists() {
            // This will be called multiple times. Subsequent calls after the first are noops.
            logger::init(
                logger::Config::default()
                    .with_tag_on_device(MIGRATION_LOG_TAG)
                    .with_max_level(LevelFilter::Info));

            let aconfig_storage_result = FLAG_VAL_MAP
                .as_ref()
                .map_err(|err| format!("failed to get flag val map: {err}"))
                .and_then(|flag_val_map| {
                    PACKAGE_OFFSET
                        .as_ref()
                        .map_err(|err| format!("failed to get package read offset: {err}"))
                        .and_then(|package_offset| {
                            match package_offset {
                                Some(offset) => {
                                    get_boolean_flag_value(&flag_val_map, offset + 1)
                                        .map_err(|err| format!("failed to get flag: {err}"))
                                },
                                None => Err("no context found for package 'com.android.aconfig.test'".to_string())
                            }
                        })
                    });

            match aconfig_storage_result {
                Ok(storage_result) if storage_result == result => {
                    log!(Level::Info, "AconfigTestMission1: success! flag 'disabled_rw' contained correct value. Legacy storage was {result}, new storage was {storage_result}");
                },
                Ok(storage_result) => {
                    log!(Level::Error, "AconfigTestMission1: error: mismatch for flag 'disabled_rw'. Legacy storage was {result}, new storage was {storage_result}");
                },
                Err(err) => {
                    log!(Level::Error, "AconfigTestMission1: error: {err}")
                }
            }
        }

        result
        };

    /// flag value cache for disabled_rw_exported

    static ref CACHED_disabled_rw_exported: bool = {
        let result = flags_rust::GetServerConfigurableFlag(
            "aconfig_flags.aconfig_test",
            "com.android.aconfig.test.disabled_rw_exported",
            "false") == "true";

        if Path::new(STORAGE_MIGRATION_MARKER_FILE).exists() {
            // This will be called multiple times. Subsequent calls after the first are noops.
            logger::init(
                logger::Config::default()
                    .with_tag_on_device(MIGRATION_LOG_TAG)
                    .with_max_level(LevelFilter::Info));

            let aconfig_storage_result = FLAG_VAL_MAP
                .as_ref()
                .map_err(|err| format!("failed to get flag val map: {err}"))
                .and_then(|flag_val_map| {
                    PACKAGE_OFFSET
                        .as_ref()
                        .map_err(|err| format!("failed to get package read offset: {err}"))
                        .and_then(|package_offset| {
                            match package_offset {
                                Some(offset) => {
                                    get_boolean_flag_value(&flag_val_map, offset + 2)
                                        .map_err(|err| format!("failed to get flag: {err}"))
                                },
                                None => Err("no context found for package 'com.android.aconfig.test'".to_string())
                            }
                        })
                    });

            match aconfig_storage_result {
                Ok(storage_result) if storage_result == result => {
                    log!(Level::Info, "AconfigTestMission1: success! flag 'disabled_rw_exported' contained correct value. Legacy storage was {result}, new storage was {storage_result}");
                },
                Ok(storage_result) => {
                    log!(Level::Error, "AconfigTestMission1: error: mismatch for flag 'disabled_rw_exported'. Legacy storage was {result}, new storage was {storage_result}");
                },
                Err(err) => {
                    log!(Level::Error, "AconfigTestMission1: error: {err}")
                }
            }
        }

        result
        };

    /// flag value cache for disabled_rw_in_other_namespace

    static ref CACHED_disabled_rw_in_other_namespace: bool = {
        let result = flags_rust::GetServerConfigurableFlag(
            "aconfig_flags.other_namespace",
            "com.android.aconfig.test.disabled_rw_in_other_namespace",
            "false") == "true";

        if Path::new(STORAGE_MIGRATION_MARKER_FILE).exists() {
            // This will be called multiple times. Subsequent calls after the first are noops.
            logger::init(
                logger::Config::default()
                    .with_tag_on_device(MIGRATION_LOG_TAG)
                    .with_max_level(LevelFilter::Info));

            let aconfig_storage_result = FLAG_VAL_MAP
                .as_ref()
                .map_err(|err| format!("failed to get flag val map: {err}"))
                .and_then(|flag_val_map| {
                    PACKAGE_OFFSET
                        .as_ref()
                        .map_err(|err| format!("failed to get package read offset: {err}"))
                        .and_then(|package_offset| {
                            match package_offset {
                                Some(offset) => {
                                    get_boolean_flag_value(&flag_val_map, offset + 3)
                                        .map_err(|err| format!("failed to get flag: {err}"))
                                },
                                None => Err("no context found for package 'com.android.aconfig.test'".to_string())
                            }
                        })
                    });

            match aconfig_storage_result {
                Ok(storage_result) if storage_result == result => {
                    log!(Level::Info, "AconfigTestMission1: success! flag 'disabled_rw_in_other_namespace' contained correct value. Legacy storage was {result}, new storage was {storage_result}");
                },
                Ok(storage_result) => {
                    log!(Level::Error, "AconfigTestMission1: error: mismatch for flag 'disabled_rw_in_other_namespace'. Legacy storage was {result}, new storage was {storage_result}");
                },
                Err(err) => {
                    log!(Level::Error, "AconfigTestMission1: error: {err}")
                }
            }
        }

        result
        };

    /// flag value cache for enabled_rw

    static ref CACHED_enabled_rw: bool = {
        let result = flags_rust::GetServerConfigurableFlag(
            "aconfig_flags.aconfig_test",
            "com.android.aconfig.test.enabled_rw",
            "true") == "true";

        if Path::new(STORAGE_MIGRATION_MARKER_FILE).exists() {
            // This will be called multiple times. Subsequent calls after the first are noops.
            logger::init(
                logger::Config::default()
                    .with_tag_on_device(MIGRATION_LOG_TAG)
                    .with_max_level(LevelFilter::Info));

            let aconfig_storage_result = FLAG_VAL_MAP
                .as_ref()
                .map_err(|err| format!("failed to get flag val map: {err}"))
                .and_then(|flag_val_map| {
                    PACKAGE_OFFSET
                        .as_ref()
                        .map_err(|err| format!("failed to get package read offset: {err}"))
                        .and_then(|package_offset| {
                            match package_offset {
                                Some(offset) => {
                                    get_boolean_flag_value(&flag_val_map, offset + 8)
                                        .map_err(|err| format!("failed to get flag: {err}"))
                                },
                                None => Err("no context found for package 'com.android.aconfig.test'".to_string())
                            }
                        })
                    });

            match aconfig_storage_result {
                Ok(storage_result) if storage_result == result => {
                    log!(Level::Info, "AconfigTestMission1: success! flag 'enabled_rw' contained correct value. Legacy storage was {result}, new storage was {storage_result}");
                },
                Ok(storage_result) => {
                    log!(Level::Error, "AconfigTestMission1: error: mismatch for flag 'enabled_rw'. Legacy storage was {result}, new storage was {storage_result}");
                },
                Err(err) => {
                    log!(Level::Error, "AconfigTestMission1: error: {err}")
                }
            }
        }

        result
        };

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

    /// query flag enabled_fixed_ro_exported
    pub fn enabled_fixed_ro_exported(&self) -> bool {
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


    let result = false;
    if !Path::new(STORAGE_MIGRATION_MARKER_FILE).exists() {
        return result;
    }

    // This will be called multiple times. Subsequent calls after the first
    // are noops.
    logger::init(
        logger::Config::default()
            .with_tag_on_device(MIGRATION_LOG_TAG)
            .with_max_level(LevelFilter::Info),
    );

    unsafe {
        let package_map = match get_mapped_storage_file("system", StorageFileType::PackageMap) {
            Ok(file) => file,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'disabled_ro': {err}");
                return result;
            }
        };

        let package_read_context = match get_package_read_context(&package_map, "com.android.aconfig.test") {
            Ok(Some(context)) => context,
            Ok(None) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'disabled_ro': did not get context");
                return result;
            },
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'disabled_ro': {err}");
                return result;
            }
        };
        let flag_val_map = match get_mapped_storage_file("system", StorageFileType::FlagVal) {
            Ok(val_map) => val_map,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'disabled_ro': {err}");
                return result;
            }
        };
        let value = match get_boolean_flag_value(&flag_val_map, 0 + package_read_context.boolean_start_index) {
            Ok(val) => val,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'disabled_ro': {err}");
                return result;
            }
        };

        if result != value {
            log!(Level::Error, "AconfigTestMission1: error: flag mismatch for 'disabled_ro'. Legacy storage was {result}, new storage was {value}");
        } else {
            let default_value = false;
            log!(Level::Info, "AconfigTestMission1: success! flag 'disabled_ro' contained correct value. Legacy storage was {default_value}, new storage was {value}");
        }
    }

    result

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


    let result = true;
    if !Path::new(STORAGE_MIGRATION_MARKER_FILE).exists() {
        return result;
    }

    // This will be called multiple times. Subsequent calls after the first
    // are noops.
    logger::init(
        logger::Config::default()
            .with_tag_on_device(MIGRATION_LOG_TAG)
            .with_max_level(LevelFilter::Info),
    );

    unsafe {
        let package_map = match get_mapped_storage_file("system", StorageFileType::PackageMap) {
            Ok(file) => file,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_fixed_ro': {err}");
                return result;
            }
        };

        let package_read_context = match get_package_read_context(&package_map, "com.android.aconfig.test") {
            Ok(Some(context)) => context,
            Ok(None) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_fixed_ro': did not get context");
                return result;
            },
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_fixed_ro': {err}");
                return result;
            }
        };
        let flag_val_map = match get_mapped_storage_file("system", StorageFileType::FlagVal) {
            Ok(val_map) => val_map,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_fixed_ro': {err}");
                return result;
            }
        };
        let value = match get_boolean_flag_value(&flag_val_map, 4 + package_read_context.boolean_start_index) {
            Ok(val) => val,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_fixed_ro': {err}");
                return result;
            }
        };

        if result != value {
            log!(Level::Error, "AconfigTestMission1: error: flag mismatch for 'enabled_fixed_ro'. Legacy storage was {result}, new storage was {value}");
        } else {
            let default_value = true;
            log!(Level::Info, "AconfigTestMission1: success! flag 'enabled_fixed_ro' contained correct value. Legacy storage was {default_value}, new storage was {value}");
        }
    }

    result

}

/// query flag enabled_fixed_ro_exported
#[inline(always)]
pub fn enabled_fixed_ro_exported() -> bool {


    let result = true;
    if !Path::new(STORAGE_MIGRATION_MARKER_FILE).exists() {
        return result;
    }

    // This will be called multiple times. Subsequent calls after the first
    // are noops.
    logger::init(
        logger::Config::default()
            .with_tag_on_device(MIGRATION_LOG_TAG)
            .with_max_level(LevelFilter::Info),
    );

    unsafe {
        let package_map = match get_mapped_storage_file("system", StorageFileType::PackageMap) {
            Ok(file) => file,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_fixed_ro_exported': {err}");
                return result;
            }
        };

        let package_read_context = match get_package_read_context(&package_map, "com.android.aconfig.test") {
            Ok(Some(context)) => context,
            Ok(None) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_fixed_ro_exported': did not get context");
                return result;
            },
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_fixed_ro_exported': {err}");
                return result;
            }
        };
        let flag_val_map = match get_mapped_storage_file("system", StorageFileType::FlagVal) {
            Ok(val_map) => val_map,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_fixed_ro_exported': {err}");
                return result;
            }
        };
        let value = match get_boolean_flag_value(&flag_val_map, 5 + package_read_context.boolean_start_index) {
            Ok(val) => val,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_fixed_ro_exported': {err}");
                return result;
            }
        };

        if result != value {
            log!(Level::Error, "AconfigTestMission1: error: flag mismatch for 'enabled_fixed_ro_exported'. Legacy storage was {result}, new storage was {value}");
        } else {
            let default_value = true;
            log!(Level::Info, "AconfigTestMission1: success! flag 'enabled_fixed_ro_exported' contained correct value. Legacy storage was {default_value}, new storage was {value}");
        }
    }

    result

}

/// query flag enabled_ro
#[inline(always)]
pub fn enabled_ro() -> bool {


    let result = true;
    if !Path::new(STORAGE_MIGRATION_MARKER_FILE).exists() {
        return result;
    }

    // This will be called multiple times. Subsequent calls after the first
    // are noops.
    logger::init(
        logger::Config::default()
            .with_tag_on_device(MIGRATION_LOG_TAG)
            .with_max_level(LevelFilter::Info),
    );

    unsafe {
        let package_map = match get_mapped_storage_file("system", StorageFileType::PackageMap) {
            Ok(file) => file,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_ro': {err}");
                return result;
            }
        };

        let package_read_context = match get_package_read_context(&package_map, "com.android.aconfig.test") {
            Ok(Some(context)) => context,
            Ok(None) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_ro': did not get context");
                return result;
            },
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_ro': {err}");
                return result;
            }
        };
        let flag_val_map = match get_mapped_storage_file("system", StorageFileType::FlagVal) {
            Ok(val_map) => val_map,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_ro': {err}");
                return result;
            }
        };
        let value = match get_boolean_flag_value(&flag_val_map, 6 + package_read_context.boolean_start_index) {
            Ok(val) => val,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_ro': {err}");
                return result;
            }
        };

        if result != value {
            log!(Level::Error, "AconfigTestMission1: error: flag mismatch for 'enabled_ro'. Legacy storage was {result}, new storage was {value}");
        } else {
            let default_value = true;
            log!(Level::Info, "AconfigTestMission1: success! flag 'enabled_ro' contained correct value. Legacy storage was {default_value}, new storage was {value}");
        }
    }

    result

}

/// query flag enabled_ro_exported
#[inline(always)]
pub fn enabled_ro_exported() -> bool {


    let result = true;
    if !Path::new(STORAGE_MIGRATION_MARKER_FILE).exists() {
        return result;
    }

    // This will be called multiple times. Subsequent calls after the first
    // are noops.
    logger::init(
        logger::Config::default()
            .with_tag_on_device(MIGRATION_LOG_TAG)
            .with_max_level(LevelFilter::Info),
    );

    unsafe {
        let package_map = match get_mapped_storage_file("system", StorageFileType::PackageMap) {
            Ok(file) => file,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_ro_exported': {err}");
                return result;
            }
        };

        let package_read_context = match get_package_read_context(&package_map, "com.android.aconfig.test") {
            Ok(Some(context)) => context,
            Ok(None) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_ro_exported': did not get context");
                return result;
            },
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_ro_exported': {err}");
                return result;
            }
        };
        let flag_val_map = match get_mapped_storage_file("system", StorageFileType::FlagVal) {
            Ok(val_map) => val_map,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_ro_exported': {err}");
                return result;
            }
        };
        let value = match get_boolean_flag_value(&flag_val_map, 7 + package_read_context.boolean_start_index) {
            Ok(val) => val,
            Err(err) => {
                log!(Level::Error, "AconfigTestMission1: error: failed to read flag 'enabled_ro_exported': {err}");
                return result;
            }
        };

        if result != value {
            log!(Level::Error, "AconfigTestMission1: error: flag mismatch for 'enabled_ro_exported'. Legacy storage was {result}, new storage was {value}");
        } else {
            let default_value = true;
            log!(Level::Info, "AconfigTestMission1: success! flag 'enabled_ro_exported' contained correct value. Legacy storage was {default_value}, new storage was {value}");
        }
    }

    result

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

    /// query flag enabled_fixed_ro_exported
    pub fn enabled_fixed_ro_exported(&self) -> bool {
        self.overrides.get("enabled_fixed_ro_exported").copied().unwrap_or(
            true
        )
    }

    /// set flag enabled_fixed_ro_exported
    pub fn set_enabled_fixed_ro_exported(&mut self, val: bool) {
        self.overrides.insert("enabled_fixed_ro_exported", val);
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

/// query flag enabled_fixed_ro_exported
#[inline(always)]
pub fn enabled_fixed_ro_exported() -> bool {
    PROVIDER.lock().unwrap().enabled_fixed_ro_exported()
}

/// set flag enabled_fixed_ro_exported
#[inline(always)]
pub fn set_enabled_fixed_ro_exported(val: bool) {
    PROVIDER.lock().unwrap().set_enabled_fixed_ro_exported(val);
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

    const EXPORTED_EXPECTED: &str = r#"
//! codegenerated rust flag lib
use aconfig_storage_read_api::{Mmap, AconfigStorageError, StorageFileType, PackageReadContext, get_mapped_storage_file, get_boolean_flag_value, get_package_read_context};
use std::path::Path;
use std::io::Write;
use log::{log, LevelFilter, Level};

static STORAGE_MIGRATION_MARKER_FILE: &str =
    "/metadata/aconfig_test_missions/mission_1";
static MIGRATION_LOG_TAG: &str = "AconfigTestMission1";

/// flag provider
pub struct FlagProvider;

lazy_static::lazy_static! {
    /// flag value cache for disabled_rw_exported
    static ref CACHED_disabled_rw_exported: bool = flags_rust::GetServerConfigurableFlag(
        "aconfig_flags.aconfig_test",
        "com.android.aconfig.test.disabled_rw_exported",
        "false") == "true";

    /// flag value cache for enabled_fixed_ro_exported
    static ref CACHED_enabled_fixed_ro_exported: bool = flags_rust::GetServerConfigurableFlag(
        "aconfig_flags.aconfig_test",
        "com.android.aconfig.test.enabled_fixed_ro_exported",
        "false") == "true";

    /// flag value cache for enabled_ro_exported
    static ref CACHED_enabled_ro_exported: bool = flags_rust::GetServerConfigurableFlag(
        "aconfig_flags.aconfig_test",
        "com.android.aconfig.test.enabled_ro_exported",
        "false") == "true";

}

impl FlagProvider {
    /// query flag disabled_rw_exported
    pub fn disabled_rw_exported(&self) -> bool {
        *CACHED_disabled_rw_exported
    }

    /// query flag enabled_fixed_ro_exported
    pub fn enabled_fixed_ro_exported(&self) -> bool {
        *CACHED_enabled_fixed_ro_exported
    }

    /// query flag enabled_ro_exported
    pub fn enabled_ro_exported(&self) -> bool {
        *CACHED_enabled_ro_exported
    }
}

/// flag provider
pub static PROVIDER: FlagProvider = FlagProvider;

/// query flag disabled_rw_exported
#[inline(always)]
pub fn disabled_rw_exported() -> bool {
    PROVIDER.disabled_rw_exported()
}

/// query flag enabled_fixed_ro_exported
#[inline(always)]
pub fn enabled_fixed_ro_exported() -> bool {
    PROVIDER.enabled_fixed_ro_exported()
}

/// query flag enabled_ro_exported
#[inline(always)]
pub fn enabled_ro_exported() -> bool {
    PROVIDER.enabled_ro_exported()
}
"#;

    const FORCE_READ_ONLY_EXPECTED: &str = r#"
//! codegenerated rust flag lib
use aconfig_storage_read_api::{Mmap, AconfigStorageError, StorageFileType, PackageReadContext, get_mapped_storage_file, get_boolean_flag_value, get_package_read_context};
use std::path::Path;
use std::io::Write;
use log::{log, LevelFilter, Level};

static STORAGE_MIGRATION_MARKER_FILE: &str =
    "/metadata/aconfig_test_missions/mission_1";
static MIGRATION_LOG_TAG: &str = "AconfigTestMission1";

/// flag provider
pub struct FlagProvider;

impl FlagProvider {
    /// query flag disabled_ro
    pub fn disabled_ro(&self) -> bool {
        false
    }

    /// query flag disabled_rw
    pub fn disabled_rw(&self) -> bool {
        false
    }

    /// query flag disabled_rw_in_other_namespace
    pub fn disabled_rw_in_other_namespace(&self) -> bool {
        false
    }

    /// query flag enabled_fixed_ro
    pub fn enabled_fixed_ro(&self) -> bool {
        true
    }

    /// query flag enabled_ro
    pub fn enabled_ro(&self) -> bool {
        true
    }

    /// query flag enabled_rw
    pub fn enabled_rw(&self) -> bool {
        true
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
    false
}

/// query flag disabled_rw_in_other_namespace
#[inline(always)]
pub fn disabled_rw_in_other_namespace() -> bool {
    false
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

/// query flag enabled_rw
#[inline(always)]
pub fn enabled_rw() -> bool {
    true
}
"#;
    use crate::commands::assign_flag_ids;

    fn test_generate_rust_code(mode: CodegenMode, allow_instrumentation: bool, expected: &str) {
        let parsed_flags = crate::test::parse_test_flags();
        let modified_parsed_flags =
            crate::commands::modify_parsed_flags_based_on_mode(parsed_flags, mode).unwrap();
        let flag_ids =
            assign_flag_ids(crate::test::TEST_PACKAGE, modified_parsed_flags.iter()).unwrap();
        let generated = generate_rust_code(
            crate::test::TEST_PACKAGE,
            flag_ids,
            modified_parsed_flags.into_iter(),
            mode,
            allow_instrumentation,
        )
        .unwrap();
        assert_eq!("src/lib.rs", format!("{}", generated.path.display()));
        assert_eq!(
            None,
            crate::test::first_significant_code_diff(
                expected,
                &String::from_utf8(generated.contents).unwrap()
            )
        );
    }

    #[test]
    fn test_generate_rust_code_for_prod() {
        test_generate_rust_code(CodegenMode::Production, false, PROD_EXPECTED);
    }

    #[test]
    fn test_generate_rust_code_for_prod_instrumented() {
        test_generate_rust_code(CodegenMode::Production, true, PROD_INSTRUMENTED_EXPECTED);
    }

    #[test]
    fn test_generate_rust_code_for_test() {
        test_generate_rust_code(CodegenMode::Test, false, TEST_EXPECTED);
    }

    #[test]
    fn test_generate_rust_code_for_exported() {
        test_generate_rust_code(CodegenMode::Exported, false, EXPORTED_EXPECTED);
    }

    #[test]
    fn test_generate_rust_code_for_force_read_only() {
        test_generate_rust_code(CodegenMode::ForceReadOnly, false, FORCE_READ_ONLY_EXPECTED);
    }
}
