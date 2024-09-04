# Read and dump the product configuration.

# Called from the product-config tool, not from the main build system.

#
# Ensure we are being called correctly
#
ifndef KATI
    $(warning Kati must be used to call dumpconfig.mk, not make.)
    $(error stopping)
endif

ifdef DEFAULT_GOAL
    $(warning Calling dumpconfig.mk from inside the make build system is not)
    $(warning supported. It is only meant to be called via kati by product-confing.)
    $(error stopping)
endif

ifndef TARGET_PRODUCT
    $(warning dumpconfig.mk requires TARGET_PRODUCT to be set)
    $(error stopping)
endif

ifndef TARGET_BUILD_VARIANT
    $(warning dumpconfig.mk requires TARGET_BUILD_VARIANT to be set)
    $(error stopping)
endif

ifneq (build/make/core/config.mk,$(wildcard build/make/core/config.mk))
    $(warning dumpconfig must be called from the root of the source tree)
    $(error stopping)
endif

ifeq (,$(DUMPCONFIG_FILE))
    $(warning dumpconfig requires DUMPCONFIG_FILE to be set)
    $(error stopping)
endif

# Skip the second inclusion of all of the product config files, because
# we will do these checks in the product_config tool.
SKIP_ARTIFACT_PATH_REQUIREMENT_PRODUCTS_CHECK := true

# Before we do anything else output the format version.
$(file > $(DUMPCONFIG_FILE),dumpconfig_version,1)
$(file >> $(DUMPCONFIG_FILE),dumpconfig_file,$(DUMPCONFIG_FILE))

# Default goal for dumpconfig
dumpconfig:
	$(file >> $(DUMPCONFIG_FILE),***DONE***)
	@echo ***DONE***

# TODO(Remove): These need to be set externally
OUT_DIR := out
TMPDIR = /tmp/build-temp
BUILD_DATETIME_FILE := $(OUT_DIR)/build_date.txt

# Escape quotation marks for CSV, and wraps in quotation marks.
define escape-for-csv
"$(subst ","",$(subst $(newline), ,$1))"
endef

# Args:
#   $(1): include stack
define dump-import-start
$(eval $(file >> $(DUMPCONFIG_FILE),import,$(strip $(1))))
endef

# Args:
#   $(1): include stack
define dump-import-done
$(eval $(file >> $(DUMPCONFIG_FILE),imported,$(strip $(1)),$(filter-out $(1),$(MAKEFILE_LIST))))
endef

# Args:
#   $(1): Current file
#   $(2): Inherited file
define dump-inherit
$(eval $(file >> $(DUMPCONFIG_FILE),inherit,$(strip $(1)),$(strip $(2))))
endef

# Args:
#   $(1): Config phase (PRODUCT, EXPAND, or DEVICE)
#   $(2): Root nodes to import
#   $(3): All variable names
#   $(4): Single-value variables
#   $(5): Makefile being processed
define dump-phase-start
$(eval $(file >> $(DUMPCONFIG_FILE),phase,$(strip $(1)),$(strip $(2)))) \
$(foreach var,$(3), \
    $(eval $(file >> $(DUMPCONFIG_FILE),var,$(if $(filter $(4),$(var)),single,list),$(var))) \
) \
$(call dump-config-vals,$(strip $(5)),initial)
endef

# Args:
#   $(1): Makefile being processed
define dump-phase-end
$(call dump-config-vals,$(strip $(1)),final)
endef

define dump-debug
$(eval $(file >> $(DUMPCONFIG_FILE),debug,$(1)))
endef

# Skip these when dumping. They're not used and they cause a lot of noise in the dump.
DUMPCONFIG_SKIP_VARS := \
	.VARIABLES \
	.KATI_SYMBOLS \
	1 \
	2 \
	3 \
	4 \
	5 \
	6 \
	7 \
	8 \
	9 \
	LOCAL_PATH \
	MAKEFILE_LIST \
	current_mk \
	_eiv_ev \
	_eiv_i \
	_eiv_sv \
	_eiv_tv \
	inherit_var \
	np \
	_node_import_context \
	_included \
	_include_stack \
	_in \
	_nic.%

# Args:
#   $(1): Makefile that was included
#   $(2): block (before,import,after,initial,final)
define dump-config-vals
$(foreach var,$(filter-out $(DUMPCONFIG_SKIP_VARS),$(.KATI_SYMBOLS)),\
    $(eval $(file >> $(DUMPCONFIG_FILE),val,$(call escape-for-csv,$(1)),$(2),$(call escape-for-csv,$(var)),$(call escape-for-csv,$($(var))),$(call escape-for-csv,$(KATI_variable_location $(var))))) \
)
endef

include build/make/core/config.mk

