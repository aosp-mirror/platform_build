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

//! `aconfig` is a build time tool to manage build time configurations, such as feature flags.

use anyhow::{anyhow, bail, ensure, Result};
use clap::{builder::ArgAction, builder::EnumValueParser, Arg, ArgMatches, Command};
use core::any::Any;
use std::fs;
use std::io;
use std::io::Write;
use std::path::{Path, PathBuf};

mod codegen;
mod codegen_cpp;
mod codegen_java;
mod codegen_rust;
mod commands;
mod protos;

#[cfg(test)]
mod test;

use commands::{CodegenMode, DumpFormat, Input, OutputFile};

fn cli() -> Command {
    Command::new("aconfig")
        .subcommand_required(true)
        .subcommand(
            Command::new("create-cache")
                .arg(Arg::new("package").long("package").required(true))
                .arg(Arg::new("declarations").long("declarations").action(ArgAction::Append))
                .arg(Arg::new("values").long("values").action(ArgAction::Append))
                .arg(Arg::new("cache").long("cache").required(true)),
        )
        .subcommand(
            Command::new("create-java-lib")
                .arg(Arg::new("cache").long("cache").required(true))
                .arg(Arg::new("out").long("out").required(true))
                .arg(
                    Arg::new("mode")
                        .long("mode")
                        .value_parser(EnumValueParser::<commands::CodegenMode>::new())
                        .default_value("production"),
                ),
        )
        .subcommand(
            Command::new("create-cpp-lib")
                .arg(Arg::new("cache").long("cache").required(true))
                .arg(Arg::new("out").long("out").required(true)),
        )
        .subcommand(
            Command::new("create-rust-lib")
                .arg(Arg::new("cache").long("cache").required(true))
                .arg(Arg::new("out").long("out").required(true)),
        )
        .subcommand(
            Command::new("create-device-config-defaults")
                .arg(Arg::new("cache").long("cache").action(ArgAction::Append).required(true))
                .arg(Arg::new("out").long("out").default_value("-")),
        )
        .subcommand(
            Command::new("create-device-config-sysprops")
                .arg(Arg::new("cache").long("cache").action(ArgAction::Append).required(true))
                .arg(Arg::new("out").long("out").default_value("-")),
        )
        .subcommand(
            Command::new("dump")
                .arg(Arg::new("cache").long("cache").action(ArgAction::Append).required(true))
                .arg(
                    Arg::new("format")
                        .long("format")
                        .value_parser(EnumValueParser::<commands::DumpFormat>::new())
                        .default_value("text"),
                )
                .arg(Arg::new("out").long("out").default_value("-")),
        )
}

fn get_required_arg<'a, T>(matches: &'a ArgMatches, arg_name: &str) -> Result<&'a T>
where
    T: Any + Clone + Send + Sync + 'static,
{
    matches
        .get_one::<T>(arg_name)
        .ok_or(anyhow!("internal error: required argument '{}' not found", arg_name))
}

fn open_zero_or_more_files(matches: &ArgMatches, arg_name: &str) -> Result<Vec<Input>> {
    let mut opened_files = vec![];
    for path in matches.get_many::<String>(arg_name).unwrap_or_default() {
        let file = Box::new(fs::File::open(path)?);
        opened_files.push(Input { source: path.to_string(), reader: file });
    }
    Ok(opened_files)
}

fn open_single_file(matches: &ArgMatches, arg_name: &str) -> Result<Input> {
    let Some(path) = matches.get_one::<String>(arg_name) else {
        bail!("missing argument {}", arg_name);
    };
    let file = Box::new(fs::File::open(path)?);
    Ok(Input { source: path.to_string(), reader: file })
}

fn write_output_file_realtive_to_dir(root: &Path, output_file: &OutputFile) -> Result<()> {
    ensure!(
        root.is_dir(),
        "output directory {} does not exist or is not a directory",
        root.display()
    );
    let path = root.join(output_file.path.clone());
    let parent = path
        .parent()
        .ok_or(anyhow!("unable to locate parent of output file {}", path.display()))?;
    fs::create_dir_all(parent)?;
    let mut file = fs::File::create(path)?;
    file.write_all(&output_file.contents)?;
    Ok(())
}

fn write_output_to_file_or_stdout(path: &str, data: &[u8]) -> Result<()> {
    if path == "-" {
        io::stdout().write_all(data)?;
    } else {
        fs::File::create(path)?.write_all(data)?;
    }
    Ok(())
}

fn main() -> Result<()> {
    let matches = cli().get_matches();
    match matches.subcommand() {
        Some(("create-cache", sub_matches)) => {
            let package = get_required_arg::<String>(sub_matches, "package")?;
            let declarations = open_zero_or_more_files(sub_matches, "declarations")?;
            let values = open_zero_or_more_files(sub_matches, "values")?;
            let output = commands::parse_flags(package, declarations, values)?;
            let path = get_required_arg::<String>(sub_matches, "cache")?;
            write_output_to_file_or_stdout(path, &output)?;
        }
        Some(("create-java-lib", sub_matches)) => {
            let cache = open_single_file(sub_matches, "cache")?;
            let mode = get_required_arg::<CodegenMode>(sub_matches, "mode")?;
            let generated_files = commands::create_java_lib(cache, *mode)?;
            let dir = PathBuf::from(get_required_arg::<String>(sub_matches, "out")?);
            generated_files
                .iter()
                .try_for_each(|file| write_output_file_realtive_to_dir(&dir, file))?;
        }
        Some(("create-cpp-lib", sub_matches)) => {
            let cache = open_single_file(sub_matches, "cache")?;
            let generated_file = commands::create_cpp_lib(cache)?;
            let dir = PathBuf::from(get_required_arg::<String>(sub_matches, "out")?);
            write_output_file_realtive_to_dir(&dir, &generated_file)?;
        }
        Some(("create-rust-lib", sub_matches)) => {
            let cache = open_single_file(sub_matches, "cache")?;
            let generated_file = commands::create_rust_lib(cache)?;
            let dir = PathBuf::from(get_required_arg::<String>(sub_matches, "out")?);
            write_output_file_realtive_to_dir(&dir, &generated_file)?;
        }
        Some(("create-device-config-defaults", sub_matches)) => {
            let cache = open_single_file(sub_matches, "cache")?;
            let output = commands::create_device_config_defaults(cache)?;
            let path = get_required_arg::<String>(sub_matches, "out")?;
            write_output_to_file_or_stdout(path, &output)?;
        }
        Some(("create-device-config-sysprops", sub_matches)) => {
            let cache = open_single_file(sub_matches, "cache")?;
            let output = commands::create_device_config_sysprops(cache)?;
            let path = get_required_arg::<String>(sub_matches, "out")?;
            write_output_to_file_or_stdout(path, &output)?;
        }
        Some(("dump", sub_matches)) => {
            let input = open_zero_or_more_files(sub_matches, "cache")?;
            let format = get_required_arg::<DumpFormat>(sub_matches, "format")?;
            let output = commands::dump_parsed_flags(input, *format)?;
            let path = get_required_arg::<String>(sub_matches, "out")?;
            write_output_to_file_or_stdout(path, &output)?;
        }
        _ => unreachable!(),
    }
    Ok(())
}
