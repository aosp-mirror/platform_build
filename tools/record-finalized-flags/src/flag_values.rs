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

use aconfig_protos::{ParsedFlagExt, ProtoFlagPermission, ProtoFlagState};
use anyhow::{anyhow, Result};
use std::{collections::HashSet, io::Read};

use crate::FlagId;

/// Parse a ProtoParsedFlags binary protobuf blob and return the fully qualified names of flags
/// that are slated for API finalization (i.e. are both ENABLED and READ_ONLY).
pub(crate) fn get_relevant_flags_from_binary_proto<R: Read>(
    mut reader: R,
) -> Result<HashSet<FlagId>> {
    let mut buffer = Vec::new();
    reader.read_to_end(&mut buffer)?;
    let parsed_flags = aconfig_protos::parsed_flags::try_from_binary_proto(&buffer)
        .map_err(|_| anyhow!("failed to parse binary proto"))?;
    let iter = parsed_flags
        .parsed_flag
        .into_iter()
        .filter(|flag| {
            flag.state() == ProtoFlagState::ENABLED
                && flag.permission() == ProtoFlagPermission::READ_ONLY
        })
        .map(|flag| flag.fully_qualified_name());
    Ok(HashSet::from_iter(iter))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_disabled_or_read_write_flags_are_ignored() {
        let bytes = include_bytes!("../tests/flags.protobuf");
        let flags = get_relevant_flags_from_binary_proto(&bytes[..]).unwrap();
        assert_eq!(flags, HashSet::from_iter(vec!["record_finalized_flags.test.foo".to_string()]));
    }
}
