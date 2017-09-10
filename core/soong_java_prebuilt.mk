# Java prebuilt coming from Soong.
# Extra inputs:
# LOCAL_SOONG_HEADER_JAR
# LOCAL_SOONG_DEX

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  $(call pretty-error,soong_java_prebuilt.mk may only be used from Soong)
endif

# TODO: device support
ifndef LOCAL_IS_HOST_MODULE
  $(call pretty-error,exporting soong device jars to make not supported yet)
endif

LOCAL_MODULE_SUFFIX := .jar
LOCAL_BUILT_MODULE_STEM := javalib.jar

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

full_classes_jar := $(intermediates.COMMON)/classes.jar
full_classes_header_jar := $(intermediates.COMMON)/classes-header.jar

LOCAL_FULL_CLASSES_PRE_JACOCO_JAR := $(LOCAL_PREBUILT_MODULE_FILE)

#######################################
include $(BUILD_SYSTEM)/jacoco.mk
#######################################

$(eval $(call copy-one-file,$(LOCAL_FULL_CLASSES_JACOCO_JAR),$(LOCAL_BUILT_MODULE)))
$(eval $(call copy-one-file,$(LOCAL_FULL_CLASSES_JACOCO_JAR),$(full_classes_jar)))

ifdef LOCAL_SOONG_HEADER_JAR
$(eval $(call copy-one-file,$(LOCAL_SOONG_HEADER_JAR),$(full_classes_header_jar)))
else
$(eval $(call copy-one-file,$(full_classes_jar),$(full_classes_header_jar)))
endif

javac-check : $(full_classes_jar)
javac-check-$(LOCAL_MODULE) : $(full_classes_jar)

# Built in equivalent to include $(CLEAR_VARS)
LOCAL_SOONG_HEADER_JAR :=
LOCAL_SOONG_DEX :=
