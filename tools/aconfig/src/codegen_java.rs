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
use serde::Serialize;
use std::path::PathBuf;
use tinytemplate::TinyTemplate;

use crate::codegen;
use crate::commands::{CodegenMode, OutputFile};
use crate::protos::{ProtoFlagPermission, ProtoFlagState, ProtoParsedFlag};

pub fn generate_java_code<'a, I>(
    package: &str,
    parsed_flags_iter: I,
    codegen_mode: CodegenMode,
) -> Result<Vec<OutputFile>>
where
    I: Iterator<Item = &'a ProtoParsedFlag>,
{
    let class_elements: Vec<ClassElement> =
        parsed_flags_iter.map(|pf| create_class_element(package, pf)).collect();
    let is_read_write = class_elements.iter().any(|elem| elem.is_read_write);
    let is_test_mode = codegen_mode == CodegenMode::Test;
    let context =
        Context { class_elements, is_test_mode, is_read_write, package_name: package.to_string() };
    let mut template = TinyTemplate::new();
    template.add_template("Flags.java", include_str!("../templates/Flags.java.template"))?;
    template.add_template(
        "FeatureFlagsImpl.java",
        include_str!("../templates/FeatureFlagsImpl.java.template"),
    )?;
    template.add_template(
        "FeatureFlags.java",
        include_str!("../templates/FeatureFlags.java.template"),
    )?;
    template.add_template(
        "FakeFeatureFlagsImpl.java",
        include_str!("../templates/FakeFeatureFlagsImpl.java.template"),
    )?;

    let path: PathBuf = package.split('.').collect();
    ["Flags.java", "FeatureFlags.java", "FeatureFlagsImpl.java", "FakeFeatureFlagsImpl.java"]
        .iter()
        .map(|file| {
            Ok(OutputFile {
                contents: template.render(file, &context)?.into(),
                path: path.join(file),
            })
        })
        .collect::<Result<Vec<OutputFile>>>()
}

#[derive(Serialize)]
struct Context {
    pub class_elements: Vec<ClassElement>,
    pub is_test_mode: bool,
    pub is_read_write: bool,
    pub package_name: String,
}

#[derive(Serialize)]
struct ClassElement {
    pub default_value: bool,
    pub device_config_namespace: String,
    pub device_config_flag: String,
    pub flag_name_constant_suffix: String,
    pub is_read_write: bool,
    pub method_name: String,
}

fn create_class_element(package: &str, pf: &ProtoParsedFlag) -> ClassElement {
    let device_config_flag = codegen::create_device_config_ident(package, pf.name())
        .expect("values checked at flag parse time");
    ClassElement {
        default_value: pf.state() == ProtoFlagState::ENABLED,
        device_config_namespace: pf.namespace().to_string(),
        device_config_flag,
        flag_name_constant_suffix: pf.name().to_ascii_uppercase(),
        is_read_write: pf.permission() == ProtoFlagPermission::READ_WRITE,
        method_name: format_java_method_name(pf.name()),
    }
}

