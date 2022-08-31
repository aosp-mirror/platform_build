# Print a list of the modules that could be built
# Currently runtime_dependencies only include the runtime libs information for cc binaries.

MODULE_INFO_JSON := $(PRODUCT_OUT)/module-info.json

$(MODULE_INFO_JSON):
	@echo Generating $@
	$(hide) echo -ne '{\n ' > $@
	$(hide) echo -ne $(foreach m, $(sort $(ALL_MODULES)), \
		' "$(m)": {' \
			'"class": [$(foreach w,$(sort $(ALL_MODULES.$(m).CLASS)),"$(w)", )], ' \
			'"path": [$(foreach w,$(sort $(ALL_MODULES.$(m).PATH)),"$(w)", )], ' \
			'"tags": [$(foreach w,$(sort $(ALL_MODULES.$(m).TAGS)),"$(w)", )], ' \
			'"installed": [$(foreach w,$(sort $(ALL_MODULES.$(m).INSTALLED)),"$(w)", )], ' \
			'"compatibility_suites": [$(foreach w,$(sort $(ALL_MODULES.$(m).COMPATIBILITY_SUITES)),"$(w)", )], ' \
			'"auto_test_config": [$(ALL_MODULES.$(m).auto_test_config)], ' \
			'"module_name": "$(ALL_MODULES.$(m).MODULE_NAME)", ' \
			'"test_config": [$(foreach w,$(strip $(ALL_MODULES.$(m).TEST_CONFIG) $(ALL_MODULES.$(m).EXTRA_TEST_CONFIGS)),"$(w)", )], ' \
			'"dependencies": [$(foreach w,$(sort $(ALL_DEPS.$(m).ALL_DEPS)),"$(w)", )], ' \
			'"shared_libs": [$(foreach w,$(sort $(ALL_MODULES.$(m).SHARED_LIBS)),"$(w)", )], ' \
			'"system_shared_libs": [$(foreach w,$(sort $(ALL_MODULES.$(m).SYSTEM_SHARED_LIBS)),"$(w)", )], ' \
			'"srcs": [$(foreach w,$(sort $(ALL_MODULES.$(m).SRCS)),"$(w)", )], ' \
			'"srcjars": [$(foreach w,$(sort $(ALL_MODULES.$(m).SRCJARS)),"$(w)", )], ' \
			'"classes_jar": [$(foreach w,$(sort $(ALL_MODULES.$(m).CLASSES_JAR)),"$(w)", )], ' \
			'"test_mainline_modules": [$(foreach w,$(sort $(ALL_MODULES.$(m).TEST_MAINLINE_MODULES)),"$(w)", )], ' \
			'"is_unit_test": "$(ALL_MODULES.$(m).IS_UNIT_TEST)", ' \
			'"test_options_tags": [$(foreach w,$(sort $(ALL_MODULES.$(m).TEST_OPTIONS_TAGS)),"$(w)", )], ' \
			'"data": [$(foreach w,$(sort $(ALL_MODULES.$(m).TEST_DATA)),"$(w)", )], ' \
			'"runtime_dependencies": [$(foreach w,$(sort $(ALL_MODULES.$(m).LOCAL_RUNTIME_LIBRARIES)),"$(w)", )], ' \
			'"static_dependencies": [$(foreach w,$(sort $(ALL_MODULES.$(m).LOCAL_STATIC_LIBRARIES)),"$(w)", )], ' \
			'"data_dependencies": [$(foreach w,$(sort $(ALL_MODULES.$(m).TEST_DATA_BINS)),"$(w)", )], ' \
			'"supported_variants": [$(foreach w,$(sort $(ALL_MODULES.$(m).SUPPORTED_VARIANTS)),"$(w)", )], ' \
			'"host_dependencies": [$(foreach w,$(sort $(ALL_MODULES.$(m).HOST_REQUIRED_FROM_TARGET)),"$(w)", )], ' \
			'},\n' \
	 ) | sed -e 's/, *\]/]/g' -e 's/, *\}/ }/g' -e '$$s/,$$//' >> $@
	$(hide) echo '}' >> $@


droidcore-unbundled: $(MODULE_INFO_JSON)

$(call dist-for-goals, general-tests, $(MODULE_INFO_JSON))
$(call dist-for-goals, droidcore-unbundled, $(MODULE_INFO_JSON))
