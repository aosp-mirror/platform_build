#
# Copyright (C) 2019 The Android Open Source Project
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

############################################################
# Internal build rules for APPS prebuilt modules
############################################################

ifneq (APPS,$(LOCAL_MODULE_CLASS))
$(call pretty-error,app_prebuilt_internal.mk is for APPS modules only)
endif

ifdef LOCAL_COMPRESSED_MODULE
  ifneq (true,$(LOCAL_COMPRESSED_MODULE))
    $(call pretty-error, Unknown value for LOCAL_COMPRESSED_MODULE $(LOCAL_COMPRESSED_MODULE))
  endif
  LOCAL_BUILT_MODULE_STEM := package.apk.gz
  ifndef LOCAL_INSTALLED_MODULE_STEM
    PACKAGES.$(LOCAL_MODULE).COMPRESSED := gz
    LOCAL_INSTALLED_MODULE_STEM := $(LOCAL_MODULE).apk.gz
  endif
else  # LOCAL_COMPRESSED_MODULE
  LOCAL_BUILT_MODULE_STEM := package.apk
  ifndef LOCAL_INSTALLED_MODULE_STEM
    LOCAL_INSTALLED_MODULE_STEM := $(LOCAL_MODULE).apk
  endif
endif  # LOCAL_COMPRESSED_MODULE

include $(BUILD_SYSTEM)/base_rules.mk
built_module := $(LOCAL_BUILT_MODULE)

# Run veridex on product, system_ext and vendor modules.
# We skip it for unbundled app builds where we cannot build veridex.
module_run_appcompat :=
ifeq (true,$(non_system_module))
ifeq (,$(TARGET_BUILD_APPS))  # ! unbundled app build
ifneq ($(UNSAFE_DISABLE_HIDDENAPI_FLAGS),true)
  module_run_appcompat := true
endif
endif
endif

PACKAGES.$(LOCAL_MODULE).OVERRIDES := $(strip $(LOCAL_OVERRIDES_PACKAGES))

my_extract_apk := $(strip $(LOCAL_EXTRACT_APK))

# Select dpi-specific source
ifdef LOCAL_DPI_VARIANTS
my_dpi := $(firstword $(filter $(LOCAL_DPI_VARIANTS),$(PRODUCT_AAPT_PREF_CONFIG) $(PRODUCT_AAPT_PREBUILT_DPI)))
ifdef my_dpi
ifdef LOCAL_DPI_FILE_STEM
my_prebuilt_dpi_file_stem := $(LOCAL_DPI_FILE_STEM)
else
my_prebuilt_dpi_file_stem := $(LOCAL_MODULE)_%.apk
endif
my_prebuilt_src_file := $(dir $(my_prebuilt_src_file))$(subst %,$(my_dpi),$(my_prebuilt_dpi_file_stem))

ifneq ($(strip $(LOCAL_EXTRACT_DPI_APK)),)
my_extract_apk := $(subst %,$(my_dpi),$(LOCAL_EXTRACT_DPI_APK))
endif  # LOCAL_EXTRACT_DPI_APK
endif  # my_dpi
endif  # LOCAL_DPI_VARIANTS

ifdef my_extract_apk
my_extracted_apk := $(intermediates)/extracted.apk

$(my_extracted_apk): PRIVATE_EXTRACT := $(my_extract_apk)
$(my_extracted_apk): $(my_prebuilt_src_file)
	@echo Extract APK: $@
	$(hide) mkdir -p $(dir $@) && rm -f $@
	$(hide) unzip -p $< $(PRIVATE_EXTRACT) >$@

my_prebuilt_src_file := $(my_extracted_apk)
my_extracted_apk :=
my_extract_apk :=
endif

rs_compatibility_jni_libs :=
include $(BUILD_SYSTEM)/install_jni_libs.mk

ifeq ($(LOCAL_CERTIFICATE),EXTERNAL)
  # The magic string "EXTERNAL" means this package will be signed with
  # the default dev key throughout the build process, but we expect
  # the final package to be signed with a different key.
  #
  # This can be used for packages where we don't have access to the
  # keys, but want the package to be predexopt'ed.
  LOCAL_CERTIFICATE := $(DEFAULT_SYSTEM_DEV_CERTIFICATE)
  PACKAGES.$(LOCAL_MODULE).EXTERNAL_KEY := 1

  $(built_module) : $(LOCAL_CERTIFICATE).pk8 $(LOCAL_CERTIFICATE).x509.pem
  $(built_module) : PRIVATE_PRIVATE_KEY := $(LOCAL_CERTIFICATE).pk8
  $(built_module) : PRIVATE_CERTIFICATE := $(LOCAL_CERTIFICATE).x509.pem
endif
ifeq ($(LOCAL_CERTIFICATE),)
  # It is now a build error to add a prebuilt .apk without
  # specifying a key for it.
  $(error No LOCAL_CERTIFICATE specified for prebuilt "$(my_prebuilt_src_file)")
