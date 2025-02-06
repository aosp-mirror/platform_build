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

pub mod cpp;
pub mod java;
pub mod rust;

use aconfig_protos::{is_valid_name_ident, is_valid_package_ident};
use anyhow::{ensure, Result};
use clap::ValueEnum;

pub fn create_device_config_ident(package: &str, flag_name: &str) -> Result<String> {
    ensure!(is_valid_package_ident(package), "bad package");
    ensure!(is_valid_name_ident(flag_name), "bad flag name");
    Ok(format!("{}.{}", package, flag_name))
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
pub enum CodegenMode {
    Exported,
    ForceReadOnly,
    Production,
    Test,
}

impl std::fmt::Display for CodegenMode {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            CodegenMode::Exported => write!(f, "exported"),
            CodegenMode::ForceReadOnly => write!(f, "force-read-only"),
            CodegenMode::Production => write!(f, "production"),
            CodegenMode::Test => write!(f, "test"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_create_device_config_ident() {
        assert_eq!(
            "com.foo.bar.some_flag",
            create_device_config_ident("com.foo.bar", "some_flag").unwrap()
        );
    }
}
