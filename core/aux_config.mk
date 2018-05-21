variant_list := $(filter AUX-%,$(MAKECMDGOALS))

ifdef variant_list
AUX_OS_VARIANT_LIST := $(patsubst AUX-%,%,$(variant_list))
else
AUX_OS_VARIANT_LIST := $(TARGET_AUX_OS_VARIANT_LIST)
endif

# exclude AUX targets from build
ifeq ($(AUX_OS_VARIANT_LIST),none)
AUX_OS_VARIANT_LIST :=
endif

# temporary workaround to support external toolchain
ifeq ($(NANOHUB_TOOLCHAIN),)
AUX_OS_VARIANT_LIST :=
endif

# setup toolchain paths for various CPU architectures
# this one will come from android prebuilts eventually
AUX_TOOLCHAIN_cortexm4 := $(NANOHUB_TOOLCHAIN)
ifeq ($(wildcard $(AUX_TOOLCHAIN_cortexm4)gcc),)
AUX_TOOLCHAIN_cortexm4:=
endif

# there is no MAKE var that defines path to HOST toolchain
# all the interesting paths are hardcoded in soong, and are not available from here
# There is no other way but to hardcode them again, as we may need host x86 toolcain for AUX
ifeq ($(HOST_OS),linux)
AUX_TOOLCHAIN_x86 := prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.15-4.8/bin/x86_64-linux-
endif

# setup AUX globals
AUX_SHLIB_SUFFIX := .so
AUX_GLOBAL_ARFLAGS := cqsD
AUX_STATIC_LIB_SUFFIX := .a

# Load ever-lasting "indexed" version of AUX variant environment; it is treated as READ-ONLY from this
# moment on.
#
# $(1) - variant
# no return value
define aux-variant-setup-paths
$(eval AUX_OUT_ROOT_$(1) := $(PRODUCT_OUT)/aux/$(1)) \
$(eval AUX_COMMON_OUT_ROOT_$(1) := $(AUX_OUT_ROOT_$(1))/common) \
$(eval AUX_OUT_$(1) := $(AUX_OUT_ROOT_$(1))/$(AUX_OS_$(1))-$(AUX_ARCH_$(1))-$(AUX_CPU_$(1))) \
$(eval AUX_OUT_INTERMEDIATES_$(1) := $(AUX_OUT_$(1))/obj) \
$(eval AUX_OUT_COMMON_INTERMEDIATES_$(1) := $(AUX_COMMON_OUT_ROOT_$(1))/obj) \
$(eval AUX_OUT_HEADERS_$(1) := $(AUX_OUT_INTERMEDIATES_$(1))/include) \
$(eval AUX_OUT_INTERMEDIATE_LIBRARIES_$(1) := $(AUX_OUT_INTERMEDIATES_$(1))/lib) \
$(eval AUX_OUT_NOTICE_FILES_$(1) := $(AUX_OUT_INTERMEDIATES_$(1))/NOTICE_FILES) \
$(eval AUX_OUT_FAKE_$(1) := $(AUX_OUT_$(1))/fake_packages) \
$(eval AUX_OUT_GEN_$(1) := $(AUX_OUT_$(1))/gen) \
$(eval AUX_OUT_COMMON_GEN_$(1) := $(AUX_COMMON_OUT_ROOT_$(1))/gen) \
$(eval AUX_OUT_EXECUTABLES_$(1) := $(AUX_OUT_$(1))/bin) \
$(eval AUX_OUT_UNSTRIPPED_$(1) := $(AUX_OUT_$(1))/symbols)
endef

# Copy "indexed" AUX environment for given VARIANT into
# volatile not-indexed set of variables for simplicity of access.
# Injection of index support throughout the build system is suboptimal
# hence volatile environment is constructed
# Unlike HOST*, TARGET* variables, AUX* variables are NOT read-only, but their
# indexed versions are.
#
# $(1) - variant
# no return value
define aux-variant-load-env
$(eval AUX_OS_VARIANT:=$(1)) \
$(eval AUX_OS:=$(AUX_OS_$(1))) \
$(eval AUX_ARCH:=$(AUX_ARCH_$(1))) \
$(eval AUX_SUBARCH:=$(AUX_SUBARCH_$(1))) \
$(eval AUX_CPU:=$(AUX_CPU_$(1))) \
$(eval AUX_OS_PATH:=$(AUX_OS_PATH_$(1))) \
$(eval AUX_OUT_ROOT := $(AUX_OUT_ROOT_$(1))) \
$(eval AUX_COMMON_OUT_ROOT := $(AUX_COMMON_OUT_ROOT_$(1))) \
$(eval AUX_OUT := $(AUX_OUT_$(1))) \
$(eval AUX_OUT_INTERMEDIATES := $(AUX_OUT_INTERMEDIATES_$(1))) \
$(eval AUX_OUT_COMMON_INTERMEDIATES := $(AUX_OUT_COMMON_INTERMEDIATES_$(1))) \
$(eval AUX_OUT_HEADERS := $(AUX_OUT_HEADERS_$(1))) \
$(eval AUX_OUT_INTERMEDIATE_LIBRARIES := $(AUX_OUT_INTERMEDIATE_LIBRARIES_$(1))) \
$(eval AUX_OUT_NOTICE_FILES := $(AUX_OUT_NOTICE_FILES_$(1))) \
$(eval AUX_OUT_FAKE := $(AUX_OUT_FAKE_$(1))) \
$(eval AUX_OUT_GEN := $(AUX_OUT_GEN_$(1))) \
$(eval AUX_OUT_COMMON_GEN := $(AUX_OUT_COMMON_GEN_$(1))) \
$(eval AUX_OUT_EXECUTABLES := $(AUX_OUT_EXECUTABLES_$(1))) \
$(eval AUX_OUT_UNSTRIPPED := $(AUX_OUT_UNSTRIPPED_$(1)))
endef

