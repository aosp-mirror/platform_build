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

#[derive(Clone, PartialEq, Debug)]
enum FlagPermission {
    ReadOnly,
    ReadWrite,
}

impl ToString for FlagPermission {
    fn to_string(&self) -> String {
        match &self {
            Self::ReadOnly => "read-only".into(),
            Self::ReadWrite => "read-write".into(),
        }
    }
}

#[derive(Clone, Debug)]
enum ValuePickedFrom {
    Default,
    Server,
}

impl ToString for ValuePickedFrom {
    fn to_string(&self) -> String {
        match &self {
            Self::Default => "default".into(),
            Self::Server => "server".into(),
        }
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

impl ToString for FlagValue {
    fn to_string(&self) -> String {
        match &self {
            Self::Enabled => "enabled".into(),
            Self::Disabled => "disabled".into(),
        }
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
        match self.staged_value {
            Some(v) => format!("(->{})", v.to_string()),
            None => "-".to_string(),
        }
    }
}

trait FlagSource {
    fn list_flags() -> Result<Vec<Flag>>;
    fn override_flag(namespace: &str, qualified_name: &str, value: &str) -> Result<()>;
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
    List,

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
}

struct PaddingInfo {
    longest_flag_col: usize,
    longest_val_col: usize,
    longest_staged_val_col: usize,
    longest_value_picked_from_col: usize,
    longest_permission_col: usize,
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
    ensure!(nix::unistd::Uid::current().is_root(), "must be root to mutate flags");

    let flags_binding = DeviceConfigSource::list_flags()?;
    let flag = flags_binding.iter().find(|f| f.qualified_name() == qualified_name).ok_or(
        anyhow!("no aconfig flag '{qualified_name}'. Does the flag have an .aconfig definition?"),
    )?;

    ensure!(flag.permission == FlagPermission::ReadWrite,
            format!("could not write flag '{qualified_name}', it is read-only for the current release configuration."));

    DeviceConfigSource::override_flag(&flag.namespace, qualified_name, value)?;

    Ok(())
}

fn list() -> Result<String> {
    let flags = DeviceConfigSource::list_flags()?;
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

fn main() {
    let cli = Cli::parse();
    let output = match cli.command {
        Command::List => list().map(Some),
        Command::Enable { qualified_name } => set_flag(&qualified_name, "true").map(|_| None),
        Command::Disable { qualified_name } => set_flag(&qualified_name, "false").map(|_| None),
    };
    match output {
        Ok(Some(text)) => println!("{text}"),
        Ok(None) => (),
        Err(message) => println!("Error: {message}"),
    }
}
