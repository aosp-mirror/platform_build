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

use anyhow::Result;

mod aconfig;
mod protos;

use aconfig::{Flag, Override};

fn main() -> Result<()> {
    let flag = Flag::try_from_text_proto(r#"id: "a" description: "description of a" value: true"#)?;
    println!("{:?}", flag);
    let flags = Flag::try_from_text_proto_list(
        r#"flag { id: "a" description: "description of a" value: true }"#,
    )?;
    println!("{:?}", flags);
    let override_ = Override::try_from_text_proto(r#"id: "foo" value: true"#)?;
    println!("{:?}", override_);
    let overrides = Override::try_from_text_proto_list(r#"override { id: "foo" value: true }"#)?;
    println!("{:?}", overrides);
    Ok(())
}
