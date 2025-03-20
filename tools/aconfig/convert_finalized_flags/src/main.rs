/*
* Copyright (C) 2025 The Android Open Source Project
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
//! convert_finalized_flags is a build time tool used to convert the finalized
//! flags text files under prebuilts/sdk into structured data (FinalizedFlag
//! struct).
//! This binary is intended to run as part of a genrule to create a json file
//! which is provided to the aconfig binary that creates the codegen.
//! Usage:
//! cargo run -- --flag-files-path path/to/prebuilts/sdk/finalized-flags.txt file2.txt etc
use anyhow::Result;
use clap::Parser;

use convert_finalized_flags::{
    read_extend_file_to_map_using_path, read_files_to_map_using_path, EXTENDED_FLAGS_35_APILEVEL,
};

const ABOUT_TEXT: &str = "Tool for processing finalized-flags.txt files.

These files contain the list of qualified flag names that have been finalized,
each on a newline. The directory of the flag file is the finalized API level.

The output is a json map of API level to set of FinalizedFlag objects. The only
supported use case for this tool is via a genrule at build time for aconfig
codegen.

Args:
* `flag-files-path`: Space-separated list of absolute paths for the finalized
flags files.
";

#[derive(Parser, Debug)]
#[clap(long_about=ABOUT_TEXT, bin_name="convert-finalized-flags")]
struct Cli {
    /// Flags files.
    #[arg(long = "flag_file_path")]
    flag_file_path: Vec<String>,

    #[arg(long)]
    extended_flag_file_path: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let mut finalized_flags_map = read_files_to_map_using_path(cli.flag_file_path)?;
    let extended_flag_set = read_extend_file_to_map_using_path(cli.extended_flag_file_path)?;
    for flag in extended_flag_set {
        finalized_flags_map.insert_if_new(EXTENDED_FLAGS_35_APILEVEL, flag);
    }

    let json_str = serde_json::to_string(&finalized_flags_map)?;
    println!("{}", json_str);
    Ok(())
}
