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

//! `aconfig-storage` is a debugging tool to parse storage files

use aconfig_storage_file::{
    list_flags, list_flags_with_info, read_file_to_bytes, AconfigStorageError, FlagInfoList,
    FlagTable, FlagValueList, PackageTable, StorageFileType,
};
use clap::{builder::ArgAction, Arg, Command};
use serde::Serialize;
use serde_json;
use std::fmt;
use std::fs;
use std::fs::File;
use std::io::Write;

/**
 * Usage Examples
 *
 * Print file:
 * $ aconfig-storage print --file=path/to/flag.map --type=flag_map
 *
 * List flags:
 * $ aconfig-storage list --flag-map=path/to/flag.map \
 * --flag-val=path/to/flag.val --package-map=path/to/package.map
 *
 * Write binary file for testing:
 * $ aconfig-storage print --file=path/to/flag.map --type=flag_map --format=json > flag_map.json
 * $ vim flag_map.json // Manually make updates
 * $ aconfig-storage write-bytes --input-file=flag_map.json --output-file=path/to/flag.map --type=flag_map
 */
fn cli() -> Command {
    Command::new("aconfig-storage")
        .subcommand_required(true)
        .subcommand(
            Command::new("print")
                .arg(Arg::new("file").long("file").required(true).action(ArgAction::Set))
                .arg(
                    Arg::new("type")
                        .long("type")
                        .required(true)
                        .value_parser(|s: &str| StorageFileType::try_from(s)),
                )
                .arg(Arg::new("format").long("format").required(false).action(ArgAction::Set)),
        )
        .subcommand(
            Command::new("list")
                .arg(
                    Arg::new("package-map")
                        .long("package-map")
                        .required(true)
                        .action(ArgAction::Set),
                )
                .arg(Arg::new("flag-map").long("flag-map").required(true).action(ArgAction::Set))
                .arg(Arg::new("flag-val").long("flag-val").required(true).action(ArgAction::Set))
                .arg(
                    Arg::new("flag-info").long("flag-info").required(false).action(ArgAction::Set),
                ),
        )
        .subcommand(
            Command::new("write-bytes")
                // Where to write the output bytes. Suggest to use the StorageFileType names (e.g. flag.map).
                .arg(
                    Arg::new("output-file")
                        .long("output-file")
                        .required(true)
                        .action(ArgAction::Set),
                )
                // Input file should be json.
                .arg(
                    Arg::new("input-file").long("input-file").required(true).action(ArgAction::Set),
                )
                .arg(
                    Arg::new("type")
                        .long("type")
                        .required(true)
                        .value_parser(|s: &str| StorageFileType::try_from(s)),
                ),
        )
}

fn print_storage_file(
    file_path: &str,
    file_type: &StorageFileType,
    as_json: bool,
) -> Result<(), AconfigStorageError> {
    let bytes = read_file_to_bytes(file_path)?;
    match file_type {
        StorageFileType::PackageMap => {
            let package_table = PackageTable::from_bytes(&bytes)?;
            println!("{}", to_print_format(package_table, as_json));
        }
        StorageFileType::FlagMap => {
            let flag_table = FlagTable::from_bytes(&bytes)?;
            println!("{}", to_print_format(flag_table, as_json));
        }
        StorageFileType::FlagVal => {
            let flag_value = FlagValueList::from_bytes(&bytes)?;
            println!("{}", to_print_format(flag_value, as_json));
        }
        StorageFileType::FlagInfo => {
            let flag_info = FlagInfoList::from_bytes(&bytes)?;
            println!("{}", to_print_format(flag_info, as_json));
        }
    }
    Ok(())
}

fn to_print_format<T>(file_contents: T, as_json: bool) -> String
where
    T: Serialize + fmt::Debug,
{
    if as_json {
        serde_json::to_string(&file_contents).unwrap()
    } else {
        format!("{:?}", file_contents)
    }
}

fn main() -> Result<(), AconfigStorageError> {
    let matches = cli().get_matches();
    match matches.subcommand() {
        Some(("print", sub_matches)) => {
            let file_path = sub_matches.get_one::<String>("file").unwrap();
            let file_type = sub_matches.get_one::<StorageFileType>("type").unwrap();
            let format = sub_matches.get_one::<String>("format");
            let as_json: bool = format == Some(&"json".to_string());
            print_storage_file(file_path, file_type, as_json)?
        }
        Some(("list", sub_matches)) => {
            let package_map = sub_matches.get_one::<String>("package-map").unwrap();
            let flag_map = sub_matches.get_one::<String>("flag-map").unwrap();
            let flag_val = sub_matches.get_one::<String>("flag-val").unwrap();
            let flag_info = sub_matches.get_one::<String>("flag-info");
            match flag_info {
                Some(info_file) => {
                    let flags = list_flags_with_info(package_map, flag_map, flag_val, info_file)?;
                    for flag in flags.iter() {
                        println!(
                          "{} {} {} {:?} IsReadWrite: {}, HasServerOverride: {}, HasLocalOverride: {}",
                          flag.package_name, flag.flag_name, flag.flag_value, flag.value_type,
                          flag.is_readwrite, flag.has_server_override, flag.has_local_override,
                      );
                    }
                }
                None => {
                    let flags = list_flags(package_map, flag_map, flag_val)?;
                    for flag in flags.iter() {
                        println!(
                            "{} {} {} {:?}",
                            flag.package_name, flag.flag_name, flag.flag_value, flag.value_type,
                        );
                    }
                }
            }
        }
        // Converts JSON of the file into raw bytes (as is used on-device).
        // Intended to generate/easily update these files for testing.
        Some(("write-bytes", sub_matches)) => {
            let input_file_path = sub_matches.get_one::<String>("input-file").unwrap();
            let input_json = fs::read_to_string(input_file_path).unwrap();

            let file_type = sub_matches.get_one::<StorageFileType>("type").unwrap();
            let output_bytes: Vec<u8>;
            match file_type {
                StorageFileType::FlagVal => {
                    let list: FlagValueList = serde_json::from_str(&input_json).unwrap();
                    output_bytes = list.into_bytes();
                }
                StorageFileType::FlagInfo => {
                    let list: FlagInfoList = serde_json::from_str(&input_json).unwrap();
                    output_bytes = list.into_bytes();
                }
                StorageFileType::FlagMap => {
                    let table: FlagTable = serde_json::from_str(&input_json).unwrap();
                    output_bytes = table.into_bytes();
                }
                StorageFileType::PackageMap => {
                    let table: PackageTable = serde_json::from_str(&input_json).unwrap();
                    output_bytes = table.into_bytes();
                }
            }

            let output_file_path = sub_matches.get_one::<String>("output-file").unwrap();
            let file = File::create(output_file_path);
            if file.is_err() {
                panic!("can't make file");
            }
            let _ = file.unwrap().write_all(&output_bytes);
        }
        _ => unreachable!(),
    }
    Ok(())
}
