/*
 * Copyright (C) 2017 The Android Open Source Project
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

#include <private/android_filesystem_config.h>

/* Test Data */

#undef NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_DIRS
#undef NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_FILES

static const struct fs_path_config android_device_dirs[] = {
    {00555, AID_ROOT, AID_SYSTEM, 0, "system/etc"},
    {00555, AID_ROOT, AID_SYSTEM, 0, "vendor/etc"},
    {00555, AID_ROOT, AID_SYSTEM, 0, "oem/etc"},
    {00555, AID_ROOT, AID_SYSTEM, 0, "odm/etc"},
    {00755, AID_SYSTEM, AID_ROOT, 0, "system/oem/etc"},
    {00755, AID_SYSTEM, AID_ROOT, 0, "system/odm/etc"},
    {00755, AID_SYSTEM, AID_ROOT, 0, "system/vendor/etc"},
    {00755, AID_SYSTEM, AID_ROOT, 0, "data/misc"},
    {00755, AID_SYSTEM, AID_ROOT, 0, "oem/data/misc"},
    {00755, AID_SYSTEM, AID_ROOT, 0, "odm/data/misc"},
    {00755, AID_SYSTEM, AID_ROOT, 0, "vendor/data/misc"},
    {00555, AID_SYSTEM, AID_ROOT, 0, "etc"},
};

static const struct fs_path_config android_device_files[] = {
    {00444, AID_ROOT, AID_SYSTEM, 0, "system/etc/fs_config_dirs"},
    {00444, AID_ROOT, AID_SYSTEM, 0, "vendor/etc/fs_config_dirs"},
    {00444, AID_ROOT, AID_SYSTEM, 0, "oem/etc/fs_config_dirs"},
    {00444, AID_ROOT, AID_SYSTEM, 0, "odm/etc/fs_config_dirs"},
    {00444, AID_ROOT, AID_SYSTEM, 0, "system/etc/fs_config_files"},
    {00444, AID_ROOT, AID_SYSTEM, 0, "vendor/etc/fs_config_files"},
    {00444, AID_ROOT, AID_SYSTEM, 0, "oem/etc/fs_config_files"},
    {00444, AID_ROOT, AID_SYSTEM, 0, "odm/etc/fs_config_files"},
    {00644, AID_SYSTEM, AID_ROOT, 0, "system/vendor/etc/fs_config_dirs"},
    {00644, AID_SYSTEM, AID_ROOT, 0, "system/oem/etc/fs_config_dirs"},
    {00644, AID_SYSTEM, AID_ROOT, 0, "system/odm/etc/fs_config_dirs"},
    {00644, AID_SYSTEM, AID_ROOT, 0, "system/vendor/etc/fs_config_files"},
    {00644, AID_SYSTEM, AID_ROOT, 0, "system/oem/etc/fs_config_files"},
    {00644, AID_SYSTEM, AID_ROOT, 0, "system/odm/etc/fs_config_files"},
    {00644, AID_SYSTEM, AID_ROOT, 0, "etc/fs_config_files"},
    {00666, AID_ROOT, AID_SYSTEM, 0, "data/misc/oem"},
};
