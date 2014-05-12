# include this makefile to create the LOCAL_MODULE symlink to the primary version binary.
# but this requires the primary version name specified via LOCAL_MODULE_STEM_32 or LOCAL_MODULE_STEM_64,
# and different with the LOCAL_MODULE value
#
# Note: now only limited to the binaries that will be installed under system/bin directory

my_symlink := $(addprefix $(TARGET_OUT)/bin/, $(LOCAL_MODULE))
# create link to the one used for prefer version
ifneq ($(TARGET_PREFER_32_BIT_APPS),true)
  $(my_symlink): PRIVATE_SRC_BINARY_NAME := $(LOCAL_MODULE_STEM_64)
else
  $(my_symlink): PRIVATE_SRC_BINARY_NAME := $(LOCAL_MODULE_STEM_32)
endif

$(my_symlink): $(LOCAL_INSTALLED_MODULE) $(LOCAL_MODULE_MAKEFILE)
	@echo "Symlink: $@ -> $(PRIVATE_SRC_BINARY_NAME)"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf $(PRIVATE_SRC_BINARY_NAME) $@

# We need this so that the installed files could be picked up based on the
# local module name
ALL_MODULES.$(LOCAL_MODULE).INSTALLED += $(my_symlink)

my_symlink :=
