###########################################################
## Standard rules for building binary object files from
## asm/c/cpp/yacc/lex source files.
##
## The list of object files is exported in $(all_objects).
###########################################################

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

###########################################################
## Define PRIVATE_ variables used by multiple module types
###########################################################
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_NO_DEFAULT_COMPILER_FLAGS := \
	$(strip $(LOCAL_NO_DEFAULT_COMPILER_FLAGS))

ifeq ($(strip $(LOCAL_CC)),)
  LOCAL_CC := $($(my_prefix)CC)
endif
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CC := $(LOCAL_CC)

ifeq ($(strip $(LOCAL_CXX)),)
  LOCAL_CXX := $($(my_prefix)CXX)
endif
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CXX := $(LOCAL_CXX)

# TODO: support a mix of standard extensions so that this isn't necessary
LOCAL_CPP_EXTENSION := $(strip $(LOCAL_CPP_EXTENSION))
ifeq ($(LOCAL_CPP_EXTENSION),)
  LOCAL_CPP_EXTENSION := .cpp
endif
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CPP_EXTENSION := $(LOCAL_CPP_EXTENSION)

# Certain modules like libdl have to have symbols resolved at runtime and blow
# up if --no-undefined is passed to the linker.
ifeq ($(strip $(LOCAL_ALLOW_UNDEFINED_SYMBOLS)),)
  LOCAL_LDFLAGS := $(LOCAL_LDFLAGS) $($(my_prefix)NO_UNDEFINED_LDFLAGS)
endif

###########################################################
## Define arm-vs-thumb-mode flags.
###########################################################
LOCAL_ARM_MODE := $(strip $(LOCAL_ARM_MODE))
arm_objects_mode := $(if $(LOCAL_ARM_MODE),$(LOCAL_ARM_MODE),arm)
normal_objects_mode := $(if $(LOCAL_ARM_MODE),$(LOCAL_ARM_MODE),thumb)

# Read the values from something like TARGET_arm_release_CFLAGS or
# TARGET_thumb_debug_CFLAGS.  HOST_(arm|thumb)_(release|debug)_CFLAGS
# values aren't actually used (although they are usually empty).
arm_objects_cflags := $($(my_prefix)$(arm_objects_mode)_$($(my_prefix)BUILD_TYPE)_CFLAGS)
normal_objects_cflags := $($(my_prefix)$(normal_objects_mode)_$($(my_prefix)BUILD_TYPE)_CFLAGS)

###########################################################
## Define per-module debugging flags.  Users can turn on
## debugging for a particular module by setting DEBUG_MODULE_ModuleName
## to a non-empty value in their environment or buildspec.mk,
## and setting HOST_/TARGET_CUSTOM_DEBUG_CFLAGS to the
## debug flags that they want to use.
###########################################################
ifdef DEBUG_MODULE_$(strip $(LOCAL_MODULE))
  debug_cflags := $($(my_prefix)CUSTOM_DEBUG_CFLAGS)
else
  debug_cflags :=
endif

###########################################################
## Stuff source generated from one-off tools
###########################################################
$(LOCAL_GENERATED_SOURCES): PRIVATE_MODULE := $(LOCAL_MODULE)

ALL_GENERATED_SOURCES += $(LOCAL_GENERATED_SOURCES)


###########################################################
## YACC: Compile .y files to .cpp and the to .o.
###########################################################

yacc_sources := $(filter %.y,$(LOCAL_SRC_FILES))
yacc_cpps := $(addprefix \
	$(intermediates)/,$(yacc_sources:.y=$(LOCAL_CPP_EXTENSION)))
yacc_headers := $(yacc_cpps:$(LOCAL_CPP_EXTENSION)=.h)
yacc_objects := $(yacc_cpps:$(LOCAL_CPP_EXTENSION)=.o)

ifneq ($(strip $(yacc_cpps)),)
$(yacc_cpps): $(intermediates)/%$(LOCAL_CPP_EXTENSION): \
		$(TOPDIR)$(LOCAL_PATH)/%.y \
		$(lex_cpps) $(PRIVATE_ADDITIONAL_DEPENDENCIES)
	$(call transform-y-to-cpp,$(PRIVATE_CPP_EXTENSION))
$(yacc_headers): $(intermediates)/%.h: $(intermediates)/%$(LOCAL_CPP_EXTENSION)

$(yacc_objects): $(intermediates)/%.o: $(intermediates)/%$(LOCAL_CPP_EXTENSION)
	$(transform-$(PRIVATE_HOST)cpp-to-o)
endif

###########################################################
## LEX: Compile .l files to .cpp and then to .o.
###########################################################

lex_sources := $(filter %.l,$(LOCAL_SRC_FILES))
lex_cpps := $(addprefix \
	$(intermediates)/,$(lex_sources:.l=$(LOCAL_CPP_EXTENSION)))
