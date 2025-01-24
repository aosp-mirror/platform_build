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

//! `record-finalized-flags` is a tool to create a snapshot (intended to be stored in
//! prebuilts/sdk) of the flags used with @FlaggedApi APIs
use anyhow::Result;

fn main() -> Result<()> {
    println!("{:?}", std::env::args());
    Ok(())
}

#[cfg(test)]
mod tests {
    #[test]
    fn test() {}
}
