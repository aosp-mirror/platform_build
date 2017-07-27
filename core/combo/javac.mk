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
ANDROID_COMPILE_WITH_JACK := false
endif

common_jdk_flags := -Xmaxerrs 9999999

ANDROID_JAVA_HOME := prebuilts/jdk/jdk8/$(HOST_PREBUILT_TAG)
ANDROID_JAVA_TOOLCHAIN := $(ANDROID_JAVA_HOME)/bin
export JAVA_HOME := $(abspath $(ANDROID_JAVA_HOME))

# Use the indexer wrapper to index the codebase instead of the javac compiler
ifeq ($(ALTERNATE_JAVAC),)
JAVACC := $(ANDROID_JAVA_TOOLCHAIN)/javac
else
JAVACC := $(ALTERNATE_JAVAC)
endif

JAVA := $(ANDROID_JAVA_TOOLCHAIN)/java
JAVADOC := $(ANDROID_JAVA_TOOLCHAIN)/javadoc
JAR := $(ANDROID_JAVA_TOOLCHAIN)/jar

# The actual compiler can be wrapped by setting the JAVAC_WRAPPER var.
ifdef JAVAC_WRAPPER
    ifneq ($(JAVAC_WRAPPER),$(firstword $(JAVACC)))
        JAVACC := $(JAVAC_WRAPPER) $(JAVACC)
    endif
endif

COMMON_JAVAC := $(JAVACC) -J-Xmx2048M $(common_jdk_flags)

GLOBAL_JAVAC_DEBUG_FLAGS := -g

HOST_JAVAC ?= $(COMMON_JAVAC)
TARGET_JAVAC ?= $(COMMON_JAVAC)

#$(info HOST_JAVAC=$(HOST_JAVAC))
#$(info TARGET_JAVAC=$(TARGET_JAVAC))
