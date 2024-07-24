/*
 * Copyright (C) 2024 The Android Open Source Project
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

use crate::load_protos;
use crate::{Flag, FlagSource, FlagValue, ValuePickedFrom};

use anyhow::{anyhow, bail, Result};
use regex::Regex;
use std::collections::HashMap;
use std::process::Command;
use std::str;

pub struct DeviceConfigSource {}

fn parse_device_config(raw: &str) -> Result<HashMap<String, FlagValue>> {
    let mut flags = HashMap::new();
    let regex = Regex::new(r"(?m)^([[[:alnum:]]_]+/[[[:alnum:]]_\.]+)=(true|false)$")?;
    for capture in regex.captures_iter(raw) {
        let key =
            capture.get(1).ok_or(anyhow!("invalid device_config output"))?.as_str().to_string();
        let value = FlagValue::try_from(
            capture.get(2).ok_or(anyhow!("invalid device_config output"))?.as_str(),
        )?;
        flags.insert(key, value);
    }
    Ok(flags)
}

fn read_device_config_output(command: &[&str]) -> Result<String> {
    let output = Command::new("/system/bin/device_config").args(command).output()?;
    if !output.status.success() {
        let reason = match output.status.code() {
            Some(code) => {
                let output = str::from_utf8(&output.stdout)?;
                if !output.is_empty() {
                    format!("exit code {code}, output was {output}")
                } else {
                    format!("exit code {code}")
                }
            }
            None => "terminated by signal".to_string(),
        };
        bail!("failed to access flag storage: {}", reason);
    }
    Ok(str::from_utf8(&output.stdout)?.to_string())
}

fn read_device_config_flags() -> Result<HashMap<String, FlagValue>> {
    let list_output = read_device_config_output(&["list"])?;
    parse_device_config(&list_output)
}

/// Parse the list of newline-separated staged flags.
///
/// The output is a newline-sepaarated list of entries which follow this format:
///   `namespace*flagname=value`
///
/// The resulting map maps from `namespace/flagname` to `value`, if a staged flag exists for
/// `namespace/flagname`.
fn parse_staged_flags(raw: &str) -> Result<HashMap<String, FlagValue>> {
    let mut flags = HashMap::new();
    for line in raw.split('\n') {
        match (line.find('*'), line.find('=')) {
            (Some(star_index), Some(equal_index)) => {
                let namespace = &line[..star_index];
                let flag = &line[star_index + 1..equal_index];
                if let Ok(value) = FlagValue::try_from(&line[equal_index + 1..]) {
                    flags.insert(namespace.to_owned() + "/" + flag, value);
                }
            }
            _ => continue,
        };
    }
    Ok(flags)
}

fn read_staged_flags() -> Result<HashMap<String, FlagValue>> {
    let staged_flags_output = read_device_config_output(&["list", "staged"])?;
    parse_staged_flags(&staged_flags_output)
}

fn reconcile(
    pb_flags: &[Flag],
    dc_flags: HashMap<String, FlagValue>,
    staged_flags: HashMap<String, FlagValue>,
) -> Vec<Flag> {
    pb_flags
        .iter()
        .map(|f| {
            let server_override = dc_flags.get(&format!("{}/{}", f.namespace, f.qualified_name()));
            let (value_picked_from, selected_value) = match server_override {
                Some(value) if *value != f.value => (ValuePickedFrom::Server, *value),
                _ => (ValuePickedFrom::Default, f.value),
            };
            Flag { value_picked_from, value: selected_value, ..f.clone() }
        })
        .map(|f| {
            let staged_value = staged_flags
                .get(&format!("{}/{}", f.namespace, f.qualified_name()))
                .map(|value| if *value != f.value { Some(*value) } else { None })
                .unwrap_or(None);
            Flag { staged_value, ..f }
        })
        .collect()
}

impl FlagSource for DeviceConfigSource {
    fn list_flags() -> Result<Vec<Flag>> {
        let pb_flags = load_protos::load()?;
        let dc_flags = read_device_config_flags()?;
        let staged_flags = read_staged_flags()?;

        let flags = reconcile(&pb_flags, dc_flags, staged_flags);
        Ok(flags)
    }

    fn override_flag(namespace: &str, qualified_name: &str, value: &str) -> Result<()> {
        read_device_config_output(&["put", namespace, qualified_name, value]).map(|_| ())
    }
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
            ("namespace_one/com.foo.bar.flag_one".to_string(), FlagValue::Enabled),
            ("namespace_one/com.foo.bar.flag_two".to_string(), FlagValue::Disabled),
            ("namespace_two/android.flag_one".to_string(), FlagValue::Enabled),
        ]);
        let actual = parse_device_config(input).unwrap();
        assert_eq!(expected, actual);
    }
}
