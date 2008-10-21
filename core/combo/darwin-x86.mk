# Configuration for Darwin (Mac OS X) on PPC.
# Included by combo/select.make

$(combo_target)GLOBAL_CFLAGS += -fPIC
$(combo_target)NO_UNDEFINED_LDFLAGS := -Wl,-undefined,error

$(combo_target)CC := $(CC)
$(combo_target)CXX := $(CXX)
$(combo_target)AR := $(AR)

$(combo_target)SHLIB_SUFFIX := .dylib
$(combo_target)JNILIB_SUFFIX := .jnilib

$(combo_target)GLOBAL_CFLAGS += \
	-include $(call select-android-config-h,darwin-x86)
$(combo_target)RUN_RANLIB_AFTER_COPYING := true

ifeq ($(combo_target),TARGET_)
$(combo_target)CUSTOM_LD_COMMAND := true
define transform-o-to-shared-lib-inner
    $(TARGET_CXX) \
        -dynamiclib -single_module -read_only_relocs suppress \
        $(TARGET_GLOBAL_LD_DIRS) \
        $(PRIVATE_ALL_OBJECTS) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(PRIVATE_LDLIBS) \
        -o $@ \
        $(PRIVATE_LDFLAGS) \
        $(if $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES),-all_load) \
        $(TARGET_LIBGCC)
endef

define transform-o-to-executable-inner
	$(TARGET_CXX) \
        -o $@ \
        -Wl,-dynamic -headerpad_max_install_names \
        $(TARGET_GLOBAL_LD_DIRS) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
        $(PRIVATE_ALL_OBJECTS) \
        $(PRIVATE_LDLIBS) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(TARGET_LIBGCC)
endef

define transform-o-to-static-executable-inner
    $(TARGET_CXX) \
        -static \
        -o $@ \
        $(TARGET_GLOBAL_LD_DIRS) \
        $(PRIVATE_LDFLAGS) \
        $(PRIVATE_ALL_OBJECTS) \
        $(PRIVATE_LDLIBS) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(TARGET_LIBGCC)
endef

else
$(combo_target)CUSTOM_LD_COMMAND := true

define transform-host-o-to-shared-lib-inner
    $(HOST_CXX) \
        -dynamiclib -single_module -read_only_relocs suppress \
        $(HOST_GLOBAL_LD_DIRS) \
        $(PRIVATE_ALL_OBJECTS) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(PRIVATE_LDLIBS) \
        -o $@ \
        $(PRIVATE_LDFLAGS) \
        $(HOST_LIBGCC)
endef

define transform-host-o-to-executable-inner
$(HOST_CXX) \
        -o $@ \
        -Wl,-dynamic -headerpad_max_install_names \
        $(HOST_GLOBAL_LD_DIRS) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
        $(PRIVATE_ALL_OBJECTS) \
        $(PRIVATE_LDLIBS) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(HOST_LIBGCC)
endef

# $(1): The file to check
define get-file-size
stat -f "%z" $(1)
endef

# Which gcc to use to build qemu, which doesn't work right when
# built with 4.2.1 or later.
GCCQEMU := prebuilt/darwin-x86/toolchain/i686-apple-darwin8-4.0.1/bin/gcc

endif

