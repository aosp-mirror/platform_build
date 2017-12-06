# Decides how to install the jni libraries needed by an apk.
# Input variables:
#   my_module_multilib, LOCAL_2ND_ARCH_VAR_PREFIX (from package.mk or prebuilt.mk)
#   rs_compatibility_jni_libs (from java.mk)
#   my_module_path (from base_rules.mk)
#   partition_tag (from base_rules.mk)
#   my_prebuilt_src_file (from prebuilt_internal.mk)
#
# Output variables:
#   jni_shared_libraries, jni_shared_libraries_abi, jni_shared_libraries_with_abis if we are going to embed the libraries into the apk;
#   embedded_prebuilt_jni_libs, prebuilt jni libs embedded in prebuilt apk.
#

my_embed_jni :=
ifneq ($(TARGET_BUILD_APPS),)
my_embed_jni := true
endif
ifneq ($(filter tests samples, $(LOCAL_MODULE_TAGS)),)
my_embed_jni := true
endif
ifeq ($(filter $(TARGET_OUT)/% $(TARGET_OUT_VENDOR)/% $(TARGET_OUT_OEM)/%, $(my_module_path)),)
# If this app isn't to be installed to system partitions.
my_embed_jni := true
endif
# If we're installing this APP as a compressed module, we include all JNI libraries
# in the compressed artifact, rather than as separate files on the partition in question.
ifdef LOCAL_COMPRESSED_MODULE
my_embed_jni := true
endif

jni_shared_libraries :=
jni_shared_libraries_abis :=
# jni_shared_libraries_with_abis is a list of <abi>:<path-to-the-built-jni-lib>
jni_shared_libraries_with_abis :=
embedded_prebuilt_jni_libs :=

#######################################
# For TARGET_ARCH
my_2nd_arch_prefix :=
my_add_jni :=
# The module is built for TARGET_ARCH
ifeq ($(my_2nd_arch_prefix),$(LOCAL_2ND_ARCH_VAR_PREFIX))
my_add_jni := true
endif
# Or it explicitly requires both
ifeq ($(my_module_multilib),both)
my_add_jni := true
endif
ifeq ($(my_add_jni),true)
my_prebuilt_jni_libs := $(LOCAL_PREBUILT_JNI_LIBS_$(TARGET_ARCH))
ifndef my_prebuilt_jni_libs
my_prebuilt_jni_libs := $(LOCAL_PREBUILT_JNI_LIBS)
endif
include $(BUILD_SYSTEM)/install_jni_libs_internal.mk
jni_shared_libraries += $(my_jni_shared_libraries)
jni_shared_libraries_abis += $(my_jni_shared_libraries_abi)
jni_shared_libraries_with_abis += $(addprefix $(my_jni_shared_libraries_abi):,\
    $(my_jni_shared_libraries))
embedded_prebuilt_jni_libs += $(my_embedded_prebuilt_jni_libs)

# Include RS dynamically-generated libraries as well
# TODO: Add multilib support once RS supports generating multilib libraries.
jni_shared_libraries += $(rs_compatibility_jni_libs)
jni_shared_libraries_with_abis += $(addprefix $(my_jni_shared_libraries_abi):,\
    $(rs_compatibility_jni_libs))
endif  # my_add_jni

#######################################
# For TARGET_2ND_ARCH
ifdef TARGET_2ND_ARCH
my_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
my_add_jni :=
# The module is built for TARGET_2ND_ARCH
ifeq ($(my_2nd_arch_prefix),$(LOCAL_2ND_ARCH_VAR_PREFIX))
my_add_jni := true
endif
# Or it explicitly requires both
ifeq ($(my_module_multilib),both)
my_add_jni := true
endif
ifeq ($(my_add_jni),true)
my_prebuilt_jni_libs := $(LOCAL_PREBUILT_JNI_LIBS_$(TARGET_2ND_ARCH))
ifndef my_prebuilt_jni_libs
my_prebuilt_jni_libs := $(LOCAL_PREBUILT_JNI_LIBS)
endif
include $(BUILD_SYSTEM)/install_jni_libs_internal.mk
jni_shared_libraries += $(my_jni_shared_libraries)
jni_shared_libraries_abis += $(my_jni_shared_libraries_abi)
jni_shared_libraries_with_abis += $(addprefix $(my_jni_shared_libraries_abi):,\
    $(my_jni_shared_libraries))
embedded_prebuilt_jni_libs += $(my_embedded_prebuilt_jni_libs)
endif  # my_add_jni
endif  # TARGET_2ND_ARCH

jni_shared_libraries := $(strip $(jni_shared_libraries))
jni_shared_libraries_abis := $(sort $(jni_shared_libraries_abis))
jni_shared_libraries_with_abis := $(strip $(jni_shared_libraries_with_abis))
embedded_prebuilt_jni_libs := $(strip $(embedded_prebuilt_jni_libs))
