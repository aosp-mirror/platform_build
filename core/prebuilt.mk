###########################################################
## Standard rules for copying files that are prebuilt
##
## Additional inputs from base_rules.make:
## None.
##
###########################################################

ifneq ($(LOCAL_PREBUILT_LIBS),)
$(error dont use LOCAL_PREBUILT_LIBS anymore LOCAL_PATH=$(LOCAL_PATH))
endif
ifneq ($(LOCAL_PREBUILT_EXECUTABLES),)
$(error dont use LOCAL_PREBUILT_EXECUTABLES anymore LOCAL_PATH=$(LOCAL_PATH))
endif
ifneq ($(LOCAL_PREBUILT_JAVA_LIBRARIES),)
$(error dont use LOCAL_PREBUILT_JAVA_LIBRARIES anymore LOCAL_PATH=$(LOCAL_PATH))
endif

include $(BUILD_SYSTEM)/base_rules.mk

# Deal with the OSX library timestamp issue when installing
# a prebuilt simulator library.
ifneq ($(filter STATIC_LIBRARIES SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
  prebuilt_module_is_a_library := true
else
  prebuilt_module_is_a_library :=
endif

PACKAGES.$(LOCAL_MODULE).OVERRIDES := $(strip $(LOCAL_OVERRIDES_PACKAGES))

# Ensure that prebuilt .apks have been aligned.
ifneq ($(filter APPS,$(LOCAL_MODULE_CLASS)),)
$(LOCAL_BUILT_MODULE) : $(LOCAL_PATH)/$(LOCAL_SRC_FILES) | $(ZIPALIGN)
	$(transform-prebuilt-to-target-with-zipalign)
else
ifneq ($(LOCAL_PREBUILT_STRIP_COMMENTS),)
$(LOCAL_BUILT_MODULE) : $(LOCAL_PATH)/$(LOCAL_SRC_FILES)
	$(transform-prebuilt-to-target-strip-comments)
else
$(LOCAL_BUILT_MODULE) : $(LOCAL_PATH)/$(LOCAL_SRC_FILES) | $(ACP)
	$(transform-prebuilt-to-target)
endif
endif

ifeq ($(LOCAL_IS_HOST_MODULE)$(LOCAL_MODULE_CLASS),JAVA_LIBRARIES)
# for target java libraries, the LOCAL_BUILT_MODULE is in a product-specific dir,
# while the deps should be in the common dir, so we make a copy in the common dir.
common_library_jar := $(call intermediates-dir-for,JAVA_LIBRARIES,$(LOCAL_MODULE),,COMMON)/$(notdir $(LOCAL_BUILT_MODULE))
$(common_library_jar) : $(LOCAL_PATH)/$(LOCAL_SRC_FILES) | $(ACP)
	$(transform-prebuilt-to-target)
endif

ifeq ($(LOCAL_CERTIFICATE),EXTERNAL)
  # The magic string "EXTERNAL" means this package will be signed with
  # the test key throughout the build process, but we expect the final
  # package to be signed with a different key.
  #
  # This can be used for packages where we don't have access to the
  # keys, but want the package to be predexopt'ed.
  LOCAL_CERTIFICATE := testkey
  PACKAGES.$(LOCAL_MODULE).EXTERNAL_KEY := 1
endif
ifeq ($(LOCAL_CERTIFICATE),)
  ifneq ($(filter APPS,$(LOCAL_MODULE_CLASS)),)
    # It is now a build error to add a prebuilt .apk without
    # specifying a key for it.
    $(error No LOCAL_CERTIFICATE specified for prebuilt "$(LOCAL_SRC_FILES)")
  endif
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
      LOCAL_CERTIFICATE := $(SRC_TARGET_DIR)/product/security/$(LOCAL_CERTIFICATE)
  endif

  PACKAGES.$(LOCAL_MODULE).PRIVATE_KEY := $(LOCAL_CERTIFICATE).pk8
  PACKAGES.$(LOCAL_MODULE).CERTIFICATE := $(LOCAL_CERTIFICATE).x509.pem
  PACKAGES := $(PACKAGES) $(LOCAL_MODULE)
endif

ifneq ($(prebuilt_module_is_a_library),)
  ifneq ($(LOCAL_IS_HOST_MODULE),)
	$(transform-host-ranlib-copy-hack)
  else
	$(transform-ranlib-copy-hack)
  endif
endif
