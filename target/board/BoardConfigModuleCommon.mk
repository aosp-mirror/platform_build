# BoardConfigModuleCommon.mk
#
# Common compile-time settings for module builds.

# Required for all module devices.
TARGET_USES_64_BIT_BINDER := true

# Necessary to make modules able to use the VNDK via 'use_vendor: true'
# TODO(b/185769808): look into whether this is still used.
BOARD_VNDK_VERSION := current
