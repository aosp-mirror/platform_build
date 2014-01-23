# dexpreopt_odex_install.mk is used to define odex creation rules for JARs and APKs
# This file depends on variables set in base_rules.mk
# Output variables: LOCAL_DEX_PREOPT, built_odex, dexpreopt_boot_jar_module

# Setting LOCAL_DEX_PREOPT based on WITH_DEXPREOPT, LOCAL_DEX_PREOPT, etc
LOCAL_DEX_PREOPT := $(strip $(LOCAL_DEX_PREOPT))
ifneq (true,$(WITH_DEXPREOPT))
  LOCAL_DEX_PREOPT :=
else # WITH_DEXPREOPT=true
  ifeq (,$(TARGET_BUILD_APPS)) # TARGET_BUILD_APPS empty
    ifndef LOCAL_DEX_PREOPT # LOCAL_DEX_PREOPT undefined
      ifeq (,$(LOCAL_APK_LIBRARIES)) # LOCAL_APK_LIBRARIES empty
        LOCAL_DEX_PREOPT := $(DEX_PREOPT_DEFAULT)
      else # LOCAL_APK_LIBRARIES not empty
        LOCAL_DEX_PREOPT := nostripping
      endif # LOCAL_APK_LIBRARIES not empty
    endif # LOCAL_DEX_PREOPT undefined
  endif # TARGET_BUILD_APPS empty
endif # WITH_DEXPREOPT=true
ifeq (false,$(LOCAL_DEX_PREOPT))
  LOCAL_DEX_PREOPT :=
endif
ifdef LOCAL_UNINSTALLABLE_MODULE
LOCAL_DEX_PREOPT :=
endif
ifeq (,$(strip $(all_java_sources)$(full_static_java_libs)$(my_prebuilt_src_file))) # contains no java code
LOCAL_DEX_PREOPT :=
endif
# if module oat file requested in data, disable LOCAL_DEX_PREOPT, will default location to dalvik-cache
ifneq (,$(filter $(LOCAL_MODULE),$(PRODUCT_DEX_PREOPT_PACKAGES_IN_DATA)))
LOCAL_DEX_PREOPT :=
endif

built_odex :=
installed_odex :=
ifdef LOCAL_DEX_PREOPT
dexpreopt_boot_jar_module := $(filter $(DEXPREOPT_BOOT_JARS_MODULES),$(LOCAL_MODULE))
ifdef dexpreopt_boot_jar_module
ifeq ($(DALVIK_VM_LIB),libdvm.so)
built_odex := $(basename $(LOCAL_BUILT_MODULE)).odex
installed_odex := $(basename $(LOCAL_INSTALLED_MODULE)).odex
else # libdvm.so
# For libart, the boot jars' odex files are replaced by $(DEFAULT_DEX_PREOPT_INSTALLED_IMAGE).
# We use this installed_odex trick to get boot.art installed.
installed_odex := $(DEFAULT_DEX_PREOPT_INSTALLED_IMAGE)
endif # libdvm.so
else  # boot jar
built_odex := $(basename $(LOCAL_BUILT_MODULE)).odex
installed_odex := $(basename $(LOCAL_INSTALLED_MODULE)).odex

ifneq ($(DALVIK_VM_LIB),libdvm.so) # libart
ifndef LOCAL_DEX_PREOPT_IMAGE
LOCAL_DEX_PREOPT_IMAGE := $(DEFAULT_DEX_PREOPT_BUILT_IMAGE)
endif
endif # libart
endif # boot jar

ifdef built_odex
# We need $(LOCAL_BUILT_MODULE) in the deps to enforce reinstallation
# even if $(built_odex) is byproduct of $(LOCAL_BUILT_MODULE), such as in package.mk.
$(installed_odex) : $(built_odex) $(LOCAL_BUILT_MODULE) | $(ACP)
	@echo "Install: $@"
	$(copy-file-to-target)
endif

# Add the installed_odex to the list of installed files for this module.
ALL_MODULES.$(LOCAL_MODULE).INSTALLED += $(installed_odex)
# Make sure to install the .odex when you run "make <module_name>"
$(my_register_name): $(installed_odex)

endif # LOCAL_DEX_PREOPT
