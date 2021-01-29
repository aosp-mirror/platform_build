#
# Copyright (C) 2020 The Android Open Source Project
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

host_init_verifier_output := $(PRODUCT_OUT)/host_init_verifier_output.txt

$(host_init_verifier_output): \
    $(INSTALLED_SYSTEMIMAGE_TARGET) \
    $(INSTALLED_SYSTEM_EXTIMAGE_TARGET) \
    $(INSTALLED_VENDORIMAGE_TARGET) \
    $(INSTALLED_ODMIMAGE_TARGET) \
    $(INSTALLED_PRODUCTIMAGE_TARGET) \
    $(call intermediates-dir-for,ETC,passwd_system)/passwd_system \
    $(call intermediates-dir-for,ETC,passwd_system_ext)/passwd_system_ext \
    $(call intermediates-dir-for,ETC,passwd_vendor)/passwd_vendor \
    $(call intermediates-dir-for,ETC,passwd_odm)/passwd_odm \
    $(call intermediates-dir-for,ETC,passwd_product)/passwd_product \
    $(call intermediates-dir-for,ETC,plat_property_contexts)/plat_property_contexts \
    $(call intermediates-dir-for,ETC,system_ext_property_contexts)/system_ext_property_contexts \
    $(call intermediates-dir-for,ETC,product_property_contexts)/product_property_contexts \
    $(call intermediates-dir-for,ETC,vendor_property_contexts)/vendor_property_contexts \
    $(call intermediates-dir-for,ETC,odm_property_contexts)/odm_property_contexts

# Run host_init_verifier on the partition staging directories.
$(host_init_verifier_output): $(HOST_INIT_VERIFIER)
	$(HOST_INIT_VERIFIER) \
		-p $(call intermediates-dir-for,ETC,passwd_system)/passwd_system \
		-p $(call intermediates-dir-for,ETC,passwd_system_ext)/passwd_system_ext \
		-p $(call intermediates-dir-for,ETC,passwd_vendor)/passwd_vendor \
		-p $(call intermediates-dir-for,ETC,passwd_odm)/passwd_odm \
		-p $(call intermediates-dir-for,ETC,passwd_product)/passwd_product \
		--property-contexts=$(call intermediates-dir-for,ETC,plat_property_contexts)/plat_property_contexts \
		--property-contexts=$(call intermediates-dir-for,ETC,system_ext_property_contexts)/system_ext_property_contexts \
		--property-contexts=$(call intermediates-dir-for,ETC,product_property_contexts)/product_property_contexts \
		--property-contexts=$(call intermediates-dir-for,ETC,vendor_property_contexts)/vendor_property_contexts \
		--property-contexts=$(call intermediates-dir-for,ETC,odm_property_contexts)/odm_property_contexts \
		--out_system $(PRODUCT_OUT)/$(TARGET_COPY_OUT_SYSTEM) \
		--out_system_ext $(PRODUCT_OUT)/$(TARGET_COPY_OUT_SYSTEM_EXT) \
		--out_vendor $(PRODUCT_OUT)/$(TARGET_COPY_OUT_VENDOR) \
		--out_odm $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ODM) \
		--out_product $(PRODUCT_OUT)/$(TARGET_COPY_OUT_PRODUCT) \
		> $@

$(call dist-for-goals,droidcore,$(host_init_verifier_output))
