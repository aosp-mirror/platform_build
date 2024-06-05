# PRODUCT_VALIDATION_CHECKS allows you to enforce that your product config variables follow some
# rules. To use it, add the paths to starlark configuration language (scl) files in
# PRODUCT_VALIDATION_CHECKS. A validate_product_variables function in those files will be called
# with a single "context" object.
#
# The context object currently 2 attributes:
#   - product_variables: This has all the product variables. All the variables are either of type
#                        string or list, more accurate typing (like bool) isn't known.
#   - board_variables: This only has a small subset of the board variables, because there isn't a
#                      known list of board variables. Feel free to expand the subset if you need a
#                      new variable.
#
# You can then inspect (but not modify) these variables and fail() if they don't meet your
# requirements. Example:
#
# In a product config file: PRODUCT_VALIDATION_CHECKS += //path/to/my_validations.scl
# In my_validations.scl:
# def validate_product_variables(ctx):
#     for dir in ctx.board_variables.BOARD_SEPOLICY_DIRS:
#         if not dir.startswith('system/sepolicy/'):
#             fail('Only sepolicies in system/seplicy are allowed, found: ' + dir)

ifdef PRODUCT_VALIDATION_CHECKS

$(if $(filter-out //%.scl,$(PRODUCT_VALIDATION_CHECKS)), \
	$(error All PRODUCT_VALIDATION_CHECKS files must start with // and end with .scl, exceptions: $(filter-out //%.scl,$(PRODUCT_VALIDATION_CHECKS))))

known_board_variables := \
  BOARD_VENDOR_SEPOLICY_DIRS BOARD_SEPOLICY_DIRS \
  SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS \
  SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS \
  PRODUCT_PUBLIC_SEPOLICY_DIRS \
  PRODUCT_PRIVATE_SEPOLICY_DIRS

known_board_list_variables := \
  BOARD_VENDOR_SEPOLICY_DIRS BOARD_SEPOLICY_DIRS \
  SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS \
  SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS \
  PRODUCT_PUBLIC_SEPOLICY_DIRS \
  PRODUCT_PRIVATE_SEPOLICY_DIRS

escape_starlark_string=$(subst ",\",$(subst \,\\,$(1)))
product_variable_starlark_value=$(if $(filter $(1),$(_product_list_vars) $(known_board_list_variables)),[$(foreach w,$($(1)),"$(call escape_starlark_string,$(w))", )],"$(call escape_starlark_string,$(1))")
filename_to_starlark=$(subst -,_,$(subst /,_,$(subst .,_,$(1))))
_c:=$(foreach f,$(PRODUCT_VALIDATION_CHECKS),$(newline)load("$(f)", validate_product_variables_$(call filename_to_starlark,$(f)) = "validate_product_variables"))
# TODO: we should freeze the context because it contains mutable lists, so that validation checks can't affect each other
_c+=$(newline)_ctx = struct(
_c+=$(newline)product_variables = struct(
_c+=$(foreach v,$(_product_var_list),$(newline)  $(v) = $(call product_variable_starlark_value,$(v)),)
_c+=$(newline)),
_c+=$(newline)board_variables = struct(
_c+=$(foreach v,$(known_board_variables),$(newline)  $(v) = $(call product_variable_starlark_value,$(v)),)
_c+=$(newline))
_c+=$(newline))
_c+=$(foreach f,$(PRODUCT_VALIDATION_CHECKS),$(newline)validate_product_variables_$(call filename_to_starlark,$(f))(_ctx))
_c+=$(newline)variables_to_export_to_make = {}
$(KATI_file_no_rerun >$(OUT_DIR)/product_validation_checks_entrypoint.scl,$(_c))
filename_to_starlark:=
escape_starlark_string:=
product_variable_starlark_value:=
known_board_variables :=
known_board_list_variables :=

# Exclude the entrypoint file as a dependency (by passing it as the 2nd argument) so that we don't
# rerun kati every build. Even though we're using KATI_file_no_rerun, product config is run every
# build, so the file will still be rewritten.
#
# We also need to pass --allow_external_entrypoint to rbcrun in case the OUT_DIR is set to something
# outside of the source tree.
$(call run-starlark,$(OUT_DIR)/product_validation_checks_entrypoint.scl,$(OUT_DIR)/product_validation_checks_entrypoint.scl,--allow_external_entrypoint)

endif # ifdef PRODUCT_VALIDATION_CHECKS
