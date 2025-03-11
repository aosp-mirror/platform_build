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

//! `exported-flag-check` is a tool to ensures that exported flags are used as intended
use anyhow::{ensure, Result};
use clap::Parser;
use std::{collections::HashSet, fs::File, path::PathBuf};

mod utils;

use utils::{
    check_all_exported_flags, extract_flagged_api_flags, get_exported_flags_from_binary_proto,
    read_finalized_flags,
};

const ABOUT: &str = "CCheck Exported Flags

This tool ensures that exported flags are used as intended. Exported flags, marked with
`is_exported: true` in their declaration, are designed to control access to specific API
features. This tool identifies and reports any exported flags that are not currently
associated with an API feature, preventing unnecessary flag proliferation and maintaining
a clear API design.

This tool works as follows:

  - Read API signature files from source tree (*current.txt files) [--api-signature-file]
  - Read the current aconfig flag values from source tree [--parsed-flags-file]
  - Read the previous finalized-flags.txt files from prebuilts/sdk [--finalized-flags-file]
  - Extract the flags slated for API by scanning through the API signature files
  - Merge the found flags with the recorded flags from previous API finalizations
  - Error if exported flags are not in the set
";

#[derive(Parser, Debug)]
#[clap(about=ABOUT)]
struct Cli {
    #[arg(long)]
    parsed_flags_file: PathBuf,

    #[arg(long)]
    api_signature_file: Vec<PathBuf>,

    #[arg(long)]
    finalized_flags_file: PathBuf,
}

fn main() -> Result<()> {
    let args = Cli::parse();

    let mut flags_used_with_flaggedapi_annotation = HashSet::new();
    for path in &args.api_signature_file {
        let file = File::open(path)?;
        let flags = extract_flagged_api_flags(file)?;
        flags_used_with_flaggedapi_annotation.extend(flags);
    }

    let file = File::open(args.parsed_flags_file)?;
    let all_flags = get_exported_flags_from_binary_proto(file)?;

    let file = File::open(args.finalized_flags_file)?;
    let already_finalized_flags = read_finalized_flags(file)?;

    let exported_flags = check_all_exported_flags(
        &flags_used_with_flaggedapi_annotation,
        &all_flags,
        &already_finalized_flags,
    )?;

    println!("{}", exported_flags.join("\n"));

    ensure!(
        exported_flags.is_empty(),
        "Flags {} are exported but not used to guard any API. \
    Exported flag should be used to guard API",
        exported_flags.join(",")
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test() {
        let input = include_bytes!("../tests/api-signature-file.txt");
        let flags_used_with_flaggedapi_annotation = extract_flagged_api_flags(&input[..]).unwrap();

        let input = include_bytes!("../tests/flags.protobuf");
        let all_flags_to_be_finalized = get_exported_flags_from_binary_proto(&input[..]).unwrap();

        let input = include_bytes!("../tests/finalized-flags.txt");
        let already_finalized_flags = read_finalized_flags(&input[..]).unwrap();

        let exported_flags = check_all_exported_flags(
            &flags_used_with_flaggedapi_annotation,
            &all_flags_to_be_finalized,
            &already_finalized_flags,
        )
        .unwrap();

        assert_eq!(1, exported_flags.len());
    }
}
