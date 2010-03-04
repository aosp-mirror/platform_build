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

###########################################################
## Standard rules for building an application package.
##
## Additional inputs from base_rules.make:
## LOCAL_PACKAGE_NAME: The name of the package; the directory
##		will be called this.
##
## MODULE, MODULE_PATH, and MODULE_SUFFIX will
## be set for you.
###########################################################


# If this makefile is being read from within an inheritance,
# use the new values.
skip_definition:=
ifdef LOCAL_PACKAGE_OVERRIDES
  package_overridden := $(call set-inherited-package-variables)
  ifeq ($(strip $(package_overridden)),)
    skip_definition := true
  endif
endif

ifndef skip_definition

LOCAL_PACKAGE_NAME := $(strip $(LOCAL_PACKAGE_NAME))
ifeq ($(LOCAL_PACKAGE_NAME),)
$(error $(LOCAL_PATH): Package modules must define LOCAL_PACKAGE_NAME)
endif

ifneq ($(strip $(LOCAL_MODULE_SUFFIX)),)
$(error $(LOCAL_PATH): Package modules may not define LOCAL_MODULE_SUFFIX)
endif
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)

ifneq ($(strip $(LOCAL_MODULE)),)
$(error $(LOCAL_PATH): Package modules may not define LOCAL_MODULE)
endif
LOCAL_MODULE := $(LOCAL_PACKAGE_NAME)

# Android packages should use Android resources or assets.
ifneq (,$(LOCAL_JAVA_RESOURCE_DIRS))
$(error $(LOCAL_PATH): Package modules may not set LOCAL_JAVA_RESOURCE_DIRS)
endif
ifneq (,$(LOCAL_JAVA_RESOURCE_FILES))
$(error $(LOCAL_PATH): Package modules may not set LOCAL_JAVA_RESOURCE_FILES)
endif

ifneq ($(strip $(LOCAL_MODULE_CLASS)),)
$(error $(LOCAL_PATH): Package modules may not set LOCAL_MODULE_CLASS)
endif
LOCAL_MODULE_CLASS := APPS

# Package LOCAL_MODULE_TAGS default to optional
LOCAL_MODULE_TAGS := $(strip $(LOCAL_MODULE_TAGS))
ifeq ($(LOCAL_MODULE_TAGS),)
LOCAL_MODULE_TAGS := optional
endif

#$(warning $(LOCAL_PATH) $(LOCAL_PACKAGE_NAME) $(sort $(LOCAL_MODULE_TAGS)))

ifeq (,$(LOCAL_ASSET_DIR))
LOCAL_ASSET_DIR := $(LOCAL_PATH)/assets
endif

ifeq (,$(LOCAL_RESOURCE_DIR))
  LOCAL_RESOURCE_DIR := $(LOCAL_PATH)/res
endif
LOCAL_RESOURCE_DIR := \
  $(wildcard $(foreach dir, $(PRODUCT_PACKAGE_OVERLAYS), \
    $(addprefix $(dir)/, $(LOCAL_RESOURCE_DIR)))) \
  $(wildcard $(foreach dir, $(DEVICE_PACKAGE_OVERLAYS), \
    $(addprefix $(dir)/, $(LOCAL_RESOURCE_DIR)))) \
  $(LOCAL_RESOURCE_DIR)

# this is an app, so add the system libraries to the search path
LOCAL_AIDL_INCLUDES += $(FRAMEWORKS_BASE_JAVA_SRC_DIRS)

#$(warning Finding assets for $(LOCAL_ASSET_DIR))

all_assets := $(call find-subdir-assets,$(LOCAL_ASSET_DIR))
all_assets := $(addprefix $(LOCAL_ASSET_DIR)/,$(patsubst assets/%,%,$(all_assets)))

all_resources := $(strip \
    $(foreach dir, $(LOCAL_RESOURCE_DIR), \
      $(addprefix $(dir)/, \
        $(patsubst res/%,%, \
          $(call find-subdir-assets,$(dir)) \
         ) \
       ) \
     ))

all_res_assets := $(strip $(all_assets) $(all_resources))

package_expected_intermediates_COMMON := $(call local-intermediates-dir,COMMON)
# If no assets or resources were found, clear the directory variables so
# we don't try to build them.
ifeq (,$(all_assets))
LOCAL_ASSET_DIR:=
endif
ifeq (,$(all_resources))
LOCAL_RESOURCE_DIR:=
R_file_stamp :=
else
# Make sure that R_file_stamp inherits the proper PRIVATE vars.
# If R.stamp moves, be sure to update the framework makefile,
# which has intimate knowledge of its location.
R_file_stamp := $(package_expected_intermediates_COMMON)/src/R.stamp
LOCAL_INTERMEDIATE_TARGETS += $(R_file_stamp)
endif

LOCAL_BUILT_MODULE_STEM := package.apk