lex_objects := $(lex_cpps:$(LOCAL_CPP_EXTENSION)=.o)

ifneq ($(strip $(lex_cpps)),)
$(lex_cpps): $(intermediates)/%$(LOCAL_CPP_EXTENSION): \
		$(TOPDIR)$(LOCAL_PATH)/%.l
	$(transform-l-to-cpp)

$(lex_objects): $(intermediates)/%.o: \
		$(intermediates)/%$(LOCAL_CPP_EXTENSION) \
		$(PRIVATE_ADDITIONAL_DEPENDENCIES) \
		$(yacc_headers)
	$(transform-$(PRIVATE_HOST)cpp-to-o)
endif

###########################################################
## C++: Compile .cpp files to .o.
###########################################################

# we also do this on host modules and sim builds, even though
# it's not really arm, because there are files that are shared.
cpp_arm_sources    := $(patsubst %$(LOCAL_CPP_EXTENSION).arm,%$(LOCAL_CPP_EXTENSION),$(filter %$(LOCAL_CPP_EXTENSION).arm,$(LOCAL_SRC_FILES)))
cpp_arm_objects    := $(addprefix $(intermediates)/,$(cpp_arm_sources:$(LOCAL_CPP_EXTENSION)=.o))

cpp_normal_sources := $(filter %$(LOCAL_CPP_EXTENSION),$(LOCAL_SRC_FILES))
cpp_normal_objects := $(addprefix $(intermediates)/,$(cpp_normal_sources:$(LOCAL_CPP_EXTENSION)=.o))