else ifeq ($(LOCAL_CERTIFICATE),PRESIGNED)
  # The magic string "PRESIGNED" means this package is already checked
  # signed with its release key.
  #
  # By setting .CERTIFICATE but not .PRIVATE_KEY, this package will be
  # mentioned in apkcerts.txt (with certificate set to "PRESIGNED")
  # but the dexpreopt process will not try to re-sign the app.
  PACKAGES.$(LOCAL_MODULE).CERTIFICATE := PRESIGNED
  PACKAGES := $(PACKAGES) $(LOCAL_MODULE)
else
  # If this is not an absolute certificate, assign it to a generic one.
  ifeq ($(dir $(strip $(LOCAL_CERTIFICATE))),./)
    LOCAL_CERTIFICATE := $(dir $(DEFAULT_SYSTEM_DEV_CERTIFICATE))$(LOCAL_CERTIFICATE)
  endif

  # NOTE(ruperts): Consider moving the logic below out of a conditional,
  # to avoid the possibility of silently ignoring user settings.

  PACKAGES.$(LOCAL_MODULE).PRIVATE_KEY := $(LOCAL_CERTIFICATE).pk8
  PACKAGES.$(LOCAL_MODULE).CERTIFICATE := $(LOCAL_CERTIFICATE).x509.pem
  PACKAGES := $(PACKAGES) $(LOCAL_MODULE)

  $(built_module) : $(LOCAL_CERTIFICATE).pk8 $(LOCAL_CERTIFICATE).x509.pem
  $(built_module) : PRIVATE_PRIVATE_KEY := $(LOCAL_CERTIFICATE).pk8
  $(built_module) : PRIVATE_CERTIFICATE := $(LOCAL_CERTIFICATE).x509.pem

  additional_certificates := $(foreach c,$(LOCAL_ADDITIONAL_CERTIFICATES), $(c).x509.pem $(c).pk8)
  $(built_module): $(additional_certificates)
  $(built_module): PRIVATE_ADDITIONAL_CERTIFICATES := $(additional_certificates)

  $(built_module): $(LOCAL_CERTIFICATE_LINEAGE)
  $(built_module): PRIVATE_CERTIFICATE_LINEAGE := $(LOCAL_CERTIFICATE_LINEAGE)

  $(built_module): PRIVATE_ROTATION_MIN_SDK_VERSION := $(LOCAL_ROTATION_MIN_SDK_VERSION)
endif

ifneq ($(LOCAL_MODULE_STEM),)
  PACKAGES.$(LOCAL_MODULE).STEM := $(LOCAL_MODULE_STEM)
else
  PACKAGES.$(LOCAL_MODULE).STEM := $(LOCAL_MODULE)
endif

include $(BUILD_SYSTEM)/app_certificate_validate.mk

# Set a actual_partition_tag (calculated in base_rules.mk) for the package.
PACKAGES.$(LOCAL_MODULE).PARTITION := $(actual_partition_tag)

# Disable dex-preopt of prebuilts to save space, if requested.
ifndef LOCAL_DEX_PREOPT
ifeq ($(DONT_DEXPREOPT_PREBUILTS),true)
LOCAL_DEX_PREOPT := false
endif
endif

# If the module is a compressed module, we don't pre-opt it because its final
# installation location will be the data partition.
ifdef LOCAL_COMPRESSED_MODULE
LOCAL_DEX_PREOPT := false
endif

my_dex_jar := $(my_prebuilt_src_file)
dex_preopt_profile_src_file := $(my_prebuilt_src_file)

#######################################
# defines built_odex along with rule to install odex
my_manifest_or_apk := $(my_prebuilt_src_file)
include $(BUILD_SYSTEM)/dex_preopt_odex_install.mk
my_manifest_or_apk :=
#######################################
ifneq ($(LOCAL_REPLACE_PREBUILT_APK_INSTALLED),)
# There is a replacement for the prebuilt .apk we can install without any processing.
$(built_module) : $(LOCAL_REPLACE_PREBUILT_APK_INSTALLED)
	$(transform-prebuilt-to-target)

else  # ! LOCAL_REPLACE_PREBUILT_APK_INSTALLED

# If the SDK version is 30 or higher, the apk is signed with a v2+ scheme.
# Altering it will invalidate the signature. Just do error checks instead.
do_not_alter_apk :=
ifeq (PRESIGNED,$(LOCAL_CERTIFICATE))
  ifneq (,$(LOCAL_SDK_VERSION))
    ifeq ($(call math_is_number,$(LOCAL_SDK_VERSION)),true)
      ifeq ($(call math_gt,$(LOCAL_SDK_VERSION),29),true)
        do_not_alter_apk := true
      endif
    endif
    # TODO: Add system_current after fixing the existing modules.
    ifneq ($(filter current test_current core_current,$(LOCAL_SDK_VERSION)),)
        do_not_alter_apk := true
    endif
  endif
endif

ifeq ($(do_not_alter_apk),true)
$(built_module) : $(my_prebuilt_src_file) | $(ZIPALIGN)
	$(transform-prebuilt-to-target)
	$(check-jni-dex-compression)
	$(check-package-alignment)
