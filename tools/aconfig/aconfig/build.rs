use anyhow::{anyhow, Result};
use std::env;
use std::fs;
use std::fs::File;
use std::io::Write;
use std::path::{Path, PathBuf};

use convert_finalized_flags::read_files_to_map_using_path;
use convert_finalized_flags::FinalizedFlagMap;

// This fn makes assumptions about the working directory which we should not rely
// on for actual (Soong) builds. It is reasonable to assume that this is being
// called from the aconfig directory as cargo is used for local development and
// the cargo workspace for our project is build/make/tools/aconfig.
// This is meant to get the list of finalized flag
// files provided by the filegroup + "locations" in soong.
// Cargo-only usage is asserted via implementation of
// read_files_to_map_using_env, the only public cargo-only fn.
fn read_files_to_map_using_env() -> Result<FinalizedFlagMap> {
    let mut current_dir = std::env::current_dir()?;

    // Path of aconfig from the top of tree.
    let aconfig_path = PathBuf::from("build/make/tools/aconfig");

    // Path of SDK files from the top of tree.
    let sdk_dir_path = PathBuf::from("prebuilts/sdk");

    // Iterate up the directory structure until we have the base aconfig dir.
    while !current_dir.canonicalize()?.ends_with(&aconfig_path) {
        if let Some(parent) = current_dir.parent() {
            current_dir = parent.to_path_buf();
        } else {
            return Err(anyhow!("Cannot execute outside of aconfig."));
        }
    }

    // Remove the aconfig path, leaving the top of the tree.
    for _ in 0..aconfig_path.components().count() {
        current_dir.pop();
    }

    // Get the absolute path of the sdk files.
    current_dir.push(sdk_dir_path);

    let mut flag_files = Vec::new();

    // Search all sub-dirs in prebuilts/sdk for finalized-flags.txt files.
    // The files are in prebuilts/sdk/<api level>/finalized-flags.txt.
    let api_level_dirs = fs::read_dir(current_dir)?;
    for api_level_dir in api_level_dirs {
        if api_level_dir.is_err() {
            eprintln!("Error opening directory: {}", api_level_dir.err().unwrap());
            continue;
        }

        // Skip non-directories.
        let api_level_dir_path = api_level_dir.unwrap().path();
        if !api_level_dir_path.is_dir() {
            continue;
        }

        // Some directories were created before trunk stable and don't have
        // flags, or aren't api level directories at all.
        let flag_file_path = api_level_dir_path.join("finalized-flags.txt");
        if !flag_file_path.exists() {
            continue;
        }

        if let Some(path) = flag_file_path.to_str() {
            flag_files.push(path.to_string());
        } else {
            eprintln!("Error converting path to string: {:?}", flag_file_path);
        }
    }

    read_files_to_map_using_path(flag_files)
}

fn main() {
    let out_dir = env::var_os("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("finalized_flags_record.json");

    let finalized_flags_map: Result<FinalizedFlagMap> = read_files_to_map_using_env();
    if finalized_flags_map.is_err() {
        return;
    }
    let json_str = serde_json::to_string(&finalized_flags_map.unwrap()).unwrap();

    let mut f = File::create(&dest_path).unwrap();
    f.write_all(json_str.as_bytes()).unwrap();

    //println!("cargo:rerun-if-changed=input.txt");
}
