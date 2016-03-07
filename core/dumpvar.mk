
# List of variables we want to print in the build banner.
print_build_config_vars := \
  PLATFORM_VERSION_CODENAME \
  PLATFORM_VERSION \
  TARGET_PRODUCT \
  TARGET_BUILD_VARIANT \
  TARGET_BUILD_TYPE \
  TARGET_BUILD_APPS \
  TARGET_ARCH \
  TARGET_ARCH_VARIANT \
  TARGET_CPU_VARIANT \
  TARGET_2ND_ARCH \
  TARGET_2ND_ARCH_VARIANT \
  TARGET_2ND_CPU_VARIANT \
  HOST_ARCH \
  HOST_2ND_ARCH \
  HOST_OS \
  HOST_OS_EXTRA \
  HOST_CROSS_OS \
  HOST_CROSS_ARCH \
  HOST_CROSS_2ND_ARCH \
  HOST_BUILD_TYPE \
  BUILD_ID \
  OUT_DIR

ifeq ($(TARGET_BUILD_PDK),true)
print_build_config_vars += \
  TARGET_BUILD_PDK \
  PDK_FUSION_PLATFORM_ZIP
endif

# ---------------------------------------------------------------
# the setpath shell function in envsetup.sh uses this to figure out
# what to add to the path given the config we have chosen.
ifeq ($(CALLED_FROM_SETUP),true)

ifneq ($(filter /%,$(HOST_OUT_EXECUTABLES)),)
ABP:=$(HOST_OUT_EXECUTABLES)
else
ABP:=$(PWD)/$(HOST_OUT_EXECUTABLES)
endif

ANDROID_BUILD_PATHS := $(ABP)
ANDROID_PREBUILTS := prebuilt/$(HOST_PREBUILT_TAG)
ANDROID_GCC_PREBUILTS := prebuilts/gcc/$(HOST_PREBUILT_TAG)

# The "dumpvar" stuff lets you say something like
#
#     CALLED_FROM_SETUP=true \
#       make -f config/envsetup.make dumpvar-TARGET_OUT
# or
#     CALLED_FROM_SETUP=true \
#       make -f config/envsetup.make dumpvar-abs-HOST_OUT_EXECUTABLES
#
# The plain (non-abs) version just dumps the value of the named variable.
# The "abs" version will treat the variable as a path, and dumps an
# absolute path to it.
#
dumpvar_goals := \
	$(strip $(patsubst dumpvar-%,%,$(filter dumpvar-%,$(MAKECMDGOALS))))
ifdef dumpvar_goals

  ifneq ($(words $(dumpvar_goals)),1)
    $(error Only one "dumpvar-" goal allowed. Saw "$(MAKECMDGOALS)")
  endif

  # If the goal is of the form "dumpvar-abs-VARNAME", then
  # treat VARNAME as a path and return the absolute path to it.
  absolute_dumpvar := $(strip $(filter abs-%,$(dumpvar_goals)))
  ifdef absolute_dumpvar
    dumpvar_goals := $(patsubst abs-%,%,$(dumpvar_goals))
    DUMPVAR_VALUE := $(abspath $($(dumpvar_goals)))
    dumpvar_target := dumpvar-abs-$(dumpvar_goals)
  else
    DUMPVAR_VALUE := $($(dumpvar_goals))
    dumpvar_target := dumpvar-$(dumpvar_goals)
  endif

.PHONY: $(dumpvar_target)
$(dumpvar_target):
	@echo $(DUMPVAR_VALUE)

endif # dumpvar_goals

ifneq ($(dumpvar_goals),report_config)
PRINT_BUILD_CONFIG:=
endif

ifneq ($(filter report_config,$(DUMP_MANY_VARS)),)
# Construct the shell commands that print the config banner.
report_config_sh := echo '============================================';
report_config_sh += $(foreach v,$(print_build_config_vars),echo '$v=$($(v))';)
report_config_sh += echo '============================================';
endif

# Dump mulitple variables to "<var>=<value>" pairs, one per line.
# The output may be executed as bash script.
# Input variables:
#   DUMP_MANY_VARS: the list of variable names.
#   DUMP_VAR_PREFIX: an optional prefix of the variable name added to the output.
#   DUMP_MANY_ABS_VARS: the list of abs variable names.
#   DUMP_ABS_VAR_PREFIX: an optional prefix of the abs variable name added to the output.
.PHONY: dump-many-vars
dump-many-vars :
	@$(foreach v, $(filter-out report_config, $(DUMP_MANY_VARS)),\
	  echo "$(DUMP_VAR_PREFIX)$(v)='$($(v))'";)
ifneq ($(filter report_config, $(DUMP_MANY_VARS)),)
	@# Construct a special variable for report_config.
	@# Escape \` to defer the execution of report_config_sh to preserve the line breaks.
	@echo "$(DUMP_VAR_PREFIX)report_config=\`$(report_config_sh)\`"
endif
	@$(foreach v, $(sort $(DUMP_MANY_ABS_VARS)),\
	  echo "$(DUMP_ABS_VAR_PREFIX)$(v)='$(abspath $($(v)))'";)

endif # CALLED_FROM_SETUP

ifneq ($(PRINT_BUILD_CONFIG),)
$(info ============================================)
$(foreach v, $(print_build_config_vars),\
  $(info $v=$($(v))))
$(info ============================================)
endif
