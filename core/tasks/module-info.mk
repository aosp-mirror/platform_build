# Print a list of the modules that could be built
# Currently runtime_dependencies only include the runtime libs information for cc binaries.

MODULE_INFO_JSON := $(PRODUCT_OUT)/module-info.json
COMMA := ,
_NEWLINE := '\n'

$(MODULE_INFO_JSON):
	@echo Generating $@
	$(hide) echo -ne '{\n ' > $@
	$(hide) echo -ne $(KATI_foreach_sep m,$(COMMA)$(_NEWLINE), $(sort $(ALL_MODULES)),\
		'"$(m)": {' \
			'"class": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).CLASS)),"$(w)")],' \
			'"path": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).PATH)),"$(w)")],' \
			'"tags": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).TAGS)),"$(w)")],' \
			'"installed": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).INSTALLED)),"$(w)")],' \
			'"compatibility_suites": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).COMPATIBILITY_SUITES)),"$(w)")],' \
			'"auto_test_config": [$(ALL_MODULES.$(m).auto_test_config)],' \
			'"module_name": "$(ALL_MODULES.$(m).MODULE_NAME)"$(COMMA)' \
			'"test_config": [$(KATI_foreach_sep w,$(COMMA) ,$(strip $(ALL_MODULES.$(m).TEST_CONFIG) $(ALL_MODULES.$(m).EXTRA_TEST_CONFIGS)),"$(w)")],' \
			'"dependencies": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).ALL_DEPS)),"$(w)")],' \
			'"shared_libs": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).SHARED_LIBS)),"$(w)")],' \
			'"static_libs": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).STATIC_LIBS)),"$(w)")],' \
			'"system_shared_libs": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).SYSTEM_SHARED_LIBS)),"$(w)")],' \
			'"srcs": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).SRCS)),"$(w)")],' \
			'"srcjars": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).SRCJARS)),"$(w)")],' \
			'"classes_jar": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).CLASSES_JAR)),"$(w)")],' \
			'"test_mainline_modules": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).TEST_MAINLINE_MODULES)),"$(w)")],' \
			'"is_unit_test": "$(ALL_MODULES.$(m).IS_UNIT_TEST)"$(COMMA)' \
			'"test_options_tags": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).TEST_OPTIONS_TAGS)),"$(w)")],' \
			'"data": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).TEST_DATA)),"$(w)")],' \
			'"runtime_dependencies": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).LOCAL_RUNTIME_LIBRARIES)),"$(w)")],' \
			'"static_dependencies": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).LOCAL_STATIC_LIBRARIES)),"$(w)")],' \
			'"data_dependencies": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).TEST_DATA_BINS)),"$(w)")],' \
			'"supported_variants": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).SUPPORTED_VARIANTS)),"$(w)")],' \
			'"host_dependencies": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).HOST_REQUIRED_FROM_TARGET)),"$(w)")],' \
			'"target_dependencies": [$(KATI_foreach_sep w,$(COMMA) ,$(sort $(ALL_MODULES.$(m).TARGET_REQUIRED_FROM_HOST)),"$(w)")]' \
			'}')'\n}\n' >> $@


droidcore-unbundled: $(MODULE_INFO_JSON)

$(call dist-for-goals, general-tests, $(MODULE_INFO_JSON))
$(call dist-for-goals, droidcore-unbundled, $(MODULE_INFO_JSON))

# On every build, generate an all_modules.txt file to be used for autocompleting
# the m command. After timing this using $(shell date +"%s.%3N"), it only adds
# 0.01 seconds to the internal master build, and will only rerun on builds that
# rerun kati.
$(file >$(PRODUCT_OUT)/all_modules.txt,$(subst $(space),$(newline),$(ALL_MODULES)))
