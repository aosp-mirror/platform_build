# Check the correctness of the prebuilt ELF files
#
# This check ensures that DT_SONAME matches with the filename, DT_NEEDED
# matches the shared libraries specified in LOCAL_SHARED_LIBRARIES, and all
# undefined symbols in the prebuilt binary can be found in one of the shared
# libraries specified in LOCAL_SHARED_LIBRARIES.
#
# Inputs:
# - LOCAL_ALLOW_UNDEFINED_SYMBOLS
# - LOCAL_BUILT_MODULE
# - LOCAL_IS_HOST_MODULE
# - LOCAL_MODULE_CLASS
# - intermediates
# - my_installed_module_stem
# - my_prebuilt_src_file
# - my_check_elf_file_shared_lib_files

ifndef LOCAL_IS_HOST_MODULE
ifneq ($(filter $(LOCAL_MODULE_CLASS),SHARED_LIBRARIES EXECUTABLES NATIVE_TESTS),)
check_elf_files_stamp := $(intermediates)/check_elf_files.timestamp
$(check_elf_files_stamp): PRIVATE_SONAME := $(if $(filter $(LOCAL_MODULE_CLASS),SHARED_LIBRARIES),$(my_installed_module_stem))
$(check_elf_files_stamp): PRIVATE_ALLOW_UNDEFINED_SYMBOLS := $(LOCAL_ALLOW_UNDEFINED_SYMBOLS)
# PRIVATE_SHARED_LIBRARY_FILES are file paths to built shared libraries.
# In addition to $(my_check_elf_file_shared_lib_files), some file paths are
# added by `resolve-shared-libs-for-elf-file-check` from `core/main.mk`.
$(check_elf_files_stamp): PRIVATE_SHARED_LIBRARY_FILES := $(my_check_elf_file_shared_lib_files)
$(check_elf_files_stamp): $(my_prebuilt_src_file) $(my_check_elf_file_shared_lib_files) $(CHECK_ELF_FILE) $(LLVM_READOBJ)
	@echo Check prebuilt ELF binary: $<
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -f $@
	$(hide) $(CHECK_ELF_FILE) \
	    --skip-bad-elf-magic \
	    --skip-unknown-elf-machine \
	    $(if $(PRIVATE_SONAME),--soname $(PRIVATE_SONAME)) \
	    $(foreach l,$(PRIVATE_SHARED_LIBRARY_FILES),--shared-lib $(l)) \
	    $(if $(PRIVATE_ALLOW_UNDEFINED_SYMBOLS),--allow-undefined-symbols) \
	    --llvm-readobj=$(LLVM_READOBJ) \
	    $<
	$(hide) touch $@

ifneq ($(PRODUCT_CHECK_ELF_FILES)$(CHECK_ELF_FILES),)
ifneq ($(strip $(LOCAL_CHECK_ELF_FILES)),false)
$(LOCAL_BUILT_MODULE): $(check_elf_files_stamp)
check-elf-files: $(check_elf_files_stamp)
endif  # LOCAL_CHECK_ELF_FILES
endif  # PRODUCT_CHECK_ELF_FILES or CHECK_ELF_FILES

endif  # SHARED_LIBRARIES, EXECUTABLES, NATIVE_TESTS
endif  # !LOCAL_IS_HOST_MODULE