LOCAL_PROGUARD_ENABLED:=$(strip $(LOCAL_PROGUARD_ENABLED))
ifndef LOCAL_PROGUARD_ENABLED
ifneq ($(filter user userdebug, $(TARGET_BUILD_VARIANT)),)
    # turn on Proguard by default for user & userdebug build
    LOCAL_PROGUARD_ENABLED :=full
endif
endif
ifeq ($(LOCAL_PROGUARD_ENABLED),disabled)
    # the package explicitly request to disable proguard.
    LOCAL_PROGUARD_ENABLED :=
endif
proguard_options_file :=
ifneq ($(LOCAL_PROGUARD_ENABLED),custom)
ifneq ($(all_resources),)
    proguard_options_file := $(package_expected_intermediates_COMMON)/proguard_options
endif # all_resources
endif # !custom
LOCAL_PROGUARD_FLAGS := $(addprefix -include ,$(proguard_options_file)) $(LOCAL_PROGUARD_FLAGS)

# The dex files go in the package, so we don't
# want to install them separately for this module.
old_DONT_INSTALL_DEX_FILES := $(DONT_INSTALL_DEX_FILES)
DONT_INSTALL_DEX_FILES := true
#################################
include $(BUILD_SYSTEM)/java.mk
#################################
DONT_INSTALL_DEX_FILES := $(old_DONT_INSTALL_DEX_FILES)
old_DONT_INSTALL_DEX_FILES =

full_android_manifest := $(LOCAL_PATH)/AndroidManifest.xml
$(LOCAL_INTERMEDIATE_TARGETS): \
	PRIVATE_ANDROID_MANIFEST := $(full_android_manifest)

ifneq ($(all_resources),)

# Since we don't know where the real R.java file is going to end up,
# we need to use another file to stand in its place.  We'll just
# copy the generated file to src/R.stamp, which means it will
# have the same contents and timestamp as the actual file.
#
# At the same time, this will copy the R.java file to a central
# 'R' directory to make it easier to add the files to an IDE.
#
#TODO: use PRIVATE_SOURCE_INTERMEDIATES_DIR instead of
#      $(intermediates.COMMON)/src
ifneq ($(package_expected_intermediates_COMMON),$(intermediates.COMMON))
  $(error $(LOCAL_MODULE): internal error: expected intermediates.COMMON "$(package_expected_intermediates_COMMON)" != intermediates.COMMON "$(intermediates.COMMON)")
endif

$(R_file_stamp): PRIVATE_RESOURCE_PUBLICS_OUTPUT := \
			$(intermediates.COMMON)/public_resources.xml
$(R_file_stamp): PRIVATE_PROGUARD_OPTIONS_FILE := $(proguard_options_file)
$(R_file_stamp): $(all_res_assets) $(full_android_manifest) $(AAPT) | $(ACP)
	@echo "target R.java/Manifest.java: $(PRIVATE_MODULE) ($@)"
	@rm -f $@
	$(create-resource-java-files)
	$(hide) for GENERATED_MANIFEST_FILE in `find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) \
					-name Manifest.java 2> /dev/null`; do \
		dir=`grep package $$GENERATED_MANIFEST_FILE | head -n1 | \
			awk '{print $$2}' | tr -d ";" | tr . /`; \
		mkdir -p $(TARGET_COMMON_OUT_ROOT)/R/$$dir; \
		$(ACP) -fpt $$GENERATED_MANIFEST_FILE $(TARGET_COMMON_OUT_ROOT)/R/$$dir; \
	done;
	$(hide) for GENERATED_R_FILE in `find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) \
					-name R.java 2> /dev/null`; do \
		dir=`grep package $$GENERATED_R_FILE | head -n1 | \
			awk '{print $$2}' | tr -d ";" | tr . /`; \
		mkdir -p $(TARGET_COMMON_OUT_ROOT)/R/$$dir; \
		$(ACP) -fpt $$GENERATED_R_FILE $(TARGET_COMMON_OUT_ROOT)/R/$$dir \
			|| exit 31; \
		$(ACP) -fpt $$GENERATED_R_FILE $@ || exit 32; \
	done; \

$(proguard_options_file): $(R_file_stamp)

ifdef LOCAL_EXPORT_PACKAGE_RESOURCES
# Put this module's resources into a PRODUCT-agnositc package that
# other packages can use to build their own PRODUCT-agnostic R.java (etc.)
# files.
resource_export_package := $(intermediates.COMMON)/package-export.apk
$(R_file_stamp): $(resource_export_package)

# add-assets-to-package looks at PRODUCT_AAPT_CONFIG, but this target
# can't know anything about PRODUCT.  Clear it out just for this target.
$(resource_export_package): PRODUCT_AAPT_CONFIG :=
$(resource_export_package): $(all_res_assets) $(full_android_manifest) $(AAPT)
	@echo "target Export Resources: $(PRIVATE_MODULE) ($@)"
	$(create-empty-package)
	$(add-assets-to-package)
