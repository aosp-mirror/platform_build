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

//! `record-finalized-flags` is a tool to create a snapshot (intended to be stored in
//! prebuilts/sdk) of the flags used with @FlaggedApi APIs
use anyhow::Result;
use clap::Parser;
use std::{collections::HashSet, fs::File, path::PathBuf};

mod api_signature_files;
mod finalized_flags;
mod flag_values;

pub(crate) type FlagId = String;

const ABOUT: &str = "Create a new prebuilts/sdk/<version>/finalized-flags.txt file

The prebuilts/sdk/<version>/finalized-flags.txt files list all aconfig flags that have been used
with @FlaggedApi annotations on APIs that have been finalized. These files are used to prevent
flags from being re-used for new, unfinalized, APIs, and by the aconfig code generation.

This tool works as follows:

  - Read API signature files from source tree (*current.txt files) [--api-signature-file]
  - Read the current aconfig flag values from source tree [--parsed-flags-file]
  - Read the previous finalized-flags.txt files from prebuilts/sdk [--finalized-flags-file]
  - Extract the flags slated for API finalization by scanning through the API signature files for
    flags that are ENABLED and READ_ONLY
  - Merge the found flags with the recorded flags from previous API finalizations
  - Print the set of flags to stdout
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

/// Filter out the ENABLED and READ_ONLY flags used with @FlaggedApi annotations in the source
/// tree, and add those flags to the set of previously finalized flags.
fn calculate_new_finalized_flags(
    flags_used_with_flaggedapi_annotation: &HashSet<FlagId>,
    all_flags_to_be_finalized: &HashSet<FlagId>,
    already_finalized_flags: &HashSet<FlagId>,
) -> HashSet<FlagId> {
    let new_flags: HashSet<_> = flags_used_with_flaggedapi_annotation
        .intersection(all_flags_to_be_finalized)
        .map(|s| s.to_owned())
        .collect();
    already_finalized_flags.union(&new_flags).map(|s| s.to_owned()).collect()
}

fn main() -> Result<()> {
    let args = Cli::parse();

    let mut flags_used_with_flaggedapi_annotation = HashSet::new();
    for path in args.api_signature_file {
        let file = File::open(path)?;
        for flag in api_signature_files::extract_flagged_api_flags(file)?.drain() {
            flags_used_with_flaggedapi_annotation.insert(flag);
        }
    }

    let file = File::open(args.parsed_flags_file)?;
    let all_flags_to_be_finalized = flag_values::get_relevant_flags_from_binary_proto(file)?;

    let file = File::open(args.finalized_flags_file)?;
    let already_finalized_flags = finalized_flags::read_finalized_flags(file)?;

    let mut new_finalized_flags = Vec::from_iter(calculate_new_finalized_flags(
        &flags_used_with_flaggedapi_annotation,
        &all_flags_to_be_finalized,
        &already_finalized_flags,
    ));
    new_finalized_flags.sort();

    println!("{}", new_finalized_flags.join("\n"));

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test() {
        let input = include_bytes!("../tests/api-signature-file.txt");
        let flags_used_with_flaggedapi_annotation =
            api_signature_files::extract_flagged_api_flags(&input[..]).unwrap();

        let input = include_bytes!("../tests/flags.protobuf");
        let all_flags_to_be_finalized =
            flag_values::get_relevant_flags_from_binary_proto(&input[..]).unwrap();

        let input = include_bytes!("../tests/finalized-flags.txt");
        let already_finalized_flags = finalized_flags::read_finalized_flags(&input[..]).unwrap();

        let new_finalized_flags = calculate_new_finalized_flags(
            &flags_used_with_flaggedapi_annotation,
            &all_flags_to_be_finalized,
            &already_finalized_flags,
        );

        assert_eq!(
            new_finalized_flags,
            HashSet::from_iter(vec![
                "record_finalized_flags.test.foo".to_string(),
                "record_finalized_flags.test.bar".to_string(),
                "record_finalized_flags.test.baz".to_string(),
            ])
        );
    }
}
