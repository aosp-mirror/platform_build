# include this makefile to create the LOCAL_MODULE symlink to the primary version binary.
# but this requires the primary version name specified via LOCAL_MODULE_STEM_32 or LOCAL_MODULE_STEM_64,
# and different with the LOCAL_MODULE value
#
# Note: now only limited to the binaries that will be installed under system/bin directory

# Create link to the one used depending on the target
# configuration. Note that we require the TARGET_IS_64_BIT
# check because 32 bit targets may not define TARGET_PREFER_32_BIT_APPS
# et al. since those variables make no sense in that context.
ifneq ($(LOCAL_IS_HOST_MODULE),true)
  my_symlink := $(addprefix $(TARGET_OUT)/bin/, $(LOCAL_MODULE))
  my_src_binary_name :=
  ifeq ($(TARGET_IS_64_BIT),true)
    ifeq ($(TARGET_SUPPORTS_64_BIT_APPS)|$(TARGET_SUPPORTS_32_BIT_APPS),true|true)
      # We support both 32 and 64 bit apps, so we will have to
      # base our decision on whether the target prefers one or the
      # other.
      ifeq ($(TARGET_PREFER_32_BIT_APPS),true)
        my_src_binary_name := $(LOCAL_MODULE_STEM_32)
      else
        my_src_binary_name := $(LOCAL_MODULE_STEM_64)
      endif
    else ifeq ($(TARGET_SUPPORTS_64_BIT_APPS),true)
      # We support only 64 bit apps.
      my_src_binary_name := $(LOCAL_MODULE_STEM_64)
    else
      # We support only 32 bit apps.
      my_src_binary_name := $(LOCAL_MODULE_STEM_32)
    endif
  else
    my_src_binary_name := $(LOCAL_MODULE_STEM_32)
  endif
else
  my_symlink := $(addprefix $(HOST_OUT)/bin/, $(LOCAL_MODULE))
  my_src_binary_name := $(LOCAL_MODULE_STEM_64)
endif

$(call symlink-file,$(my_module_path)/$(my_src_binary_name),$(my_src_binary_name),$(my_symlink))

# We need this so that the installed files could be picked up based on the
# local module name
ALL_MODULES.$(my_register_name).INSTALLED += $(my_symlink)

# Create the symlink when you run mm/mmm or "make <module_name>"
$(LOCAL_MODULE) : $(my_symlink)

my_symlink :=
