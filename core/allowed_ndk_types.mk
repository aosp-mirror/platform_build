# Determines the types of NDK modules the current module is allowed to link to.
# Input variables:
#   LOCAL_MODULE
#   LOCAL_MODULE_CLASS
#   LOCAL_NDK_STL_VARIANT
#   LOCAL_SDK_VERSION
# Output variables:
#   my_ndk_stl_family: Family of the NDK STL.
#   my_ndk_stl_link_type: STL link type, static or shared.
#   my_allowed_ndk_types: Types of NDK modules that may be linked.
#   my_warn_ndk_types: Types of NDK modules that shouldn't be linked, but are.

my_allowed_ndk_types :=
my_warn_ndk_types :=
my_ndk_stl_family :=
my_ndk_stl_link_type :=

ifdef LOCAL_SDK_VERSION
    ifeq ($(LOCAL_NDK_STL_VARIANT),)
        my_ndk_stl_family := system
        my_ndk_stl_link_type := shared
    else ifeq ($(LOCAL_NDK_STL_VARIANT),system)
        my_ndk_stl_family := system
        my_ndk_stl_link_type := shared
    else ifeq ($(LOCAL_NDK_STL_VARIANT),c++_shared)
        my_ndk_stl_family := libc++
        my_ndk_stl_link_type := shared
    else ifeq ($(LOCAL_NDK_STL_VARIANT),c++_static)
        my_ndk_stl_family := libc++
        my_ndk_stl_link_type := static
    else ifeq ($(LOCAL_NDK_STL_VARIANT),none)
        my_ndk_stl_family := none
        my_ndk_stl_link_type := none
    else
        $(call pretty-error,invalid LOCAL_NDK_STL_VARIANT: $(LOCAL_NDK_STL_VARIANT))
    endif

    ifeq ($(LOCAL_MODULE_CLASS),STATIC_LIBRARIES)
        # The "none" link type indicates that nothing is actually linked. Since
        # this is a static library, it's still up to the final use of the
        # library whether a static or shared STL should be used.
        my_ndk_stl_link_type := none
    endif

    # The system STL is only the C++ ABI layer, so it's compatible with any STL.
    my_allowed_ndk_types += native:ndk:system:shared
    my_allowed_ndk_types += native:ndk:system:none

    # Libaries that don't use the STL can be linked to anything.
    my_allowed_ndk_types += native:ndk:none:none

    # And it's always okay to link a static library that uses your own STL type.
    # Since nothing was actually linked for the static library, it is up to the
    # first linked library in the dependency chain which gets used.
    my_allowed_ndk_types += native:ndk:$(my_ndk_stl_family):none

    ifeq ($(LOCAL_MODULE_CLASS),APPS)
        # For an app package, it's actually okay to depend on any set of STLs.
        # If any of the individual libraries depend on each other they've
        # already been checked for consistency, and if they don't they'll be
        # kept isolated by RTLD_LOCAL anyway.
        my_allowed_ndk_types += \
            native:ndk:libc++:shared native:ndk:libc++:static

        # The "none" link type that used by static libraries is intentionally
        # omitted here. We should only be dealing with shared libraries in
        # LOCAL_JNI_SHARED_LIBRARIES.
    else ifeq ($(my_ndk_stl_link_type),shared)
        # Modules linked to a shared STL can only use another shared STL.
        my_allowed_ndk_types += native:ndk:$(my_ndk_stl_family):shared
    endif
    # Else we are a non-static library that uses a static STL, and are
    # incompatible with all other shared libraries that use an STL.
else
    my_allowed_ndk_types := \
        native:ndk:none:none \
        native:ndk:system:none \
        native:ndk:system:shared \

    ifeq ($(LOCAL_MODULE_CLASS),APPS)
        # CTS is bad and it should feel bad: http://b/13249737
        my_warn_ndk_types += native:ndk:libc++:static
    endif
endif