else
# Sign and align non-presigned .apks.
# The embedded prebuilt jni to uncompress.
ifeq ($(LOCAL_CERTIFICATE),PRESIGNED)
# For PRESIGNED apks we must uncompress every .so file:
# even if the .so file isn't for the current TARGET_ARCH,
# we can't strip the file.
embedded_prebuilt_jni_libs :=
endif
ifndef embedded_prebuilt_jni_libs
# No LOCAL_PREBUILT_JNI_LIBS, uncompress all.
embedded_prebuilt_jni_libs :=
endif
$(built_module): PRIVATE_EMBEDDED_JNI_LIBS := $(embedded_prebuilt_jni_libs)

ifdef LOCAL_COMPRESSED_MODULE
$(built_module) : $(GZIP)
endif

ifeq ($(module_run_appcompat),true)
$(built_module) : $(appcompat-files)
$(LOCAL_BUILT_MODULE): PRIVATE_INSTALLED_MODULE := $(LOCAL_INSTALLED_MODULE)
endif

ifeq ($(module_run_appcompat),true)
$(built_module) : $(AAPT2)
endif
$(built_module) : $(my_prebuilt_src_file) | $(ZIPALIGN) $(ZIP2ZIP) $(SIGNAPK_JAR) $(SIGNAPK_JNI_LIBRARY_PATH)
	$(transform-prebuilt-to-target)
	$(uncompress-prebuilt-embedded-jni-libs)
	$(remove-unwanted-prebuilt-embedded-jni-libs)
ifeq (true, $(LOCAL_UNCOMPRESS_DEX))
	$(uncompress-dexs)
endif  # LOCAL_UNCOMPRESS_DEX
ifneq ($(LOCAL_CERTIFICATE),PRESIGNED)
ifeq ($(module_run_appcompat),true)
	$(call appcompat-header, aapt2)
	$(run-appcompat)
endif  # module_run_appcompat
	$(sign-package)
	# No need for align-package because sign-package takes care of alignment
else  # LOCAL_CERTIFICATE == PRESIGNED
	$(align-package)
endif  # LOCAL_CERTIFICATE
ifdef LOCAL_COMPRESSED_MODULE
	$(compress-package)
endif  # LOCAL_COMPRESSED_MODULE
endif  # ! do_not_alter_apk
endif  # ! LOCAL_REPLACE_PREBUILT_APK_INSTALLED


###############################
## Install split apks.
ifdef LOCAL_PACKAGE_SPLITS
ifdef LOCAL_COMPRESSED_MODULE
$(error $(LOCAL_MODULE): LOCAL_COMPRESSED_MODULE is not currently supported for split installs)
endif  # LOCAL_COMPRESSED_MODULE

# LOCAL_PACKAGE_SPLITS is a list of apks to be installed.
built_apk_splits := $(addprefix $(intermediates)/,$(notdir $(LOCAL_PACKAGE_SPLITS)))
installed_apk_splits := $(addprefix $(my_module_path)/,$(notdir $(LOCAL_PACKAGE_SPLITS)))

# Rules to sign the split apks.
my_src_dir := $(sort $(dir $(LOCAL_PACKAGE_SPLITS)))
ifneq (1,$(words $(my_src_dir)))
$(error You must put all the split source apks in the same folder: $(LOCAL_PACKAGE_SPLITS))
endif
my_src_dir := $(LOCAL_PATH)/$(my_src_dir)

$(built_apk_splits) : $(LOCAL_CERTIFICATE).pk8 $(LOCAL_CERTIFICATE).x509.pem | $(ZIPALIGN) $(ZIP2ZIP) $(SIGNAPK_JAR) $(SIGNAPK_JNI_LIBRARY_PATH)
$(built_apk_splits) : PRIVATE_PRIVATE_KEY := $(LOCAL_CERTIFICATE).pk8
$(built_apk_splits) : PRIVATE_CERTIFICATE := $(LOCAL_CERTIFICATE).x509.pem
$(built_apk_splits) : $(intermediates)/%.apk : $(my_src_dir)/%.apk
	$(copy-file-to-new-target)
	$(sign-package)

# Rules to install the split apks.
$(installed_apk_splits) : $(my_module_path)/%.apk : $(intermediates)/%.apk
	@echo "Install: $@"
	$(copy-file-to-new-target)

# Register the additional built and installed files.
ALL_MODULES.$(my_register_name).INSTALLED += $(installed_apk_splits)
ALL_MODULES.$(my_register_name).BUILT_INSTALLED += \
  $(foreach s,$(LOCAL_PACKAGE_SPLITS),$(intermediates)/$(notdir $(s)):$(my_module_path)/$(notdir $(s)))

# Make sure to install the splits when you run "make <module_name>".
$(my_all_targets): $(installed_apk_splits)

endif # LOCAL_PACKAGE_SPLITS

###########################################################
## SBOM generation
###########################################################
include $(BUILD_SBOM_GEN)
