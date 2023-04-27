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

use anyhow::Result;
use clap::{builder::ArgAction, builder::EnumValueParser, Arg, Command};
use std::fs;

mod aconfig;
mod cache;
mod commands;
mod protos;

use crate::cache::Cache;
use commands::{Input, Source};

fn cli() -> Command {
    Command::new("aconfig")
        .subcommand_required(true)
        .subcommand(
            Command::new("create-cache")
                .arg(Arg::new("aconfig").long("aconfig").action(ArgAction::Append))
                .arg(Arg::new("override").long("override").action(ArgAction::Append))
                .arg(Arg::new("cache").long("cache").required(true)),
        )
        .subcommand(
            Command::new("dump").arg(Arg::new("cache").long("cache").required(true)).arg(
                Arg::new("format")
                    .long("format")
                    .value_parser(EnumValueParser::<commands::Format>::new())
                    .default_value("text"),
            ),
        )
}

fn main() -> Result<()> {
    let matches = cli().get_matches();
    match matches.subcommand() {
        Some(("create-cache", sub_matches)) => {
            let mut aconfigs = vec![];
            for path in
                sub_matches.get_many::<String>("aconfig").unwrap_or_default().collect::<Vec<_>>()
            {
                let file = Box::new(fs::File::open(path)?);
                aconfigs.push(Input { source: Source::File(path.to_string()), reader: file });
            }
            let mut overrides = vec![];
            for path in
                sub_matches.get_many::<String>("override").unwrap_or_default().collect::<Vec<_>>()
            {
                let file = Box::new(fs::File::open(path)?);
                overrides.push(Input { source: Source::File(path.to_string()), reader: file });
            }
            let cache = commands::create_cache(aconfigs, overrides)?;
            let path = sub_matches.get_one::<String>("cache").unwrap();
            let file = fs::File::create(path)?;
            cache.write_to_writer(file)?;
        }
        Some(("dump", sub_matches)) => {
            let path = sub_matches.get_one::<String>("cache").unwrap();
            let file = fs::File::open(path)?;
            let cache = Cache::read_from_reader(file)?;
            let format = sub_matches.get_one("format").unwrap();
            commands::dump_cache(cache, *format)?;
        }
        _ => unreachable!(),
    }
    Ok(())
}
