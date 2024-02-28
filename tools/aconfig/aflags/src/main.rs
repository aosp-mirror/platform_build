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

use anyhow::Result;
use clap::Parser;

mod device_config_source;
use device_config_source::DeviceConfigSource;

#[derive(Clone)]
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

#[derive(Clone)]
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

#[derive(Clone)]
struct Flag {
    namespace: String,
    name: String,
    package: String,
    container: String,
    value: String,
    permission: FlagPermission,
    value_picked_from: ValuePickedFrom,
}

trait FlagSource {
    fn list_flags() -> Result<Vec<Flag>>;
}

const ABOUT_TEXT: &str = "Tool for reading and writing flags.

Rows in the table from the `list` command follow this format:

  package flag_name value provenance permission container

  * `package`: package set for this flag in its .aconfig definition.
  * `flag_name`: flag name, also set in definition.
  * `value`: the value read from the flag.
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
}

struct PaddingInfo {
    longest_package_col: usize,
    longest_name_col: usize,
    longest_val_col: usize,
    longest_value_picked_from_col: usize,
    longest_permission_col: usize,
}

fn format_flag_row(flag: &Flag, info: &PaddingInfo) -> String {
    let pkg = &flag.package;
    let p0 = info.longest_package_col + 1;

    let name = &flag.name;
    let p1 = info.longest_name_col + 1;

    let val = flag.value.to_string();
    let p2 = info.longest_val_col + 1;

    let value_picked_from = flag.value_picked_from.to_string();
    let p3 = info.longest_value_picked_from_col + 1;

    let perm = flag.permission.to_string();
    let p4 = info.longest_permission_col + 1;

    let container = &flag.container;

    format!("{pkg:p0$}{name:p1$}{val:p2$}{value_picked_from:p3$}{perm:p4$}{container}\n")
}

fn list() -> Result<String> {
    let flags = DeviceConfigSource::list_flags()?;
    let padding_info = PaddingInfo {
        longest_package_col: flags.iter().map(|f| f.package.len()).max().unwrap_or(0),
        longest_name_col: flags.iter().map(|f| f.name.len()).max().unwrap_or(0),
        longest_val_col: flags.iter().map(|f| f.value.to_string().len()).max().unwrap_or(0),
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
        Command::List => list(),
    };
    match output {
        Ok(text) => println!("{text}"),
        Err(msg) => println!("Error: {}", msg),
    }
}
