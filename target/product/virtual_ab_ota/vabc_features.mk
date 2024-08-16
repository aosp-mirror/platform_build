#
# Copyright (C) 2022 The Android Open-Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This file enables baseline features, such as io_uring,
# userspace merge, etc. But sets compression method to none.
# This .mk file also removes snapuserd from vendor ramdisk,
# as T launching devices will have init_boot which has snapuserd
# in generic ramdisk.
#
# T and U launching devices should include this .mk file, and configure
# compression algorithm by setting
# PRODUCT_VIRTUAL_AB_COMPRESSION_METHOD to lz4, gz or brotli. Complete
# set of supported algorithms can be found in
# system/core/fs_mgr/libsnapshot/cow_writer.cpp

PRODUCT_VIRTUAL_AB_OTA := true

PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.enabled=true

PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.compression.enabled=true
PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.userspace.snapshots.enabled=true
PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.io_uring.enabled=true
PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.compression.xor.enabled=true
PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.batch_writes=true
# Low memory device configurations. If memory usage and cpu utilization is
# a bottleneck during OTA, the below configurations can be added to a
# device's .mk file improve performance for low mem devices. Disabling
# ro.virtual_ab.compression.xor.enabled and ro.virtual_ab.io_uring.enabled
# is also recommended
#
# PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.read_ahead_size=16
# PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.o_direct.enabled=true
# PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.merge_thread_priority=19
# PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.worker_thread_priority=0
# PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.num_worker_threads=3
# PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.num_merge_threads=1
# PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.num_verify_threads=1
# PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.cow_op_merge_size=16
# PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.verify_threshold_size=1073741824
# PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.verify_block_size=1048576

# Enabling this property, will improve OTA install time
# but will use an additional CPU core
# PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.compression.threads=true
ifndef PRODUCT_VIRTUAL_AB_COMPRESSION_FACTOR
    PRODUCT_VIRTUAL_AB_COMPRESSION_FACTOR := 65536
endif

PRODUCT_VIRTUAL_AB_COMPRESSION := true
PRODUCT_VIRTUAL_AB_COMPRESSION_METHOD ?= none
PRODUCT_PACKAGES += \
    snapuserd \

