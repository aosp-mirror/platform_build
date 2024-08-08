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

use anyhow::{anyhow, bail, Context, Result};
use clap::{builder::ArgAction, builder::EnumValueParser, Arg, ArgMatches, Command};
use core::any::Any;
use std::fs;
use std::io;
use std::io::Write;
use std::path::{Path, PathBuf};

mod codegen;
mod commands;
mod dump;
mod storage;

use aconfig_storage_file::StorageFileType;
use codegen::CodegenMode;
use dump::DumpFormat;

#[cfg(test)]
mod test;

use commands::{Input, OutputFile};

const HELP_DUMP_FILTER: &str = r#"
Limit which flags to output. If multiple --filter arguments are provided, the output will be
limited to flags that match any of the filters.
"#;

fn cli() -> Command {
    Command::new("aconfig")
        .subcommand_required(true)
        .subcommand(
            Command::new("create-cache")
                .arg(Arg::new("package").long("package").required(true))
                // TODO(b/312769710): Make this argument required.
                .arg(Arg::new("container").long("container"))
                .arg(Arg::new("declarations").long("declarations").action(ArgAction::Append))
                .arg(Arg::new("values").long("values").action(ArgAction::Append))
                .arg(
                    Arg::new("default-permission")
                        .long("default-permission")
                        .value_parser(aconfig_protos::flag_permission::parse_from_str)
                        .default_value(aconfig_protos::flag_permission::to_string(
                            &commands::DEFAULT_FLAG_PERMISSION,
                        )),
                )
                .arg(Arg::new("cache").long("cache").required(true)),
        )
        .subcommand(
            Command::new("create-java-lib")
                .arg(Arg::new("cache").long("cache").required(true))
                .arg(Arg::new("out").long("out").required(true))
                .arg(
                    Arg::new("mode")
                        .long("mode")
                        .value_parser(EnumValueParser::<CodegenMode>::new())
                        .default_value("production"),
                )
                .arg(
                    Arg::new("allow-instrumentation")
                        .long("allow-instrumentation")
                        .value_parser(clap::value_parser!(bool))
                        .default_value("false"),
                ),
        )
        .subcommand(
            Command::new("create-cpp-lib")
                .arg(Arg::new("cache").long("cache").required(true))
                .arg(Arg::new("out").long("out").required(true))
                .arg(
                    Arg::new("mode")
                        .long("mode")
                        .value_parser(EnumValueParser::<CodegenMode>::new())
                        .default_value("production"),
                )
                .arg(
                    Arg::new("allow-instrumentation")
                        .long("allow-instrumentation")
                        .value_parser(clap::value_parser!(bool))
                        .default_value("false"),
                ),
        )
        .subcommand(
            Command::new("create-rust-lib")
                .arg(Arg::new("cache").long("cache").required(true))
                .arg(Arg::new("out").long("out").required(true))
                .arg(
                    Arg::new("allow-instrumentation")
                        .long("allow-instrumentation")
                        .value_parser(clap::value_parser!(bool))
                        .default_value("false"),
                )
                .arg(
                    Arg::new("mode")
                        .long("mode")
                        .value_parser(EnumValueParser::<CodegenMode>::new())
                        .default_value("production"),
                ),
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
            Command::new("dump-cache")
                .alias("dump")
                .arg(Arg::new("cache").long("cache").action(ArgAction::Append))
                .arg(
                    Arg::new("format")
                        .long("format")
                        .value_parser(|s: &str| DumpFormat::try_from(s))
                        .default_value(
                            "{fully_qualified_name} [{container}]: {permission} + {state}",
                        ),
                )
                .arg(
                    Arg::new("filter")
                        .long("filter")
                        .action(ArgAction::Append)
                        .help(HELP_DUMP_FILTER.trim()),
                )
                .arg(Arg::new("dedup").long("dedup").num_args(0).action(ArgAction::SetTrue))
                .arg(Arg::new("out").long("out").default_value("-")),
        )
        .subcommand(
            Command::new("create-storage")
                .arg(
                    Arg::new("container")
                        .long("container")
                        .required(true)
                        .help("The target container for the generated storage file."),
                )
                .arg(
                    Arg::new("file")
                        .long("file")
                        .value_parser(|s: &str| StorageFileType::try_from(s)),
                )
                .arg(Arg::new("cache").long("cache").action(ArgAction::Append).required(true))
                .arg(Arg::new("out").long("out").required(true)),
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

fn get_optional_arg<'a, T>(matches: &'a ArgMatches, arg_name: &str) -> Option<&'a T>
where
    T: Any + Clone + Send + Sync + 'static,
{
    matches.get_one::<T>(arg_name)
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
    let path = root.join(&output_file.path);
    let parent = path
        .parent()
        .ok_or(anyhow!("unable to locate parent of output file {}", path.display()))?;
    fs::create_dir_all(parent)
        .with_context(|| format!("failed to create directory {}", parent.display()))?;
    let mut file =
        fs::File::create(&path).with_context(|| format!("failed to open {}", path.display()))?;
    file.write_all(&output_file.contents)
        .with_context(|| format!("failed to write to {}", path.display()))?;
    Ok(())
}

fn write_output_to_file_or_stdout(path: &str, data: &[u8]) -> Result<()> {
    if path == "-" {
        io::stdout().write_all(data).context("failed to write to stdout")?;
    } else {
        fs::File::create(path)
            .with_context(|| format!("failed to open {}", path))?
            .write_all(data)
            .with_context(|| format!("failed to write to {}", path))?;
    }
    Ok(())
}

fn main() -> Result<()> {
    let matches = cli().get_matches();
    match matches.subcommand() {
        Some(("create-cache", sub_matches)) => {
            let package = get_required_arg::<String>(sub_matches, "package")?;
            let container =
                get_optional_arg::<String>(sub_matches, "container").map(|c| c.as_str());
            let declarations = open_zero_or_more_files(sub_matches, "declarations")?;
            let values = open_zero_or_more_files(sub_matches, "values")?;
            let default_permission = get_required_arg::<aconfig_protos::ProtoFlagPermission>(
                sub_matches,
                "default-permission",
            )?;
            let output = commands::parse_flags(
                package,
                container,
                declarations,
                values,
                *default_permission,
            )
            .context("failed to create cache")?;
            let path = get_required_arg::<String>(sub_matches, "cache")?;
            write_output_to_file_or_stdout(path, &output)?;
        }
        Some(("create-java-lib", sub_matches)) => {
            let cache = open_single_file(sub_matches, "cache")?;
            let mode = get_required_arg::<CodegenMode>(sub_matches, "mode")?;
            let allow_instrumentation =
                get_required_arg::<bool>(sub_matches, "allow-instrumentation")?;
            let generated_files = commands::create_java_lib(cache, *mode, *allow_instrumentation)
                .context("failed to create java lib")?;
            let dir = PathBuf::from(get_required_arg::<String>(sub_matches, "out")?);
            generated_files
                .iter()
                .try_for_each(|file| write_output_file_realtive_to_dir(&dir, file))?;
        }
        Some(("create-cpp-lib", sub_matches)) => {
            let cache = open_single_file(sub_matches, "cache")?;
            let mode = get_required_arg::<CodegenMode>(sub_matches, "mode")?;
            let allow_instrumentation =
                get_required_arg::<bool>(sub_matches, "allow-instrumentation")?;
            let generated_files = commands::create_cpp_lib(cache, *mode, *allow_instrumentation)
                .context("failed to create cpp lib")?;
            let dir = PathBuf::from(get_required_arg::<String>(sub_matches, "out")?);
            generated_files
                .iter()
                .try_for_each(|file| write_output_file_realtive_to_dir(&dir, file))?;
        }
        Some(("create-rust-lib", sub_matches)) => {
            let cache = open_single_file(sub_matches, "cache")?;
            let mode = get_required_arg::<CodegenMode>(sub_matches, "mode")?;
            let allow_instrumentation =
                get_required_arg::<bool>(sub_matches, "allow-instrumentation")?;
            let generated_file = commands::create_rust_lib(cache, *mode, *allow_instrumentation)
                .context("failed to create rust lib")?;
            let dir = PathBuf::from(get_required_arg::<String>(sub_matches, "out")?);
            write_output_file_realtive_to_dir(&dir, &generated_file)?;
        }
        Some(("create-device-config-defaults", sub_matches)) => {
            let cache = open_single_file(sub_matches, "cache")?;
            let output = commands::create_device_config_defaults(cache)
                .context("failed to create device config defaults")?;
            let path = get_required_arg::<String>(sub_matches, "out")?;
            write_output_to_file_or_stdout(path, &output)?;
        }
        Some(("create-device-config-sysprops", sub_matches)) => {
            let cache = open_single_file(sub_matches, "cache")?;
            let output = commands::create_device_config_sysprops(cache)
                .context("failed to create device config sysprops")?;
            let path = get_required_arg::<String>(sub_matches, "out")?;
            write_output_to_file_or_stdout(path, &output)?;
        }
        Some(("dump-cache", sub_matches)) => {
            let input = open_zero_or_more_files(sub_matches, "cache")?;
            let format = get_required_arg::<DumpFormat>(sub_matches, "format")
                .context("failed to dump previously parsed flags")?;
            let filters = sub_matches
                .get_many::<String>("filter")
                .unwrap_or_default()
                .map(String::as_ref)
                .collect::<Vec<_>>();
            let dedup = get_required_arg::<bool>(sub_matches, "dedup")?;
            let output = commands::dump_parsed_flags(input, format.clone(), &filters, *dedup)?;
            let path = get_required_arg::<String>(sub_matches, "out")?;
            write_output_to_file_or_stdout(path, &output)?;
        }
        Some(("create-storage", sub_matches)) => {
            let file = get_required_arg::<StorageFileType>(sub_matches, "file")
                .context("Invalid storage file selection")?;
            let cache = open_zero_or_more_files(sub_matches, "cache")?;
            let container = get_required_arg::<String>(sub_matches, "container")?;
            let path = get_required_arg::<String>(sub_matches, "out")?;
            let output = commands::create_storage(cache, container, file)
                .context("failed to create storage files")?;
            write_output_to_file_or_stdout(path, &output)?;
        }
        _ => unreachable!(),
    }
    Ok(())
}
