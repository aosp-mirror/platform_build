#############################################################
## Set up flags based on LOCAL_CXX_STL.
## Input variables: LOCAL_CXX_STL
## Output variables: My_cflags, my_c_includes, my_shared_libraries, etc.
#############################################################

# Only around for development purposes. Will be removed soon.
my_libcxx_is_default := false

# Select the appropriate C++ STL
ifeq ($(strip $(LOCAL_CXX_STL)),default)
    ifndef LOCAL_SDK_VERSION
        ifeq ($(strip $(my_libcxx_is_default)),true)
            # Platform code. Select the appropriate STL.
            my_cxx_stl := libc++
        else
            my_cxx_stl := bionic
        endif
    else
        my_cxx_stl := ndk
    endif
else
    my_cxx_stl := $(strip $(LOCAL_CXX_STL))
endif

ifneq ($(filter $(my_cxx_stl),libc++ libc++_static),)
    my_cflags += -D_USING_LIBCXX
    my_c_includes += external/libcxx/include
    ifeq ($(my_cxx_stl),libc++)
        my_shared_libraries += libc++
    else
        my_static_libraries += libc++_static
    endif

    ifdef LOCAL_IS_HOST_MODULE
        my_cppflags += -nostdinc++
        my_ldflags += -nodefaultlibs
        my_ldlibs += -lc -lm
    endif
else ifneq ($(filter $(my_cxx_stl),stlport stlport_static),)
    my_c_includes += external/stlport/stlport bionic/libstdc++/include bionic
    ifeq ($(my_cxx_stl),stlport)
        my_shared_libraries += libstdc++ libstlport
    else
        my_static_libraries += libstdc++ libstlport_static
    endif
else ifeq ($(my_cxx_stl),ndk)
    # Using an NDK STL. Handled farther up in this file.
    ifndef LOCAL_IS_HOST_MODULE
        my_system_shared_libraries += libstdc++
    endif
else ifeq ($(my_cxx_stl),bionic)
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
        my_ldflags += -nodefaultlibs -lc -lm
    endif
else
    $(error $(my_cxx_stl) is not a supported STL.)
endif
