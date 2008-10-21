if [[ "x$ANDROID_JAVA_HOME" != x && -e $ANDROID_JAVA_HOME/lib/tools.jar ]] ; then
    echo $ANDROID_JAVA_HOME/lib/tools.jar
else
    JAVAC=$(which javac)
    while [ -L $JAVAC ] ; do
        LSLINE=$(ls -l $JAVAC)
        JAVAC=$(echo -n $LSLINE | sed -e "s/.* -> //")
    done
    echo $JAVAC | sed -e "s:\(.*\)/bin/javac.*:\\1/lib/tools.jar:"
fi
