####################################
# dexpreopt support for Dalvik
#
####################################

DEXOPT := $(HOST_OUT_EXECUTABLES)/dexopt$(HOST_EXECUTABLE_SUFFIX)
DEXPREOPT := dalvik/tools/dex-preopt

DEXPREOPT_DEXOPT := $(patsubst $(DEXPREOPT_BUILD_DIR)/%,%,$(DEXOPT))

DEXPREOPT_BOOT_ODEXS := $(foreach b,$(DEXPREOPT_BOOT_JARS_MODULES),\
    $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/$(b).odex)

# If the target is a uniprocessor, then explicitly tell the preoptimizer
# that fact. (By default, it always optimizes for an SMP target.)
ifeq ($(TARGET_CPU_SMP),true)
    DEXPREOPT_UNIPROCESSOR :=
else
    DEXPREOPT_UNIPROCESSOR := --uniprocessor
endif

# By default, do not run rerun dexopt if the tool changes.
# Comment out the | to force dex2oat to rerun on after all changes.
DEXOPT_DEPENDENCY := |
DEXOPT_DEPENDENCY += $(DEXPREOPT) $(DEXOPT)

# $(1): the input .jar or .apk file
# $(2): the output .odex file
define dexopt-one-file
$(hide) rm -f $(2)
$(hide) mkdir -p $(dir $(2))
$(hide) $(DEXPREOPT) \
        --dexopt=$(DEXPREOPT_DEXOPT) \
        --build-dir=$(DEXPREOPT_BUILD_DIR) \
        --product-dir=$(DEXPREOPT_PRODUCT_DIR) \
        --boot-dir=$(DEXPREOPT_BOOT_JAR_DIR) \
        --boot-jars=$(DEXPREOPT_BOOT_JARS) \
        $(DEXPREOPT_UNIPROCESSOR) \
        $(patsubst $(DEXPREOPT_BUILD_DIR)/%,%,$(1)) \
        $(patsubst $(DEXPREOPT_BUILD_DIR)/%,%,$(2))
endef

# Special rules for building odex files for boot jars that override java_library.mk rules

# $(1): boot jar module name
define _dexpreopt-boot-odex
_dbj_jar := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/$(1).jar
_dbj_odex := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/$(1).odex
_dbj_src_jar := $(call intermediates-dir-for,JAVA_LIBRARIES,$(1),,COMMON)/javalib.jar
$$(_dbj_odex): PRIVATE_DBJ_JAR := $$(_dbj_jar)
$$(_dbj_odex) : $$(_dbj_src_jar) | $(ACP) $(DEXPREOPT) $(DEXOPT)
	@echo "Dexpreopt Boot Jar: $$@"
	$(hide) mkdir -p $$(dir $$(PRIVATE_DBJ_JAR)) && $(ACP) -fp $$< $$(PRIVATE_DBJ_JAR)
	$$(call dexopt-one-file,$$(PRIVATE_DBJ_JAR),$$@)

_dbj_jar :=
_dbj_odex :=
_dbj_src_jar :=
endef

$(foreach b,$(DEXPREOPT_BOOT_JARS_MODULES),$(eval $(call _dexpreopt-boot-odex,$(b))))

# $(1): the rest list of boot jars
define _build-dexpreopt-boot-jar-dependency-pair
$(if $(filter 1,$(words $(1)))$(filter 0,$(words $(1))),,\
	$(eval _bdbjdp_target := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/$(word 2,$(1)).odex) \
	$(eval _bdbjdp_dep := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/$(word 1,$(1)).odex) \
	$(eval $(call add-dependency,$(_bdbjdp_target),$(_bdbjdp_dep))) \
	$(eval $(call _build-dexpreopt-boot-jar-dependency-pair,$(wordlist 2,999,$(1)))))
endef

define _build-dexpreopt-boot-jar-dependency
$(call _build-dexpreopt-boot-jar-dependency-pair,$(DEXPREOPT_BOOT_JARS_MODULES))
endef

$(eval $(call _build-dexpreopt-boot-jar-dependency))
