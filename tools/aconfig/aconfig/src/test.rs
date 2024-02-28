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
pub use test_utils::*;

#[cfg(test)]
pub mod test_utils {
    use crate::commands::Input;
    use aconfig_protos::ProtoParsedFlags;
    use itertools;

    pub const TEST_PACKAGE: &str = "com.android.aconfig.test";

    pub const TEST_FLAGS_TEXTPROTO: &str = r#"
parsed_flag {
  package: "com.android.aconfig.test"
  name: "disabled_ro"
  namespace: "aconfig_test"
  description: "This flag is DISABLED + READ_ONLY"
  bug: "123"
  state: DISABLED
  permission: READ_ONLY
  trace {
    source: "tests/test.aconfig"
    state: DISABLED
    permission: READ_WRITE
  }
  trace {
    source: "tests/first.values"
    state: DISABLED
    permission: READ_ONLY
  }
  is_fixed_read_only: false
  is_exported: false
  container: "system"
  metadata {
    purpose: PURPOSE_UNSPECIFIED
  }
}
parsed_flag {
  package: "com.android.aconfig.test"
  name: "disabled_rw"
  namespace: "aconfig_test"
  description: "This flag is DISABLED + READ_WRITE"
  bug: "456"
  state: DISABLED
  permission: READ_WRITE
  trace {
    source: "tests/test.aconfig"
    state: DISABLED
    permission: READ_WRITE
  }
  is_fixed_read_only: false
  is_exported: false
  container: "system"
  metadata {
    purpose: PURPOSE_UNSPECIFIED
  }
}
parsed_flag {
  package: "com.android.aconfig.test"
  name: "disabled_rw_exported"
  namespace: "aconfig_test"
  description: "This flag is DISABLED + READ_WRITE and exported"
  bug: "111"
  state: DISABLED
  permission: READ_WRITE
  trace {
    source: "tests/test.aconfig"
    state: DISABLED
    permission: READ_WRITE
  }
  trace {
    source: "tests/first.values"
    state: DISABLED
    permission: READ_WRITE
  }
  is_fixed_read_only: false
  is_exported: true
  container: "system"
  metadata {
    purpose: PURPOSE_UNSPECIFIED
  }
}
parsed_flag {
  package: "com.android.aconfig.test"
  name: "disabled_rw_in_other_namespace"
  namespace: "other_namespace"
  description: "This flag is DISABLED + READ_WRITE, and is defined in another namespace"
  bug: "999"
  state: DISABLED
  permission: READ_WRITE
  trace {
    source: "tests/test.aconfig"
    state: DISABLED
    permission: READ_WRITE
  }
  trace {
    source: "tests/first.values"
    state: DISABLED
    permission: READ_WRITE
  }
  is_fixed_read_only: false
  is_exported: false
  container: "system"
  metadata {
    purpose: PURPOSE_UNSPECIFIED
  }
}
parsed_flag {
  package: "com.android.aconfig.test"
  name: "enabled_fixed_ro"
  namespace: "aconfig_test"
  description: "This flag is fixed READ_ONLY + ENABLED"
  bug: ""
  state: ENABLED
  permission: READ_ONLY
  trace {
    source: "tests/test.aconfig"
    state: DISABLED
    permission: READ_ONLY
  }
  trace {
    source: "tests/first.values"
    state: ENABLED
    permission: READ_ONLY
  }
  is_fixed_read_only: true
  is_exported: false
  container: "system"
  metadata {
    purpose: PURPOSE_UNSPECIFIED
  }
}
parsed_flag {
  package: "com.android.aconfig.test"
  name: "enabled_fixed_ro_exported"
  namespace: "aconfig_test"
  description: "This flag is fixed ENABLED + READ_ONLY and exported"
  bug: "111"
  state: ENABLED
  permission: READ_ONLY
  trace {
    source: "tests/test.aconfig"
    state: DISABLED
    permission: READ_ONLY
  }
  trace {
    source: "tests/first.values"
    state: ENABLED
    permission: READ_ONLY
  }
  is_fixed_read_only: true
  is_exported: true
  container: "system"
  metadata {
    purpose: PURPOSE_UNSPECIFIED
  }
}
parsed_flag {
  package: "com.android.aconfig.test"
  name: "enabled_ro"
  namespace: "aconfig_test"
  description: "This flag is ENABLED + READ_ONLY"
  bug: "abc"
  state: ENABLED
  permission: READ_ONLY
  trace {
    source: "tests/test.aconfig"
    state: DISABLED
    permission: READ_WRITE
  }
  trace {
    source: "tests/first.values"
    state: DISABLED
    permission: READ_WRITE
  }
  trace {
    source: "tests/second.values"
    state: ENABLED
    permission: READ_ONLY
  }
  is_fixed_read_only: false
  is_exported: false
  container: "system"
  metadata {
    purpose: PURPOSE_BUGFIX
  }
}
parsed_flag {
  package: "com.android.aconfig.test"
  name: "enabled_ro_exported"
  namespace: "aconfig_test"
  description: "This flag is ENABLED + READ_ONLY and exported"
  bug: "111"
  state: ENABLED
  permission: READ_ONLY
  trace {
    source: "tests/test.aconfig"
    state: DISABLED
    permission: READ_WRITE
  }
  trace {
    source: "tests/first.values"
    state: ENABLED
    permission: READ_ONLY
  }
  is_fixed_read_only: false
  is_exported: true
  container: "system"
  metadata {
    purpose: PURPOSE_UNSPECIFIED
  }
}
parsed_flag {
  package: "com.android.aconfig.test"
  name: "enabled_rw"
  namespace: "aconfig_test"
  description: "This flag is ENABLED + READ_WRITE"
  bug: ""
  state: ENABLED
  permission: READ_WRITE
  trace {
    source: "tests/test.aconfig"
    state: DISABLED
    permission: READ_WRITE
  }
  trace {
    source: "tests/first.values"
    state: ENABLED
    permission: READ_WRITE
  }
  is_fixed_read_only: false
  is_exported: false
  container: "system"
  metadata {
    purpose: PURPOSE_UNSPECIFIED
  }
}
"#;

