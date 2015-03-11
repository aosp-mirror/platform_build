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
      ifneq ($(filter $(TARGET_OUT)/%,$(my_module_path)),) # Installed to system.img.
        ifeq (,$(LOCAL_APK_LIBRARIES)) # LOCAL_APK_LIBRARIES empty
          # If we have product-specific config for this module?
          ifeq (disable,$(DEXPREOPT.$(TARGET_PRODUCT).$(LOCAL_MODULE).CONFIG))
            LOCAL_DEX_PREOPT := false
          else
            LOCAL_DEX_PREOPT := $(DEX_PREOPT_DEFAULT)
          endif
        else # LOCAL_APK_LIBRARIES not empty
          LOCAL_DEX_PREOPT := nostripping
        endif # LOCAL_APK_LIBRARIES not empty
      endif # Installed to system.img.
    endif # LOCAL_DEX_PREOPT undefined
  endif # TARGET_BUILD_APPS empty
endif # WITH_DEXPREOPT=true
ifeq (false,$(LOCAL_DEX_PREOPT))
  LOCAL_DEX_PREOPT :=
endif
ifdef LOCAL_UNINSTALLABLE_MODULE
LOCAL_DEX_PREOPT :=
endif
ifeq (,$(strip $(built_dex)$(my_prebuilt_src_file))) # contains no java code
LOCAL_DEX_PREOPT :=
endif
# if WITH_DEXPREOPT_BOOT_IMG_ONLY=true and module is not in boot class path skip
ifeq (true,$(WITH_DEXPREOPT_BOOT_IMG_ONLY))
ifeq ($(filter $(DEXPREOPT_BOOT_JARS_MODULES),$(LOCAL_MODULE)),)
LOCAL_DEX_PREOPT :=
endif
endif

built_odex :=
installed_odex :=
built_installed_odex :=
ifdef LOCAL_DEX_PREOPT
dexpreopt_boot_jar_module := $(filter $(DEXPREOPT_BOOT_JARS_MODULES),$(LOCAL_MODULE))
ifdef dexpreopt_boot_jar_module
# For libart, the boot jars' odex files are replaced by $(DEFAULT_DEX_PREOPT_INSTALLED_IMAGE).
# We use this installed_odex trick to get boot.art installed.
installed_odex := $(DEFAULT_DEX_PREOPT_INSTALLED_IMAGE)
# Append the odex for the 2nd arch if we have one.
installed_odex += $($(TARGET_2ND_ARCH_VAR_PREFIX)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE)
else  # boot jar
ifeq ($(LOCAL_MODULE_CLASS),JAVA_LIBRARIES)
# For a Java library, by default we build odex for both 1st arch and 2nd arch.
# But it can be overridden with "LOCAL_MULTILIB := first".
ifneq (,$(filter $(PRODUCT_SYSTEM_SERVER_JARS),$(LOCAL_MODULE)))
# For system server jars, we build for only "first".
my_module_multilib := first
else
my_module_multilib := $(LOCAL_MULTILIB)
endif
# #################################################
# Odex for the 1st arch
my_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/setup_one_odex.mk
# #################################################
# Odex for the 2nd arch
ifdef TARGET_2ND_ARCH
ifneq (first,$(my_module_multilib))
my_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/setup_one_odex.mk
endif  # my_module_multilib is not first.
endif  # TARGET_2ND_ARCH
# #################################################
else  # must be APPS
# The preferred arch
my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/setup_one_odex.mk
ifdef TARGET_2ND_ARCH
ifeq ($(LOCAL_MULTILIB),both)
# The non-preferred arch
my_2nd_arch_prefix := $(if $(LOCAL_2ND_ARCH_VAR_PREFIX),,$(TARGET_2ND_ARCH_VAR_PREFIX))
include $(BUILD_SYSTEM)/setup_one_odex.mk
endif  # LOCAL_MULTILIB is both
endif  # TARGET_2ND_ARCH
endif  # LOCAL_MODULE_CLASS
endif  # boot jar

ifdef built_odex
ifndef LOCAL_DEX_PREOPT_FLAGS
LOCAL_DEX_PREOPT_FLAGS := $(DEXPREOPT.$(TARGET_PRODUCT).$(LOCAL_MODULE).CONFIG)
ifndef LOCAL_DEX_PREOPT_FLAGS
LOCAL_DEX_PREOPT_FLAGS := $(PRODUCT_DEX_PREOPT_DEFAULT_FLAGS)
endif
endif

# Compile apps with position-independent code if WITH_DEXPREOPT_PIC=true
ifeq (true,$(WITH_DEXPREOPT_PIC))
  LOCAL_DEX_PREOPT_FLAGS += --compile-pic
endif

$(built_odex): PRIVATE_DEX_PREOPT_FLAGS := $(LOCAL_DEX_PREOPT_FLAGS)

# Use pattern rule - we may have multiple installed odex files.
# Ugly syntax - See the definition get-odex-file-path.
$(installed_odex) : $(dir $(LOCAL_INSTALLED_MODULE))%$(notdir $(word 1,$(installed_odex))) \
                  : $(dir $(LOCAL_BUILT_MODULE))%$(notdir $(word 1,$(built_odex))) \
    | $(ACP)
	@echo "Install: $@"
	$(copy-file-to-target)
endif

# Add the installed_odex to the list of installed files for this module.
ALL_MODULES.$(my_register_name).INSTALLED += $(installed_odex)
ALL_MODULES.$(my_register_name).BUILT_INSTALLED += $(built_installed_odex)

# Make sure to install the .odex when you run "make <module_name>"
$(my_register_name): $(installed_odex)

endif # LOCAL_DEX_PREOPT
