# This file contains logic to enforce artifact path requirements
# defined in product makefiles.

# Fakes don't get installed, and NDK stubs aren't installed to device.
static_allowed_patterns := $(TARGET_OUT_FAKE)/% $(SOONG_OUT_DIR)/ndk/%
# RROs become REQUIRED by the source module, but are always placed on the vendor partition.
static_allowed_patterns += %__auto_generated_rro_product.apk
static_allowed_patterns += %__auto_generated_rro_vendor.apk
# Auto-included targets are not considered
static_allowed_patterns += $(call product-installed-files,)
# $(PRODUCT_OUT)/apex is where shared libraries in APEXes get installed.
# The path can be considered as a fake path, as the shared libraries
# are installed there just to have symbols files for them under
# $(PRODUCT_OUT)/symbols/apex for debugging purpose. The /apex directory
# is never compiled into a filesystem image.
static_allowed_patterns += $(PRODUCT_OUT)/apex/%
ifeq (true,$(BOARD_USES_SYSTEM_OTHER_ODEX))
  # Allow system_other odex space optimization.
  static_allowed_patterns += \
    $(TARGET_OUT_SYSTEM_OTHER)/%.odex \
    $(TARGET_OUT_SYSTEM_OTHER)/%.vdex \
    $(TARGET_OUT_SYSTEM_OTHER)/%.art
endif

all_offending_files :=
$(foreach makefile,$(ARTIFACT_PATH_REQUIREMENT_PRODUCTS),\
  $(eval requirements := $(PRODUCTS.$(makefile).ARTIFACT_PATH_REQUIREMENTS)) \
  $(eval ### Verify that the product only produces files inside its path requirements.) \
  $(eval allowed := $(PRODUCTS.$(makefile).ARTIFACT_PATH_ALLOWED_LIST)) \
  $(eval path_patterns := $(call resolve-product-relative-paths,$(requirements),%)) \
  $(eval allowed_patterns := $(call resolve-product-relative-paths,$(allowed))) \
  $(eval files := $(call product-installed-files, $(makefile))) \
  $(eval offending_files := $(filter-out $(path_patterns) $(allowed_patterns) $(static_allowed_patterns),$(files))) \
  $(call maybe-print-list-and-error,$(offending_files),\
    $(makefile) produces files outside its artifact path requirement. \
    Allowed paths are $(subst $(space),$(comma)$(space),$(addsuffix *,$(requirements)))) \
  $(eval unused_allowed := $(filter-out $(files),$(allowed_patterns))) \
  $(call maybe-print-list-and-error,$(unused_allowed),$(makefile) includes redundant allowed entries in its artifact path requirement.) \
  $(eval ### Optionally verify that nothing else produces files inside this artifact path requirement.) \
  $(eval extra_files := $(filter-out $(files) $(HOST_OUT)/%,$(product_target_FILES))) \
  $(eval files_in_requirement := $(filter $(path_patterns),$(extra_files))) \
  $(eval all_offending_files += $(files_in_requirement)) \
  $(eval allowed := $(PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST)) \
  $(eval allowed_patterns := $(call resolve-product-relative-paths,$(allowed))) \
  $(eval offending_files := $(filter-out $(allowed_patterns),$(files_in_requirement))) \
  $(eval enforcement := $(PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS)) \
  $(if $(enforcement),\
    $(call maybe-print-list-and-error,$(offending_files),\
      $(INTERNAL_PRODUCT) produces files inside $(makefile)s artifact path requirement. \
      $(PRODUCT_ARTIFACT_PATH_REQUIREMENT_HINT)) \
    $(eval unused_allowed := $(if $(filter true strict,$(enforcement)),\
      $(foreach p,$(allowed_patterns),$(if $(filter $(p),$(extra_files)),,$(p))))) \
    $(call maybe-print-list-and-error,$(unused_allowed),$(INTERNAL_PRODUCT) includes redundant artifact path requirement allowed list entries.) \
  ) \
)
$(PRODUCT_OUT)/offending_artifacts.txt:
	rm -f $@
	$(foreach f,$(sort $(all_offending_files)),echo $(f) >> $@;)
