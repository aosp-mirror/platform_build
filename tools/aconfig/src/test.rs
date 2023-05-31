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

#[cfg(test)]
pub mod test_utils {
    use crate::cache::Cache;
    use crate::commands::{Input, Source};

    pub fn create_cache() -> Cache {
        crate::commands::create_cache(
            "com.android.aconfig.test",
            vec![Input {
                source: Source::File("testdata/test.aconfig".to_string()),
                reader: Box::new(include_bytes!("../testdata/test.aconfig").as_slice()),
            }],
            vec![
                Input {
                    source: Source::File("testdata/first.values".to_string()),
                    reader: Box::new(include_bytes!("../testdata/first.values").as_slice()),
                },
                Input {
                    source: Source::File("testdata/test.aconfig".to_string()),
                    reader: Box::new(include_bytes!("../testdata/second.values").as_slice()),
                },
            ],
        )
        .unwrap()
    }
}

#[cfg(test)]
pub use test_utils::*;
