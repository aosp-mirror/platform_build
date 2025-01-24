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
use std::{collections::HashSet, io::Read};

use crate::FlagId;

/// Read a list of flag names. The input is expected to be plain text, with each line containing
/// the name of a single flag.
pub(crate) fn read_finalized_flags<R: Read>(mut reader: R) -> Result<HashSet<FlagId>> {
    let mut contents = String::new();
    reader.read_to_string(&mut contents)?;
    let iter = contents.lines().map(|s| s.to_owned());
    Ok(HashSet::from_iter(iter))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test() {
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
}