fn format_java_method_name(flag_name: &str) -> String {
    flag_name
        .split('_')
        .filter(|&word| !word.is_empty())
        .enumerate()
        .map(|(index, word)| {
            if index == 0 {
                word.to_ascii_lowercase()
            } else {
                word[0..1].to_ascii_uppercase() + &word[1..].to_ascii_lowercase()
            }
        })
        .collect::<Vec<String>>()
        .join("")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    const EXPECTED_FEATUREFLAGS_COMMON_CONTENT: &str = r#"
    package com.android.aconfig.test;
    /** @hide */
    public interface FeatureFlags {
        @com.android.aconfig.annotations.AssumeFalseForR8
        boolean disabledRo();
        boolean disabledRw();
        @com.android.aconfig.annotations.AssumeTrueForR8
        boolean enabledFixedRo();
        @com.android.aconfig.annotations.AssumeTrueForR8
        boolean enabledRo();
        boolean enabledRw();
    }
    "#;

    const EXPECTED_FLAG_COMMON_CONTENT: &str = r#"
    package com.android.aconfig.test;
    /** @hide */
    public final class Flags {
        /** @hide */
        public static final String FLAG_DISABLED_RO = "com.android.aconfig.test.disabled_ro";
        /** @hide */
        public static final String FLAG_DISABLED_RW = "com.android.aconfig.test.disabled_rw";
        /** @hide */
        public static final String FLAG_ENABLED_FIXED_RO = "com.android.aconfig.test.enabled_fixed_ro";
        /** @hide */
        public static final String FLAG_ENABLED_RO = "com.android.aconfig.test.enabled_ro";
        /** @hide */
        public static final String FLAG_ENABLED_RW = "com.android.aconfig.test.enabled_rw";

        @com.android.aconfig.annotations.AssumeFalseForR8
        public static boolean disabledRo() {
            return FEATURE_FLAGS.disabledRo();
        }
        public static boolean disabledRw() {
            return FEATURE_FLAGS.disabledRw();
        }
        @com.android.aconfig.annotations.AssumeTrueForR8
        public static boolean enabledFixedRo() {
            return FEATURE_FLAGS.enabledFixedRo();
        }
        @com.android.aconfig.annotations.AssumeTrueForR8
        public static boolean enabledRo() {
            return FEATURE_FLAGS.enabledRo();
        }
        public static boolean enabledRw() {
            return FEATURE_FLAGS.enabledRw();
        }
    "#;

    const EXPECTED_FAKEFEATUREFLAGSIMPL_CONTENT: &str = r#"
    package com.android.aconfig.test;
    import java.util.HashMap;
    import java.util.Map;
    /** @hide */
    public class FakeFeatureFlagsImpl implements FeatureFlags {
        public FakeFeatureFlagsImpl() {
            resetAll();
        }
        @Override
        public boolean disabledRo() {
            return getValue(Flags.FLAG_DISABLED_RO);
        }
        @Override
        public boolean disabledRw() {
            return getValue(Flags.FLAG_DISABLED_RW);
        }
        @Override
        public boolean enabledFixedRo() {
            return getValue(Flags.FLAG_ENABLED_FIXED_RO);
        }
        @Override
        public boolean enabledRo() {
            return getValue(Flags.FLAG_ENABLED_RO);
        }
        @Override
        public boolean enabledRw() {
            return getValue(Flags.FLAG_ENABLED_RW);
        }
        public void setFlag(String flagName, boolean value) {
            if (!this.mFlagMap.containsKey(flagName)) {
                throw new IllegalArgumentException("no such flag " + flagName);
            }
            this.mFlagMap.put(flagName, value);
        }
        public void resetAll() {
            for (Map.Entry entry : mFlagMap.entrySet()) {
                entry.setValue(null);
            }
        }
        private boolean getValue(String flagName) {
            Boolean value = this.mFlagMap.get(flagName);
            if (value == null) {
                throw new IllegalArgumentException(flagName + " is not set");
            }
            return value;
        }
        private Map<String, Boolean> mFlagMap = new HashMap<>(
            Map.ofEntries(
                Map.entry(Flags.FLAG_DISABLED_RO, false),
                Map.entry(Flags.FLAG_DISABLED_RW, false),
                Map.entry(Flags.FLAG_ENABLED_FIXED_RO, false),
                Map.entry(Flags.FLAG_ENABLED_RO, false),
                Map.entry(Flags.FLAG_ENABLED_RW, false)
            )
        );
    }
    "#;

    #[test]
    fn test_generate_java_code_production() {
        let parsed_flags = crate::test::parse_test_flags();
        let generated_files = generate_java_code(
            crate::test::TEST_PACKAGE,
            parsed_flags.parsed_flag.iter(),
            CodegenMode::Production,
        )
        .unwrap();
        let expect_flags_content = EXPECTED_FLAG_COMMON_CONTENT.to_string()
            + r#"
            private static FeatureFlags FEATURE_FLAGS = new FeatureFlagsImpl();
        }"#;

        let expect_featureflagsimpl_content = r#"
        package com.android.aconfig.test;
        import android.provider.DeviceConfig;
        /** @hide */
        public final class FeatureFlagsImpl implements FeatureFlags {
            @Override
            public boolean disabledRo() {
                return false;
            }
            @Override
            public boolean disabledRw() {
                return getValue(
                    "aconfig_test",
                    "com.android.aconfig.test.disabled_rw",
                    false
                );
            }
            @Override
            public boolean enabledFixedRo() {
                return true;
            }
            @Override
            public boolean enabledRo() {
                return true;
            }
            @Override
            public boolean enabledRw() {
                return getValue(
                    "aconfig_test",
                    "com.android.aconfig.test.enabled_rw",
                    true
                );
            }
            private boolean getValue(String nameSpace,
                String flagName, boolean defaultValue) {
                boolean value = defaultValue;
                try {
                    value = DeviceConfig.getBoolean(
                        nameSpace,
                        flagName,
                        defaultValue
                    );
                } catch (NullPointerException e) {
                    throw new RuntimeException(
                        "Cannot read value of flag " + flagName + " from DeviceConfig. " +
                        "It could be that the code using flag executed " +
                        "before SettingsProvider initialization. " +
                        "Please use fixed read-only flag by adding " +
                        "is_fixed_read_only: true in flag declaration.",
                        e
                    );
                }
                return value;
            }
        }
        "#;
        let mut file_set = HashMap::from([
            ("com/android/aconfig/test/Flags.java", expect_flags_content.as_str()),
            ("com/android/aconfig/test/FeatureFlagsImpl.java", expect_featureflagsimpl_content),
            ("com/android/aconfig/test/FeatureFlags.java", EXPECTED_FEATUREFLAGS_COMMON_CONTENT),
            (
                "com/android/aconfig/test/FakeFeatureFlagsImpl.java",
                EXPECTED_FAKEFEATUREFLAGSIMPL_CONTENT,
            ),
        ]);

        for file in generated_files {
            let file_path = file.path.to_str().unwrap();
            assert!(file_set.contains_key(file_path), "Cannot find {}", file_path);
            assert_eq!(
                None,
                crate::test::first_significant_code_diff(
                    file_set.get(file_path).unwrap(),
                    &String::from_utf8(file.contents).unwrap()
                ),
                "File {} content is not correct",
                file_path
            );
            file_set.remove(file_path);
        }

        assert!(file_set.is_empty());
    }

    #[test]
    fn test_generate_java_code_test() {
        let parsed_flags = crate::test::parse_test_flags();
        let generated_files = generate_java_code(
            crate::test::TEST_PACKAGE,
            parsed_flags.parsed_flag.iter(),
            CodegenMode::Test,
        )
        .unwrap();

        let expect_flags_content = EXPECTED_FLAG_COMMON_CONTENT.to_string()
            + r#"
            public static void setFeatureFlags(FeatureFlags featureFlags) {
                Flags.FEATURE_FLAGS = featureFlags;
            }
            public static void unsetFeatureFlags() {
                Flags.FEATURE_FLAGS = null;
            }
            private static FeatureFlags FEATURE_FLAGS;
        }
        "#;
        let expect_featureflagsimpl_content = r#"
        package com.android.aconfig.test;
        /** @hide */
        public final class FeatureFlagsImpl implements FeatureFlags {
            @Override
            public boolean disabledRo() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            public boolean disabledRw() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            public boolean enabledFixedRo() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            public boolean enabledRo() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            public boolean enabledRw() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
        }
        "#;

        let mut file_set = HashMap::from([
            ("com/android/aconfig/test/Flags.java", expect_flags_content.as_str()),
            ("com/android/aconfig/test/FeatureFlags.java", EXPECTED_FEATUREFLAGS_COMMON_CONTENT),
            ("com/android/aconfig/test/FeatureFlagsImpl.java", expect_featureflagsimpl_content),
            (
                "com/android/aconfig/test/FakeFeatureFlagsImpl.java",
                EXPECTED_FAKEFEATUREFLAGSIMPL_CONTENT,
            ),
        ]);

        for file in generated_files {
            let file_path = file.path.to_str().unwrap();
            assert!(file_set.contains_key(file_path), "Cannot find {}", file_path);
            assert_eq!(
                None,
                crate::test::first_significant_code_diff(
                    file_set.get(file_path).unwrap(),
                    &String::from_utf8(file.contents).unwrap()
                ),
                "File {} content is not correct",
                file_path
            );
            file_set.remove(file_path);
        }

        assert!(file_set.is_empty());
    }

    #[test]
    fn test_format_java_method_name() {
        let input = "____some_snake___name____";
        let expected = "someSnakeName";
        let formatted_name = format_java_method_name(input);
        assert_eq!(expected, formatted_name);
    }
}
