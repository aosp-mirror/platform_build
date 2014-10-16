#!/bin/sh
if [ "x$ANDROID_JAVA_HOME" != x ] && [ -e "$ANDROID_JAVA_HOME/lib/tools.jar" ] ; then
    echo $ANDROID_JAVA_HOME/lib/tools.jar
else
    JAVAC=$(realpath $(which javac) 2>/dev/null)
    if [ -z "$JAVAC" ]; then
        JAVAC=$(readlink -f $(which javac) 2>/dev/null)
    fi
    if [ -z "$JAVAC" ]; then
        JAVAC=$(which javac)
    fi
    if [ -z "$JAVAC" ] ; then
        exit 1
    fi
    while [ -L "$JAVAC" ] ; do
        LSLINE=$(ls -l "$JAVAC")
        JAVAC=$(echo -n "$LSLINE" | sed -e "s/.* -> //")
    done
    echo $JAVAC | sed -e "s:\(.*\)/bin/javac.*:\\1/lib/tools.jar:"
fi
