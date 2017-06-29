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

            ifeq ($($(my_prefix)OS),windows)
                # libc++ is not supported on mingw.
                my_cxx_stl := libstdc++
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
    ifdef LOCAL_IS_HOST_MODULE
        ifeq ($($(my_prefix)OS),windows)
            ifneq ($(filter $(my_cxx_stl),libc++ libc++_static),)
                # libc++ is not supported on mingw.
                my_cxx_stl := libstdc++
            endif
        endif
    endif
endif

# Yes, this is actually what the clang driver does.
linux_dynamic_gcclibs := -lgcc_s -lgcc -lc -lgcc_s -lgcc
linux_static_gcclibs := -Wl,--start-group -lgcc -lgcc_eh -lc -Wl,--end-group
darwin_dynamic_gcclibs := -lc -lSystem
darwin_static_gcclibs := NO_STATIC_HOST_BINARIES_ON_DARWIN
windows_dynamic_gcclibs := \
    -lmsvcr110 -lmingw32 -lgcc -lmoldname -lmingwex -lmsvcrt -ladvapi32 \
    -lshell32 -luser32 -lkernel32 -lmingw32 -lgcc -lmoldname -lmingwex -lmsvcrt
windows_static_gcclibs := NO_STATIC_HOST_BINARIES_ON_WINDOWS

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
    my_cflags += -D_USING_LIBCXX

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
        my_ldflags += -nodefaultlibs
        my_ldlibs += -lpthread -lm
        my_cxx_ldlibs += $($($(my_prefix)OS)_$(my_link_type)_gcclibs)
    else
        ifeq (arm,$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH))
            my_static_libraries += libunwind_llvm
            my_ldflags += -Wl,--exclude-libs,libunwind_llvm.a
        endif

        ifeq ($(my_link_type),static)
            my_static_libraries += libm libc libdl
        endif
    endif
else ifeq ($(my_cxx_stl),ndk)
    # Using an NDK STL. Handled in binary.mk.
else ifeq ($(my_cxx_stl),libstdc++)
    ifndef LOCAL_IS_HOST_MODULE
        $(error $(LOCAL_PATH): $(LOCAL_MODULE): libstdc++ is not supported for device modules)
    else ifneq ($($(my_prefix)OS),windows)
        $(error $(LOCAL_PATH): $(LOCAL_MODULE): libstdc++ is not supported on $($(my_prefix)OS))
    endif
else ifeq ($(my_cxx_stl),none)
    ifdef LOCAL_IS_HOST_MODULE
        my_cppflags += -nostdinc++
        my_ldflags += -nodefaultlibs
        my_cxx_ldlibs += $($($(my_prefix)OS)_$(my_link_type)_gcclibs)
    endif
else
    $(error $(LOCAL_PATH): $(LOCAL_MODULE): $(my_cxx_stl) is not a supported STL.)
endif
