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

# Set up rules to merge library manifest files
ifdef LOCAL_FULL_LIBS_MANIFEST_FILES
main_android_manifest := $(full_android_manifest)
full_android_manifest := $(intermediates.COMMON)/AndroidManifest.xml
$(full_android_manifest): PRIVATE_LIBS_MANIFESTS := $(LOCAL_FULL_LIBS_MANIFEST_FILES)
$(full_android_manifest) : $(main_android_manifest) $(LOCAL_FULL_LIBS_MANIFEST_FILES)
	@echo "Merge android manifest files: $@ <-- $^"
	@mkdir -p $(dir $@)
	$(hide) $(ANDROID_MANIFEST_MERGER) --main $< --libs $(PRIVATE_LIBS_MANIFESTS) \
	    --out $@

endif
