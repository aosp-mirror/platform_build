# ---------------------------------------------------------------
# the setpath shell function in envsetup.sh uses this to figure out
# what to add to the path given the config we have chosen.
ifeq ($(CALLED_FROM_SETUP),true)

ANDROID_PREBUILTS := prebuilt/$(HOST_PREBUILT_TAG)
ANDROID_GCC_PREBUILTS := prebuilts/gcc/$(HOST_PREBUILT_TAG)
ANDROID_CLANG_PREBUILTS := prebuilts/clang/host/$(HOST_PREBUILT_TAG)

# Dump mulitple variables to "<var>=<value>" pairs, one per line.
# The output may be executed as bash script.
# Input variables:
#   DUMP_MANY_VARS: the list of variable names.
#   DUMP_VAR_PREFIX: an optional prefix of the variable name added to the output.
# The value is printed in parts because large variables like PRODUCT_PACKAGES
# can exceed the maximum linux command line size
.PHONY: dump-many-vars
dump-many-vars :
	@$(foreach v, $(DUMP_MANY_VARS),\
	  printf "%s='%s" '$(DUMP_VAR_PREFIX)$(v)' '$(firstword $($(v)))'; \
	  $(foreach part, $(wordlist 2, $(words $($(v))), $($(v))),\
	    printf " %s" '$(part)'$(newline))\
	  printf "'\n";)

endif # CALLED_FROM_SETUP

ifneq (,$(RBC_DUMP_CONFIG_FILE))
$(call dump-variables-rbc,$(RBC_DUMP_CONFIG_FILE))
endif