# given a variant:path pair, load the variant conviguration with aux-variant-setup-paths from file
# this is a build system extension mechainsm, since configuration typically resides in non-build
# project space
#
# $(1) - variant:path pair
# $(2) - file suffix
# no return value
define aux-variant-import-from-pair
$(eval _pair := $(subst :, ,$(1))) \
$(eval _name:=$(word 1,$(_pair))) \
$(eval _path:=$(word 2,$(_pair))) \
$(eval include $(_path)/$(_name)$(2)) \
$(eval AUX_OS_VARIANT_LIST_$(AUX_OS_$(1)):=) \
$(call aux-variant-setup-paths,$(_name)) \
$(eval AUX_ALL_VARIANTS += $(_name)) \
$(eval AUX_ALL_OSES := $(filter-out $(AUX_OS_$(_name)),$(AUX_ALL_OSES)) $(AUX_OS_$(_name))) \
$(eval AUX_ALL_CPUS := $(filter-out $(AUX_CPU_$(_name)),$(AUX_ALL_CPUS)) $(AUX_CPU_$(_name))) \
$(eval AUX_ALL_ARCHS := $(filter-out $(AUX_ARCH_$(_name)),$(AUX_ALL_ARCHS)) $(AUX_ARCH_$(_name))) \
$(eval AUX_ALL_SUBARCHS := $(filter-out $(AUX_SUBARCH_$(_name)),$(AUX_ALL_SUBARCHS)) $(AUX_SUBARCH_$(_name)))
endef

# Load system configuration referenced by AUX variant config;
# this is a build extension mechanism; typically system config
# resides in a non-build projects;
# system config may define new rules and globally visible BUILD*
# includes to support project-specific build steps and toolchains
# MAintains list of valiants that reference this os config in OS "indexed" var
# this facilitates multivariant build of the OS (or whataver it is the name of common component these variants share)
#
# $(1) - variant
# no return value
define aux-import-os-config
$(eval _aioc_os := $(AUX_OS_$(1))) \
$(eval AUX_OS_PATH_$(1) := $(patsubst $(_aioc_os):%,%,$(filter $(_aioc_os):%,$(AUX_ALL_OS_PATHS)))) \
$(eval _aioc_os_cfg := $(AUX_OS_PATH_$(1))/$(_aioc_os)$(os_sfx)) \
$(if $(wildcard $(_aioc_os_cfg)),,$(error AUX '$(_aioc_os)' OS config file [$(notdir $(_aioc_os_cfg))] required by AUX variant '$(1)' does not exist)) \
$(if $(filter $(_aioc_os),$(_os_list)),,$(eval include $(_aioc_os_cfg))) \
$(eval AUX_OS_VARIANT_LIST_$(_aioc_os) += $(1)) \
$(eval _os_list += $(_aioc_os))
endef

# make sure that AUX config variables are minimally sane;
# as a bare minimum they must contain the vars described by aux_env
# Generate error if requirement is not met.
#
#$(1) - variant
# no return value
define aux-variant-validate
$(eval _all:=) \
$(eval _req:=$(addsuffix _$(1),$(aux_env))) \
$(foreach var,$(_req),$(eval _all += $(var))) \
$(eval _missing := $(filter-out $(_all),$(_req))) \
$(if $(_missing),$(error AUX variant $(1) must define vars: $(_missing)))
endef

AUX_ALL_VARIANTS :=
AUX_ALL_OSES :=
AUX_ALL_CPUS :=
AUX_ALL_ARCHS :=
AUX_ALL_SUBARCHS :=

variant_sfx :=_aux_variant_config.mk
os_sfx :=_aux_os_config.mk

config_roots := $(wildcard device vendor)
all_configs :=
ifdef config_roots
all_configs := $(sort $(shell find $(config_roots) -maxdepth 4 -name '*$(variant_sfx)' -o -name '*$(os_sfx)'))
endif
all_os_configs := $(filter %$(os_sfx),$(all_configs))
all_variant_configs := $(filter %$(variant_sfx),$(all_configs))

AUX_ALL_OS_PATHS := $(foreach f,$(all_os_configs),$(patsubst %$(os_sfx),%,$(notdir $(f))):$(patsubst %/,%,$(dir $(f))))
AUX_ALL_OS_VARIANT_PATHS := $(foreach f,$(all_variant_configs),$(patsubst %$(variant_sfx),%,$(notdir $(f))):$(patsubst %/,%,$(dir $(f))))

my_variant_pairs := $(foreach v,$(AUX_OS_VARIANT_LIST),$(filter $(v):%,$(AUX_ALL_OS_VARIANT_PATHS)))
my_missing_variants := $(foreach v,$(AUX_OS_VARIANT_LIST),$(if $(filter $(v):%,$(AUX_ALL_OS_VARIANT_PATHS)),,$(v)))

ifneq ($(strip $(my_missing_variants)),)
$(error Don't know how to build variant(s): $(my_missing_variants))
endif

# mandatory variables
aux_env := AUX_OS AUX_ARCH AUX_SUBARCH AUX_CPU

$(foreach v,$(my_variant_pairs),$(if $(filter $(v),$(AUX_ALL_VARIANTS)),,$(call aux-variant-import-from-pair,$(v),$(variant_sfx))))

ifdef AUX_ALL_VARIANTS
_os_list :=
$(foreach v,$(AUX_ALL_VARIANTS),\
  $(call aux-import-os-config,$(v)) \
  $(call aux-variant-validate,$(v)) \
)
endif

INSTALLED_AUX_TARGETS :=

droidcore: auxiliary
