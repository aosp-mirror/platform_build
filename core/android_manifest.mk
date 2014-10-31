# Handle AndroidManifest.xmls
# Input: LOCAL_MANIFEST_FILE, LOCAL_FULL_MANIFEST_FILE, LOCAL_FULL_LIBS_MANIFEST_FILES
# Output: full_android_manifest

ifeq ($(strip $(LOCAL_MANIFEST_FILE)),)
  LOCAL_MANIFEST_FILE := AndroidManifest.xml
endif
ifdef LOCAL_FULL_MANIFEST_FILE
  full_android_manifest := $(LOCAL_FULL_MANIFEST_FILE)
else
  full_android_manifest := $(LOCAL_PATH)/$(LOCAL_MANIFEST_FILE)
endif

my_full_libs_manifest_files := $(LOCAL_FULL_LIBS_MANIFEST_FILES)
my_full_libs_manifest_deps := $(LOCAL_FULL_LIBS_MANIFEST_FILES)

# Set up dependency on aar libraries
ifdef LOCAL_STATIC_JAVA_AAR_LIBRARIES
my_full_libs_manifest_deps += $(foreach lib, $(LOCAL_STATIC_JAVA_AAR_LIBRARIES),\
  $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/aar/classes.jar)
my_full_libs_manifest_files += $(foreach lib, $(LOCAL_STATIC_JAVA_AAR_LIBRARIES),\
  $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/aar/AndroidManifest.xml)

LOCAL_RESOURCE_DIR += $(foreach lib, $(LOCAL_STATIC_JAVA_AAR_LIBRARIES),\
  $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/aar/res)
endif

# Set up rules to merge library manifest files
ifdef my_full_libs_manifest_files
main_android_manifest := $(full_android_manifest)
full_android_manifest := $(intermediates.COMMON)/AndroidManifest.xml
$(full_android_manifest): PRIVATE_LIBS_MANIFESTS := $(my_full_libs_manifest_files)
$(full_android_manifest) : $(main_android_manifest) $(my_full_libs_manifest_deps)
	@echo "Merge android manifest files: $@ <-- $< $(PRIVATE_LIBS_MANIFESTS)"
	@mkdir -p $(dir $@)
	$(hide) $(ANDROID_MANIFEST_MERGER) --main $< --libs $(PRIVATE_LIBS_MANIFESTS) \
	    --out $@

endif
