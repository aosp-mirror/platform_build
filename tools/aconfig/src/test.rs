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
    use itertools;

    pub fn create_cache() -> Cache {
        crate::commands::create_cache(
            "com.android.aconfig.test",
            vec![Input {
                source: Source::File("tests/test.aconfig".to_string()),
                reader: Box::new(include_bytes!("../tests/test.aconfig").as_slice()),
            }],
            vec![
                Input {
                    source: Source::File("tests/first.values".to_string()),
                    reader: Box::new(include_bytes!("../tests/first.values").as_slice()),
                },
                Input {
                    source: Source::File("tests/test.aconfig".to_string()),
                    reader: Box::new(include_bytes!("../tests/second.values").as_slice()),
                },
            ],
        )
        .unwrap()
    }

    pub fn first_significant_code_diff(a: &str, b: &str) -> Option<String> {
        let a = a.lines().map(|line| line.trim_start()).filter(|line| !line.is_empty());
        let b = b.lines().map(|line| line.trim_start()).filter(|line| !line.is_empty());
        match itertools::diff_with(a, b, |left, right| left == right) {
            Some(itertools::Diff::FirstMismatch(_, mut left, mut right)) => {
                Some(format!("'{}' vs '{}'", left.next().unwrap(), right.next().unwrap()))
            }
            Some(itertools::Diff::Shorter(_, mut left)) => {
                Some(format!("LHS trailing data: '{}'", left.next().unwrap()))
            }
            Some(itertools::Diff::Longer(_, mut right)) => {
                Some(format!("RHS trailing data: '{}'", right.next().unwrap()))
            }
            None => None,
        }
    }

    #[test]
    fn test_first_significant_code_diff() {
        assert!(first_significant_code_diff("", "").is_none());
        assert!(first_significant_code_diff("   a", "\n\na\n").is_none());
        let a = r#"
        public class A {
            private static final String FOO = "FOO";
            public static void main(String[] args) {
                System.out.println("FOO=" + FOO);
            }
        }
        "#;
        let b = r#"
        public class A {
            private static final String FOO = "BAR";
            public static void main(String[] args) {
                System.out.println("foo=" + FOO);
            }
        }
        "#;
        assert_eq!(Some(r#"'private static final String FOO = "FOO";' vs 'private static final String FOO = "BAR";'"#.to_string()), first_significant_code_diff(a, b));
        assert_eq!(
            Some("LHS trailing data: 'b'".to_string()),
            first_significant_code_diff("a\nb", "a")
        );
        assert_eq!(
            Some("RHS trailing data: 'b'".to_string()),
            first_significant_code_diff("a", "a\nb")
        );
    }
}

#[cfg(test)]
pub use test_utils::*;
