LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_SUFFIX := 
LOCAL_FORCE_STATIC_EXECUTABLE := true

include $(BUILD_SYSTEM)/binary.mk

$(LOCAL_BUILT_MODULE) : PRIVATE_ELF_FILE := $(intermediates)/$(PRIVATE_MODULE).elf
$(LOCAL_BUILT_MODULE) : PRIVATE_LIBS := `$(TARGET_CC) -mthumb-interwork -print-libgcc-file-name`

$(all_objects) : PRIVATE_TARGET_PROJECT_INCLUDES :=
$(all_objects) : PRIVATE_TARGET_C_INCLUDES :=
$(all_objects) : PRIVATE_TARGET_GLOBAL_CFLAGS :=
$(all_objects) : PRIVATE_TARGET_GLOBAL_CPPFLAGS :=

$(LOCAL_BUILT_MODULE): $(all_objects) $(all_libraries)
	@$(mkdir -p $(dir $@)
	@echo "target Linking: $(PRIVATE_MODULE)"
	$(hide) $(TARGET_LD) \
		$(addprefix --script ,$(PRIVATE_LINK_SCRIPT)) \
		$(PRIVATE_RAW_EXECUTABLE_LDFLAGS) \
		-o $(PRIVATE_ELF_FILE) \
		$(PRIVATE_ALL_OBJECTS) \
		--start-group $(PRIVATE_ALL_STATIC_LIBRARIES) --end-group \
		$(PRIVATE_LIBS)
	$(hide) $(TARGET_OBJCOPY) -O binary $(PRIVATE_ELF_FILE) $@
