check_emu_boot0 := $(DIST_DIR)/$(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT)-emulator-boot-test-result.txt
$(check_emu_boot0) : PRIVATE_PREFIX := $(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT)
$(check_emu_boot0) : PRIVATE_EMULATOR_BOOT_TEST_SH := device/generic/goldfish/tools/emulator_boot_test.sh
$(check_emu_boot0) : PRIVATE_BOOT_COMPLETE_STRING := "emulator: INFO: boot completed"
$(check_emu_boot0) : PRIVATE_BOOT_FAIL_STRING := "emulator: ERROR: fail to boot after"
$(check_emu_boot0) : PRIVATE_SUCCESS_FILE := $(DIST_DIR)/$(PRIVATE_PREFIX)-BOOT-SUCCESS.txt
$(check_emu_boot0) : PRIVATE_FAIL_FILE := $(DIST_DIR)/$(PRIVATE_PREFIX)-BOOT-FAIL.txt
$(check_emu_boot0) : $(INSTALLED_QEMU_SYSTEMIMAGE)  $(INSTALLED_QEMU_VENDORIMAGE) \
                 $(if $(BOARD_USERDATAIMAGE_PARTITION_SIZE),$(PRODUCT_OUT)/userdata.img) \
                 $(PRODUCT_OUT)/ramdisk.img device/generic/goldfish/tools/emulator_boot_test.sh
	@mkdir -p $(dir $(check_emu_boot0))
	$(hide) rm -f $(check_emu_boot0)
	$(hide) rm -f $(PRIVATE_SUCCESS_FILE)
	$(hide) rm -f $(PRIVATE_FAIL_FILE)
	(export ANDROID_PRODUCT_OUT=$$(cd $(PRODUCT_OUT);pwd);\
		export ANDROID_BUILD_TOP=$$(pwd);\
		$(PRIVATE_EMULATOR_BOOT_TEST_SH) > $(check_emu_boot0))
	(if grep -q $(PRIVATE_BOOT_COMPLETE_STRING) $(check_emu_boot0);\
	then echo boot_succeeded > $(PRIVATE_SUCCESS_FILE); fi)
	(if grep -q $(PRIVATE_BOOT_FAIL_STRING) $(check_emu_boot0);\
	then echo boot_failed > $(PRIVATE_FAIL_FILE); fi)
.PHONY: check_emu_boot
check_emu_boot: $(check_emu_boot0)
