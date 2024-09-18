/*
 * Copyright (C) 2024 The Android Open Source Project
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

//! `aflags` is a device binary to read and write aconfig flags.

use anyhow::{anyhow, ensure, Result};
use clap::Parser;

mod device_config_source;
use device_config_source::DeviceConfigSource;

mod aconfig_storage_source;
use aconfig_storage_source::AconfigStorageSource;

mod load_protos;

#[derive(Clone, PartialEq, Debug)]
enum FlagPermission {
    ReadOnly,
    ReadWrite,
}

impl std::fmt::Display for FlagPermission {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}",
            match &self {
                Self::ReadOnly => "read-only",
                Self::ReadWrite => "read-write",
            }
        )
    }
}

#[derive(Clone, Debug)]
enum ValuePickedFrom {
    Default,
    Server,
    Local,
}

impl std::fmt::Display for ValuePickedFrom {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}",
            match &self {
                Self::Default => "default",
                Self::Server => "server",
                Self::Local => "local",
            }
        )
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum FlagValue {
    Enabled,
    Disabled,
}

impl TryFrom<&str> for FlagValue {
    type Error = anyhow::Error;

    fn try_from(value: &str) -> std::result::Result<Self, Self::Error> {
        match value {
            "true" | "enabled" => Ok(Self::Enabled),
            "false" | "disabled" => Ok(Self::Disabled),
            _ => Err(anyhow!("cannot convert string '{}' to FlagValue", value)),
        }
    }
}

impl std::fmt::Display for FlagValue {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}",
            match &self {
                Self::Enabled => "enabled",
                Self::Disabled => "disabled",
            }
        )
    }
}

#[derive(Clone, Debug)]
struct Flag {
    namespace: String,
    name: String,
    package: String,
    container: String,
    value: FlagValue,
    staged_value: Option<FlagValue>,
    permission: FlagPermission,
    value_picked_from: ValuePickedFrom,
}

impl Flag {
    fn qualified_name(&self) -> String {
        format!("{}.{}", self.package, self.name)
    }

    fn display_staged_value(&self) -> String {
        match (&self.permission, self.staged_value) {
            (FlagPermission::ReadOnly, _) => "-".to_string(),
            (FlagPermission::ReadWrite, None) => "-".to_string(),
            (FlagPermission::ReadWrite, Some(v)) => format!("(->{})", v),
        }
    }
}

trait FlagSource {
    fn list_flags() -> Result<Vec<Flag>>;
    fn override_flag(namespace: &str, qualified_name: &str, value: &str) -> Result<()>;
}

enum FlagSourceType {
    DeviceConfig,
    AconfigStorage,
}

const ABOUT_TEXT: &str = "Tool for reading and writing flags.

Rows in the table from the `list` command follow this format:

  package flag_name value provenance permission container

  * `package`: package set for this flag in its .aconfig definition.
  * `flag_name`: flag name, also set in definition.
  * `value`: the value read from the flag.
  * `staged_value`: the value on next boot:
    + `-`: same as current value
    + `(->enabled) flipped to enabled on boot.
    + `(->disabled) flipped to disabled on boot.
  * `provenance`: one of:
    + `default`: the flag value comes from its build-time default.
    + `server`: the flag value comes from a server override.
  * `permission`: read-write or read-only.
  * `container`: the container for the flag, configured in its definition.
";

#[derive(Parser, Debug)]
#[clap(long_about=ABOUT_TEXT)]
struct Cli {
    #[clap(subcommand)]
    command: Command,
}

#[derive(Parser, Debug)]
enum Command {
    /// List all aconfig flags on this device.
    List {
        /// Optionally filter by container name.
        #[clap(short = 'c', long = "container")]
        container: Option<String>,
    },

    /// Enable an aconfig flag on this device, on the next boot.
    Enable {
        /// <package>.<flag_name>
        qualified_name: String,
    },

    /// Disable an aconfig flag on this device, on the next boot.
    Disable {
        /// <package>.<flag_name>
        qualified_name: String,
    },

    /// Display which flag storage backs aconfig flags.
    WhichBacking,
}

struct PaddingInfo {
    longest_flag_col: usize,
    longest_val_col: usize,
    longest_staged_val_col: usize,
    longest_value_picked_from_col: usize,
    longest_permission_col: usize,
}

struct Filter {
    container: Option<String>,
}

impl Filter {
    fn apply(&self, flags: &[Flag]) -> Vec<Flag> {
        flags
            .iter()
            .filter(|flag| match &self.container {
                Some(c) => flag.container == *c,
                None => true,
            })
            .cloned()
            .collect()
    }
}

fn format_flag_row(flag: &Flag, info: &PaddingInfo) -> String {
    let full_name = flag.qualified_name();
    let p0 = info.longest_flag_col + 1;

    let val = flag.value.to_string();
    let p1 = info.longest_val_col + 1;

    let staged_val = flag.display_staged_value();
    let p2 = info.longest_staged_val_col + 1;

    let value_picked_from = flag.value_picked_from.to_string();
    let p3 = info.longest_value_picked_from_col + 1;

    let perm = flag.permission.to_string();
    let p4 = info.longest_permission_col + 1;

    let container = &flag.container;

    format!(
        "{full_name:p0$}{val:p1$}{staged_val:p2$}{value_picked_from:p3$}{perm:p4$}{container}\n"
    )
}

fn set_flag(qualified_name: &str, value: &str) -> Result<()> {
    let flags_binding = DeviceConfigSource::list_flags()?;
    let flag = flags_binding.iter().find(|f| f.qualified_name() == qualified_name).ok_or(
        anyhow!("no aconfig flag '{qualified_name}'. Does the flag have an .aconfig definition?"),
    )?;

    ensure!(flag.permission == FlagPermission::ReadWrite,
            format!("could not write flag '{qualified_name}', it is read-only for the current release configuration."));

    DeviceConfigSource::override_flag(&flag.namespace, qualified_name, value)?;

    Ok(())
}

fn list(source_type: FlagSourceType, container: Option<String>) -> Result<String> {
    let flags_unfiltered = match source_type {
        FlagSourceType::DeviceConfig => DeviceConfigSource::list_flags()?,
        FlagSourceType::AconfigStorage => AconfigStorageSource::list_flags()?,
    };
    let flags = (Filter { container }).apply(&flags_unfiltered);
    let padding_info = PaddingInfo {
        longest_flag_col: flags.iter().map(|f| f.qualified_name().len()).max().unwrap_or(0),
        longest_val_col: flags.iter().map(|f| f.value.to_string().len()).max().unwrap_or(0),
        longest_staged_val_col: flags
            .iter()
            .map(|f| f.display_staged_value().len())
            .max()
            .unwrap_or(0),
        longest_value_picked_from_col: flags
            .iter()
            .map(|f| f.value_picked_from.to_string().len())
            .max()
            .unwrap_or(0),
        longest_permission_col: flags
            .iter()
            .map(|f| f.permission.to_string().len())
            .max()
            .unwrap_or(0),
    };

    let mut result = String::from("");
    for flag in flags {
        let row = format_flag_row(&flag, &padding_info);
        result.push_str(&row);
    }
    Ok(result)
}

fn display_which_backing() -> String {
    if aconfig_flags::auto_generated::enable_only_new_storage() {
        "aconfig_storage".to_string()
    } else {
        "device_config".to_string()
    }
}

fn main() -> Result<()> {
    ensure!(nix::unistd::Uid::current().is_root(), "must be root");

    let cli = Cli::parse();
    let output = match cli.command {
        Command::List { container } => {
            if aconfig_flags::auto_generated::enable_only_new_storage() {
                list(FlagSourceType::AconfigStorage, container)
                    .map_err(|err| anyhow!("storage may not be enabled: {err}"))
                    .map(Some)
            } else {
                list(FlagSourceType::DeviceConfig, container).map(Some)
            }
        }
        Command::Enable { qualified_name } => set_flag(&qualified_name, "true").map(|_| None),
        Command::Disable { qualified_name } => set_flag(&qualified_name, "false").map(|_| None),
        Command::WhichBacking => Ok(Some(display_which_backing())),
    };
    match output {
        Ok(Some(text)) => println!("{text}"),
        Ok(None) => (),
        Err(message) => println!("Error: {message}"),
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_filter_container() {
        let flags = vec![
            Flag {
                namespace: "namespace".to_string(),
                name: "test1".to_string(),
                package: "package".to_string(),
                value: FlagValue::Disabled,
                staged_value: None,
                permission: FlagPermission::ReadWrite,
                value_picked_from: ValuePickedFrom::Default,
                container: "system".to_string(),
            },
            Flag {
                namespace: "namespace".to_string(),
                name: "test2".to_string(),
                package: "package".to_string(),
                value: FlagValue::Disabled,
                staged_value: None,
                permission: FlagPermission::ReadWrite,
                value_picked_from: ValuePickedFrom::Default,
                container: "not_system".to_string(),
            },
            Flag {
                namespace: "namespace".to_string(),
                name: "test3".to_string(),
                package: "package".to_string(),
                value: FlagValue::Disabled,
                staged_value: None,
                permission: FlagPermission::ReadWrite,
                value_picked_from: ValuePickedFrom::Default,
                container: "system".to_string(),
            },
        ];

        assert_eq!((Filter { container: Some("system".to_string()) }).apply(&flags).len(), 2);
    }

    #[test]
    fn test_filter_no_container() {
        let flags = vec![
            Flag {
                namespace: "namespace".to_string(),
                name: "test1".to_string(),
                package: "package".to_string(),
                value: FlagValue::Disabled,
                staged_value: None,
                permission: FlagPermission::ReadWrite,
                value_picked_from: ValuePickedFrom::Default,
                container: "system".to_string(),
            },
            Flag {
                namespace: "namespace".to_string(),
                name: "test2".to_string(),
                package: "package".to_string(),
                value: FlagValue::Disabled,
                staged_value: None,
                permission: FlagPermission::ReadWrite,
                value_picked_from: ValuePickedFrom::Default,
                container: "not_system".to_string(),
            },
            Flag {
                namespace: "namespace".to_string(),
                name: "test3".to_string(),
                package: "package".to_string(),
                value: FlagValue::Disabled,
                staged_value: None,
                permission: FlagPermission::ReadWrite,
                value_picked_from: ValuePickedFrom::Default,
                container: "system".to_string(),
            },
        ];

        assert_eq!((Filter { container: None }).apply(&flags).len(), 3);
    }
}
