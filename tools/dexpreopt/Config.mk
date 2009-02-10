#
# Copyright (C) 2008 The Android Open Source Project
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

#
# Included by config/Makefile.
# Defines the pieces necessary for the dexpreopt process.
#
# inputs: INSTALLED_RAMDISK_TARGET, BUILT_SYSTEMIMAGE_UNOPT
# outputs: BUILT_SYSTEMIMAGE, SYSTEMIMAGE_SOURCE_DIR
#
LOCAL_PATH := $(my-dir)

# TODO: see if we can make the .odex files not be product-specific.
# They can't be completely common, though, because their format
# depends on the architecture of the target system; ARM and x86
# would have different versions.
intermediates := \
	$(call intermediates-dir-for,PACKAGING,dexpreopt)
dexpreopt_system_dir := $(intermediates)/system
built_afar := $(call intermediates-dir-for,EXECUTABLES,afar)/afar
built_dowrapper := \
	$(call intermediates-dir-for,EXECUTABLES,dexopt-wrapper)/dexopt-wrapper

# Generate a stripped-down init.rc based on the real one.
dexpreopt_initrc := $(intermediates)/etc/init.rc
geninitrc_script := $(LOCAL_PATH)/geninitrc.awk
$(dexpreopt_initrc): script := $(geninitrc_script)
$(dexpreopt_initrc): system/core/rootdir/init.rc $(geninitrc_script)
	@echo "Dexpreopt init.rc: $@"
	@mkdir -p $(dir $@)
	$(hide) awk -f $(script) < $< > $@

BUILT_DEXPREOPT_RAMDISK := $(intermediates)/ramdisk.img
$(BUILT_DEXPREOPT_RAMDISK): intermediates := $(intermediates)
$(BUILT_DEXPREOPT_RAMDISK): dexpreopt_root_out := $(intermediates)/root
$(BUILT_DEXPREOPT_RAMDISK): dexpreopt_initrc := $(dexpreopt_initrc)
$(BUILT_DEXPREOPT_RAMDISK): built_afar := $(built_afar)
$(BUILT_DEXPREOPT_RAMDISK): built_dowrapper := $(built_dowrapper)
$(BUILT_DEXPREOPT_RAMDISK): \
	$(INSTALLED_RAMDISK_TARGET) \
	$(dexpreopt_initrc) \
	$(built_afar) \
	$(built_dowrapper) \
	| $(MKBOOTFS) $(ACP)
$(BUILT_DEXPREOPT_RAMDISK):
	@echo "Dexpreopt ramdisk: $@"
	$(hide) rm -f $@
	$(hide) rm -rf $(dexpreopt_root_out)
	$(hide) mkdir -p $(dexpreopt_root_out)
	$(hide) $(ACP) -rd $(TARGET_ROOT_OUT) $(intermediates)
	$(hide) $(ACP) -f $(dexpreopt_initrc) $(dexpreopt_root_out)/
	$(hide) $(ACP) $(built_afar) $(dexpreopt_root_out)/sbin/
	$(hide) $(ACP) $(built_dowrapper) $(dexpreopt_root_out)/sbin/
	$(MKBOOTFS) $(dexpreopt_root_out) | gzip > $@

sign_dexpreopt := true
ifdef sign_dexpreopt
  # Such a huge hack.  We need to re-sign the .apks with the
  # same certs that they were originally signed with.
  dexpreopt_package_certs_file := $(intermediates)/package-certs
  $(shell mkdir -p $(intermediates))
  $(shell rm -f $(dexpreopt_package_certs_file))
  $(foreach p,$(PACKAGES),\
    $(shell echo "$(p) $(PACKAGES.$(p).CERTIFICATE) $(PACKAGES.$(p).PRIVATE_KEY)" >> $(dexpreopt_package_certs_file)))
endif

