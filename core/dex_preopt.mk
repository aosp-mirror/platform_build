####################################
# dexpreopt support - typically used on user builds to run dexopt (for Dalvik) or dex2oat (for ART) ahead of time
#
####################################

include $(BUILD_SYSTEM)/dex_preopt_config.mk

# Method returning whether the install path $(1) should be for system_other.
# Under SANITIZE_LITE, we do not want system_other. Just put things under /data/asan.
ifeq ($(SANITIZE_LITE),true)
install-on-system-other =
else
install-on-system-other = $(filter-out $(PRODUCT_DEXPREOPT_SPEED_APPS) $(PRODUCT_SYSTEM_SERVER_APPS),$(basename $(notdir $(filter $(foreach f,$(SYSTEM_OTHER_ODEX_FILTER),$(TARGET_OUT)/$(f)),$(1)))))
endif

ifeq ($(WITH_DEXPREOPT), true)
ifneq ($(WITH_DEXPREOPT_ART_BOOT_IMG_ONLY), true)
ifeq ($(PRODUCT_USES_DEFAULT_ART_CONFIG), true)

# Infix can be 'art' (ART image for testing), 'boot' (primary), or 'mainline' (mainline extension).
# Soong creates a set of variables for Make, one or each boot image. The only reason why the ART
# image is exposed to Make is testing (art gtests) and benchmarking (art golem benchmarks). Install
# rules that use those variables are in dex_preopt_libart.mk. Here for dexpreopt purposes the infix
# is always 'boot' or 'mainline'.
DEXPREOPT_INFIX := $(if $(filter true,$(DEX_PREOPT_WITH_UPDATABLE_BCP)),mainline,boot)

endif  #PRODUCT_USES_DEFAULT_ART_CONFIG
endif  #WITH_DEXPREOPT_ART_BOOT_IMG_ONLY
endif  #WITH_DEXPREOPT
