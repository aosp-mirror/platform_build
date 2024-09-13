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
use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;
use tinytemplate::TinyTemplate;

use crate::codegen;
use crate::codegen::CodegenMode;
use crate::commands::OutputFile;
use aconfig_protos::{ProtoFlagPermission, ProtoFlagState, ProtoParsedFlag};
use std::collections::HashMap;

pub fn generate_java_code<I>(
    package: &str,
    parsed_flags_iter: I,
    codegen_mode: CodegenMode,
    flag_ids: HashMap<String, u16>,
    allow_instrumentation: bool,
) -> Result<Vec<OutputFile>>
where
    I: Iterator<Item = ProtoParsedFlag>,
{
    let flag_elements: Vec<FlagElement> =
        parsed_flags_iter.map(|pf| create_flag_element(package, &pf, flag_ids.clone())).collect();
    let namespace_flags = gen_flags_by_namespace(&flag_elements);
    let properties_set: BTreeSet<String> =
        flag_elements.iter().map(|fe| format_property_name(&fe.device_config_namespace)).collect();
    let is_test_mode = codegen_mode == CodegenMode::Test;
    let library_exported = codegen_mode == CodegenMode::Exported;
    let runtime_lookup_required =
        flag_elements.iter().any(|elem| elem.is_read_write) || library_exported;
    let container = (flag_elements.first().expect("zero template flags").container).to_string();
    let context = Context {
        flag_elements,
        namespace_flags,
        is_test_mode,
        runtime_lookup_required,
        properties_set,
        package_name: package.to_string(),
        library_exported,
        allow_instrumentation,
        container,
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
        "CustomFeatureFlags.java",
        include_str!("../../templates/CustomFeatureFlags.java.template"),
    )?;
    template.add_template(
        "FakeFeatureFlagsImpl.java",
        include_str!("../../templates/FakeFeatureFlagsImpl.java.template"),
    )?;

    let path: PathBuf = package.split('.').collect();
    [
        "Flags.java",
        "FeatureFlags.java",
        "FeatureFlagsImpl.java",
        "CustomFeatureFlags.java",
        "FakeFeatureFlagsImpl.java",
    ]
    .iter()
    .map(|file| {
        Ok(OutputFile { contents: template.render(file, &context)?.into(), path: path.join(file) })
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
    pub namespace_flags: Vec<NamespaceFlags>,
    pub is_test_mode: bool,
    pub runtime_lookup_required: bool,
    pub properties_set: BTreeSet<String>,
    pub package_name: String,
    pub library_exported: bool,
    pub allow_instrumentation: bool,
    pub container: String,
}

#[derive(Serialize, Debug)]
struct NamespaceFlags {
    pub namespace: String,
    pub flags: Vec<FlagElement>,
}

#[derive(Serialize, Clone, Debug)]
struct FlagElement {
    pub container: String,
    pub default_value: bool,
    pub device_config_namespace: String,
    pub device_config_flag: String,
    pub flag_name_constant_suffix: String,
    pub flag_offset: u16,
    pub is_read_write: bool,
    pub method_name: String,
    pub properties: String,
}

fn create_flag_element(
    package: &str,
    pf: &ProtoParsedFlag,
    flag_offsets: HashMap<String, u16>,
) -> FlagElement {
    let device_config_flag = codegen::create_device_config_ident(package, pf.name())
        .expect("values checked at flag parse time");
    FlagElement {
        container: pf.container().to_string(),
        default_value: pf.state() == ProtoFlagState::ENABLED,
        device_config_namespace: pf.namespace().to_string(),
        device_config_flag,
        flag_name_constant_suffix: pf.name().to_ascii_uppercase(),
        flag_offset: *flag_offsets.get(pf.name()).expect("didnt find package offset :("),
        is_read_write: pf.permission() == ProtoFlagPermission::READ_WRITE,
        method_name: format_java_method_name(pf.name()),
        properties: format_property_name(pf.namespace()),
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
    use crate::commands::assign_flag_ids;
    use std::collections::HashMap;

    const EXPECTED_FEATUREFLAGS_COMMON_CONTENT: &str = r#"
    package com.android.aconfig.test;
    // TODO(b/303773055): Remove the annotation after access issue is resolved.
    import android.compat.annotation.UnsupportedAppUsage;
    /** @hide */
    public interface FeatureFlags {
        @com.android.aconfig.annotations.AssumeFalseForR8
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        boolean disabledRo();
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        boolean disabledRw();
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        boolean disabledRwExported();
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        boolean disabledRwInOtherNamespace();
        @com.android.aconfig.annotations.AssumeTrueForR8
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        boolean enabledFixedRo();
        @com.android.aconfig.annotations.AssumeTrueForR8
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        boolean enabledFixedRoExported();
        @com.android.aconfig.annotations.AssumeTrueForR8
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        boolean enabledRo();
        @com.android.aconfig.annotations.AssumeTrueForR8
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        boolean enabledRoExported();
        @com.android.aconfig.annotations.AconfigFlagAccessor
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
        public static final String FLAG_ENABLED_FIXED_RO_EXPORTED = "com.android.aconfig.test.enabled_fixed_ro_exported";
        /** @hide */
        public static final String FLAG_ENABLED_RO = "com.android.aconfig.test.enabled_ro";
        /** @hide */
        public static final String FLAG_ENABLED_RO_EXPORTED = "com.android.aconfig.test.enabled_ro_exported";
        /** @hide */
        public static final String FLAG_ENABLED_RW = "com.android.aconfig.test.enabled_rw";

        @com.android.aconfig.annotations.AssumeFalseForR8
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        public static boolean disabledRo() {
            return FEATURE_FLAGS.disabledRo();
        }
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        public static boolean disabledRw() {
            return FEATURE_FLAGS.disabledRw();
        }
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        public static boolean disabledRwExported() {
            return FEATURE_FLAGS.disabledRwExported();
        }
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        public static boolean disabledRwInOtherNamespace() {
            return FEATURE_FLAGS.disabledRwInOtherNamespace();
        }
        @com.android.aconfig.annotations.AssumeTrueForR8
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        public static boolean enabledFixedRo() {
            return FEATURE_FLAGS.enabledFixedRo();
        }
        @com.android.aconfig.annotations.AssumeTrueForR8
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        public static boolean enabledFixedRoExported() {
            return FEATURE_FLAGS.enabledFixedRoExported();
        }
        @com.android.aconfig.annotations.AssumeTrueForR8
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        public static boolean enabledRo() {
            return FEATURE_FLAGS.enabledRo();
        }
        @com.android.aconfig.annotations.AssumeTrueForR8
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        public static boolean enabledRoExported() {
            return FEATURE_FLAGS.enabledRoExported();
        }
        @com.android.aconfig.annotations.AconfigFlagAccessor
        @UnsupportedAppUsage
        public static boolean enabledRw() {
            return FEATURE_FLAGS.enabledRw();
        }
    "#;

    const EXPECTED_CUSTOMFEATUREFLAGS_CONTENT: &str = r#"
    package com.android.aconfig.test;

    // TODO(b/303773055): Remove the annotation after access issue is resolved.
    import android.compat.annotation.UnsupportedAppUsage;
    import java.util.Arrays;
    import java.util.HashSet;
    import java.util.List;
    import java.util.Set;
    import java.util.function.BiPredicate;
    import java.util.function.Predicate;

    /** @hide */
    public class CustomFeatureFlags implements FeatureFlags {

        private BiPredicate<String, Predicate<FeatureFlags>> mGetValueImpl;

        public CustomFeatureFlags(BiPredicate<String, Predicate<FeatureFlags>> getValueImpl) {
            mGetValueImpl = getValueImpl;
        }

        @Override
        @UnsupportedAppUsage
        public boolean disabledRo() {
            return getValue(Flags.FLAG_DISABLED_RO,
                    FeatureFlags::disabledRo);
        }
        @Override
        @UnsupportedAppUsage
        public boolean disabledRw() {
            return getValue(Flags.FLAG_DISABLED_RW,
                FeatureFlags::disabledRw);
        }
        @Override
        @UnsupportedAppUsage
        public boolean disabledRwExported() {
            return getValue(Flags.FLAG_DISABLED_RW_EXPORTED,
                FeatureFlags::disabledRwExported);
        }
        @Override
        @UnsupportedAppUsage
        public boolean disabledRwInOtherNamespace() {
            return getValue(Flags.FLAG_DISABLED_RW_IN_OTHER_NAMESPACE,
                FeatureFlags::disabledRwInOtherNamespace);
        }
        @Override
        @UnsupportedAppUsage
        public boolean enabledFixedRo() {
            return getValue(Flags.FLAG_ENABLED_FIXED_RO,
                FeatureFlags::enabledFixedRo);
        }
        @Override
        @UnsupportedAppUsage
        public boolean enabledFixedRoExported() {
            return getValue(Flags.FLAG_ENABLED_FIXED_RO_EXPORTED,
                FeatureFlags::enabledFixedRoExported);
        }
        @Override
        @UnsupportedAppUsage
        public boolean enabledRo() {
            return getValue(Flags.FLAG_ENABLED_RO,
                FeatureFlags::enabledRo);
        }
        @Override
        @UnsupportedAppUsage
        public boolean enabledRoExported() {
            return getValue(Flags.FLAG_ENABLED_RO_EXPORTED,
                FeatureFlags::enabledRoExported);
        }
        @Override
        @UnsupportedAppUsage
        public boolean enabledRw() {
            return getValue(Flags.FLAG_ENABLED_RW,
                FeatureFlags::enabledRw);
        }

        public boolean isFlagReadOnlyOptimized(String flagName) {
            if (mReadOnlyFlagsSet.contains(flagName) &&
                isOptimizationEnabled()) {
                    return true;
            }
            return false;
        }

        @com.android.aconfig.annotations.AssumeTrueForR8
        private boolean isOptimizationEnabled() {
            return false;
        }

        protected boolean getValue(String flagName, Predicate<FeatureFlags> getter) {
            return mGetValueImpl.test(flagName, getter);
        }

        public List<String> getFlagNames() {
            return Arrays.asList(
                Flags.FLAG_DISABLED_RO,
                Flags.FLAG_DISABLED_RW,
                Flags.FLAG_DISABLED_RW_EXPORTED,
                Flags.FLAG_DISABLED_RW_IN_OTHER_NAMESPACE,
                Flags.FLAG_ENABLED_FIXED_RO,
                Flags.FLAG_ENABLED_FIXED_RO_EXPORTED,
                Flags.FLAG_ENABLED_RO,
                Flags.FLAG_ENABLED_RO_EXPORTED,
                Flags.FLAG_ENABLED_RW
            );
        }

        private Set<String> mReadOnlyFlagsSet = new HashSet<>(
            Arrays.asList(
                Flags.FLAG_DISABLED_RO,
                Flags.FLAG_ENABLED_FIXED_RO,
                Flags.FLAG_ENABLED_FIXED_RO_EXPORTED,
                Flags.FLAG_ENABLED_RO,
                Flags.FLAG_ENABLED_RO_EXPORTED,
                ""
            )
        );
    }
    "#;

    const EXPECTED_FAKEFEATUREFLAGSIMPL_CONTENT: &str = r#"
    package com.android.aconfig.test;

    import java.util.HashMap;
    import java.util.Map;
    import java.util.function.Predicate;

    /** @hide */
    public class FakeFeatureFlagsImpl extends CustomFeatureFlags {
        private final Map<String, Boolean> mFlagMap = new HashMap<>();
        private final FeatureFlags mDefaults;

        public FakeFeatureFlagsImpl() {
            this(null);
        }

        public FakeFeatureFlagsImpl(FeatureFlags defaults) {
            super(null);
            mDefaults = defaults;
            // Initialize the map with null values
            for (String flagName : getFlagNames()) {
                mFlagMap.put(flagName, null);
            }
        }

        @Override
        protected boolean getValue(String flagName, Predicate<FeatureFlags> getter) {
            Boolean value = this.mFlagMap.get(flagName);
            if (value != null) {
                return value;
            }
            if (mDefaults != null) {
                return getter.test(mDefaults);
            }
            throw new IllegalArgumentException(flagName + " is not set");
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
    }
    "#;

    #[test]
    fn test_generate_java_code_production() {
        let parsed_flags = crate::test::parse_test_flags();
        let mode = CodegenMode::Production;
        let modified_parsed_flags =
            crate::commands::modify_parsed_flags_based_on_mode(parsed_flags, mode).unwrap();
        let flag_ids =
            assign_flag_ids(crate::test::TEST_PACKAGE, modified_parsed_flags.iter()).unwrap();
        let generated_files = generate_java_code(
            crate::test::TEST_PACKAGE,
            modified_parsed_flags.into_iter(),
            mode,
            flag_ids,
            false,
        )
        .unwrap();
        let expect_flags_content = EXPECTED_FLAG_COMMON_CONTENT.to_string()
            + r#"
            private static FeatureFlags FEATURE_FLAGS = new FeatureFlagsImpl();
        }"#;

        let expected_featureflagsmpl_content_0 = r#"
        package com.android.aconfig.test;
        // TODO(b/303773055): Remove the annotation after access issue is resolved.
        import android.compat.annotation.UnsupportedAppUsage;
        import android.provider.DeviceConfig;
        import android.provider.DeviceConfig.Properties;
        "#;

        let expected_featureflagsmpl_content_1 = r#"
        /** @hide */
        public final class FeatureFlagsImpl implements FeatureFlags {
            private static volatile boolean aconfig_test_is_cached = false;
            private static volatile boolean other_namespace_is_cached = false;
            private static boolean disabledRw = false;
            private static boolean disabledRwExported = false;
            private static boolean disabledRwInOtherNamespace = false;
            private static boolean enabledRw = true;
        "#;
        let expected_featureflagsmpl_content_2 = r#"
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean disabledRo() {
                return false;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean disabledRw() {
                if (!aconfig_test_is_cached) {
                    load_overrides_aconfig_test();
                }
                return disabledRw;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean disabledRwExported() {
                if (!aconfig_test_is_cached) {
                    load_overrides_aconfig_test();
                }
                return disabledRwExported;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean disabledRwInOtherNamespace() {
                if (!other_namespace_is_cached) {
                    load_overrides_other_namespace();
                }
                return disabledRwInOtherNamespace;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean enabledFixedRo() {
                return true;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean enabledFixedRoExported() {
                return true;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean enabledRo() {
                return true;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean enabledRoExported() {
                return true;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean enabledRw() {
                if (!aconfig_test_is_cached) {
                    load_overrides_aconfig_test();
                }
                return enabledRw;
            }
        }
        "#;

        let expect_featureflagsimpl_content_old = expected_featureflagsmpl_content_0.to_owned()
            + expected_featureflagsmpl_content_1
            + r#"
            private void load_overrides_aconfig_test() {
                try {
                    Properties properties = DeviceConfig.getProperties("aconfig_test");
                    disabledRw =
                        properties.getBoolean(Flags.FLAG_DISABLED_RW, false);
                    disabledRwExported =
                        properties.getBoolean(Flags.FLAG_DISABLED_RW_EXPORTED, false);
                    enabledRw =
                        properties.getBoolean(Flags.FLAG_ENABLED_RW, true);
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
                        properties.getBoolean(Flags.FLAG_DISABLED_RW_IN_OTHER_NAMESPACE, false);
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
            }"#
            + expected_featureflagsmpl_content_2;

        let mut file_set = HashMap::from([
            ("com/android/aconfig/test/Flags.java", expect_flags_content.as_str()),
            (
                "com/android/aconfig/test/FeatureFlagsImpl.java",
                &expect_featureflagsimpl_content_old,
            ),
            ("com/android/aconfig/test/FeatureFlags.java", EXPECTED_FEATUREFLAGS_COMMON_CONTENT),
            (
                "com/android/aconfig/test/CustomFeatureFlags.java",
                EXPECTED_CUSTOMFEATUREFLAGS_CONTENT,
            ),
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

        let parsed_flags = crate::test::parse_test_flags();
        let mode = CodegenMode::Production;
        let modified_parsed_flags =
            crate::commands::modify_parsed_flags_based_on_mode(parsed_flags, mode).unwrap();
        let flag_ids =
            assign_flag_ids(crate::test::TEST_PACKAGE, modified_parsed_flags.iter()).unwrap();
        let generated_files = generate_java_code(
            crate::test::TEST_PACKAGE,
            modified_parsed_flags.into_iter(),
            mode,
            flag_ids,
            true,
        )
        .unwrap();

        let expect_featureflagsimpl_content_new = expected_featureflagsmpl_content_0.to_owned()
            + r#"
            import android.aconfig.storage.StorageInternalReader;
            import android.util.Log;
            "#
            + expected_featureflagsmpl_content_1
            + r#"
        StorageInternalReader reader;
        boolean readFromNewStorage;

        boolean useNewStorageValueAndDiscardOld = false;

        private final static String TAG = "AconfigJavaCodegen";
        private final static String SUCCESS_LOG = "success: %s value matches";
        private final static String MISMATCH_LOG = "error: %s value mismatch, new storage value is %s, old storage value is %s";
        private final static String ERROR_LOG = "error: failed to read flag value";

        private void init() {
            if (reader != null) return;
            if (DeviceConfig.getBoolean("core_experiments_team_internal", "com.android.providers.settings.storage_test_mission_1", false)) {
                readFromNewStorage = true;
                try {
                    reader = new StorageInternalReader("system", "com.android.aconfig.test");
                } catch (Exception e) {
                    reader = null;
                }
            }

            useNewStorageValueAndDiscardOld =
                DeviceConfig.getBoolean("core_experiments_team_internal", "com.android.providers.settings.use_new_storage_value", false);
        }

        private void load_overrides_aconfig_test() {
            try {
                Properties properties = DeviceConfig.getProperties("aconfig_test");
                disabledRw =
                    properties.getBoolean(Flags.FLAG_DISABLED_RW, false);
                disabledRwExported =
                    properties.getBoolean(Flags.FLAG_DISABLED_RW_EXPORTED, false);
                enabledRw =
                    properties.getBoolean(Flags.FLAG_ENABLED_RW, true);
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
            init();
            if (readFromNewStorage && reader != null) {
                boolean val;
                try {
                    val = reader.getBooleanFlagValue(1);
                    if (val != disabledRw) {
                        Log.w(TAG, String.format(MISMATCH_LOG, "disabledRw", val, disabledRw));
                    }

                    if (useNewStorageValueAndDiscardOld) {
                        disabledRw = val;
                    }

                    val = reader.getBooleanFlagValue(2);
                    if (val != disabledRwExported) {
                        Log.w(TAG, String.format(MISMATCH_LOG, "disabledRwExported", val, disabledRwExported));
                    }

                    if (useNewStorageValueAndDiscardOld) {
                        disabledRwExported = val;
                    }

                    val = reader.getBooleanFlagValue(8);
                    if (val != enabledRw) {
                        Log.w(TAG, String.format(MISMATCH_LOG, "enabledRw", val, enabledRw));
                    }

                    if (useNewStorageValueAndDiscardOld) {
                        enabledRw = val;
                    }

                } catch (Exception e) {
                    Log.e(TAG, ERROR_LOG, e);
                }
            }
        }

        private void load_overrides_other_namespace() {
            try {
                Properties properties = DeviceConfig.getProperties("other_namespace");
                disabledRwInOtherNamespace =
                    properties.getBoolean(Flags.FLAG_DISABLED_RW_IN_OTHER_NAMESPACE, false);
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
            init();
            if (readFromNewStorage && reader != null) {
                boolean val;
                try {
                    val = reader.getBooleanFlagValue(3);
                    if (val != disabledRwInOtherNamespace) {
                        Log.w(TAG, String.format(MISMATCH_LOG, "disabledRwInOtherNamespace", val, disabledRwInOtherNamespace));
                    }

                    if (useNewStorageValueAndDiscardOld) {
                        disabledRwInOtherNamespace = val;
                    }

                } catch (Exception e) {
                    Log.e(TAG, ERROR_LOG, e);
                }
            }
        }"# + expected_featureflagsmpl_content_2;

        let mut file_set = HashMap::from([
            ("com/android/aconfig/test/Flags.java", expect_flags_content.as_str()),
            (
                "com/android/aconfig/test/FeatureFlagsImpl.java",
                &expect_featureflagsimpl_content_new,
            ),
            ("com/android/aconfig/test/FeatureFlags.java", EXPECTED_FEATUREFLAGS_COMMON_CONTENT),
            (
                "com/android/aconfig/test/CustomFeatureFlags.java",
                EXPECTED_CUSTOMFEATUREFLAGS_CONTENT,
            ),
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
        let mode = CodegenMode::Exported;
        let modified_parsed_flags =
            crate::commands::modify_parsed_flags_based_on_mode(parsed_flags, mode).unwrap();
        let flag_ids =
            assign_flag_ids(crate::test::TEST_PACKAGE, modified_parsed_flags.iter()).unwrap();
        let generated_files = generate_java_code(
            crate::test::TEST_PACKAGE,
            modified_parsed_flags.into_iter(),
            mode,
            flag_ids,
            true,
        )
        .unwrap();

        let expect_flags_content = r#"
        package com.android.aconfig.test;
        /** @hide */
        public final class Flags {
            /** @hide */
            public static final String FLAG_DISABLED_RW_EXPORTED = "com.android.aconfig.test.disabled_rw_exported";
            /** @hide */
            public static final String FLAG_ENABLED_FIXED_RO_EXPORTED = "com.android.aconfig.test.enabled_fixed_ro_exported";
            /** @hide */
            public static final String FLAG_ENABLED_RO_EXPORTED = "com.android.aconfig.test.enabled_ro_exported";
            public static boolean disabledRwExported() {
                return FEATURE_FLAGS.disabledRwExported();
            }
            public static boolean enabledFixedRoExported() {
                return FEATURE_FLAGS.enabledFixedRoExported();
            }
            public static boolean enabledRoExported() {
                return FEATURE_FLAGS.enabledRoExported();
            }
            private static FeatureFlags FEATURE_FLAGS = new FeatureFlagsImpl();
        }
        "#;

        let expect_feature_flags_content = r#"
        package com.android.aconfig.test;
        /** @hide */
        public interface FeatureFlags {
            boolean disabledRwExported();
            boolean enabledFixedRoExported();
            boolean enabledRoExported();
        }
        "#;

        let expect_feature_flags_impl_content = r#"
        package com.android.aconfig.test;
        import android.provider.DeviceConfig;
        import android.provider.DeviceConfig.Properties;
        /** @hide */
        public final class FeatureFlagsImpl implements FeatureFlags {
            private static volatile boolean aconfig_test_is_cached = false;
            private static boolean disabledRwExported = false;
            private static boolean enabledFixedRoExported = false;
            private static boolean enabledRoExported = false;


            private void load_overrides_aconfig_test() {
                try {
                    Properties properties = DeviceConfig.getProperties("aconfig_test");
                    disabledRwExported =
                        properties.getBoolean(Flags.FLAG_DISABLED_RW_EXPORTED, false);
                    enabledFixedRoExported =
                        properties.getBoolean(Flags.FLAG_ENABLED_FIXED_RO_EXPORTED, false);
                    enabledRoExported =
                        properties.getBoolean(Flags.FLAG_ENABLED_RO_EXPORTED, false);
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
            @Override
            public boolean disabledRwExported() {
                if (!aconfig_test_is_cached) {
                    load_overrides_aconfig_test();
                }
                return disabledRwExported;
            }
            @Override
            public boolean enabledFixedRoExported() {
                if (!aconfig_test_is_cached) {
                    load_overrides_aconfig_test();
                }
                return enabledFixedRoExported;
            }
            @Override
            public boolean enabledRoExported() {
                if (!aconfig_test_is_cached) {
                    load_overrides_aconfig_test();
                }
                return enabledRoExported;
            }
        }"#;

        let expect_custom_feature_flags_content = r#"
        package com.android.aconfig.test;

        import java.util.Arrays;
        import java.util.HashSet;
        import java.util.List;
        import java.util.Set;
        import java.util.function.BiPredicate;
        import java.util.function.Predicate;

        /** @hide */
        public class CustomFeatureFlags implements FeatureFlags {

            private BiPredicate<String, Predicate<FeatureFlags>> mGetValueImpl;

            public CustomFeatureFlags(BiPredicate<String, Predicate<FeatureFlags>> getValueImpl) {
                mGetValueImpl = getValueImpl;
            }

            @Override
            public boolean disabledRwExported() {
                return getValue(Flags.FLAG_DISABLED_RW_EXPORTED,
                    FeatureFlags::disabledRwExported);
            }
            @Override
            public boolean enabledFixedRoExported() {
                return getValue(Flags.FLAG_ENABLED_FIXED_RO_EXPORTED,
                    FeatureFlags::enabledFixedRoExported);
            }
            @Override
            public boolean enabledRoExported() {
                return getValue(Flags.FLAG_ENABLED_RO_EXPORTED,
                    FeatureFlags::enabledRoExported);
            }

            protected boolean getValue(String flagName, Predicate<FeatureFlags> getter) {
                return mGetValueImpl.test(flagName, getter);
            }

            public List<String> getFlagNames() {
                return Arrays.asList(
                    Flags.FLAG_DISABLED_RW_EXPORTED,
                    Flags.FLAG_ENABLED_FIXED_RO_EXPORTED,
                    Flags.FLAG_ENABLED_RO_EXPORTED
                );
            }

            private Set<String> mReadOnlyFlagsSet = new HashSet<>(
                Arrays.asList(
                    ""
                )
            );
        }
    "#;

        let mut file_set = HashMap::from([
            ("com/android/aconfig/test/Flags.java", expect_flags_content),
            ("com/android/aconfig/test/FeatureFlags.java", expect_feature_flags_content),
            ("com/android/aconfig/test/FeatureFlagsImpl.java", expect_feature_flags_impl_content),
            (
                "com/android/aconfig/test/CustomFeatureFlags.java",
                expect_custom_feature_flags_content,
            ),
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
        let mode = CodegenMode::Test;
        let modified_parsed_flags =
            crate::commands::modify_parsed_flags_based_on_mode(parsed_flags, mode).unwrap();
        let flag_ids =
            assign_flag_ids(crate::test::TEST_PACKAGE, modified_parsed_flags.iter()).unwrap();
        let generated_files = generate_java_code(
            crate::test::TEST_PACKAGE,
            modified_parsed_flags.into_iter(),
            mode,
            flag_ids,
            true,
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
            @com.android.aconfig.annotations.AconfigFlagAccessor
            public boolean disabledRo() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            public boolean disabledRw() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            public boolean disabledRwExported() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            public boolean disabledRwInOtherNamespace() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            public boolean enabledFixedRo() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            public boolean enabledFixedRoExported() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            public boolean enabledRo() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            public boolean enabledRoExported() {
                throw new UnsupportedOperationException(
                    "Method is not implemented.");
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
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
                "com/android/aconfig/test/CustomFeatureFlags.java",
                EXPECTED_CUSTOMFEATUREFLAGS_CONTENT,
            ),
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
    fn test_generate_java_code_force_read_only() {
        let parsed_flags = crate::test::parse_test_flags();
        let mode = CodegenMode::ForceReadOnly;
        let modified_parsed_flags =
            crate::commands::modify_parsed_flags_based_on_mode(parsed_flags, mode).unwrap();
        let flag_ids =
            assign_flag_ids(crate::test::TEST_PACKAGE, modified_parsed_flags.iter()).unwrap();
        let generated_files = generate_java_code(
            crate::test::TEST_PACKAGE,
            modified_parsed_flags.into_iter(),
            mode,
            flag_ids,
            true,
        )
        .unwrap();
        let expect_featureflags_content = r#"
        package com.android.aconfig.test;
        // TODO(b/303773055): Remove the annotation after access issue is resolved.
        import android.compat.annotation.UnsupportedAppUsage;
        /** @hide */
        public interface FeatureFlags {
            @com.android.aconfig.annotations.AssumeFalseForR8
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            boolean disabledRo();
            @com.android.aconfig.annotations.AssumeFalseForR8
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            boolean disabledRw();
            @com.android.aconfig.annotations.AssumeFalseForR8
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            boolean disabledRwInOtherNamespace();
            @com.android.aconfig.annotations.AssumeTrueForR8
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            boolean enabledFixedRo();
            @com.android.aconfig.annotations.AssumeTrueForR8
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            boolean enabledRo();
            @com.android.aconfig.annotations.AssumeTrueForR8
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            boolean enabledRw();
        }"#;

        let expect_featureflagsimpl_content = r#"
        package com.android.aconfig.test;
        // TODO(b/303773055): Remove the annotation after access issue is resolved.
        import android.compat.annotation.UnsupportedAppUsage;
        /** @hide */
        public final class FeatureFlagsImpl implements FeatureFlags {
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean disabledRo() {
                return false;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean disabledRw() {
                return false;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean disabledRwInOtherNamespace() {
                return false;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean enabledFixedRo() {
                return true;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean enabledRo() {
                return true;
            }
            @Override
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public boolean enabledRw() {
                return true;
            }
        }
        "#;

        let expect_flags_content = r#"
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
            public static final String FLAG_DISABLED_RW_IN_OTHER_NAMESPACE = "com.android.aconfig.test.disabled_rw_in_other_namespace";
            /** @hide */
            public static final String FLAG_ENABLED_FIXED_RO = "com.android.aconfig.test.enabled_fixed_ro";
            /** @hide */
            public static final String FLAG_ENABLED_RO = "com.android.aconfig.test.enabled_ro";
            /** @hide */
            public static final String FLAG_ENABLED_RW = "com.android.aconfig.test.enabled_rw";
            @com.android.aconfig.annotations.AssumeFalseForR8
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public static boolean disabledRo() {
                return FEATURE_FLAGS.disabledRo();
            }
            @com.android.aconfig.annotations.AssumeFalseForR8
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public static boolean disabledRw() {
                return FEATURE_FLAGS.disabledRw();
            }
            @com.android.aconfig.annotations.AssumeFalseForR8
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public static boolean disabledRwInOtherNamespace() {
                return FEATURE_FLAGS.disabledRwInOtherNamespace();
            }
            @com.android.aconfig.annotations.AssumeTrueForR8
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public static boolean enabledFixedRo() {
                return FEATURE_FLAGS.enabledFixedRo();
            }
            @com.android.aconfig.annotations.AssumeTrueForR8
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public static boolean enabledRo() {
                return FEATURE_FLAGS.enabledRo();
            }
            @com.android.aconfig.annotations.AssumeTrueForR8
            @com.android.aconfig.annotations.AconfigFlagAccessor
            @UnsupportedAppUsage
            public static boolean enabledRw() {
                return FEATURE_FLAGS.enabledRw();
            }
            private static FeatureFlags FEATURE_FLAGS = new FeatureFlagsImpl();
        }"#;

        let expect_customfeatureflags_content = r#"
        package com.android.aconfig.test;

        // TODO(b/303773055): Remove the annotation after access issue is resolved.
        import android.compat.annotation.UnsupportedAppUsage;
        import java.util.Arrays;
        import java.util.HashSet;
        import java.util.List;
        import java.util.Set;
        import java.util.function.BiPredicate;
        import java.util.function.Predicate;

        /** @hide */
        public class CustomFeatureFlags implements FeatureFlags {

            private BiPredicate<String, Predicate<FeatureFlags>> mGetValueImpl;

            public CustomFeatureFlags(BiPredicate<String, Predicate<FeatureFlags>> getValueImpl) {
                mGetValueImpl = getValueImpl;
            }

            @Override
            @UnsupportedAppUsage
            public boolean disabledRo() {
                return getValue(Flags.FLAG_DISABLED_RO,
                        FeatureFlags::disabledRo);
            }
            @Override
            @UnsupportedAppUsage
            public boolean disabledRw() {
                return getValue(Flags.FLAG_DISABLED_RW,
                    FeatureFlags::disabledRw);
            }
            @Override
            @UnsupportedAppUsage
            public boolean disabledRwInOtherNamespace() {
                return getValue(Flags.FLAG_DISABLED_RW_IN_OTHER_NAMESPACE,
                    FeatureFlags::disabledRwInOtherNamespace);
            }
            @Override
            @UnsupportedAppUsage
            public boolean enabledFixedRo() {
                return getValue(Flags.FLAG_ENABLED_FIXED_RO,
                    FeatureFlags::enabledFixedRo);
            }
            @Override
            @UnsupportedAppUsage
            public boolean enabledRo() {
                return getValue(Flags.FLAG_ENABLED_RO,
                    FeatureFlags::enabledRo);
            }
            @Override
            @UnsupportedAppUsage
            public boolean enabledRw() {
                return getValue(Flags.FLAG_ENABLED_RW,
                    FeatureFlags::enabledRw);
            }

            public boolean isFlagReadOnlyOptimized(String flagName) {
                if (mReadOnlyFlagsSet.contains(flagName) &&
                    isOptimizationEnabled()) {
                        return true;
                }
                return false;
            }

            @com.android.aconfig.annotations.AssumeTrueForR8
            private boolean isOptimizationEnabled() {
                return false;
            }

            protected boolean getValue(String flagName, Predicate<FeatureFlags> getter) {
                return mGetValueImpl.test(flagName, getter);
            }

            public List<String> getFlagNames() {
                return Arrays.asList(
                    Flags.FLAG_DISABLED_RO,
                    Flags.FLAG_DISABLED_RW,
                    Flags.FLAG_DISABLED_RW_IN_OTHER_NAMESPACE,
                    Flags.FLAG_ENABLED_FIXED_RO,
                    Flags.FLAG_ENABLED_RO,
                    Flags.FLAG_ENABLED_RW
                );
            }

            private Set<String> mReadOnlyFlagsSet = new HashSet<>(
                Arrays.asList(
                    Flags.FLAG_DISABLED_RO,
                    Flags.FLAG_DISABLED_RW,
                    Flags.FLAG_DISABLED_RW_IN_OTHER_NAMESPACE,
                    Flags.FLAG_ENABLED_FIXED_RO,
                    Flags.FLAG_ENABLED_RO,
                    Flags.FLAG_ENABLED_RW,
                    ""
                )
            );
        }
        "#;

        let mut file_set = HashMap::from([
            ("com/android/aconfig/test/Flags.java", expect_flags_content),
            ("com/android/aconfig/test/FeatureFlagsImpl.java", expect_featureflagsimpl_content),
            ("com/android/aconfig/test/FeatureFlags.java", expect_featureflags_content),
            ("com/android/aconfig/test/CustomFeatureFlags.java", expect_customfeatureflags_content),
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
