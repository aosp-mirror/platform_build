###########################################################
# takes form LOCAL_AUX_TOOLCHAIN_$(LOCAL_AUX_CPU)
###########################################################

###############################
# setup AUX environment
###############################

# shortcuts for targets with a single instance of OS, ARCH, VARIANT, CPU
AUX_TOOLCHAIN := $(if $(LOCAL_AUX_TOOLCHAIN),$(LOCAL_AUX_TOOLCHAIN),$(AUX_TOOLCHAIN_$(AUX_CPU)))
AUX_BUILD_NOT_COMPATIBLE:=
ifeq ($(strip $(AUX_TOOLCHAIN)),)
  ifeq ($(strip $(AUX_CPU)),)
    $(warning $(LOCAL_PATH): $(LOCAL_MODULE): Undefined CPU for AUX toolchain)
    AUX_BUILD_NOT_COMPATIBLE += TOOLCHAIN
  else
    $(warning $(LOCAL_PATH): $(LOCAL_MODULE): Undefined AUX toolchain for CPU=$(AUX_CPU))
    AUX_BUILD_NOT_COMPATIBLE += TOOLCHAIN
  endif
endif

AUX_BUILD_NOT_COMPATIBLE += $(foreach var,OS ARCH SUBARCH CPU OS_VARIANT,$(if $(LOCAL_AUX_$(var)),$(if \
    $(filter $(LOCAL_AUX_$(var)),$(AUX_$(var))),,$(var))))

AUX_BUILD_NOT_COMPATIBLE := $(strip $(AUX_BUILD_NOT_COMPATIBLE))

ifneq ($(AUX_BUILD_NOT_COMPATIBLE),)
$(info $(LOCAL_PATH): $(LOCAL_MODULE): not compatible: "$(AUX_BUILD_NOT_COMPATIBLE)" with)
$(info ====> OS=$(AUX_OS) CPU=$(AUX_CPU) ARCH=$(AUX_ARCH) SUBARCH=$(AUX_SUBARCH) OS_VARIANT=$(AUX_OS_VARIANT))
$(info ====> TOOLCHAIN=$(AUX_TOOLCHAIN))
endif

AUX_AR := $(AUX_TOOLCHAIN)ar
AUX_AS := $(AUX_TOOLCHAIN)gcc
AUX_CC := $(AUX_TOOLCHAIN)gcc
AUX_CXX := $(AUX_TOOLCHAIN)g++
AUX_LINKER := $(AUX_TOOLCHAIN)ld
AUX_OBJCOPY := $(AUX_TOOLCHAIN)objcopy
AUX_OBJDUMP := $(AUX_TOOLCHAIN)objdump

###############################
# setup Android environment
###############################

LOCAL_IS_AUX_MODULE := true
LOCAL_2ND_ARCH_VAR_PREFIX :=
LOCAL_CC := $(AUX_CC)
LOCAL_CXX := $(AUX_CXX)
LOCAL_NO_DEFAULT_COMPILER_FLAGS := true
LOCAL_SYSTEM_SHARED_LIBRARIES :=
LOCAL_CXX_STL := none
LOCAL_NO_PIC := true
LOCAL_NO_LIBCOMPILER_RT := true
