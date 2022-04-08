# Auto-generate module defitions from platform.zip.
# We use these rules to rebuild .odex files of the .jar/.apk inside the platform.zip.
#

ifdef PDK_FUSION_PLATFORM_ZIP
pdk_dexpreopt_config_mk := $(TARGET_OUT_INTERMEDIATES)/pdk_dexpreopt_config.mk

$(shell rm -f $(pdk_dexpreopt_config_mk) && mkdir -p $(dir $(pdk_dexpreopt_config_mk)) && \
        unzip -qo $(PDK_FUSION_PLATFORM_ZIP) -d $(dir $(pdk_dexpreopt_config_mk)) pdk_dexpreopt_config.mk 2>/dev/null)
endif

ifdef PDK_FUSION_PLATFORM_DIR
pdk_dexpreopt_config_mk := $(PDK_FUSION_PLATFORM_DIR)/pdk_dexpreopt_config.mk
endif

-include $(pdk_dexpreopt_config_mk)

# Define a PDK prebuilt module that comes from platform.zip.
# Must be called with $(eval)
define prebuilt-pdk-java-module
include $(CLEAR_VARS)
LOCAL_MODULE:=$(1)
LOCAL_MODULE_CLASS:=$(2)
# Use LOCAL_PREBUILT_MODULE_FILE instead of LOCAL_SRC_FILES so we don't need to deal with LOCAL_PATH.
LOCAL_PREBUILT_MODULE_FILE:=$(3)
LOCAL_DEX_PREOPT:=$(4)
LOCAL_MULTILIB:=$(5)
LOCAL_DEX_PREOPT_FLAGS:=$(6)
LOCAL_BUILT_MODULE_STEM:=$(7)
LOCAL_MODULE_SUFFIX:=$(suffix $(7))
LOCAL_PRIVILEGED_MODULE:=$(8)
LOCAL_VENDOR_MODULE:=$(9)
LOCAL_MODULE_TARGET_ARCH:=$(10)
LOCAL_REPLACE_PREBUILT_APK_INSTALLED:=$(11)
LOCAL_CERTIFICATE:=PRESIGNED
include $(BUILD_PREBUILT)

# The source prebuilts are extracted in the rule of _pdk_fusion_stamp.
# Use a touch rule to establish the dependency.
ifndef PDK_FUSION_PLATFORM_DIR
$(3) $(11) : $(_pdk_fusion_stamp)
	$(hide) if [ ! -f $$@ ]; then \
	  echo 'Error: $$@ does not exist. Check your platform.zip.' 1>&2; \
	  exit 1; \
	fi
	$(hide) touch $$@
endif
endef

# We don't have a LOCAL_PATH for the auto-generated modules, so let it be the $(BUILD_SYSTEM).
LOCAL_PATH := $(BUILD_SYSTEM)

##### Java libraries.
# Only set up rules for modules that aren't built from source.
pdk_prebuilt_libraries := $(foreach l,$(PDK.DEXPREOPT.JAVA_LIBRARIES),\
  $(if $(MODULE.TARGET.JAVA_LIBRARIES.$(l)),,$(l)))

$(foreach l,$(pdk_prebuilt_libraries), $(eval \
  $(call prebuilt-pdk-java-module,\
    $(l),\
    JAVA_LIBRARIES,\
    $(_pdk_fusion_intermediates)/$(PDK.DEXPREOPT.$(l).SRC),\
    $(PDK.DEXPREOPT.$(l).DEX_PREOPT),\
    $(PDK.DEXPREOPT.$(l).MULTILIB),\
    $(PDK.DEXPREOPT.$(l).DEX_PREOPT_FLAGS),\
    javalib.jar,\
    )))

###### Apps.
pdk_prebuilt_apps := $(foreach a,$(PDK.DEXPREOPT.APPS),\
  $(if $(MODULE.TARGET.APPS.$(a)),,$(a)))

$(foreach a,$(pdk_prebuilt_apps), $(eval \
  $(call prebuilt-pdk-java-module,\
    $(a),\
    APPS,\
    $(_pdk_fusion_intermediates)/$(PDK.DEXPREOPT.$(a).SRC),\
    $(PDK.DEXPREOPT.$(a).DEX_PREOPT),\
    $(PDK.DEXPREOPT.$(a).MULTILIB),\
    $(PDK.DEXPREOPT.$(a).DEX_PREOPT_FLAGS),\
    package.apk,\
    $(PDK.DEXPREOPT.$(a).PRIVILEGED_MODULE),\
    $(PDK.DEXPREOPT.$(a).VENDOR_MODULE),\
    $(PDK.DEXPREOPT.$(a).TARGET_ARCH),\
    $(_pdk_fusion_intermediates)/$(PDK.DEXPREOPT.$(a).STRIPPED_SRC),\
    )))
