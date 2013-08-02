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

# Not much sense to check build prebuilts
LOCAL_DONT_CHECK_MODULE := true

ifdef LOCAL_PREBUILT_MODULE_FILE
my_prebuilt_src_file := $(LOCAL_PREBUILT_MODULE_FILE)
else
my_prebuilt_src_file := $(LOCAL_PATH)/$(LOCAL_SRC_FILES)
endif

ifdef LOCAL_IS_HOST_MODULE
  my_prefix := HOST_
else
  my_prefix := TARGET_
endif
ifeq (SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS))
  # Put the built targets of all shared libraries in a common directory
  # to simplify the link line.
  OVERRIDE_BUILT_MODULE_PATH := $($(my_prefix)OUT_INTERMEDIATE_LIBRARIES)
endif

ifneq ($(filter STATIC_LIBRARIES SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
  prebuilt_module_is_a_library := true
else
  prebuilt_module_is_a_library :=
endif

# Don't install static libraries by default.
ifndef LOCAL_UNINSTALLABLE_MODULE
ifeq (STATIC_LIBRARIES,$(LOCAL_MODULE_CLASS))
  LOCAL_UNINSTALLABLE_MODULE := true
endif
endif

ifeq ($(LOCAL_STRIP_MODULE),true)
  ifdef LOCAL_IS_HOST_MODULE
    $(error Cannot strip host module LOCAL_PATH=$(LOCAL_PATH))
  endif
  ifeq ($(filter SHARED_LIBRARIES EXECUTABLES,$(LOCAL_MODULE_CLASS)),)
    $(error Can strip only shared libraries or executables LOCAL_PATH=$(LOCAL_PATH))
  endif
  ifneq ($(LOCAL_PREBUILT_STRIP_COMMENTS),)
    $(error Cannot strip scripts LOCAL_PATH=$(LOCAL_PATH))
  endif
  include $(BUILD_SYSTEM)/dynamic_binary.mk
  built_module := $(linked_module)
else  # LOCAL_STRIP_MODULE not true
  include $(BUILD_SYSTEM)/base_rules.mk
  built_module := $(LOCAL_BUILT_MODULE)

ifdef prebuilt_module_is_a_library
export_includes := $(intermediates)/export_includes
$(export_includes): PRIVATE_EXPORT_C_INCLUDE_DIRS := $(LOCAL_EXPORT_C_INCLUDE_DIRS)
$(export_includes) : $(LOCAL_MODULE_MAKEFILE)
	@echo Export includes file: $< -- $@
	$(hide) mkdir -p $(dir $@) && rm -f $@
ifdef LOCAL_EXPORT_C_INCLUDE_DIRS
	$(hide) for d in $(PRIVATE_EXPORT_C_INCLUDE_DIRS); do \
	        echo "-I $$d" >> $@; \
	        done
else
	$(hide) touch $@
endif

$(LOCAL_BUILT_MODULE) : | $(intermediates)/export_includes
endif  # prebuilt_module_is_a_library

# The real dependency will be added after all Android.mks are loaded and the install paths
# of the shared libraries are determined.
ifdef LOCAL_INSTALLED_MODULE
ifdef LOCAL_SHARED_LIBRARIES
$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += $(LOCAL_MODULE):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(LOCAL_SHARED_LIBRARIES))

# We also need the LOCAL_BUILT_MODULE dependency,
# since we use -rpath-link which points to the built module's path.
built_shared_libraries := \
    $(addprefix $($(my_prefix)OUT_INTERMEDIATE_LIBRARIES)/, \
    $(addsuffix $($(my_prefix)SHLIB_SUFFIX), \
        $(LOCAL_SHARED_LIBRARIES)))
$(LOCAL_BUILT_MODULE) : $(built_shared_libraries)
endif
endif

endif  # LOCAL_STRIP_MODULE not true

PACKAGES.$(LOCAL_MODULE).OVERRIDES := $(strip $(LOCAL_OVERRIDES_PACKAGES))

ifeq ($(LOCAL_CERTIFICATE),EXTERNAL)
  # The magic string "EXTERNAL" means this package will be signed with
  # the default dev key throughout the build process, but we expect
  # the final package to be signed with a different key.
  #
  # This can be used for packages where we don't have access to the
  # keys, but want the package to be predexopt'ed.
  LOCAL_CERTIFICATE := $(DEFAULT_SYSTEM_DEV_CERTIFICATE)
  PACKAGES.$(LOCAL_MODULE).EXTERNAL_KEY := 1

  $(built_module) : PRIVATE_PRIVATE_KEY := $(LOCAL_CERTIFICATE).pk8
  $(built_module) : PRIVATE_CERTIFICATE := $(LOCAL_CERTIFICATE).x509.pem
endif
ifeq ($(LOCAL_CERTIFICATE),)
  ifneq ($(filter APPS,$(LOCAL_MODULE_CLASS)),)
    # It is now a build error to add a prebuilt .apk without
    # specifying a key for it.
    $(error No LOCAL_CERTIFICATE specified for prebuilt "$(my_prebuilt_src_file)")
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
      LOCAL_CERTIFICATE := $(dir $(DEFAULT_SYSTEM_DEV_CERTIFICATE))$(LOCAL_CERTIFICATE)
  endif

  PACKAGES.$(LOCAL_MODULE).PRIVATE_KEY := $(LOCAL_CERTIFICATE).pk8
  PACKAGES.$(LOCAL_MODULE).CERTIFICATE := $(LOCAL_CERTIFICATE).x509.pem
  PACKAGES := $(PACKAGES) $(LOCAL_MODULE)

  $(built_module) : PRIVATE_PRIVATE_KEY := $(LOCAL_CERTIFICATE).pk8
  $(built_module) : PRIVATE_CERTIFICATE := $(LOCAL_CERTIFICATE).x509.pem
endif

ifneq ($(filter APPS,$(LOCAL_MODULE_CLASS)),)
ifeq ($(LOCAL_CERTIFICATE),PRESIGNED)
# Ensure that presigned .apks have been aligned.
$(built_module) : $(my_prebuilt_src_file) | $(ZIPALIGN)
	$(transform-prebuilt-to-target-with-zipalign)
else
# Sign and align non-presigned .apks.
$(built_module) : $(my_prebuilt_src_file) | $(ACP) $(ZIPALIGN) $(SIGNAPK_JAR)
	$(transform-prebuilt-to-target)
	$(sign-package)
	$(align-package)
endif
else
ifneq ($(LOCAL_PREBUILT_STRIP_COMMENTS),)
$(built_module) : $(my_prebuilt_src_file)
	$(transform-prebuilt-to-target-strip-comments)
else
$(built_module) : $(my_prebuilt_src_file) | $(ACP)
	$(transform-prebuilt-to-target)
ifneq ($(prebuilt_module_is_a_library),)
  ifneq ($(LOCAL_IS_HOST_MODULE),)
	$(transform-host-ranlib-copy-hack)
  else
	$(transform-ranlib-copy-hack)
  endif
endif
endif
endif

ifeq ($(LOCAL_IS_HOST_MODULE)$(LOCAL_MODULE_CLASS),JAVA_LIBRARIES)
# for target java libraries, the LOCAL_BUILT_MODULE is in a product-specific dir,
# while the deps should be in the common dir, so we make a copy in the common dir.
# For nonstatic library, $(common_javalib_jar) is the dependency file,
# while $(common_classes_jar) is used to link.
common_classes_jar := $(call intermediates-dir-for,JAVA_LIBRARIES,$(LOCAL_MODULE),,COMMON)/classes.jar
common_javalib_jar := $(dir $(common_classes_jar))javalib.jar

$(common_classes_jar) : $(my_prebuilt_src_file) | $(ACP)
	$(transform-prebuilt-to-target)

$(common_javalib_jar) : $(common_classes_jar) | $(ACP)
	$(transform-prebuilt-to-target)

# make sure the classes.jar and javalib.jar are built before $(LOCAL_BUILT_MODULE)
$(built_module) : $(common_javalib_jar)
endif # TARGET JAVA_LIBRARIES
