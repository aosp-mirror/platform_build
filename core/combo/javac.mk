# Selects a Java compiler.
#
# Inputs:
#	CUSTOM_JAVA_COMPILER -- "eclipse", "openjdk". or nothing for the system 
#                           default
#
# Outputs:
#   COMMON_JAVAC -- Java compiler command with common arguments
#

ifeq ($(EXPERIMENTAL_USE_JAVA7_OPENJDK),)
common_flags := -target 1.5 -Xmaxerrs 9999999
else
common_flags := -Xmaxerrs 9999999
endif


# Whatever compiler is on this system.
ifeq ($(BUILD_OS), windows)
    COMMON_JAVAC := development/host/windows/prebuilt/javawrap.exe -J-Xmx256m \
        $(common_flags)
else
    COMMON_JAVAC := javac -J-Xmx512M $(common_flags)
endif

# Eclipse.
ifeq ($(CUSTOM_JAVA_COMPILER), eclipse)
    COMMON_JAVAC := java -Xmx256m -jar prebuilt/common/ecj/ecj.jar -5 \
        -maxProblems 9999999 -nowarn
    $(info CUSTOM_JAVA_COMPILER=eclipse)
endif

HOST_JAVAC ?= $(COMMON_JAVAC)
TARGET_JAVAC ?= $(COMMON_JAVAC)
    
#$(info HOST_JAVAC=$(HOST_JAVAC))
#$(info TARGET_JAVAC=$(TARGET_JAVAC))
