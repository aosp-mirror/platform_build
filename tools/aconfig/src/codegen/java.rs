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

use anyhow::{anyhow, Result};
use serde::Serialize;
use std::collections::{BTreeMap, BTreeSet};
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
    let flag_elements: Vec<FlagElement> =
        parsed_flags_iter.map(|pf| create_flag_element(package, pf)).collect();
    let exported_flag_elements: Vec<FlagElement> =
        flag_elements.iter().filter(|elem| elem.exported).cloned().collect();
    let namespace_flags = gen_flags_by_namespace(&flag_elements);
    let properties_set: BTreeSet<String> =
        flag_elements.iter().map(|fe| format_property_name(&fe.device_config_namespace)).collect();
    let is_test_mode = codegen_mode == CodegenMode::Test;
    let library_exported = codegen_mode == CodegenMode::Exported;
    let runtime_lookup_required =
        flag_elements.iter().any(|elem| elem.is_read_write) || library_exported;

    if library_exported && exported_flag_elements.is_empty() {
        return Err(anyhow!("exported library contains no exported flags"));
    }

    let context = Context {
        flag_elements,
        exported_flag_elements,
        namespace_flags,
        is_test_mode,
        runtime_lookup_required,
        properties_set,
        package_name: package.to_string(),
        library_exported,
    };
    let mut template = TinyTemplate::new();
    template.add_template("Flags.java", include_str!("../../templates/Flags.java.template"))?;
    template.add_template(
        "FeatureFlagsImpl.java",
        include_str!("../../templates/FeatureFlagsImpl.java.template"),
    )?;
    template.add_template(
        "FeatureFlags.java",
        include_str!("../../templates/FeatureFlags.java.template"),
    )?;
    template.add_template(
        "FakeFeatureFlagsImpl.java",
        include_str!("../../templates/FakeFeatureFlagsImpl.java.template"),
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

fn gen_flags_by_namespace(flags: &[FlagElement]) -> Vec<NamespaceFlags> {
    let mut namespace_to_flag: BTreeMap<String, Vec<FlagElement>> = BTreeMap::new();

    for flag in flags {
        match namespace_to_flag.get_mut(&flag.device_config_namespace) {
            Some(flag_list) => flag_list.push(flag.clone()),
            None => {
                namespace_to_flag.insert(flag.device_config_namespace.clone(), vec![flag.clone()]);
            }
        }
    }

    namespace_to_flag
        .iter()
        .map(|(namespace, flags)| NamespaceFlags {
            namespace: namespace.to_string(),
            flags: flags.clone(),
        })
        .collect()
}

#[derive(Serialize)]
struct Context {
    pub flag_elements: Vec<FlagElement>,
    pub exported_flag_elements: Vec<FlagElement>,
    pub namespace_flags: Vec<NamespaceFlags>,
    pub is_test_mode: bool,
    pub runtime_lookup_required: bool,
    pub properties_set: BTreeSet<String>,
    pub package_name: String,
    pub library_exported: bool,
}

#[derive(Serialize, Debug)]
struct NamespaceFlags {
    pub namespace: String,
    pub flags: Vec<FlagElement>,
}

#[derive(Serialize, Clone, Debug)]
struct FlagElement {
    pub default_value: bool,
    pub device_config_namespace: String,
    pub device_config_flag: String,
    pub flag_name_constant_suffix: String,
    pub is_read_write: bool,
    pub method_name: String,
    pub properties: String,
    pub exported: bool,
}

fn create_flag_element(package: &str, pf: &ProtoParsedFlag) -> FlagElement {
    let device_config_flag = codegen::create_device_config_ident(package, pf.name())
        .expect("values checked at flag parse time");
    FlagElement {
        default_value: pf.state() == ProtoFlagState::ENABLED,
        device_config_namespace: pf.namespace().to_string(),
        device_config_flag,
        flag_name_constant_suffix: pf.name().to_ascii_uppercase(),
        is_read_write: pf.permission() == ProtoFlagPermission::READ_WRITE,
        method_name: format_java_method_name(pf.name()),
        properties: format_property_name(pf.namespace()),
        exported: pf.is_exported.unwrap_or(false),
    }
}

fn format_java_method_name(flag_name: &str) -> String {
    let splits: Vec<&str> = flag_name.split('_').filter(|&word| !word.is_empty()).collect();
    if splits.len() == 1 {
        let name = splits[0];
        name[0..1].to_ascii_lowercase() + &name[1..]
    } else {
        splits
            .iter()
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
}

fn format_property_name(property_name: &str) -> String {
    let name = format_java_method_name(property_name);
    format!("mProperties{}{}", &name[0..1].to_ascii_uppercase(), &name[1..])
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    const EXPECTED_FEATUREFLAGS_COMMON_CONTENT: &str = r#"
    package com.android.aconfig.test;
    // TODO(b/303773055): Remove the annotation after access issue is resolved.
    import android.compat.annotation.UnsupportedAppUsage;
    /** @hide */
    public interface FeatureFlags {
        @com.android.aconfig.annotations.AssumeFalseForR8
        @UnsupportedAppUsage
        boolean disabledRo();
        @UnsupportedAppUsage
        boolean disabledRw();
        @UnsupportedAppUsage
        boolean disabledRwExported();
        @UnsupportedAppUsage
        boolean disabledRwInOtherNamespace();
        @com.android.aconfig.annotations.AssumeTrueForR8
        @UnsupportedAppUsage
        boolean enabledFixedRo();
        @com.android.aconfig.annotations.AssumeTrueForR8
        @UnsupportedAppUsage
        boolean enabledRo();
        @com.android.aconfig.annotations.AssumeTrueForR8
        @UnsupportedAppUsage
        boolean enabledRoExported();
        @UnsupportedAppUsage
        boolean enabledRw();
    }
    "#;

    const EXPECTED_FLAG_COMMON_CONTENT: &str = r#"
    package com.android.aconfig.test;
    // TODO(b/303773055): Remove the annotation after access issue is resolved.
    import android.compat.annotation.UnsupportedAppUsage;
    /** @hide */
    public final class Flags {
        /** @hide */
        public static final String FLAG_DISABLED_RO = "com.android.aconfig.test.disabled_ro";
        /** @hide */
        public static final String FLAG_DISABLED_RW = "com.android.aconfig.test.disabled_rw";
        /** @hide */
        public static final String FLAG_DISABLED_RW_EXPORTED = "com.android.aconfig.test.disabled_rw_exported";
        /** @hide */
        public static final String FLAG_DISABLED_RW_IN_OTHER_NAMESPACE = "com.android.aconfig.test.disabled_rw_in_other_namespace";
        /** @hide */
        public static final String FLAG_ENABLED_FIXED_RO = "com.android.aconfig.test.enabled_fixed_ro";
        /** @hide */
        public static final String FLAG_ENABLED_RO = "com.android.aconfig.test.enabled_ro";
        /** @hide */
        public static final String FLAG_ENABLED_RO_EXPORTED = "com.android.aconfig.test.enabled_ro_exported";
        /** @hide */
        public static final String FLAG_ENABLED_RW = "com.android.aconfig.test.enabled_rw";

        @com.android.aconfig.annotations.AssumeFalseForR8
        @UnsupportedAppUsage
        public static boolean disabledRo() {
            return FEATURE_FLAGS.disabledRo();
        }
        @UnsupportedAppUsage
        public static boolean disabledRw() {
            return FEATURE_FLAGS.disabledRw();
        }
        @UnsupportedAppUsage
        public static boolean disabledRwExported() {
            return FEATURE_FLAGS.disabledRwExported();
        }
        @UnsupportedAppUsage
        public static boolean disabledRwInOtherNamespace() {
            return FEATURE_FLAGS.disabledRwInOtherNamespace();
        }
        @com.android.aconfig.annotations.AssumeTrueForR8
        @UnsupportedAppUsage
        public static boolean enabledFixedRo() {
            return FEATURE_FLAGS.enabledFixedRo();
        }
        @com.android.aconfig.annotations.AssumeTrueForR8
        @UnsupportedAppUsage
        public static boolean enabledRo() {
            return FEATURE_FLAGS.enabledRo();
        }
        @com.android.aconfig.annotations.AssumeTrueForR8
        @UnsupportedAppUsage
        public static boolean enabledRoExported() {
            return FEATURE_FLAGS.enabledRoExported();
        }
        @UnsupportedAppUsage
        public static boolean enabledRw() {
            return FEATURE_FLAGS.enabledRw();
        }
    "#;

    const EXPECTED_FAKEFEATUREFLAGSIMPL_CONTENT: &str = r#"
    package com.android.aconfig.test;
    // TODO(b/303773055): Remove the annotation after access issue is resolved.
    import android.compat.annotation.UnsupportedAppUsage;
    import java.util.HashMap;
    import java.util.Map;
    /** @hide */
    public class FakeFeatureFlagsImpl implements FeatureFlags {
        public FakeFeatureFlagsImpl() {
            resetAll();
        }
        @Override
        @UnsupportedAppUsage
        public boolean disabledRo() {
            return getValue(Flags.FLAG_DISABLED_RO);
        }
        @Override
        @UnsupportedAppUsage
        public boolean disabledRw() {
            return getValue(Flags.FLAG_DISABLED_RW);
        }
        @Override
        @UnsupportedAppUsage
        public boolean disabledRwExported() {
            return getValue(Flags.FLAG_DISABLED_RW_EXPORTED);
        }
        @Override
        @UnsupportedAppUsage
        public boolean disabledRwInOtherNamespace() {
            return getValue(Flags.FLAG_DISABLED_RW_IN_OTHER_NAMESPACE);
        }
        @Override
        @UnsupportedAppUsage
        public boolean enabledFixedRo() {
            return getValue(Flags.FLAG_ENABLED_FIXED_RO);
        }
        @Override
        @UnsupportedAppUsage
        public boolean enabledRo() {
            return getValue(Flags.FLAG_ENABLED_RO);
        }
        @Override
        @UnsupportedAppUsage
        public boolean enabledRoExported() {
            return getValue(Flags.FLAG_ENABLED_RO_EXPORTED);
        }
        @Override
        @UnsupportedAppUsage
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
                Map.entry(Flags.FLAG_DISABLED_RW_EXPORTED, false),
                Map.entry(Flags.FLAG_DISABLED_RW_IN_OTHER_NAMESPACE, false),
                Map.entry(Flags.FLAG_ENABLED_FIXED_RO, false),
                Map.entry(Flags.FLAG_ENABLED_RO, false),
                Map.entry(Flags.FLAG_ENABLED_RO_EXPORTED, false),
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
        // TODO(b/303773055): Remove the annotation after access issue is resolved.
        import android.compat.annotation.UnsupportedAppUsage;
        import android.provider.DeviceConfig;
        import android.provider.DeviceConfig.Properties;
        /** @hide */
        public final class FeatureFlagsImpl implements FeatureFlags {
            private static boolean aconfig_test_is_cached = false;
            private static boolean other_namespace_is_cached = false;
            private static boolean disabledRw = false;
            private static boolean disabledRwExported = false;
            private static boolean disabledRwInOtherNamespace = false;
            private static boolean enabledRw = true;


            private void load_overrides_aconfig_test() {
                try {
                    Properties properties = DeviceConfig.getProperties("aconfig_test");
                    disabledRw =
                        properties.getBoolean("com.android.aconfig.test.disabled_rw", false);
                    disabledRwExported =
                        properties.getBoolean("com.android.aconfig.test.disabled_rw_exported", false);
                    enabledRw =
                        properties.getBoolean("com.android.aconfig.test.enabled_rw", true);
                } catch (NullPointerException e) {
                    throw new RuntimeException(
                        "Cannot read value from namespace aconfig_test "
                        + "from DeviceConfig. It could be that the code using flag "
                        + "executed before SettingsProvider initialization. Please use "
                        + "fixed read-only flag by adding is_fixed_read_only: true in "
                        + "flag declaration.",
                        e
                    );
                }
                aconfig_test_is_cached = true;
            }

            private void load_overrides_other_namespace() {
                try {
                    Properties properties = DeviceConfig.getProperties("other_namespace");
                    disabledRwInOtherNamespace =
                        properties.getBoolean("com.android.aconfig.test.disabled_rw_in_other_namespace", false);
                } catch (NullPointerException e) {
                    throw new RuntimeException(
                        "Cannot read value from namespace other_namespace "
                        + "from DeviceConfig. It could be that the code using flag "
                        + "executed before SettingsProvider initialization. Please use "
                        + "fixed read-only flag by adding is_fixed_read_only: true in "
                        + "flag declaration.",
                        e
                    );
                }
                other_namespace_is_cached = true;
            }


            @Override
            @UnsupportedAppUsage
            public boolean disabledRo() {
                return false;
            }
            @Override
            @UnsupportedAppUsage
            public boolean disabledRw() {
                if (!aconfig_test_is_cached) {
                    load_overrides_aconfig_test();
                }
                return disabledRw;
            }
            @Override
            @UnsupportedAppUsage
            public boolean disabledRwExported() {
                if (!aconfig_test_is_cached) {
                    load_overrides_aconfig_test();
                }
                return disabledRwExported;
            }
            @Override
            @UnsupportedAppUsage
            public boolean disabledRwInOtherNamespace() {
                if (!other_namespace_is_cached) {
                    load_overrides_other_namespace();
                }
                return disabledRwInOtherNamespace;
            }
            @Override
            @UnsupportedAppUsage
            public boolean enabledFixedRo() {
                return true;
            }
            @Override
            @UnsupportedAppUsage
            public boolean enabledRo() {
                return true;
            }
            @Override
            @UnsupportedAppUsage
            public boolean enabledRoExported() {
                return true;
            }
            @Override
            @UnsupportedAppUsage
            public boolean enabledRw() {
                if (!aconfig_test_is_cached) {
                    load_overrides_aconfig_test();
                }
                return enabledRw;
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
    fn test_generate_java_code_exported() {
        let parsed_flags = crate::test::parse_test_flags();
        let generated_files = generate_java_code(
            crate::test::TEST_PACKAGE,
            parsed_flags.parsed_flag.iter(),
            CodegenMode::Exported,
        )
        .unwrap();

        let expect_flags_content = r#"
        package com.android.aconfig.test;
        // TODO(b/303773055): Remove the annotation after access issue is resolved.
        import android.compat.annotation.UnsupportedAppUsage;
        /** @hide */
        public final class Flags {
            /** @hide */
            public static final String FLAG_DISABLED_RW_EXPORTED = "com.android.aconfig.test.disabled_rw_exported";
            /** @hide */
            public static final String FLAG_ENABLED_RO_EXPORTED = "com.android.aconfig.test.enabled_ro_exported";

            @UnsupportedAppUsage
            public static boolean disabledRwExported() {
                return FEATURE_FLAGS.disabledRwExported();
            }
            @UnsupportedAppUsage
            public static boolean enabledRoExported() {
                return FEATURE_FLAGS.enabledRoExported();
            }
            private static FeatureFlags FEATURE_FLAGS = new FeatureFlagsImpl();
        }
        "#;

        let expect_feature_flags_content = r#"
        package com.android.aconfig.test;
        // TODO(b/303773055): Remove the annotation after access issue is resolved.
        import android.compat.annotation.UnsupportedAppUsage;
        /** @hide */
        public interface FeatureFlags {
            @UnsupportedAppUsage
            boolean disabledRwExported();
            @UnsupportedAppUsage
            boolean enabledRoExported();
        }
        "#;

        let expect_feature_flags_impl_content = r#"
        package com.android.aconfig.test;
        // TODO(b/303773055): Remove the annotation after access issue is resolved.
        import android.compat.annotation.UnsupportedAppUsage;
        import android.provider.DeviceConfig;
        import android.provider.DeviceConfig.Properties;
        /** @hide */
        public final class FeatureFlagsImpl implements FeatureFlags {
            private static boolean aconfig_test_is_cached = false;
            private static boolean other_namespace_is_cached = false;
            private static boolean disabledRwExported = false;
            private static boolean enabledRoExported = false;


            private void load_overrides_aconfig_test() {
                try {
                    Properties properties = DeviceConfig.getProperties("aconfig_test");
                    disabledRwExported =
                        properties.getBoolean("com.android.aconfig.test.disabled_rw_exported", false);
                    enabledRoExported =
                        properties.getBoolean("com.android.aconfig.test.enabled_ro_exported", false);
                } catch (NullPointerException e) {
                    throw new RuntimeException(
                        "Cannot read value from namespace aconfig_test "
                        + "from DeviceConfig. It could be that the code using flag "
                        + "executed before SettingsProvider initialization. Please use "
                        + "fixed read-only flag by adding is_fixed_read_only: true in "
                        + "flag declaration.",
                        e
                    );
                }
                aconfig_test_is_cached = true;
            }

            private void load_overrides_other_namespace() {
                try {
                    Properties properties = DeviceConfig.getProperties("other_namespace");
                } catch (NullPointerException e) {
                    throw new RuntimeException(
                        "Cannot read value from namespace other_namespace "
                        + "from DeviceConfig. It could be that the code using flag "
                        + "executed before SettingsProvider initialization. Please use "
                        + "fixed read-only flag by adding is_fixed_read_only: true in "
                        + "flag declaration.",
                        e
                    );
                }
                other_namespace_is_cached = true;
            }

            @Override
            @UnsupportedAppUsage
            public boolean disabledRwExported() {
                if (!aconfig_test_is_cached) {
                    load_overrides_aconfig_test();
                }
                return disabledRwExported;
            }

            @Override
            @UnsupportedAppUsage
            public boolean enabledRoExported() {
                if (!aconfig_test_is_cached) {
                    load_overrides_aconfig_test();
                }
                return enabledRoExported;
            }
        }"#;

        let expect_fake_feature_flags_impl_content = r#"
        package com.android.aconfig.test;
        // TODO(b/303773055): Remove the annotation after access issue is resolved.
        import android.compat.annotation.UnsupportedAppUsage;
        import java.util.HashMap;
        import java.util.Map;
        /** @hide */
        public class FakeFeatureFlagsImpl implements FeatureFlags {
            public FakeFeatureFlagsImpl() {
                resetAll();
            }
            @Override
            @UnsupportedAppUsage
            public boolean disabledRwExported() {
                return getValue(Flags.FLAG_DISABLED_RW_EXPORTED);
            }
            @Override
            @UnsupportedAppUsage
            public boolean enabledRoExported() {
                return getValue(Flags.FLAG_ENABLED_RO_EXPORTED);
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
                    Map.entry(Flags.FLAG_DISABLED_RW_EXPORTED, false),
                    Map.entry(Flags.FLAG_ENABLED_RO_EXPORTED, false)
                )
            );
        }
    "#;

        let mut file_set = HashMap::from([
            ("com/android/aconfig/test/Flags.java", expect_flags_content),
            ("com/android/aconfig/test/FeatureFlags.java", expect_feature_flags_content),
            ("com/android/aconfig/test/FeatureFlagsImpl.java", expect_feature_flags_impl_content),
            (
                "com/android/aconfig/test/FakeFeatureFlagsImpl.java",
                expect_fake_feature_flags_impl_content,
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
        // TODO(b/303773055): Remove the annotation after access issue is resolved.
        import android.compat.annotation.UnsupportedAppUsage;
        /** @hide */
        public final class FeatureFlagsImpl implements FeatureFlags {
            @Override
            @UnsupportedAppUsage
            public boolean disabledRo() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @UnsupportedAppUsage
            public boolean disabledRw() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @UnsupportedAppUsage
            public boolean disabledRwExported() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @UnsupportedAppUsage
            public boolean disabledRwInOtherNamespace() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @UnsupportedAppUsage
            public boolean enabledFixedRo() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @UnsupportedAppUsage
            public boolean enabledRo() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @UnsupportedAppUsage
            public boolean enabledRoExported() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @UnsupportedAppUsage
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
        let expected = "someSnakeName";
        let input = "____some_snake___name____";
        let formatted_name = format_java_method_name(input);
        assert_eq!(expected, formatted_name);

        let input = "someSnakeName";
        let formatted_name = format_java_method_name(input);
        assert_eq!(expected, formatted_name);

        let input = "SomeSnakeName";
        let formatted_name = format_java_method_name(input);
        assert_eq!(expected, formatted_name);

        let input = "SomeSnakeName_";
        let formatted_name = format_java_method_name(input);
        assert_eq!(expected, formatted_name);

        let input = "_SomeSnakeName";
        let formatted_name = format_java_method_name(input);
        assert_eq!(expected, formatted_name);
    }

    #[test]
    fn test_format_property_name() {
        let expected = "mPropertiesSomeSnakeName";
        let input = "____some_snake___name____";
        let formatted_name = format_property_name(input);
        assert_eq!(expected, formatted_name);

        let input = "someSnakeName";
        let formatted_name = format_property_name(input);
        assert_eq!(expected, formatted_name);

        let input = "SomeSnakeName";
        let formatted_name = format_property_name(input);
        assert_eq!(expected, formatted_name);

        let input = "SomeSnakeName_";
        let formatted_name = format_property_name(input);
        assert_eq!(expected, formatted_name);
    }
}
