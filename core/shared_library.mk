###########################################################
## Standard rules for building a normal shared library.
##
## Additional inputs from base_rules.make:
## None.
##
## LOCAL_MODULE_SUFFIX will be set for you.
###########################################################

ifeq ($(strip $(LOCAL_MODULE_CLASS)),)
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
endif
ifeq ($(strip $(LOCAL_MODULE_SUFFIX)),)
LOCAL_MODULE_SUFFIX := $(TARGET_SHLIB_SUFFIX)
endif
ifneq ($(strip $(OVERRIDE_BUILT_MODULE_PATH)),)
$(error $(LOCAL_PATH): Illegal use of OVERRIDE_BUILT_MODULE_PATH)
endif

# Put the built targets of all shared libraries in a common directory
# to simplify the link line.
OVERRIDE_BUILT_MODULE_PATH := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)

include $(BUILD_SYSTEM)/dynamic_binary.mk

# Define PRIVATE_ variables from global vars
my_target_global_ld_dirs := $(TARGET_GLOBAL_LD_DIRS)
my_target_global_ldflags := $(TARGET_GLOBAL_LDFLAGS)
my_target_fdo_lib := $(TARGET_FDO_LIB)
my_target_libgcc := $(TARGET_LIBGCC)
my_target_crtbegin_so_o := $(TARGET_CRTBEGIN_SO_O)
my_target_crtend_so_o := $(TARGET_CRTEND_SO_O)
ifdef LOCAL_NDK_VERSION
# Make sure the prebuilt NDK paths are put ahead of the TARGET_GLOBAL_LD_DIRS,
# so we don't have race condition when the system libraries (such as libc, libstdc++) are also built in the tree.
my_target_global_ld_dirs := \
    $(addprefix -L, $(patsubst %/,%,$(dir $(my_ndk_stl_shared_lib_fullpath))) \
    $(my_ndk_version_root)/usr/lib) \
    $(my_target_global_ld_dirs)
my_target_global_ldflags := $(my_ndk_stl_shared_lib) $(my_target_global_ldflags)
my_target_crtbegin_so_o := $(wildcard $(my_ndk_version_root)/usr/lib/crtbegin_so.o)
my_target_crtend_so_o := $(wildcard $(my_ndk_version_root)/usr/lib/crtend_so.o)
endif
$(linked_module): PRIVATE_TARGET_GLOBAL_LD_DIRS := $(my_target_global_ld_dirs)
$(linked_module): PRIVATE_TARGET_GLOBAL_LDFLAGS := $(my_target_global_ldflags)
$(linked_module): PRIVATE_TARGET_FDO_LIB := $(my_target_fdo_lib)
$(linked_module): PRIVATE_TARGET_LIBGCC := $(my_target_libgcc)
$(linked_module): PRIVATE_TARGET_CRTBEGIN_SO_O := $(my_target_crtbegin_so_o)
$(linked_module): PRIVATE_TARGET_CRTEND_SO_O := $(my_target_crtend_so_o)

$(linked_module): $(all_objects) $(all_libraries) \
                  $(LOCAL_ADDITIONAL_DEPENDENCIES) \
                  $(my_target_crtbegin_so_o) $(my_target_crtend_so_o)
	$(transform-o-to-shared-lib)
