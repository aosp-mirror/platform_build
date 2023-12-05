# Print a list of the modules that could be built
# Currently runtime_dependencies only include the runtime libs information for cc binaries.

MODULE_INFO_JSON := $(PRODUCT_OUT)/module-info.json
COMMA := ,
_NEWLINE := '\n'

define write-optional-json-list
$(if $(strip $(2)),'$(COMMA)$(strip $(1)): [$(KATI_foreach_sep w,$(COMMA) ,$(2),"$(w)")]')
endef

define write-optional-json-bool
$(if $(strip $(2)),'$(COMMA)$(strip $(1)): "$(strip $(2))"')
endef

$(MODULE_INFO_JSON):
	@echo Generating $@
	$(hide) echo -ne '{\n ' > $@
	$(hide) echo -ne $(KATI_foreach_sep m,$(COMMA)$(_NEWLINE), $(sort $(ALL_MODULES)),\
		'"$(m)": {' \
			'"module_name": "$(ALL_MODULES.$(m).MODULE_NAME)"' \
			$(call write-optional-json-list, "class", $(sort $(ALL_MODULES.$(m).CLASS))) \
			$(call write-optional-json-list, "path", $(sort $(ALL_MODULES.$(m).PATH))) \
			$(call write-optional-json-list, "tags", $(sort $(ALL_MODULES.$(m).TAGS))) \
			$(call write-optional-json-list, "installed", $(sort $(ALL_MODULES.$(m).INSTALLED))) \
			$(call write-optional-json-list, "compatibility_suites", $(sort $(ALL_MODULES.$(m).COMPATIBILITY_SUITES))) \
			$(call write-optional-json-list, "auto_test_config", $(sort $(ALL_MODULES.$(m).auto_test_config))) \
			$(call write-optional-json-list, "test_config", $(strip $(ALL_MODULES.$(m).TEST_CONFIG) $(ALL_MODULES.$(m).EXTRA_TEST_CONFIGS))) \
			$(call write-optional-json-list, "dependencies", $(sort $(ALL_MODULES.$(m).ALL_DEPS))) \
			$(call write-optional-json-list, "shared_libs", $(sort $(ALL_MODULES.$(m).SHARED_LIBS))) \
			$(call write-optional-json-list, "static_libs", $(sort $(ALL_MODULES.$(m).STATIC_LIBS))) \
			$(call write-optional-json-list, "system_shared_libs", $(sort $(ALL_MODULES.$(m).SYSTEM_SHARED_LIBS))) \
			$(call write-optional-json-list, "srcs", $(sort $(ALL_MODULES.$(m).SRCS))) \
			$(call write-optional-json-list, "srcjars", $(sort $(ALL_MODULES.$(m).SRCJARS))) \
			$(call write-optional-json-list, "classes_jar", $(sort $(ALL_MODULES.$(m).CLASSES_JAR))) \
			$(call write-optional-json-list, "test_mainline_modules", $(sort $(ALL_MODULES.$(m).TEST_MAINLINE_MODULES))) \
			$(call write-optional-json-bool, $(ALL_MODULES.$(m).IS_UNIT_TEST)) \
			$(call write-optional-json-list, "test_options_tags", $(sort $(ALL_MODULES.$(m).TEST_OPTIONS_TAGS))) \
			$(call write-optional-json-list, "data", $(sort $(ALL_MODULES.$(m).TEST_DATA))) \
			$(call write-optional-json-list, "runtime_dependencies", $(sort $(ALL_MODULES.$(m).LOCAL_RUNTIME_LIBRARIES))) \
			$(call write-optional-json-list, "static_dependencies", $(sort $(ALL_MODULES.$(m).LOCAL_STATIC_LIBRARIES))) \
			$(call write-optional-json-list, "data_dependencies", $(sort $(ALL_MODULES.$(m).TEST_DATA_BINS))) \
			$(call write-optional-json-list, "supported_variants", $(sort $(ALL_MODULES.$(m).SUPPORTED_VARIANTS))) \
			$(call write-optional-json-list, "host_dependencies", $(sort $(ALL_MODULES.$(m).HOST_REQUIRED_FROM_TARGET))) \
			$(call write-optional-json-list, "target_dependencies", $(sort $(ALL_MODULES.$(m).TARGET_REQUIRED_FROM_HOST))) \
		'}')'\n}\n' >> $@


droidcore-unbundled: $(MODULE_INFO_JSON)

$(call dist-for-goals, general-tests, $(MODULE_INFO_JSON))
$(call dist-for-goals, droidcore-unbundled, $(MODULE_INFO_JSON))

# On every build, generate an all_modules.txt file to be used for autocompleting
# the m command. After timing this using $(shell date +"%s.%3N"), it only adds
# 0.01 seconds to the internal master build, and will only rerun on builds that
# rerun kati.
$(file >$(PRODUCT_OUT)/all_modules.txt,$(subst $(space),$(newline),$(ALL_MODULES)))
