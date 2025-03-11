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

use aconfig_protos::ParsedFlagExt;
use anyhow::{anyhow, Context, Result};
use regex::Regex;
use std::{
    collections::HashSet,
    io::{BufRead, BufReader, Read},
};

pub(crate) type FlagId = String;

/// Grep for all flags used with @FlaggedApi annotations in an API signature file (*current.txt
/// file).
pub(crate) fn extract_flagged_api_flags<R: Read>(mut reader: R) -> Result<HashSet<FlagId>> {
    let mut haystack = String::new();
    reader.read_to_string(&mut haystack)?;
    let regex = Regex::new(r#"(?ms)@FlaggedApi\("(.*?)"\)"#).unwrap();
    let iter = regex.captures_iter(&haystack).map(|cap| cap[1].to_owned());
    Ok(HashSet::from_iter(iter))
}

/// Read a list of flag names. The input is expected to be plain text, with each line containing
/// the name of a single flag.
pub(crate) fn read_finalized_flags<R: Read>(reader: R) -> Result<HashSet<FlagId>> {
    BufReader::new(reader)
        .lines()
        .map(|line_result| line_result.context("Failed to read line from finalized flags file"))
        .collect()
}

/// Parse a ProtoParsedFlags binary protobuf blob and return the fully qualified names of flags
/// have is_exported as true.
pub(crate) fn get_exported_flags_from_binary_proto<R: Read>(
    mut reader: R,
) -> Result<HashSet<FlagId>> {
    let mut buffer = Vec::new();
    reader.read_to_end(&mut buffer)?;
    let parsed_flags = aconfig_protos::parsed_flags::try_from_binary_proto(&buffer)
        .map_err(|_| anyhow!("failed to parse binary proto"))?;
    let iter = parsed_flags
        .parsed_flag
        .into_iter()
        .filter(|flag| flag.is_exported())
        .map(|flag| flag.fully_qualified_name());
    Ok(HashSet::from_iter(iter))
}

fn get_allow_list() -> Result<HashSet<FlagId>> {
    let allow_list: HashSet<FlagId> =
        include_str!("../allow_list.txt").lines().map(|x| x.into()).collect();
    Ok(allow_list)
}

/// Filter out the flags have is_exported as true but not used with @FlaggedApi annotations
/// in the source tree, or in the previously finalized flags set.
pub(crate) fn check_all_exported_flags(
    flags_used_with_flaggedapi_annotation: &HashSet<FlagId>,
    all_flags: &HashSet<FlagId>,
    already_finalized_flags: &HashSet<FlagId>,
) -> Result<Vec<FlagId>> {
    let allow_list = get_allow_list()?;
    let new_flags: Vec<FlagId> = all_flags
        .difference(flags_used_with_flaggedapi_annotation)
        .cloned()
        .collect::<HashSet<_>>()
        .difference(already_finalized_flags)
        .cloned()
        .collect::<HashSet<_>>()
        .difference(&allow_list)
        .cloned()
        .collect();

    Ok(new_flags.into_iter().collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_flagged_api_flags() {
        let api_signature_file = include_bytes!("../tests/api-signature-file.txt");
        let flags = extract_flagged_api_flags(&api_signature_file[..]).unwrap();
        assert_eq!(
            flags,
            HashSet::from_iter(vec![
                "record_finalized_flags.test.foo".to_string(),
                "this.flag.is.not.used".to_string(),
            ])
        );
    }

    #[test]
    fn test_read_finalized_flags() {
        let input = include_bytes!("../tests/finalized-flags.txt");
        let flags = read_finalized_flags(&input[..]).unwrap();
        assert_eq!(
            flags,
            HashSet::from_iter(vec![
                "record_finalized_flags.test.bar".to_string(),
                "record_finalized_flags.test.baz".to_string(),
            ])
        );
    }

    #[test]
    fn test_disabled_or_read_write_flags_are_ignored() {
        let bytes = include_bytes!("../tests/flags.protobuf");
        let flags = get_exported_flags_from_binary_proto(&bytes[..]).unwrap();
        assert_eq!(
            flags,
            HashSet::from_iter(vec![
                "record_finalized_flags.test.foo".to_string(),
                "record_finalized_flags.test.not_enabled".to_string()
            ])
        );
    }
}
