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
    # TODO(b/64113890, b/35788202): remove PRODUCT_COMPILE_WITH_JACK
    ifdef PRODUCT_COMPILE_WITH_JACK
        ANDROID_COMPILE_WITH_JACK := $(PRODUCT_COMPILE_WITH_JACK)
    else
        # TODO(b/62038127): remove TARGET_BUILD_APPS check
        ifdef TARGET_BUILD_APPS
            ANDROID_COMPILE_WITH_JACK := true
        else
            ANDROID_COMPILE_WITH_JACK := false
        endif
    endif
endif

common_jdk_flags := -Xmaxerrs 9999999

ifeq ($(OVERRIDE_ANDROID_JAVA_HOME),)
ANDROID_JAVA_HOME := prebuilts/jdk/jdk8/$(HOST_PREBUILT_TAG)
else
# Use this build toolchain instead of the bundled one.
ANDROID_JAVA_HOME := $(OVERRIDE_ANDROID_JAVA_HOME)
endif
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
