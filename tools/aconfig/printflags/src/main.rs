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

//! `printflags` is a device binary to print feature flags.

use aconfig_protos::aconfig::Parsed_flags as ProtoParsedFlags;
use anyhow::Result;
use std::collections::HashMap;
use std::fs;

fn main() -> Result<()> {
    let mut flags: HashMap<String, Vec<String>> = HashMap::new();
    for partition in ["system", "system_ext", "product", "vendor"] {
        let path = format!("/{}/etc/aconfig_flags.pb", partition);
        let Ok(bytes) = fs::read(&path) else {
            eprintln!("warning: failed to read {}", path);
            continue;
        };
        let parsed_flags: ProtoParsedFlags = protobuf::Message::parse_from_bytes(&bytes)?;
        for flag in parsed_flags.parsed_flag {
            let key = format!("{}.{}", flag.package(), flag.name());
            let value = format!("{:?} + {:?} ({})", flag.permission(), flag.state(), partition);
            flags.entry(key).or_default().push(value);
        }
    }
    for (key, value) in flags {
        // TODO: if the flag is READ_WRITE (for any partition), call "device_config get" to obtain
        // the flag's current state, and append value to the output
        println!("{}: {}", key, value.join(", "));
    }
    Ok(())
}
