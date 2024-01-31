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

use aconfig_protos::ProtoFlagState as State;
use aconfig_protos::ProtoParsedFlags;
use anyhow::{bail, Context, Result};
use regex::Regex;
use std::collections::BTreeMap;
use std::collections::HashMap;
use std::process::Command;
use std::{fs, str};

fn parse_device_config(raw: &str) -> HashMap<String, String> {
    let mut flags = HashMap::new();
    let regex = Regex::new(r"(?m)^([[[:alnum:]]_]+/[[[:alnum:]]_\.]+)=(true|false)$").unwrap();
    for capture in regex.captures_iter(raw) {
        let key = capture.get(1).unwrap().as_str().to_string();
        let value = match capture.get(2).unwrap().as_str() {
            "true" => format!("{:?} (device_config)", State::ENABLED),
            "false" => format!("{:?} (device_config)", State::DISABLED),
            _ => panic!(),
        };
        flags.insert(key, value);
    }
    flags
}

fn xxd(bytes: &[u8]) -> String {
    let n = 8.min(bytes.len());
    let mut v = Vec::with_capacity(n);
    for byte in bytes.iter().take(n) {
        v.push(format!("{:02x}", byte));
    }
    let trailer = match bytes.len() {
        0..=8 => "",
        _ => " ..",
    };
    format!("[{}{}]", v.join(" "), trailer)
}

fn main() -> Result<()> {
    // read device_config
    let output = Command::new("/system/bin/device_config").arg("list").output()?;
    if !output.status.success() {
        let reason = match output.status.code() {
            Some(code) => format!("exit code {}", code),
            None => "terminated by signal".to_string(),
        };
        bail!("failed to execute device_config: {}", reason);
    }
    let dc_stdout = str::from_utf8(&output.stdout)?;
    let device_config_flags = parse_device_config(dc_stdout);

    // read aconfig_flags.pb files
    let mut flags: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for partition in ["system", "system_ext", "product", "vendor"] {
        let path = format!("/{}/etc/aconfig_flags.pb", partition);
        let Ok(bytes) = fs::read(&path) else {
            eprintln!("warning: failed to read {}", path);
            continue;
        };
        let parsed_flags: ProtoParsedFlags = protobuf::Message::parse_from_bytes(&bytes)
            .with_context(|| {
                format!("failed to parse {} ({}, {} byte(s))", path, xxd(&bytes), bytes.len())
            })?;
        for flag in parsed_flags.parsed_flag {
            let key = format!("{}/{}.{}", flag.namespace(), flag.package(), flag.name());
            let value = format!("{:?} + {:?} ({})", flag.permission(), flag.state(), partition);
            flags.entry(key).or_default().push(value);
        }
    }

    // print flags
    for (key, mut value) in flags {
        if let Some(dc_value) = device_config_flags.get(&key) {
            value.push(dc_value.to_string());
        }
        println!("{}: {}", key, value.join(", "));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_device_config() {
        let input = r#"
namespace_one/com.foo.bar.flag_one=true
namespace_one/com.foo.bar.flag_two=false
random_noise;
namespace_two/android.flag_one=true
namespace_two/android.flag_two=nonsense
"#;
        let expected = HashMap::from([
            (
                "namespace_one/com.foo.bar.flag_one".to_string(),
                "ENABLED (device_config)".to_string(),
            ),
            (
                "namespace_one/com.foo.bar.flag_two".to_string(),
                "DISABLED (device_config)".to_string(),
            ),
            ("namespace_two/android.flag_one".to_string(), "ENABLED (device_config)".to_string()),
        ]);
        let actual = parse_device_config(input);
        assert_eq!(expected, actual);
    }

    #[test]
    fn test_xxd() {
        let input = [0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9];
        assert_eq!("[]", &xxd(&input[0..0]));
        assert_eq!("[00]", &xxd(&input[0..1]));
        assert_eq!("[00 01]", &xxd(&input[0..2]));
        assert_eq!("[00 01 02 03 04 05 06]", &xxd(&input[0..7]));
        assert_eq!("[00 01 02 03 04 05 06 07]", &xxd(&input[0..8]));
        assert_eq!("[00 01 02 03 04 05 06 07 ..]", &xxd(&input[0..9]));
        assert_eq!("[00 01 02 03 04 05 06 07 ..]", &xxd(&input));
    }
}
