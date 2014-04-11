ifneq ($(TARGET_2ND_ARCH),)

# Chromium/V8: needs 64-bit support
_64_bit_directory_blacklist += \
	external/chromium-libpac \
	external/chromium_org \
	external/v8 \
	frameworks/webview \

# misc build errors
_64_bit_directory_blacklist += \
	device/generic/goldfish/opengl \
	device/generic/goldfish/camera \

_64_bit_directory_blacklist_pattern := $(addsuffix %,$(_64_bit_directory_blacklist))

define directory_is_64_bit_blacklisted
$(if $(filter $(_64_bit_directory_blacklist_pattern),$(1)),true)
endef
else
define directory_is_64_bit_blacklisted
endef
endif
