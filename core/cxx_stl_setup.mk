#############################################################
## Set up flags based on LOCAL_CXX_STL.
## Input variables: LOCAL_CXX_STL
## Output variables: My_cflags, my_c_includes, my_shared_libraries, etc.
#############################################################

# Select the appropriate C++ STL
ifeq ($(strip $(LOCAL_CXX_STL)),default)
    ifndef LOCAL_SDK_VERSION
        # Platform code. Select the appropriate STL.
        ifndef USE_MINGW
            my_cxx_stl := libc++
            ifdef LOCAL_IS_HOST_MODULE
                ifneq (,$(BUILD_HOST_static))
                    my_cxx_stl := libc++_static
                endif
            endif
        else
            # libc++ is not supported on mingw.
            my_cxx_stl := libstdc++
        endif
    else
        my_cxx_stl := ndk
    endif
else
    my_cxx_stl := $(strip $(LOCAL_CXX_STL))
endif

# Yes, this is actually what the clang driver does.
HOST_linux_dynamic_gcclibs := -lgcc_s -lgcc -lc -lgcc_s -lgcc
HOST_linux_static_gcclibs := -Wl,--start-group -lgcc -lgcc_eh -lc -Wl,--end-group
HOST_darwin_dynamic_gcclibs := -lc -lSystem
HOST_darwin_static_gcclibs := NO_STATIC_HOST_BINARIES_ON_DARWIN

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

ifneq ($(filter $(my_cxx_stl),libc++ libc++_static),)
    my_cflags += -D_USING_LIBCXX
    my_c_includes += external/libcxx/include
    ifeq ($(my_cxx_stl),libc++)
        my_shared_libraries += libc++
    else
        my_static_libraries += libc++_static
        ifndef LOCAL_IS_HOST_MODULE
            ifeq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
                my_static_libraries += libm libc libdl
            endif
        endif
    endif

    ifdef LOCAL_IS_HOST_MODULE
        my_cppflags += -nostdinc++
        my_ldflags += -nodefaultlibs
        my_ldlibs += -lpthread -lm
        my_ldlibs += $($(my_prefix)$(HOST_OS)_$(my_link_type)_gcclibs)
    else
        ifeq (arm,$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH))
            my_static_libraries += libunwind_llvm
            my_ldflags += -Wl,--exclude-libs,libunwind_llvm.a
        endif

        ifeq ($(my_link_type),static)
            my_static_libraries += libdl
        else
            my_shared_libraries += libdl
        endif
    endif
else ifeq ($(my_cxx_stl),ndk)
    # Using an NDK STL. Handled in binary.mk.
    ifndef LOCAL_IS_HOST_MODULE
        my_system_shared_libraries += libstdc++
    endif
else ifeq ($(my_cxx_stl),libstdc++)
    # Using bionic's basic libstdc++. Not actually an STL. Only around until the
    # tree is in good enough shape to not need it.
    ifndef LOCAL_IS_HOST_MODULE
        my_c_includes += bionic/libstdc++/include
        my_system_shared_libraries += libstdc++
    endif
    # Host builds will use GNU libstdc++.
else ifeq ($(my_cxx_stl),none)
    ifdef LOCAL_IS_HOST_MODULE
        my_cppflags += -nostdinc++
        my_ldflags += -nodefaultlibs
        my_ldlibs += $($(my_prefix)$(HOST_OS)_$(my_link_type)_gcclibs)
    endif
else
    $(error $(LOCAL_PATH): $(LOCAL_MODULE): $(my_cxx_stl) is not a supported STL.)
endif
