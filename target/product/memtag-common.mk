# Copyright (C) 2023 The Android Open Source Project
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
#

# This is a recommended set of common components to enable MTE for.

PRODUCT_MEMTAG_HEAP_ASYNC_DEFAULT_INCLUDE_PATHS := \
    external/android-clat \
    external/iproute2 \
    external/iptables \
    external/mtpd \
    external/ppp \
    hardware/st/nfc \
    hardware/st/secure_element \
    hardware/st/secure_element2 \
    packages/modules/StatsD \
    system/bpf \
    system/netd/netutil_wrappers \
    system/netd/server
