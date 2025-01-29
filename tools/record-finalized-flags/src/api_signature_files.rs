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

use anyhow::Result;
use regex::Regex;
use std::{collections::HashSet, io::Read};

use crate::FlagId;

/// Grep for all flags used with @FlaggedApi annotations in an API signature file (*current.txt
/// file).
pub(crate) fn extract_flagged_api_flags<R: Read>(mut reader: R) -> Result<HashSet<FlagId>> {
    let mut haystack = String::new();
    reader.read_to_string(&mut haystack)?;
    let regex = Regex::new(r#"(?ms)@FlaggedApi\("(.*?)"\)"#).unwrap();
    let iter = regex.captures_iter(&haystack).map(|cap| cap[1].to_owned());
    Ok(HashSet::from_iter(iter))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test() {
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
}