# Build an optimized image from the unoptimized image
BUILT_DEXPREOPT_SYSTEMIMAGE := $(intermediates)/system.img
$(BUILT_DEXPREOPT_SYSTEMIMAGE): $(BUILT_SYSTEMIMAGE_UNOPT)
$(BUILT_DEXPREOPT_SYSTEMIMAGE): $(BUILT_DEXPREOPT_RAMDISK)
$(BUILT_DEXPREOPT_SYSTEMIMAGE): | $(DEXPREOPT) $(ACP) $(ZIPALIGN)
$(BUILT_DEXPREOPT_SYSTEMIMAGE): SYSTEM_DIR := $(dexpreopt_system_dir)
$(BUILT_DEXPREOPT_SYSTEMIMAGE): DEXPREOPT_TMP := $(intermediates)/emutmp
ifdef sign_dexpreopt
$(BUILT_DEXPREOPT_SYSTEMIMAGE): | $(SIGNAPK_JAR)
endif
$(BUILT_DEXPREOPT_SYSTEMIMAGE):
	@rm -f $@
	@echo "dexpreopt: copy system to $(SYSTEM_DIR)"
	@rm -rf $(SYSTEM_DIR)
	@mkdir -p $(dir $(SYSTEM_DIR))
	$(hide) $(ACP) -rd $(TARGET_OUT) $(SYSTEM_DIR)
	@echo "dexpreopt: optimize dex files"
	@rm -rf $(DEXPREOPT_TMP)
	@mkdir -p $(DEXPREOPT_TMP)
	$(hide) \
	    PATH=$(HOST_OUT_EXECUTABLES):$$PATH \
	    $(DEXPREOPT) \
		    --kernel prebuilt/android-arm/kernel/kernel-qemu \
		    --ramdisk $(BUILT_DEXPREOPT_RAMDISK) \
		    --image $(BUILT_SYSTEMIMAGE_UNOPT) \
		    --system $(PRODUCT_OUT) \
		    --tmpdir $(DEXPREOPT_TMP) \
		    --outsystemdir $(SYSTEM_DIR)
ifdef sign_dexpreopt
	@echo "dexpreopt: re-sign apk files"
	$(hide) \
	    export PATH=$(HOST_OUT_EXECUTABLES):$$PATH; \
	    for apk in $(SYSTEM_DIR)/app/*.apk; do \
		packageName=`basename $$apk`; \
		packageName=`echo $$packageName | sed -e 's/.apk$$//'`; \
		cert=`grep "^$$packageName " $(dexpreopt_package_certs_file) | \
		      awk '{print $$2}'`; \
		pkey=`grep "^$$packageName " $(dexpreopt_package_certs_file) | \
		      awk '{print $$3}'`; \
		if [ "$$cert" -a "$$pkey" ]; then \
		    echo "dexpreopt: re-sign app/"$$packageName".apk"; \
		    tmpApk=$$apk~; \
		    rm -f $$tmpApk; \
		    java -jar $(SIGNAPK_JAR) $$cert $$pkey $$apk $$tmpApk || \
			  exit 11; \
		    mv -f $$tmpApk $$apk; \
		else \
		    echo "dexpreopt: no keys for app/"$$packageName".apk"; \
		    rm $(SYSTEM_DIR)/app/$$packageName.* && \
			cp $(TARGET_OUT)/app/$$packageName.apk \
			   $(SYSTEM_DIR)/app || exit 12; \
		fi; \
		tmpApk=$$apk~; \
		rm -f $$tmpApk; \
		$(ZIPALIGN) -f 4 $$apk $$tmpApk || exit 13; \
		mv -f $$tmpApk $$apk; \
	    done
endif
	@echo "Dexpreopt system image: $@"
	$(hide) $(MKYAFFS2) -f $(SYSTEM_DIR) $@

.PHONY: dexpreoptimage
dexpreoptimage: $(BUILT_DEXPREOPT_SYSTEMIMAGE)

# Tell our caller to use the optimized systemimage
BUILT_SYSTEMIMAGE := $(BUILT_DEXPREOPT_SYSTEMIMAGE)
SYSTEMIMAGE_SOURCE_DIR := $(dexpreopt_system_dir)