endif

# Other modules should depend on the BUILT module if
# they want to use this module's R.java file.
$(LOCAL_BUILT_MODULE): $(R_file_stamp)

ifneq ($(full_classes_jar),)
# If full_classes_jar is non-empty, we're building sources.
# If we're building sources, the initial javac step (which
# produces full_classes_compiled_jar) needs to ensure the
# R.java and Manifest.java files have been generated first.
$(full_classes_compiled_jar): $(R_file_stamp)
endif

endif	# all_resources

ifeq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
# We need to explicitly clear this var so that we don't
# inherit the value from whomever caused us to be built.
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_AAPT_INCLUDES :=
else
# Most packages should link against the resources defined by framework-res.
# Even if they don't have their own resources, they may use framework
# resources.
framework_res_package_export := \
	$(call intermediates-dir-for,APPS,framework-res,,COMMON)/package-export.apk
$(LOCAL_INTERMEDIATE_TARGETS): \
	PRIVATE_AAPT_INCLUDES := $(framework_res_package_export)
# We can't depend directly on the export.apk file; it won't get its
# PRIVATE_ vars set up correctly if we do.  Instead, depend on the
# corresponding R.stamp file, which lists the export.apk as a dependency.
framework_res_package_export_deps := \
	$(dir $(framework_res_package_export))src/R.stamp
$(R_file_stamp): $(framework_res_package_export_deps)
endif

ifneq ($(full_classes_jar),)
$(LOCAL_BUILT_MODULE): PRIVATE_DEX_FILE := $(built_dex)
$(LOCAL_BUILT_MODULE): $(built_dex)
endif # full_classes_jar


# Get the list of jni libraries to be included in the apk file.

so_suffix := $($(my_prefix)SHLIB_SUFFIX)

jni_shared_libraries := \
    $(addprefix $($(my_prefix)OUT_INTERMEDIATE_LIBRARIES)/, \
      $(addsuffix $(so_suffix), \
        $(LOCAL_JNI_SHARED_LIBRARIES)))

# Pick a key to sign the package with.  If this package hasn't specified
# an explicit certificate, use the default.
# Secure release builds will have their packages signed after the fact,
# so it's ok for these private keys to be in the clear.
ifeq ($(LOCAL_CERTIFICATE),)
    LOCAL_CERTIFICATE := testkey
endif

ifeq ($(LOCAL_CERTIFICATE),EXTERNAL)
  # The special value "EXTERNAL" means that we will sign it with the
  # default testkey, apply predexopt, but then expect the final .apk
  # (after dexopting) to be signed by an outside tool.
  LOCAL_CERTIFICATE := testkey
  PACKAGES.$(LOCAL_PACKAGE_NAME).EXTERNAL_KEY := 1
endif

# If this is not an absolute certificate, assign it to a generic one.
ifeq ($(dir $(strip $(LOCAL_CERTIFICATE))),./)
    LOCAL_CERTIFICATE := $(SRC_TARGET_DIR)/product/security/$(LOCAL_CERTIFICATE)
endif
private_key := $(LOCAL_CERTIFICATE).pk8
certificate := $(LOCAL_CERTIFICATE).x509.pem

$(LOCAL_BUILT_MODULE): $(private_key) $(certificate) $(SIGNAPK_JAR)
$(LOCAL_BUILT_MODULE): PRIVATE_PRIVATE_KEY := $(private_key)
$(LOCAL_BUILT_MODULE): PRIVATE_CERTIFICATE := $(certificate)

PACKAGES.$(LOCAL_PACKAGE_NAME).PRIVATE_KEY := $(private_key)
PACKAGES.$(LOCAL_PACKAGE_NAME).CERTIFICATE := $(certificate)

# Define the rule to build the actual package.
$(LOCAL_BUILT_MODULE): $(AAPT) | $(ZIPALIGN)
$(LOCAL_BUILT_MODULE): PRIVATE_JNI_SHARED_LIBRARIES := $(jni_shared_libraries)
$(LOCAL_BUILT_MODULE): $(all_res_assets) $(jni_shared_libraries) $(full_android_manifest)
	@echo "target Package: $(PRIVATE_MODULE) ($@)"
	$(create-empty-package)
	$(add-assets-to-package)
ifneq ($(jni_shared_libraries),)
	$(add-jni-shared-libs-to-package)
endif
ifneq ($(full_classes_jar),)
	$(add-dex-to-package)
endif
	$(sign-package)
	@# Alignment must happen after all other zip operations.
	$(align-package)

# Save information about this package
PACKAGES.$(LOCAL_PACKAGE_NAME).OVERRIDES := $(strip $(LOCAL_OVERRIDES_PACKAGES))
PACKAGES.$(LOCAL_PACKAGE_NAME).RESOURCE_FILES := $(all_resources)

PACKAGES := $(PACKAGES) $(LOCAL_PACKAGE_NAME)

endif # skip_definition
