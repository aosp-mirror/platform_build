# Selects a Java compiler.
#
# Inputs:
#	CUSTOM_JAVA_COMPILER -- "eclipse", "openjdk". or nothing for the system
#                           default
#	ALTERNATE_JAVAC -- the alternate java compiler to use
#
# Outputs:
#   COMMON_JAVAC -- Java compiler command with common arguments
#

ifndef ANDROID_COMPILE_WITH_JACK
# Defines if compilation with jack is enabled by default.
ANDROID_COMPILE_WITH_JACK := true
endif

common_jdk_flags := -Xmaxerrs 9999999

# Use the indexer wrapper to index the codebase instead of the javac compiler
ifeq ($(ALTERNATE_JAVAC),)
JAVACC := javac
else
JAVACC := $(ALTERNATE_JAVAC)
endif

# The actual compiler can be wrapped by setting the JAVAC_WRAPPER var.
ifdef JAVAC_WRAPPER
    ifneq ($(JAVAC_WRAPPER),$(firstword $(JAVACC)))
        JAVACC := $(JAVAC_WRAPPER) $(JAVACC)
    endif
endif

# Whatever compiler is on this system.
COMMON_JAVAC := $(JAVACC) -J-Xmx1024M $(common_jdk_flags)

# Eclipse.
ifeq ($(CUSTOM_JAVA_COMPILER), eclipse)
    COMMON_JAVAC := java -Xmx256m -jar prebuilt/common/ecj/ecj.jar -5 \
        -maxProblems 9999999 -nowarn
    $(info CUSTOM_JAVA_COMPILER=eclipse)
endif

GLOBAL_JAVAC_DEBUG_FLAGS := -g

HOST_JAVAC ?= $(COMMON_JAVAC)
TARGET_JAVAC ?= $(COMMON_JAVAC)

#$(info HOST_JAVAC=$(HOST_JAVAC))
#$(info TARGET_JAVAC=$(TARGET_JAVAC))
