LOCAL_PATH := $(call my-dir)

# We're relocating the build project to a subdirectory, then using symlinks
# to expose the subdirectories where they used to be. If the manifest hasn't
# been updated, we need to include all the subdirectories.
ifeq ($(LOCAL_PATH),build)
include $(call first-makefiles-under,$(LOCAL_PATH))
endif
