# Selects a Java compiler.
#
# Inputs:
#	CUSTOM_JAVA_COMPILER -- "eclipse", "openjdk". or nothing for the system 
#                           default
#
# Outputs:
#   COMMON_JAVAC -- Java compiler command with common arguments

# Whatever compiler is on this system.
ifeq ($(HOST_OS), windows)
    COMMON_JAVAC := development/host/windows/prebuilt/javawrap.exe -J-Xmx256m \
        -target 1.5 -Xmaxerrs 9999999
else
    COMMON_JAVAC := javac -J-Xmx512M -target 1.5 -Xmaxerrs 9999999
endif

# Eclipse.
ifeq ($(CUSTOM_JAVA_COMPILER), eclipse)
    COMMON_JAVAC := java -Xmx256m -jar prebuilt/common/ecj/ecj.jar -5 \
        -maxProblems 9999999 -nowarn
    $(info CUSTOM_JAVA_COMPILER=eclipse)
endif

# OpenJDK.
ifeq ($(CUSTOM_JAVA_COMPILER), openjdk)
    # We set the VM options (like -Xmx) in the javac script.
    COMMON_JAVAC := prebuilt/common/openjdk/bin/javac -target 1.5 \
        -Xmaxerrs 9999999
    $(info CUSTOM_JAVA_COMPILER=openjdk)
endif
   
HOST_JAVAC ?= $(COMMON_JAVAC)
TARGET_JAVAC ?= $(COMMON_JAVAC)
    
#$(info HOST_JAVAC=$(HOST_JAVAC))
#$(info TARGET_JAVAC=$(TARGET_JAVAC))
