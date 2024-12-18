//! aconfig storage read api java rust interlop

use aconfig_storage_file::SipHasher13;
use aconfig_storage_read_api::flag_table_query::find_flag_read_context;
use aconfig_storage_read_api::flag_value_query::find_boolean_flag_value;
use aconfig_storage_read_api::package_table_query::find_package_read_context;
use aconfig_storage_read_api::{FlagReadContext, PackageReadContext};

use anyhow::Result;
use jni::objects::{JByteBuffer, JClass, JString};
use jni::sys::{jboolean, jint, jlong};
use jni::JNIEnv;
use std::hash::Hasher;

/// Call rust find package read context
fn get_package_read_context_java(
    env: &mut JNIEnv,
    file: JByteBuffer,
    package: JString,
) -> Result<Option<PackageReadContext>> {
    // SAFETY:
    // The safety here is ensured as the package name is guaranteed to be a java string
    let package_name: String = unsafe { env.get_string_unchecked(&package)?.into() };
    let buffer_ptr = env.get_direct_buffer_address(&file)?;
    let buffer_size = env.get_direct_buffer_capacity(&file)?;
    // SAFETY:
    // The safety here is ensured as only non null MemoryMappedBuffer will be passed in,
    // so the conversion to slice is guaranteed to be valid
    let buffer = unsafe { std::slice::from_raw_parts(buffer_ptr, buffer_size) };
    Ok(find_package_read_context(buffer, &package_name)?)
}

/// Get package read context JNI
#[no_mangle]
#[allow(unused)]
pub extern "system" fn Java_android_aconfig_storage_AconfigStorageReadAPI_getPackageReadContextImpl<
    'local,
>(
    mut env: JNIEnv<'local>,
    class: JClass<'local>,
    file: JByteBuffer<'local>,
    package: JString<'local>,
) -> JByteBuffer<'local> {
    let mut package_id = -1;
    let mut boolean_start_index = -1;

    match get_package_read_context_java(&mut env, file, package) {
        Ok(context_opt) => {
            if let Some(context) = context_opt {
                package_id = context.package_id as i32;
                boolean_start_index = context.boolean_start_index as i32;
            }
        }
        Err(errmsg) => {
            env.throw(("java/io/IOException", errmsg.to_string())).expect("failed to throw");
        }
    }

    let mut bytes = Vec::new();
    bytes.extend_from_slice(&package_id.to_le_bytes());
    bytes.extend_from_slice(&boolean_start_index.to_le_bytes());
    let (addr, len) = {
        let buf = bytes.leak();
        (buf.as_mut_ptr(), buf.len())
    };
    // SAFETY:
    // The safety here is ensured as the content is ensured to be valid
    unsafe { env.new_direct_byte_buffer(addr, len).expect("failed to create byte buffer") }
}

/// Call rust find flag read context
fn get_flag_read_context_java(
    env: &mut JNIEnv,
    file: JByteBuffer,
    package_id: jint,
    flag: JString,
) -> Result<Option<FlagReadContext>> {
    // SAFETY:
    // The safety here is ensured as the flag name is guaranteed to be a java string
    let flag_name: String = unsafe { env.get_string_unchecked(&flag)?.into() };
    let buffer_ptr = env.get_direct_buffer_address(&file)?;
    let buffer_size = env.get_direct_buffer_capacity(&file)?;
    // SAFETY:
    // The safety here is ensured as only non null MemoryMappedBuffer will be passed in,
    // so the conversion to slice is guaranteed to be valid
    let buffer = unsafe { std::slice::from_raw_parts(buffer_ptr, buffer_size) };
    Ok(find_flag_read_context(buffer, package_id as u32, &flag_name)?)
}

/// Get flag read context JNI
#[no_mangle]
#[allow(unused)]
pub extern "system" fn Java_android_aconfig_storage_AconfigStorageReadAPI_getFlagReadContextImpl<
    'local,
>(
    mut env: JNIEnv<'local>,
    class: JClass<'local>,
    file: JByteBuffer<'local>,
    package_id: jint,
    flag: JString<'local>,
) -> JByteBuffer<'local> {
    let mut flag_type = -1;
    let mut flag_index = -1;

    match get_flag_read_context_java(&mut env, file, package_id, flag) {
        Ok(context_opt) => {
            if let Some(context) = context_opt {
                flag_type = context.flag_type as i32;
                flag_index = context.flag_index as i32;
            }
        }
        Err(errmsg) => {
            env.throw(("java/io/IOException", errmsg.to_string())).expect("failed to throw");
        }
    }

    let mut bytes = Vec::new();
    bytes.extend_from_slice(&flag_type.to_le_bytes());
    bytes.extend_from_slice(&flag_index.to_le_bytes());
    let (addr, len) = {
        let buf = bytes.leak();
        (buf.as_mut_ptr(), buf.len())
    };
    // SAFETY:
    // The safety here is ensured as the content is ensured to be valid
    unsafe { env.new_direct_byte_buffer(addr, len).expect("failed to create byte buffer") }
}

/// Call rust find boolean flag value
fn get_boolean_flag_value_java(
    env: &mut JNIEnv,
    file: JByteBuffer,
    flag_index: jint,
) -> Result<bool> {
    let buffer_ptr = env.get_direct_buffer_address(&file)?;
    let buffer_size = env.get_direct_buffer_capacity(&file)?;
    // SAFETY:
    // The safety here is ensured as only non null MemoryMappedBuffer will be passed in,
    // so the conversion to slice is guaranteed to be valid
    let buffer = unsafe { std::slice::from_raw_parts(buffer_ptr, buffer_size) };
    Ok(find_boolean_flag_value(buffer, flag_index as u32)?)
}

/// Get flag value JNI
#[no_mangle]
#[allow(unused)]
pub extern "system" fn Java_android_aconfig_storage_AconfigStorageReadAPI_getBooleanFlagValue<
    'local,
>(
    mut env: JNIEnv<'local>,
    class: JClass<'local>,
    file: JByteBuffer<'local>,
    flag_index: jint,
) -> jboolean {
    match get_boolean_flag_value_java(&mut env, file, flag_index) {
        Ok(value) => value as u8,
        Err(errmsg) => {
            env.throw(("java/io/IOException", errmsg.to_string())).expect("failed to throw");
            0u8
        }
    }
}

/// Get flag value JNI
#[no_mangle]
#[allow(unused)]
pub extern "system" fn Java_android_aconfig_storage_AconfigStorageReadAPI_hash<'local>(
    mut env: JNIEnv<'local>,
    class: JClass<'local>,
    package_name: JString<'local>,
) -> jlong {
    match siphasher13_hash(&mut env, package_name) {
        Ok(value) => value as jlong,
        Err(errmsg) => {
            env.throw(("java/io/IOException", errmsg.to_string())).expect("failed to throw");
            0i64
        }
    }
}

fn siphasher13_hash(env: &mut JNIEnv, package_name: JString) -> Result<u64> {
    // SAFETY:
    // The safety here is ensured as the flag name is guaranteed to be a java string
    let flag_name: String = unsafe { env.get_string_unchecked(&package_name)?.into() };
    let mut s = SipHasher13::new();
    s.write(flag_name.as_bytes());
    s.write_u8(0xff);
    Ok(s.finish())
}
