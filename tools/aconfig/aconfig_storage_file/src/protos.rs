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

// When building with the Android tool-chain
//
//   - an external crate `aconfig_storage_metadata_protos` will be generated
//   - the feature "cargo" will be disabled
//
// When building with cargo
//
//   - a local sub-module will be generated in OUT_DIR and included in this file
//   - the feature "cargo" will be enabled
//
// This module hides these differences from the rest of the codebase.

// ---- When building with the Android tool-chain ----
#[cfg(not(feature = "cargo"))]
mod auto_generated {
    pub use aconfig_storage_protos::aconfig_storage_metadata as ProtoStorage;
    pub use ProtoStorage::Storage_file_info as ProtoStorageFileInfo;
    pub use ProtoStorage::Storage_files as ProtoStorageFiles;
}

// ---- When building with cargo ----
#[cfg(feature = "cargo")]
mod auto_generated {
    // include! statements should be avoided (because they import file contents verbatim), but
    // because this is only used during local development, and only if using cargo instead of the
    // Android tool-chain, we allow it
    include!(concat!(env!("OUT_DIR"), "/aconfig_storage_protos/mod.rs"));
    pub use aconfig_storage_metadata::Storage_file_info as ProtoStorageFileInfo;
    pub use aconfig_storage_metadata::Storage_files as ProtoStorageFiles;
}

// ---- Common for both the Android tool-chain and cargo ----
pub use auto_generated::*;

use anyhow::Result;

pub mod storage_files {
    use super::*;
    use anyhow::ensure;

    pub fn try_from_binary_proto(bytes: &[u8]) -> Result<ProtoStorageFiles> {
        let message: ProtoStorageFiles = protobuf::Message::parse_from_bytes(bytes)?;
        verify_fields(&message)?;
        Ok(message)
    }

    pub fn verify_fields(storage_files: &ProtoStorageFiles) -> Result<()> {
        for storage_file_info in storage_files.files.iter() {
            ensure!(
                !storage_file_info.package_map().is_empty(),
                "invalid storage file record: missing package map file for container {}",
                storage_file_info.container()
            );
            ensure!(
                !storage_file_info.flag_map().is_empty(),
                "invalid storage file record: missing flag map file for container {}",
                storage_file_info.container()
            );
            ensure!(
                !storage_file_info.flag_val().is_empty(),
                "invalid storage file record: missing flag val file for container {}",
                storage_file_info.container()
            );
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::get_binary_storage_proto_bytes;

    #[test]
    fn test_parse_storage_files() {
        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: "/system/etc/package.map"
    flag_map: "/system/etc/flag.map"
    flag_val: "/metadata/aconfig/system.val"
    timestamp: 12345
}
files {
    version: 1
    container: "product"
    package_map: "/product/etc/package.map"
    flag_map: "/product/etc/flag.map"
    flag_val: "/metadata/aconfig/product.val"
    timestamp: 54321
}
"#;
        let binary_proto_bytes = get_binary_storage_proto_bytes(text_proto).unwrap();
        let storage_files = storage_files::try_from_binary_proto(&binary_proto_bytes).unwrap();
        assert_eq!(storage_files.files.len(), 2);
        let system_file = &storage_files.files[0];
        assert_eq!(system_file.version(), 0);
        assert_eq!(system_file.container(), "system");
        assert_eq!(system_file.package_map(), "/system/etc/package.map");
        assert_eq!(system_file.flag_map(), "/system/etc/flag.map");
        assert_eq!(system_file.flag_val(), "/metadata/aconfig/system.val");
        assert_eq!(system_file.timestamp(), 12345);
        let product_file = &storage_files.files[1];
        assert_eq!(product_file.version(), 1);
        assert_eq!(product_file.container(), "product");
        assert_eq!(product_file.package_map(), "/product/etc/package.map");
        assert_eq!(product_file.flag_map(), "/product/etc/flag.map");
        assert_eq!(product_file.flag_val(), "/metadata/aconfig/product.val");
        assert_eq!(product_file.timestamp(), 54321);
    }

    #[test]
    fn test_parse_invalid_storage_files() {
        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: ""
    flag_map: "/system/etc/flag.map"
    flag_val: "/metadata/aconfig/system.val"
    timestamp: 12345
}
"#;
        let binary_proto_bytes = get_binary_storage_proto_bytes(text_proto).unwrap();
        let err = storage_files::try_from_binary_proto(&binary_proto_bytes).unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "invalid storage file record: missing package map file for container system"
        );

        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: "/system/etc/package.map"
    flag_map: ""
    flag_val: "/metadata/aconfig/system.val"
    timestamp: 12345
}
"#;
        let binary_proto_bytes = get_binary_storage_proto_bytes(text_proto).unwrap();
        let err = storage_files::try_from_binary_proto(&binary_proto_bytes).unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "invalid storage file record: missing flag map file for container system"
        );

        let text_proto = r#"
files {
    version: 0
    container: "system"
    package_map: "/system/etc/package.map"
    flag_map: "/system/etc/flag.map"
    flag_val: ""
    timestamp: 12345
}
"#;
        let binary_proto_bytes = get_binary_storage_proto_bytes(text_proto).unwrap();
        let err = storage_files::try_from_binary_proto(&binary_proto_bytes).unwrap_err();
        assert_eq!(
            format!("{:?}", err),
            "invalid storage file record: missing flag val file for container system"
        );
    }
}
