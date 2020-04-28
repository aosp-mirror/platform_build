# Selects a Java compiler.
#
# Outputs:
#   ANDROID_JAVA_TOOLCHAIN -- Directory that contains javac and other java tools
#

ANDROID_COMPILE_WITH_JACK := false

ifdef TARGET_BUILD_APPS
  ifndef TURBINE_ENABLED
    TURBINE_ENABLED := false
  endif
endif

ANDROID_JAVA_TOOLCHAIN := $(ANDROID_JAVA_HOME)/bin

# TODO(ccross): remove this, it is needed for now because it is used by
# config.mk before makevars from soong are loaded
JAVA := $(ANDROID_JAVA_TOOLCHAIN)/java
