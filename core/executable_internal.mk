###########################################################
## Standard rules for building an executable file.
##
## Additional inputs from base_rules.make:
## None.
###########################################################

ifeq ($(strip $(LOCAL_MODULE_CLASS)),)
LOCAL_MODULE_CLASS := EXECUTABLES
endif
ifeq ($(strip $(LOCAL_MODULE_SUFFIX)),)
LOCAL_MODULE_SUFFIX := $(TARGET_EXECUTABLE_SUFFIX)
endif

$(call target-executable-hook)

skip_build_from_source :=
ifdef LOCAL_PREBUILT_MODULE_FILE
ifeq (,$(call if-build-from-source,$(LOCAL_MODULE),$(LOCAL_PATH)))
include $(BUILD_SYSTEM)/prebuilt_internal.mk
skip_build_from_source := true
endif
endif

ifndef skip_build_from_source

include $(BUILD_SYSTEM)/dynamic_binary.mk

# Check for statically linked libc
ifneq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
ifneq ($(filter $(my_static_libraries),libc),)
$(error $(LOCAL_PATH): $(LOCAL_MODULE) is statically linking libc to dynamic executable, please remove libc from static libs or set LOCAL_FORCE_STATIC_EXECUTABLE := true)
endif
endif

# Define PRIVATE_ variables from global vars
my_target_global_ld_dirs := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_LD_DIRS)
my_target_libgcc := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_LIBGCC)
my_target_libatomic := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_LIBATOMIC)
my_target_crtbegin_dynamic_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_CRTBEGIN_DYNAMIC_O)
my_target_crtbegin_static_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_CRTBEGIN_STATIC_O)
my_target_crtend_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_CRTEND_O)
ifdef LOCAL_SDK_VERSION
# Make sure the prebuilt NDK paths are put ahead of the TARGET_GLOBAL_LD_DIRS,
# so we don't have race condition when the system libraries (such as libc, libstdc++) are also built in the tree.
my_target_global_ld_dirs := \
    $(addprefix -L, $(patsubst %/,%,$(dir $(my_ndk_stl_shared_lib_fullpath))) \
    $(my_ndk_sysroot_lib)) \
    $(my_target_global_ld_dirs)
my_target_global_ldflags := $(my_ndk_stl_shared_lib) $(my_target_global_ldflags)
my_target_crtbegin_dynamic_o := $(wildcard $(my_ndk_sysroot_lib)/crtbegin_dynamic.o)
my_target_crtbegin_static_o := $(wildcard $(my_ndk_sysroot_lib)/crtbegin_static.o)
my_target_crtend_o := $(wildcard $(my_ndk_sysroot_lib)/crtend_android.o)
endif
$(linked_module): PRIVATE_TARGET_GLOBAL_LD_DIRS := $(my_target_global_ld_dirs)
$(linked_module): PRIVATE_TARGET_GLOBAL_LDFLAGS := $(my_target_global_ldflags)
$(linked_module): PRIVATE_TARGET_LIBGCC := $(my_target_libgcc)
$(linked_module): PRIVATE_TARGET_LIBATOMIC := $(my_target_libatomic)
$(linked_module): PRIVATE_TARGET_CRTBEGIN_DYNAMIC_O := $(my_target_crtbegin_dynamic_o)
$(linked_module): PRIVATE_TARGET_CRTBEGIN_STATIC_O := $(my_target_crtbegin_static_o)
$(linked_module): PRIVATE_TARGET_CRTEND_O := $(my_target_crtend_o)
$(linked_module): PRIVATE_TARGET_OUT_INTERMEDIATE_LIBRARIES := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)

ifeq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
$(linked_module): $(my_target_crtbegin_static_o) $(all_objects) $(all_libraries) $(my_target_crtend_o)
	$(transform-o-to-static-executable)
else
$(linked_module): $(my_target_crtbegin_dynamic_o) $(all_objects) $(all_libraries) $(my_target_crtend_o)
	$(transform-o-to-executable)
endif

endif  # skip_build_from_source
