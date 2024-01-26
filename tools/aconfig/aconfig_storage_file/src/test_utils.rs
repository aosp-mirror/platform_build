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

use anyhow::Result;
use protobuf::Message;
use crate::protos::ProtoStorageFiles;

pub fn get_binary_storage_proto_bytes(text_proto: &str) -> Result<Vec<u8>> {
    let storage_files: ProtoStorageFiles = protobuf::text_format::parse_from_str(text_proto)?;
    let mut binary_proto = Vec::new();
    storage_files.write_to_vec(&mut binary_proto)?;
    Ok(binary_proto)
}
