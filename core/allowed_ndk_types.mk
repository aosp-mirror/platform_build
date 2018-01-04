# Determines the types of NDK modules the current module is allowed to link to.
# Input variables:
#   LOCAL_MODULE
#   LOCAL_MODULE_CLASS
#   LOCAL_NDK_STL_VARIANT
#   LOCAL_SDK_VERSION
# Output variables:
#   my_ndk_stl_family: Family of the NDK STL.
#   my_allowed_ndk_types: Types of NDK modules that may be linked.
#   my_warn_ndk_types: Types of NDK modules that shouldn't be linked, but are.

my_allowed_ndk_types :=
my_warn_ndk_types :=
my_ndk_stl_family :=

ifdef LOCAL_SDK_VERSION
    ifeq ($(LOCAL_NDK_STL_VARIANT),)
        my_ndk_stl_family := system
    else ifeq ($(LOCAL_NDK_STL_VARIANT),system)
        my_ndk_stl_family := system
    else ifeq ($(LOCAL_NDK_STL_VARIANT),c++_shared)
        my_ndk_stl_family := libc++
    else ifeq ($(LOCAL_NDK_STL_VARIANT),c++_static)
        my_ndk_stl_family := libc++
    else ifeq ($(LOCAL_NDK_STL_VARIANT),gnustl_static)
        my_ndk_stl_family := gnustl
    else ifeq ($(LOCAL_NDK_STL_VARIANT),stlport_shared)
        my_ndk_stl_family := stlport
    else ifeq ($(LOCAL_NDK_STL_VARIANT),stlport_static)
        my_ndk_stl_family := stlport
    else ifeq ($(LOCAL_NDK_STL_VARIANT),none)
        my_ndk_stl_family := none
    else
        $(call pretty-error,invalid LOCAL_NDK_STL_VARIANT: $(LOCAL_NDK_STL_VARIANT))
    endif

    # The system STL is only the C++ ABI layer, so it's compatible with any STL.
    my_allowed_ndk_types += native:ndk:system

    # Libaries that don't use the STL can be linked to anything.
    my_allowed_ndk_types += native:ndk:none

    # And it's okay to link your own STL type. Strictly speaking there are more
    # restrictions depending on static vs shared STL, but that will be a follow
    # up patch.
    my_allowed_ndk_types += native:ndk:$(my_ndk_stl_family)

    ifeq ($(LOCAL_MODULE_CLASS),APPS)
        # For an app package, it's actually okay to depend on any set of STLs.
        # If any of the individual libraries depend on each other they've
        # already been checked for consistency, and if they don't they'll be
        # kept isolated by RTLD_LOCAL anyway.
        my_allowed_ndk_types += \
            native:ndk:gnustl native:ndk:libc++ native:ndk:stlport
    endif
else
    my_allowed_ndk_types := native:ndk:none native:ndk:system
    ifeq ($(LOCAL_MODULE_CLASS),APPS)
        # CTS is bad and it should feel bad: http://b/13249737
        my_warn_ndk_types += native:ndk:libc++
    endif
endif