    pub fn parse_read_only_test_flags() -> ProtoParsedFlags {
        let bytes = crate::commands::parse_flags(
            "com.android.aconfig.test",
            Some("system"),
            vec![Input {
                source: "tests/read_only_test.aconfig".to_string(),
                reader: Box::new(include_bytes!("../tests/read_only_test.aconfig").as_slice()),
            }],
            vec![Input {
                source: "tests/read_only_test.values".to_string(),
                reader: Box::new(include_bytes!("../tests/read_only_test.values").as_slice()),
            }],
            crate::commands::DEFAULT_FLAG_PERMISSION,
        )
        .unwrap();
        aconfig_protos::parsed_flags::try_from_binary_proto(&bytes).unwrap()
    }

    pub fn parse_test_flags() -> ProtoParsedFlags {
        let bytes = crate::commands::parse_flags(
            "com.android.aconfig.test",
            Some("system"),
            vec![Input {
                source: "tests/test.aconfig".to_string(),
                reader: Box::new(include_bytes!("../tests/test.aconfig").as_slice()),
            }],
            vec![
                Input {
                    source: "tests/first.values".to_string(),
                    reader: Box::new(include_bytes!("../tests/first.values").as_slice()),
                },
                Input {
                    source: "tests/second.values".to_string(),
                    reader: Box::new(include_bytes!("../tests/second.values").as_slice()),
                },
            ],
            crate::commands::DEFAULT_FLAG_PERMISSION,
        )
        .unwrap();
        aconfig_protos::parsed_flags::try_from_binary_proto(&bytes).unwrap()
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
