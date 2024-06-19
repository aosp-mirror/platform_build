###########################################################
## Standard rules for copying files that are prebuilt
##
## Additional inputs from base_rules.make:
## None.
##
###########################################################

include $(BUILD_SYSTEM)/use_lld_setup.mk

ifneq ($(LOCAL_PREBUILT_LIBS),)
$(call pretty-error,dont use LOCAL_PREBUILT_LIBS anymore)
endif
ifneq ($(LOCAL_PREBUILT_EXECUTABLES),)
$(call pretty-error,dont use LOCAL_PREBUILT_EXECUTABLES anymore)
endif
ifneq ($(LOCAL_PREBUILT_JAVA_LIBRARIES),)
$(call pretty-error,dont use LOCAL_PREBUILT_JAVA_LIBRARIES anymore)
endif

my_32_64_bit_suffix := $(if $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)IS_64_BIT),64,32)

ifdef LOCAL_PREBUILT_MODULE_FILE
  my_prebuilt_src_file := $(LOCAL_PREBUILT_MODULE_FILE)
else ifdef LOCAL_SRC_FILES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)
  my_prebuilt_src_file := $(call clean-path,$(LOCAL_PATH)/$(LOCAL_SRC_FILES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)))
  LOCAL_SRC_FILES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH) :=
else ifdef LOCAL_SRC_FILES_$(my_32_64_bit_suffix)
  my_prebuilt_src_file := $(call clean-path,$(LOCAL_PATH)/$(LOCAL_SRC_FILES_$(my_32_64_bit_suffix)))
  LOCAL_SRC_FILES_$(my_32_64_bit_suffix) :=
else ifdef LOCAL_SRC_FILES
  my_prebuilt_src_file := $(call clean-path,$(LOCAL_PATH)/$(LOCAL_SRC_FILES))
  LOCAL_SRC_FILES :=
else ifdef LOCAL_REPLACE_PREBUILT_APK_INSTALLED
  # This is handled specially in app_prebuilt_internal.mk
else
  $(call pretty-error,No source files specified)
endif

LOCAL_CHECKED_MODULE := $(my_prebuilt_src_file)

ifneq (APPS,$(LOCAL_MODULE_CLASS))
ifdef LOCAL_COMPRESSED_MODULE
$(error $(LOCAL_MODULE) : LOCAL_COMPRESSED_MODULE can only be defined for module class APPS)
endif  # LOCAL_COMPRESSED_MODULE
endif  # APPS

ifeq (APPS,$(LOCAL_MODULE_CLASS))
  include $(BUILD_SYSTEM)/app_prebuilt_internal.mk
else ifeq (JAVA_LIBRARIES,$(LOCAL_MODULE_CLASS))
  include $(BUILD_SYSTEM)/java_prebuilt_internal.mk
else ifneq ($(filter STATIC_LIBRARIES SHARED_LIBRARIES EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
  include $(BUILD_SYSTEM)/cc_prebuilt_internal.mk
else ifneq ($(filter SCRIPT ETC DATA RENDERSCRIPT_BITCODE,$(LOCAL_MODULE_CLASS)),)
  include $(BUILD_SYSTEM)/misc_prebuilt_internal.mk
else
  $(error $(LOCAL_MODULE) : unexpected LOCAL_MODULE_CLASS for prebuilts: $(LOCAL_MODULE_CLASS))
endif

$(if $(filter-out $(SOONG_ANDROID_MK),$(LOCAL_MODULE_MAKEFILE)), \
  $(eval ALL_MODULES.$(my_register_name).IS_PREBUILT_MAKE_MODULE := Y))

$(built_module) : $(LOCAL_ADDITIONAL_DEPENDENCIES)

my_prebuilt_src_file :=
