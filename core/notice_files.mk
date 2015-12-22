###########################################################
## Track NOTICE files
###########################################################

ifneq ($(LOCAL_NOTICE_FILE),)
notice_file:=$(strip $(LOCAL_NOTICE_FILE))
else
notice_file:=$(strip $(wildcard $(LOCAL_PATH)/NOTICE))
endif

ifeq ($(LOCAL_MODULE_CLASS),GYP)
  # We ignore NOTICE files for modules of type GYP.
  notice_file :=
endif

ifeq ($(LOCAL_MODULE_CLASS),NOTICE_FILES)
# If this is a NOTICE-only module, we don't include base_rule.mk,
# so my_prefix is not set at this point.
ifeq ($(LOCAL_IS_HOST_MODULE),true)
  my_prefix := HOST_
  LOCAL_HOST_PREFIX :=
else
  my_prefix := TARGET_
endif
endif

ifdef notice_file

# This relies on the name of the directory in PRODUCT_OUT matching where
# it's installed on the target - i.e. system, data, etc.  This does
# not work for root and isn't exact, but it's probably good enough for
# compliance.
# Includes the leading slash
ifdef LOCAL_INSTALLED_MODULE
  module_installed_filename := $(patsubst $(PRODUCT_OUT)%,%,$(LOCAL_INSTALLED_MODULE))
else
  # This module isn't installable
  ifeq ($(LOCAL_MODULE_CLASS),STATIC_LIBRARIES)
    # Stick the static libraries with the dynamic libraries.
    # We can't use xxx_OUT_STATIC_LIBRARIES because it points into
    # device-obj or host-obj.
    module_installed_filename := \
        $(patsubst $(PRODUCT_OUT)%,%,$($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)OUT_SHARED_LIBRARIES))/$(notdir $(LOCAL_BUILT_MODULE))
  else
    ifeq ($(LOCAL_MODULE_CLASS),JAVA_LIBRARIES)
      # Stick the static java libraries with the regular java libraries.
      module_leaf := $(notdir $(LOCAL_BUILT_MODULE))
      # javalib.jar is the default name for the build module (and isn't meaningful)
      # If that's what we have, substitute the module name instead.  These files
      # aren't included on the device, so this name is synthetic anyway.
      ifneq ($(filter javalib.jar classes.jack,$(module_leaf)),)
        module_leaf := $(LOCAL_MODULE).jar
      endif
      module_installed_filename := \
          $(patsubst $(PRODUCT_OUT)%,%,$($(my_prefix)OUT_JAVA_LIBRARIES))/$(module_leaf)
    else
      $(error Cannot determine where to install NOTICE file for $(LOCAL_MODULE))
    endif # JAVA_LIBRARIES
  endif # STATIC_LIBRARIES
endif

# In case it's actually a host file
module_installed_filename := $(patsubst $(HOST_OUT)%,%,$(module_installed_filename))
module_installed_filename := $(patsubst $(HOST_CROSS_OUT)%,%,$(module_installed_filename))

installed_notice_file := $($(my_prefix)OUT_NOTICE_FILES)/src/$(module_installed_filename).txt

$(installed_notice_file): PRIVATE_INSTALLED_MODULE := $(module_installed_filename)

$(installed_notice_file): $(notice_file)
	@echo Notice file: $< -- $@
	$(hide) mkdir -p $(dir $@)
	$(hide) cat $< > $@

ifdef LOCAL_INSTALLED_MODULE
# Make LOCAL_INSTALLED_MODULE depend on NOTICE files if they exist
# libraries so they get installed along with it.  Make it an order-only
# dependency so we don't re-install a module when the NOTICE changes.
$(LOCAL_INSTALLED_MODULE): | $(installed_notice_file)
endif

# To facilitate collecting NOTICE files for apps_only build,
# we install the NOTICE file even if a module gets built but not installed,
# because shared jni libraries won't be installed to the system image.
ifdef TARGET_BUILD_APPS
# for static Java libraries, we don't need to even build LOCAL_BUILT_MODULE,
# but just javalib.jar in the common intermediate dir.
ifeq ($(LOCAL_MODULE_CLASS),JAVA_LIBRARIES)
$(intermediates.COMMON)/javalib.jar : | $(installed_notice_file)
else
$(LOCAL_BUILT_MODULE): | $(installed_notice_file)
endif  # JAVA_LIBRARIES
endif  # TARGET_BUILD_APPS

else
# NOTICE file does not exist
installed_notice_file :=
endif

# Create a predictable, phony target to build this notice file.
# Define it even if the notice file doesn't exist so that other
# modules can depend on it.
notice_target := NOTICE-$(if \
    $(LOCAL_IS_HOST_MODULE),HOST,TARGET)-$(LOCAL_MODULE_CLASS)-$(LOCAL_MODULE)
.PHONY: $(notice_target)
$(notice_target): $(installed_notice_file)
