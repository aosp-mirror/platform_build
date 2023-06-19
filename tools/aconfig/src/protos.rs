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

// When building with the Android tool-chain
//
//   - an external crate `aconfig_protos` will be generated
//   - the feature "cargo" will be disabled
//
// When building with cargo
//
//   - a local sub-module will be generated in OUT_DIR and included in this file
//   - the feature "cargo" will be enabled
//
// This module hides these differences from the rest of aconfig.

// ---- When building with the Android tool-chain ----
#[cfg(not(feature = "cargo"))]
mod auto_generated {
    pub use aconfig_protos::aconfig::Flag_declaration as ProtoFlagDeclaration;
    pub use aconfig_protos::aconfig::Flag_declarations as ProtoFlagDeclarations;
    pub use aconfig_protos::aconfig::Flag_permission as ProtoFlagPermission;
    pub use aconfig_protos::aconfig::Flag_state as ProtoFlagState;
    pub use aconfig_protos::aconfig::Flag_value as ProtoFlagValue;
    pub use aconfig_protos::aconfig::Flag_values as ProtoFlagValues;
    pub use aconfig_protos::aconfig::Parsed_flag as ProtoParsedFlag;
    pub use aconfig_protos::aconfig::Parsed_flags as ProtoParsedFlags;
    pub use aconfig_protos::aconfig::Tracepoint as ProtoTracepoint;
}

// ---- When building with cargo ----
#[cfg(feature = "cargo")]
mod auto_generated {
    // include! statements should be avoided (because they import file contents verbatim), but
    // because this is only used during local development, and only if using cargo instead of the
    // Android tool-chain, we allow it
    include!(concat!(env!("OUT_DIR"), "/aconfig_proto/mod.rs"));
    pub use aconfig::Flag_declaration as ProtoFlagDeclaration;
    pub use aconfig::Flag_declarations as ProtoFlagDeclarations;
    pub use aconfig::Flag_permission as ProtoFlagPermission;
    pub use aconfig::Flag_state as ProtoFlagState;
    pub use aconfig::Flag_value as ProtoFlagValue;
    pub use aconfig::Flag_values as ProtoFlagValues;
    pub use aconfig::Parsed_flag as ProtoParsedFlag;
    pub use aconfig::Parsed_flags as ProtoParsedFlags;
    pub use aconfig::Tracepoint as ProtoTracepoint;
}

// ---- Common for both the Android tool-chain and cargo ----
pub use auto_generated::*;

use anyhow::Result;

pub fn try_from_text_proto<T>(s: &str) -> Result<T>
where
    T: protobuf::MessageFull,
{
    // warning: parse_from_str does not check if required fields are set
    protobuf::text_format::parse_from_str(s).map_err(|e| e.into())
}
