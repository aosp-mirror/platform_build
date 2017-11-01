# Selects a Java compiler.
#
# Inputs:
#   OVERRIDE_ANDROID_JAVA_HOME -- alternate location to use for jdk
#
# Outputs:
#   ANDROID_JAVA_HOME -- Directory that contains JDK
#   ANDROID_JAVA_TOOLCHAIN -- Directory that contains javac and other java tools
#

ANDROID_COMPILE_WITH_JACK := false

ifdef TARGET_BUILD_APPS
  ifndef TURBINE_ENABLED
    TURBINE_ENABLED := false
  endif
endif

ifneq ($(OVERRIDE_ANDROID_JAVA_HOME),)
  # Use this build toolchain instead of the bundled one.
  ANDROID_JAVA_HOME := $(OVERRIDE_ANDROID_JAVA_HOME)
else # !OVERRIDE_ANDROID_JAVA_HOME
  ifneq ($(EXPERIMENTAL_USE_OPENJDK9),)
    ANDROID_JAVA_HOME := prebuilts/jdk/jdk9/$(HOST_PREBUILT_TAG)
  else
    ANDROID_JAVA_HOME := prebuilts/jdk/jdk8/$(HOST_PREBUILT_TAG)
  endif
endif

ANDROID_JAVA_TOOLCHAIN := $(ANDROID_JAVA_HOME)/bin
export JAVA_HOME := $(abspath $(ANDROID_JAVA_HOME))

# TODO(ccross): remove this, it is needed for now because it is used by
# config.mk before makevars from soong are loaded
JAVA := $(ANDROID_JAVA_TOOLCHAIN)/java
