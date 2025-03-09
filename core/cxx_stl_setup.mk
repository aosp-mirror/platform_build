#############################################################
## Set up flags based on LOCAL_CXX_STL.
## Input variables: LOCAL_CXX_STL, my_prefix
## Output variables: My_cflags, my_c_includes, my_shared_libraries, etc.
#############################################################

# Select the appropriate C++ STL
ifeq ($(strip $(LOCAL_CXX_STL)),default)
    ifndef LOCAL_SDK_VERSION
        # Platform code. Select the appropriate STL.
        my_cxx_stl := libc++
        ifdef LOCAL_IS_HOST_MODULE
            ifneq (,$(BUILD_HOST_static))
                my_cxx_stl := libc++_static
            endif
        endif
    else
        my_cxx_stl := ndk
    endif
else
    my_cxx_stl := $(strip $(LOCAL_CXX_STL))
    ifdef LOCAL_SDK_VERSION
        # The NDK has historically used LOCAL_NDK_STL_VARIANT to specify the
        # STL. An Android.mk that specifies both LOCAL_CXX_STL and
        # LOCAL_SDK_VERSION will incorrectly try (and most likely fail) to use
        # the platform STL in an NDK binary. Emit an error to direct the user
        # toward the correct option.
        #
        # Note that we could also accept LOCAL_CXX_STL as an alias for
        # LOCAL_NDK_STL_VARIANT (and in fact soong does use the same name), but
        # the two options use different names for the STLs.
        $(error $(LOCAL_PATH): $(LOCAL_MODULE): Must use LOCAL_NDK_STL_VARIANT rather than LOCAL_CXX_STL for NDK binaries)
    endif
endif

my_link_type := dynamic
ifdef LOCAL_IS_HOST_MODULE
    ifneq (,$(BUILD_HOST_static))
        my_link_type := static
    endif
    ifeq (-static,$(filter -static,$(my_ldflags)))
        my_link_type := static
    endif
else
    ifeq (true,$(LOCAL_FORCE_STATIC_EXECUTABLE))
        my_link_type := static
    endif
endif

my_cxx_ldlibs :=
ifneq ($(filter $(my_cxx_stl),libc++ libc++_static),)
    ifeq ($($(my_prefix)OS),darwin)
        # libc++'s headers are annotated with availability macros that indicate
        # which version of Mac OS was the first to ship with a libc++ feature
        # available in its *system's* libc++.dylib. We do not use the system's
        # library, but rather ship our own. As such, these availability
        # attributes are meaningless for us but cause build breaks when we try
        # to use code that would not be available in the system's dylib.
        my_cppflags += -D_LIBCPP_DISABLE_AVAILABILITY
    endif

    # Note that the structure of this means that LOCAL_CXX_STL := libc++ will
    # use the static libc++ for static executables.
    ifeq ($(my_link_type),dynamic)
        ifeq ($(my_cxx_stl),libc++)
            my_shared_libraries += libc++
        else
            my_static_libraries += libc++_static
        endif
    else
        my_static_libraries += libc++_static
    endif

    ifdef LOCAL_IS_HOST_MODULE
        my_cppflags += -nostdinc++
        my_ldflags += -nostdlib++
    else
        my_static_libraries += libc++demangle

        ifeq ($(my_link_type),static)
            my_static_libraries += libm libc libunwind libstatic_rustlibs_for_make
        endif
    endif
else ifeq ($(my_cxx_stl),ndk)
    # Using an NDK STL. Handled in binary.mk.
else ifeq ($(my_cxx_stl),libstdc++)
    $(error $(LOCAL_PATH): $(LOCAL_MODULE): libstdc++ is not supported)
else ifeq ($(my_cxx_stl),none)
    ifdef LOCAL_IS_HOST_MODULE
        my_cppflags += -nostdinc++
        my_ldflags += -nostdlib++
    endif
else
    $(error $(LOCAL_PATH): $(LOCAL_MODULE): $(my_cxx_stl) is not a supported STL.)
endif
