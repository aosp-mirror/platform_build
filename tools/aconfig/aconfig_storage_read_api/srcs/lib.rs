//! aconfig storage read api java rust interlop

use aconfig_storage_read_api::flag_table_query::find_flag_read_context;
use aconfig_storage_read_api::flag_value_query::find_boolean_flag_value;
use aconfig_storage_read_api::package_table_query::find_package_read_context;
use aconfig_storage_read_api::{FlagReadContext, PackageReadContext};

use anyhow::Result;
use jni::objects::{JByteBuffer, JClass, JString, JValue};
use jni::sys::{jint, jobject};
use jni::JNIEnv;

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

/// Create java package read context return
fn create_java_package_read_context(
    env: &mut JNIEnv,
    success_query: bool,
    error_message: String,
    pkg_found: bool,
    pkg_id: u32,
    start_index: u32,
) -> jobject {
    let query_success = JValue::Bool(success_query as u8);
    let errmsg = env.new_string(error_message).expect("failed to create JString");
    let package_exists = JValue::Bool(pkg_found as u8);
    let package_id = JValue::Int(pkg_id as i32);
    let boolean_start_index = JValue::Int(start_index as i32);
    let context = env.new_object(
        "android/aconfig/storage/PackageReadContext",
        "(ZLjava/lang/String;ZII)V",
        &[query_success, (&errmsg).into(), package_exists, package_id, boolean_start_index],
    );
    context.expect("failed to call PackageReadContext constructor").into_raw()
}

/// Get package read context JNI
#[no_mangle]
#[allow(unused)]
pub extern "system" fn Java_android_aconfig_storage_AconfigStorageReadAPI_getPackageReadContext<
    'local,
>(
    mut env: JNIEnv<'local>,
    class: JClass<'local>,
    file: JByteBuffer<'local>,
    package: JString<'local>,
) -> jobject {
    match get_package_read_context_java(&mut env, file, package) {
        Ok(context_opt) => match context_opt {
            Some(context) => create_java_package_read_context(
                &mut env,
                true,
                String::from(""),
                true,
                context.package_id,
                context.boolean_start_index,
            ),
            None => create_java_package_read_context(&mut env, true, String::from(""), false, 0, 0),
        },
        Err(errmsg) => {
            create_java_package_read_context(&mut env, false, format!("{:?}", errmsg), false, 0, 0)
        }
    }
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

/// Create java flag read context return
fn create_java_flag_read_context(
    env: &mut JNIEnv,
    success_query: bool,
    error_message: String,
    flg_found: bool,
    flg_type: u32,
    flg_index: u32,
) -> jobject {
    let query_success = JValue::Bool(success_query as u8);
    let errmsg = env.new_string(error_message).expect("failed to create JString");
    let flag_exists = JValue::Bool(flg_found as u8);
    let flag_type = JValue::Int(flg_type as i32);
    let flag_index = JValue::Int(flg_index as i32);
    let context = env.new_object(
        "android/aconfig/storage/FlagReadContext",
        "(ZLjava/lang/String;ZII)V",
        &[query_success, (&errmsg).into(), flag_exists, flag_type, flag_index],
    );
    context.expect("failed to call FlagReadContext constructor").into_raw()
}

/// Get flag read context JNI
#[no_mangle]
#[allow(unused)]
pub extern "system" fn Java_android_aconfig_storage_AconfigStorageReadAPI_getFlagReadContext<
    'local,
>(
    mut env: JNIEnv<'local>,
    class: JClass<'local>,
    file: JByteBuffer<'local>,
    package_id: jint,
    flag: JString<'local>,
) -> jobject {
    match get_flag_read_context_java(&mut env, file, package_id, flag) {
        Ok(context_opt) => match context_opt {
            Some(context) => create_java_flag_read_context(
                &mut env,
                true,
                String::from(""),
                true,
                context.flag_type as u32,
                context.flag_index as u32,
            ),
            None => create_java_flag_read_context(&mut env, true, String::from(""), false, 9999, 0),
        },
        Err(errmsg) => {
            create_java_flag_read_context(&mut env, false, format!("{:?}", errmsg), false, 9999, 0)
        }
    }
}

/// Create java boolean flag value return
fn create_java_boolean_flag_value(
    env: &mut JNIEnv,
    success_query: bool,
    error_message: String,
    value: bool,
) -> jobject {
    let query_success = JValue::Bool(success_query as u8);
    let errmsg = env.new_string(error_message).expect("failed to create JString");
    let flag_value = JValue::Bool(value as u8);
    let context = env.new_object(
        "android/aconfig/storage/BooleanFlagValue",
        "(ZLjava/lang/String;Z)V",
        &[query_success, (&errmsg).into(), flag_value],
    );
    context.expect("failed to call BooleanFlagValue constructor").into_raw()
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
) -> jobject {
    match get_boolean_flag_value_java(&mut env, file, flag_index) {
        Ok(value) => create_java_boolean_flag_value(&mut env, true, String::from(""), value),
        Err(errmsg) => {
            create_java_boolean_flag_value(&mut env, false, format!("{:?}", errmsg), false)
        }
    }
}