$(cpp_arm_objects):    PRIVATE_ARM_MODE := $(arm_objects_mode)
$(cpp_arm_objects):    PRIVATE_ARM_CFLAGS := $(arm_objects_cflags)
$(cpp_normal_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(cpp_normal_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)

cpp_objects        := $(cpp_arm_objects) $(cpp_normal_objects)

ifneq ($(strip $(cpp_objects)),)
$(cpp_objects): $(intermediates)/%.o: \
		$(TOPDIR)$(LOCAL_PATH)/%$(LOCAL_CPP_EXTENSION) \
		$(yacc_cpps) $(PRIVATE_ADDITIONAL_DEPENDENCIES)
	$(transform-$(PRIVATE_HOST)cpp-to-o)
-include $(cpp_objects:%.o=%.P)
endif

###########################################################
## C++: Compile generated .cpp files to .o.
###########################################################

gen_cpp_sources := $(filter %$(LOCAL_CPP_EXTENSION),$(LOCAL_GENERATED_SOURCES))
gen_cpp_objects := $(gen_cpp_sources:%$(LOCAL_CPP_EXTENSION)=%.o)

ifneq ($(strip $(gen_cpp_objects)),)
# Compile all generated files as thumb.
# TODO: support compiling certain generated files as arm.
$(gen_cpp_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(gen_cpp_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)
$(gen_cpp_objects): $(intermediates)/%.o: $(intermediates)/%$(LOCAL_CPP_EXTENSION) $(yacc_cpps) $(PRIVATE_ADDITIONAL_DEPENDENCIES)
	$(transform-$(PRIVATE_HOST)cpp-to-o)
-include $(gen_cpp_objects:%.o=%.P)
endif

###########################################################
## S: Compile generated .S and .s files to .o.
###########################################################

gen_S_sources := $(filter %.S,$(LOCAL_GENERATED_SOURCES))
gen_S_objects := $(gen_S_sources:%.S=%.o)

ifneq ($(strip $(gen_S_sources)),)
$(gen_S_objects): $(intermediates)/%.o: $(intermediates)/%.S $(PRIVATE_ADDITIONAL_DEPENDENCIES)
	$(transform-$(PRIVATE_HOST)s-to-o)
-include $(gen_S_objects:%.o=%.P)
endif

gen_s_sources := $(filter %.s,$(LOCAL_GENERATED_SOURCES))
gen_s_objects := $(gen_s_sources:%.s=%.o)

ifneq ($(strip $(gen_s_objects)),)
$(gen_s_objects): $(intermediates)/%.o: $(intermediates)/%.s $(PRIVATE_ADDITIONAL_DEPENDENCIES)
	$(transform-$(PRIVATE_HOST)s-to-o-no-deps)
-include $(gen_s_objects:%.o=%.P)
endif

gen_asm_objects := $(gen_S_objects) $(gen_s_objects)

###########################################################
## C: Compile .c files to .o.
###########################################################

c_arm_sources    := $(patsubst %.c.arm,%.c,$(filter %.c.arm,$(LOCAL_SRC_FILES)))
c_arm_objects    := $(addprefix $(intermediates)/,$(c_arm_sources:.c=.o))

c_normal_sources := $(filter %.c,$(LOCAL_SRC_FILES))
c_normal_objects := $(addprefix $(intermediates)/,$(c_normal_sources:.c=.o))

$(c_arm_objects):    PRIVATE_ARM_MODE := $(arm_objects_mode)
$(c_arm_objects):    PRIVATE_ARM_CFLAGS := $(arm_objects_cflags)
$(c_normal_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(c_normal_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)

c_objects        := $(c_arm_objects) $(c_normal_objects)

ifneq ($(strip $(c_objects)),)
$(c_objects): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.c $(yacc_cpps) $(PRIVATE_ADDITIONAL_DEPENDENCIES)
	$(transform-$(PRIVATE_HOST)c-to-o)
-include $(c_objects:%.o=%.P)
endif

###########################################################
## AS: Compile .S files to .o.
###########################################################

asm_sources_S := $(filter %.S,$(LOCAL_SRC_FILES))
asm_objects_S := $(addprefix $(intermediates)/,$(asm_sources_S:.S=.o))

ifneq ($(strip $(asm_objects_S)),)
$(asm_objects_S): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.S $(PRIVATE_ADDITIONAL_DEPENDENCIES)
	$(transform-$(PRIVATE_HOST)s-to-o)
-include $(asm_objects_S:%.o=%.P)
endif

asm_sources_s := $(filter %.s,$(LOCAL_SRC_FILES))
asm_objects_s := $(addprefix $(intermediates)/,$(asm_sources_s:.s=.o))

ifneq ($(strip $(asm_objects_s)),)
$(asm_objects_s): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.s $(PRIVATE_ADDITIONAL_DEPENDENCIES)
	$(transform-$(PRIVATE_HOST)s-to-o-no-deps)
-include $(asm_objects_s:%.o=%.P)
endif

asm_objects := $(asm_objects_S) $(asm_objects_s)


###########################################################
## Common object handling.
###########################################################

# some rules depend on asm_objects being first.  If your code depends on
# being first, it's reasonable to require it to be assembly
all_objects := \
	$(asm_objects) \
	$(cpp_objects) \
	$(gen_cpp_objects) \
	$(gen_asm_objects) \
	$(c_objects) \
	$(yacc_objects) \
	$(lex_objects) \
	$(addprefix $(TOPDIR)$(LOCAL_PATH)/,$(LOCAL_PREBUILT_OBJ_FILES))

LOCAL_C_INCLUDES += $(TOPDIR)$(LOCAL_PATH) $(intermediates) $(base_intermediates)

$(all_objects) : | $(LOCAL_GENERATED_SOURCES)
ALL_C_CPP_ETC_OBJECTS += $(all_objects)

###########################################################
## Copy headers to the install tree
###########################################################
include $(BUILD_COPY_HEADERS)

###########################################################
# Standard library handling.
#
# On the target, we compile with -nostdlib, so we must add in the
# default system shared libraries, unless they have requested not
# to by supplying a LOCAL_SYSTEM_SHARED_LIBRARIES value.  One would
# supply that, for example, when building libc itself.
###########################################################
ifndef LOCAL_IS_HOST_MODULE
  ifeq ($(LOCAL_SYSTEM_SHARED_LIBRARIES),none)
    LOCAL_SHARED_LIBRARIES += $($(my_prefix)DEFAULT_SYSTEM_SHARED_LIBRARIES)
  else
    LOCAL_SHARED_LIBRARIES += $(LOCAL_SYSTEM_SHARED_LIBRARIES)
  endif
endif

# Logging used to be part of libcutils (target) and libutils (sim);
# hack modules that use those other libs to also include liblog.
# All of this complexity is to make sure that liblog only appears
# once, and appears just before libcutils or libutils on the link
# line.
# TODO: remove this hack and change all modules to use liblog
# when necessary.
define insert-liblog
  $(if $(filter liblog,$(1)),$(1), \
    $(if $(filter libcutils,$(1)), \
      $(patsubst libcutils,liblog libcutils,$(1)) \
     , \
      $(patsubst libutils,liblog libutils,$(1)) \
     ) \
   )
endef
ifneq (,$(filter libcutils libutils,$(LOCAL_SHARED_LIBRARIES)))
  LOCAL_SHARED_LIBRARIES := $(call insert-liblog,$(LOCAL_SHARED_LIBRARIES))
endif
ifneq (,$(filter libcutils libutils,$(LOCAL_STATIC_LIBRARIES)))
  LOCAL_STATIC_LIBRARIES := $(call insert-liblog,$(LOCAL_STATIC_LIBRARIES))
endif
ifneq (,$(filter libcutils libutils,$(LOCAL_WHOLE_STATIC_LIBRARIES)))
  LOCAL_WHOLE_STATIC_LIBRARIES := $(call insert-liblog,$(LOCAL_WHOLE_STATIC_LIBRARIES))
endif

###########################################################
# The list of libraries that this module will link against are in
# these variables.  Each is a list of bare module names like "libc libm".
#
# LOCAL_SHARED_LIBRARIES
# LOCAL_STATIC_LIBRARIES
# LOCAL_WHOLE_STATIC_LIBRARIES
#
# We need to convert the bare names into the dependencies that
# we'll use for LOCAL_BUILT_MODULE and LOCAL_INSTALLED_MODULE.
# LOCAL_BUILT_MODULE should depend on the BUILT versions of the
# libraries, so that simply building this module doesn't force
# an install of a library.  Similarly, LOCAL_INSTALLED_MODULE
# should depend on the INSTALLED versions of the libraries so
# that they get installed when this module does.
###########################################################
# NOTE:
# WHOLE_STATIC_LIBRARIES are libraries that are pulled into the
# module without leaving anything out, which is useful for turning
# a collection of .a files into a .so file.  Linking against a
# normal STATIC_LIBRARY will only pull in code/symbols that are
# referenced by the module. (see gcc/ld's --whole-archive option)
###########################################################

# Get the list of BUILT libraries, which are under
# various intermediates directories.
so_suffix := $($(my_prefix)SHLIB_SUFFIX)
a_suffix := $($(my_prefix)STATIC_LIB_SUFFIX)

built_shared_libraries := \
    $(addprefix $($(my_prefix)OUT_INTERMEDIATE_LIBRARIES)/, \
      $(addsuffix $(so_suffix), \
        $(LOCAL_SHARED_LIBRARIES)))

built_static_libraries := \
    $(foreach lib,$(LOCAL_STATIC_LIBRARIES), \
      $(call intermediates-dir-for, \
        STATIC_LIBRARIES,$(lib),$(LOCAL_IS_HOST_MODULE))/$(lib)$(a_suffix))

built_whole_libraries := \
    $(foreach lib,$(LOCAL_WHOLE_STATIC_LIBRARIES), \
      $(call intermediates-dir-for, \
        STATIC_LIBRARIES,$(lib),$(LOCAL_IS_HOST_MODULE))/$(lib)$(a_suffix))

# Get the list of INSTALLED libraries.  Strip off the various
# intermediates directories and point to the common lib dirs.
installed_shared_libraries := \
    $(addprefix $($(my_prefix)OUT_SHARED_LIBRARIES)/, \
      $(notdir $(built_shared_libraries)))

# We don't care about installed static libraries, since the
# libraries have already been linked into the module at that point.
# We do, however, care about the NOTICE files for any static
# libraries that we use. (see notice_files.make)

installed_static_library_notice_file_targets := \
    $(foreach lib,$(LOCAL_STATIC_LIBRARIES) $(LOCAL_WHOLE_STATIC_LIBRARIES), \
      NOTICE-$(if $(LOCAL_IS_HOST_MODULE),HOST,TARGET)-STATIC_LIBRARIES-$(lib))

###########################################################
# Rule-specific variable definitions
###########################################################
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_YACCFLAGS := $(LOCAL_YACCFLAGS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ASFLAGS := $(LOCAL_ASFLAGS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CFLAGS := $(LOCAL_CFLAGS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CPPFLAGS := $(LOCAL_CPPFLAGS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_DEBUG_CFLAGS := $(debug_cflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_C_INCLUDES := $(LOCAL_C_INCLUDES)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_LDFLAGS := $(LOCAL_LDFLAGS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_LDLIBS := $(LOCAL_LDLIBS)

# this is really the way to get the files onto the command line instead
# of using $^, because then LOCAL_ADDITIONAL_DEPENDENCIES doesn't work
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_SHARED_LIBRARIES := $(built_shared_libraries)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_STATIC_LIBRARIES := $(built_static_libraries)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_WHOLE_STATIC_LIBRARIES := $(built_whole_libraries)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_OBJECTS := $(all_objects)

###########################################################
# Define library dependencies.
###########################################################
# all_libraries is used for the dependencies on LOCAL_BUILT_MODULE.
all_libraries := \
    $(built_shared_libraries) \
    $(built_static_libraries) \
    $(built_whole_libraries)

# Make LOCAL_INSTALLED_MODULE depend on the installed versions of the
# libraries so they get installed along with it.  We don't need to
# rebuild it when installing it, though, so this can be an order-only
# dependency.
$(LOCAL_INSTALLED_MODULE): | $(installed_shared_libraries)

# Also depend on the notice files for any static libraries that
# are linked into this module.  This will force them to be installed
# when this module is.
$(LOCAL_INSTALLED_MODULE): | $(installed_static_library_notice_file_targets)
