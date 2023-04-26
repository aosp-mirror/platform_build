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

//! `aconfig` is a build time tool to manage build time configurations, such as feature flags.

use protobuf::text_format::{parse_from_str, ParseError};

mod protos;
use protos::Placeholder;

fn foo() -> Result<String, ParseError> {
    let placeholder = parse_from_str::<Placeholder>(r#"name: "aconfig""#)?;
    Ok(placeholder.name)
}

fn main() {
    println!("{:?}", foo());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_foo() {
        assert_eq!("aconfig", foo().unwrap());
    }

    #[test]
    fn test_binary_protobuf() {
        use protobuf::Message;
        let mut buffer = Vec::new();

        let mut original = Placeholder::new();
        original.name = "test".to_owned();
        original.write_to_writer(&mut buffer).unwrap();

        let copy = Placeholder::parse_from_reader(&mut buffer.as_slice()).unwrap();

        assert_eq!(original, copy);
    }
}
