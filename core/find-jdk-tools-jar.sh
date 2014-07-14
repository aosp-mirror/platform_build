#!/bin/sh
if [ "x$ANDROID_JAVA_HOME" != x ] && [ -e "$ANDROID_JAVA_HOME/lib/tools.jar" ] ; then
    echo $ANDROID_JAVA_HOME/lib/tools.jar
else
    JAVAC=$(readlink -f $(which javac))
    if [ -z "$JAVAC" ] ; then
        exit 1
    fi
    echo $JAVAC | sed -e "s:\(.*\)/bin/javac.*:\\1/lib/tools.jar:"
fi
