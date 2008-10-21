function help() {
cat <<EOF
Invoke ". envsetup.sh" from your shell to add the following functions to your environment:
- croot:   Changes directory to the top of the tree.
- m:       Makes from the top of the tree.
- mm:      Builds all of the modules in the current directory.
- mmm:     Builds all of the modules in the supplied directories.
- cgrep:   Greps on all local C/C++ files.
- jgrep:   Greps on all local Java files.
- resgrep: Greps on all local res/*.xml files.

Look at the source to view more functions. The complete list is:
EOF
    T=$(gettop)
    local A
    A=""
    for i in `cat $T/build/envsetup.sh | sed -n "/^function /s/function \([a-z_]*\).*/\1/p" | sort`; do
      A="$A $i"
    done
    echo $A
}

# Get the value of a build variable as an absolute path.
function get_abs_build_var()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
    CALLED_FROM_SETUP=true \
      make --no-print-directory -C "$T" -f build/core/envsetup.mk dumpvar-abs-$1
}

# Get the exact value of a build variable.
function get_build_var()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
    CALLED_FROM_SETUP=true \
      make --no-print-directory -C "$T" -f build/core/envsetup.mk dumpvar-$1
}

function setpaths()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP."
        return
    fi

    ##################################################################
    #                                                                #
    #              Read me before you modify this code               #
    #                                                                #
    #   This function sets ANDROID_BUILD_PATHS to what it is adding  #
    #   to PATH, and the next time it is run, it removes that from   #
    #   PATH.  This is required so lunch can be run more than once   #
    #   and still have working paths.                                #
    #                                                                #
    ##################################################################


    # out with the old
    if [ -n $ANDROID_BUILD_PATHS ] ; then
        export PATH=${PATH/$ANDROID_BUILD_PATHS/}
    fi

    # and in with the new
    CODE_REVIEWS=
    prebuiltdir=$(getprebuilt)
    export ANDROID_EABI_TOOLCHAIN=$prebuiltdir/toolchain-eabi-4.2.1/bin
    export ANDROID_TOOLCHAIN=$ANDROID_EABI_TOOLCHAIN
    export ANDROID_QTOOLS=$T/development/emulator/qtools
    export ANDROID_BUILD_PATHS=:$(get_build_var ANDROID_BUILD_PATHS):$ANDROID_QTOOLS:$ANDROID_TOOLCHAIN:$ANDROID_EABI_TOOLCHAIN$CODE_REVIEWS
    export PATH=$PATH$ANDROID_BUILD_PATHS
    
    export ANDROID_PRODUCT_OUT=$(get_abs_build_var PRODUCT_OUT)
    export OUT=$ANDROID_PRODUCT_OUT

    # needed for building linux on MacOS    
    # TODO: fix the path
    #export HOST_EXTRACFLAGS="-I "$T/system/kernel_headers/host_include
}

function printconfig()
{
    echo "=============================================="
    echo "Build System Configuration"
    echo
    echo "   TARGET_SIMULATOR:  " $TARGET_SIMULATOR
    echo "   TARGET_BUILD_TYPE: " $TARGET_BUILD_TYPE
    echo "   TARGET_PRODUCT:    " $TARGET_PRODUCT
    echo "=============================================="
}

function set_stuff_for_environment()
{
    if [ "$TARGET_SIMULATOR" -a "$TARGET_PRODUCT" -a "$TARGET_BUILD_TYPE" ]
    then
        settitle
        printconfig
        setpaths
        set_sequence_number

        # Don't try to do preoptimization until it works better on OSX.
        export DISABLE_DEXPREOPT=true

        export ANDROID_BUILD_TOP=$(gettop)
    fi
}

function set_sequence_number()
{
    export BUILD_ENV_SEQUENCE_NUMBER=8
}

function settitle()
{
        if [ "$STAY_OFF_MY_LAWN" = "" ]; then
                TARGET_PRODUCT=$(get_build_var TARGET_PRODUCT)
                export PROMPT_COMMAND='echo -ne "\033]0;[${TARGET_PRODUCT}] ${USER}@${HOSTNAME}: ${PWD}\007"'
        fi
}

case `uname -s` in
    Linux)
        function choosesim()
        {
            echo "Build for the simulator or the device?"
            echo "     1. Device"
            echo "     2. Simulator"
            echo

            export TARGET_SIMULATOR=$1
            while [ -z $TARGET_SIMULATOR ]
            do
                echo -n "Which would you like? [1] "
                read ANSWER
                case $ANSWER in
                "")
                    export TARGET_SIMULATOR=false
                    ;;
                1)
                    export TARGET_SIMULATOR=false
                    ;;
                2)
                    export TARGET_SIMULATOR=true
                    ;;
                *)
                    echo
                    echo "I didn't understand your response.  Please try again."
                    echo
                    continue
                    ;;
                esac
            done

            set_stuff_for_environment
        }
        ;;
    *)
        function choosesim()
        {
            echo "Only device builds are supported for" `uname -s`
            echo "     Forcing TARGET_SIMULATOR=false"
            echo
            echo -n "Press enter: "
            read

            export TARGET_SIMULATOR=false
            set_stuff_for_environment
        }
        ;;
esac

function choosetype()
{
    echo "Build type choices are:"
    echo "     1. release"
    echo "     2. debug"
    echo

    if [ $TARGET_SIMULATOR = "false" ] ; then
        DEFAULT_NUM=1
        DEFAULT_VALUE=release
    else
        DEFAULT_NUM=2
        DEFAULT_VALUE=debug
    fi

    export TARGET_BUILD_TYPE=$1
    while [ -z $TARGET_BUILD_TYPE ]
    do
        echo -n "Which would you like? ["$DEFAULT_NUM"] "
        read ANSWER
        case $ANSWER in
        "")
            export TARGET_BUILD_TYPE=$DEFAULT_VALUE
            ;;
        1)
            export TARGET_BUILD_TYPE=release
            ;;
        2)
            export TARGET_BUILD_TYPE=debug
            ;;
        *)
            echo
            echo "I didn't understand your response.  Please try again."
            echo
            continue
            ;;
        esac
    done

    set_stuff_for_environment
}

function chooseproduct()
{
    # Find the makefiles that must exist for a product.
    # Send stderr to /dev/null in case partner isn't present.
    choices=(`/bin/ls build/target/board/*/BoardConfig.mk vendor/*/*/BoardConfig.mk 2> /dev/null`)
    count=${#choices[@]}
    index=0
    echo "Product choices are:"

    while [ "$index" -lt "$count" ]
    do
        # The product name is the name of the directory containing
        # the makefile we found, above.
        choices[$index]=`dirname ${choices[$index]} | xargs basename`
        echo "     $index. ${choices[$index]}"
        let "index = $index + 1"
    done

    if [ "x$TARGET_PRODUCT" != x ] ; then
        default_value=$TARGET_PRODUCT
    else
        if [ "$TARGET_SIMULATOR" = true ] ; then
            default_value=sim
        else
            default_value=generic
        fi
    fi

    export TARGET_PRODUCT=$1
    while [ -z "$TARGET_PRODUCT" ]
    do
        echo -n "which would you like? [$default_value] "
        read ANSWER
        if [ -z "$ANSWER" ] ; then
            export TARGET_PRODUCT=$default_value
        elif [ "$ANSWER" -lt "$count" ] ; then
            export TARGET_PRODUCT=${choices[$ANSWER]}
        fi
    done

    set_stuff_for_environment
}

function tapas()
{
    choosecombo
}

function choosecombo()
{
    choosesim $1

    echo
    echo
    choosetype $2

    echo
    echo
    chooseproduct $3

    echo
    set_stuff_for_environment
}

function print_lunch_menu()
{
    local uname=$(uname)

    echo
    echo "You're building on" $uname

    echo
    echo "Lunch menu... pick a combo:"
    echo "     1. device    release  generic"
    if [ $uname = Linux ]
    then
        echo "     2. simulator debug    sim"
    else
        echo "     <no simulator on $uname>"
    fi
    echo
}

function lunch()
{
    if [ "$1" ] ; then
        ANSWER=$1
    else
        print_lunch_menu
        echo -n "Which would you like? "
        read ANSWER
    fi

    if [ $ANSWER -eq 2 -a $(uname) != Linux ]
    then
        echo "Simulator builds are not supported on this platform"
        ANSWER=0
    fi

    case $ANSWER in
    1)
        export TARGET_SIMULATOR=false
        export TARGET_BUILD_TYPE=release
        export TARGET_PRODUCT=generic
        ;;
    2)
        export TARGET_SIMULATOR=true
        export TARGET_BUILD_TYPE=debug
        export TARGET_PRODUCT=sim
        ;;
    *)
        echo
        if [ "$1" ] ; then
            echo "I didn't understand your request.  Please try again"
            print_lunch_menu
        else
            echo "I didn't understand your response.  Please try again."
        fi
        return
        ;;
    esac

    echo
    set_stuff_for_environment
}

function partner_setup()
{
   # Set up the various TARGET_ variables so that we can use
   # the lunch helper functions to build the PATH.
   #
   if [ $# -lt 1 ] ; then
       export TARGET_PRODUCT=generic
       echo "Usage: partner_setup <product-name>" >&2
       echo "    Defaulting to product \"$TARGET_PRODUCT\"" >&2
   else
       export TARGET_PRODUCT=$1
   fi
   if [ $TARGET_PRODUCT = "sim" ] ; then
       export TARGET_SIMULATOR=true
       export TARGET_BUILD_TYPE=debug
   else
       export TARGET_SIMULATOR=false
       export TARGET_BUILD_TYPE=release
   fi

   # setpaths will fix up the PATH to point to the tools, and will also
   # set ANDROID_PRODUCT_OUT.  set_sequence_number is necessary for
   # certain consistency checks within the build system.
   #
   setpaths
   set_sequence_number

   # Clear the TARGET_ variables so that the build is based purely on
   # buildspec.mk and the commandline, except for sim
   #
   if [ $TARGET_PRODUCT != sim ] ; then
       export TARGET_PRODUCT=
       export TARGET_SIMULATOR=
       export TARGET_BUILD_TYPE=
   fi
   export ANDROID_BUILD_TOP=$(gettop)
   # Don't try to do preoptimization until it works better on OSX.
   export DISABLE_DEXPREOPT=true

   echo "   ANDROID_PRODUCT_OUT: $ANDROID_PRODUCT_OUT"
   echo "   ANDROID_BUILD_TOP:   $ANDROID_BUILD_TOP"
}

function gettop
{
    TOPFILE=build/core/envsetup.mk
    if [ -n "$TOP" -a -f "$TOP/$TOPFILE" ] ; then
        echo $TOP
    else
        if [ -f $TOPFILE ] ; then
            echo $PWD
        else
            # We redirect cd to /dev/null in case it's aliased to
            # a command that prints something as a side-effect
            # (like pushd)
            HERE=$PWD
            T=
            while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
                cd .. > /dev/null
                T=$PWD
            done
            cd $HERE > /dev/null
            if [ -f "$T/$TOPFILE" ]; then
                echo $T
            fi
        fi
    fi
}

function m()
{
    T=$(gettop)
    if [ "$T" ]; then
        make -C $T $@
    else
        echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
}

function findmakefile()
{
    TOPFILE=build/core/envsetup.mk
    # We redirect cd to /dev/null in case it's aliased to
    # a command that prints something as a side-effect
    # (like pushd)
    HERE=$PWD
    T=
    while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
        T=$PWD
        if [ -f "$T/Android.mk" ]; then
            echo $T/Android.mk
            cd $HERE > /dev/null
            return
        fi
        cd .. > /dev/null
    done
    cd $HERE > /dev/null
}

function mm()
{
    # If we're sitting in the root of the build tree, just do a
    # normal make.
    if [ -f build/core/envsetup.mk -a -f Makefile ]; then
        make $@
    else
        # Find the closest Android.mk file.
        T=$(gettop)
        M=$(findmakefile)
        if [ ! "$T" ]; then
            echo "Couldn't locate the top of the tree.  Try setting TOP."
        elif [ ! "$M" ]; then
            echo "Couldn't locate a makefile from the current directory."
        else
            ONE_SHOT_MAKEFILE=$M make -C $T files $@
        fi
    fi
}

function mmm()
{
    T=$(gettop)
    if [ "$T" ]; then
        MAKEFILE=
        ARGS=
        for DIR in $@ ; do
            DIR=`echo $DIR | sed -e 's:/$::'`
            if [ -f $DIR/Android.mk ]; then
                TO_CHOP=`echo $T | wc -c | tr -d ' '`
                TO_CHOP=`expr $TO_CHOP + 1`
                MFILE=`echo $PWD | cut -c${TO_CHOP}-`
                if [ "$MFILE" = "" ] ; then
                    MFILE=$DIR/Android.mk
                else
                    MFILE=$MFILE/$DIR/Android.mk
                fi
                MAKEFILE="$MAKEFILE $MFILE"
            else
                if [ "$DIR" = snod ]; then
                    ARGS="$ARGS snod"
                elif [ "$DIR" = showcommands ]; then
                    ARGS="$ARGS showcommands"
                else
                    echo "No Android.mk in $DIR."
                fi
            fi
        done
        ONE_SHOT_MAKEFILE="$MAKEFILE" make -C $T files $ARGS
    else
        echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
}

function croot()
{
    T=$(gettop)
    if [ "$T" ]; then
        cd $(gettop)
    else
        echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
}

function pid()
{
   local EXE="$1"
   if [ "$EXE" ] ; then
       local PID=`adb shell ps | fgrep $1 | sed -e 's/[^ ]* *\([0-9]*\).*/\1/'`
       echo "$PID"
   else
       echo "usage: pid name"
   fi
}

function gdbclient()
{
   OUT_ROOT=$(get_abs_build_var PRODUCT_OUT)
   OUT_SYMBOLS=$(get_abs_build_var TARGET_OUT_UNSTRIPPED)
   OUT_SO_SYMBOLS=$(get_abs_build_var TARGET_OUT_SHARED_LIBRARIES_UNSTRIPPED)
   OUT_EXE_SYMBOLS=$(get_abs_build_var TARGET_OUT_EXECUTABLES_UNSTRIPPED)
   PREBUILTS=$(get_abs_build_var ANDROID_PREBUILTS)
   if [ "$OUT_ROOT" -a "$PREBUILTS" ]; then
       local EXE="$1"
       if [ "$EXE" ] ; then
           EXE=$1
       else
           EXE="app_process"
       fi

       local PORT="$2"
       if [ "$PORT" ] ; then
           PORT=$2
       else
           PORT=":5039"
       fi

       local PID
       local PROG="$3"
       if [ "$PROG" ] ; then
           PID=`pid $3`
           adb forward "tcp$PORT" "tcp$PORT"
           adb shell gdbserver $PORT --attach $PID &
           sleep 2
       else
               echo ""
               echo "If you haven't done so already, do this first on the device:"
               echo "    gdbserver $PORT /system/bin/$EXE"
                   echo " or"
               echo "    gdbserver $PORT --attach $PID"
               echo ""
       fi

       echo >|"$OUT_ROOT/gdbclient.cmds" "set solib-absolute-prefix $OUT_SYMBOLS"
       echo >>"$OUT_ROOT/gdbclient.cmds" "set solib-search-path $OUT_SO_SYMBOLS"
       echo >>"$OUT_ROOT/gdbclient.cmds" "target remote $PORT"
       echo >>"$OUT_ROOT/gdbclient.cmds" ""

       arm-eabi-gdb -x "$OUT_ROOT/gdbclient.cmds" "$OUT_EXE_SYMBOLS/$EXE"
  else
       echo "Unable to determine build system output dir."
   fi

}

case `uname -s` in
    Darwin)
        function sgrep()
        {
            find -E . -type f -iregex '.*\.(c|h|cpp|S|java|xml)' -print0 | xargs -0 grep --color -n "$@"
        }

        ;;
    *)
        function sgrep()
        {
            find . -type f -iregex '.*\.\(c\|h\|cpp\|S\|java\|xml\)' -print0 | xargs -0 grep --color -n "$@"
        }
        ;;
esac

function jgrep()
{
    find . -type f -name "*\.java" -print0 | xargs -0 grep --color -n "$@"
}

function cgrep()
{
    find . -type f -name "*\.c*" -print0 | xargs -0 grep --color -n "$@"
}

function resgrep()
{
    for dir in `find . -name res -type d`; do find $dir -type f -name '*\.xml' -print0 | xargs -0 grep --color -n "$@"; done;
}

case `uname -s` in
    Darwin)
        function mgrep()
        {
            find -E . -type f -iregex '.*/(Makefile|Makefile\..*|.*\.make|.*\.mak|.*\.mk)' -print0 | xargs -0 grep --color -n "$@"
        }

        function treegrep()
        {
            find -E . -type f -iregex '.*\.(c|h|cpp|S|java|xml)' -print0 | xargs -0 grep --color -n -i "$@"
        }

        ;;
    *)
        function mgrep()
        {
            find . -regextype posix-egrep -iregex '\(.*\/Makefile\|.*\/Makefile\..*\|.*\.make\|.*\.mak\|.*\.mk\)'  -type f -print0 | xargs -0 grep --color -n "$@"
        }

        function treegrep()
        {
            find . -regextype posix-egrep -iregex '.*\.(c|h|cpp|S|java|xml)' -type f -print0 | xargs -0 grep --color -n -i "$@"
        }

        ;;
esac

function getprebuilt
{
    get_abs_build_var ANDROID_PREBUILTS
}


function tracedmdump()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP."
        return
    fi
    prebuiltdir=$(getprebuilt)
    KERNEL=$T/prebuilt/android-arm/vmlinux-qemu

    TRACE=$1
    if [ ! "$TRACE" ] ; then
        echo "usage:  tracedmdump  tracename"
        return
    fi

    BASETRACE=$(basename $TRACE)
    if [ "$BASETRACE" = "$TRACE" ] ; then
        TRACE=$ANDROID_PRODUCT_OUT/traces/$TRACE
    fi

    echo "post-processing traces..."
    rm -f $TRACE/qtrace.dexlist
    post_trace $TRACE
    if [ $? -ne 0 ]; then
        echo "***"
        echo "*** Error: malformed trace.  Did you remember to exit the emulator?"
        echo "***"
        return
    fi
    echo "generating dexlist output..."
    /bin/ls $ANDROID_PRODUCT_OUT/system/framework/*.jar $ANDROID_PRODUCT_OUT/system/app/*.apk $ANDROID_PRODUCT_OUT/data/app/*.apk 2>/dev/null | xargs dexlist > $TRACE/qtrace.dexlist
    echo "generating dmtrace data..."
    q2dm -r $ANDROID_PRODUCT_OUT/symbols $TRACE $KERNEL $TRACE/dmtrace || return
    echo "generating html file..."
    dmtracedump -h $TRACE/dmtrace >| $TRACE/dmtrace.html || return
    echo "done, see $TRACE/dmtrace.html for details"
    echo "or run:"
    echo "    traceview $TRACE/dmtrace"
}

function runhat()
{
    targetPid=$1
    outputFile=$2

    if [ "$targetPid" = "" ]; then
        echo "Usage: runhat target-pid [output-file]"
        return
    fi

    adb shell >/dev/null mkdir /data/misc
    adb shell chmod 777 /data/misc

    echo "Poking $targetPid and waiting for data..."
    adb shell kill -10 $targetPid
    echo "Press enter when logcat shows \"GC freed ## objects / ## bytes\""
    echo -n "> "
    read

    availFiles=( $(adb shell ls /data/misc | grep '^heap-dump' | sed -e 's/.*heap-dump-/heap-dump-/' | sort -r | tr '[:space:][:cntrl:]' ' ') )
    devHeadFile=/data/misc/${availFiles[0]}
    devTailFile=/data/misc/${availFiles[1]}

    localHeadFile=/tmp/$$-hprof-head
    localTailFile=/tmp/$$-hprof-tail

    echo "Retrieving file $devHeadFile..."
    adb pull $devHeadFile $localHeadFile
    echo "Retrieving file $devTailFile..."
    adb pull $devTailFile $localTailFile

    combinedFile=$outputFile
    if [ "$combinedFile" = "" ]; then
        combinedFile=/tmp/$$.hprof
    fi

    cat $localHeadFile $localTailFile >$combinedFile
    adb shell rm $devHeadFile
    adb shell rm $devTailFile
    rm $localHeadFile
    rm $localTailFile

    echo "Running hat on $combinedFile"
    echo "View the output by pointing your browser at http://localhost:7000/"
    echo ""
    hat $combinedFile
}

function getbugreports()
{
    reports=(`adb shell ls /sdcard/bugreports | tr -d '\r'`)

    if [ ! "$reports" ]; then
        echo "Could not locate any bugreports."
        return
    fi

    count=${#reports[@]}
    index=0

    while [ "$index" -lt "$count" ]
    do
        echo "/sdcard/bugreports/${reports[$index]}"
        adb pull /sdcard/bugreports/${reports[$index]} ${reports[$index]}
        gunzip ${reports[$index]}
        let "index = $index + 1"
    done
}

function startviewserver()
{
    port=4939
    if [ $# -gt 0 ]; then
            port=$1
    fi
    adb shell service call window 1 i32 $port
}

function stopviewserver()
{
    adb shell service call window 2
}

function isviewserverstarted()
{
    adb shell service call window 3
}

function smoketest()
{
    if [ ! "$ANDROID_PRODUCT_OUT" ]; then
        echo "Couldn't locate output files.  Try running 'lunch' first." >&2
        return
    fi
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi

    (cd "$T" && mmm tests/SmokeTest) &&
      adb uninstall com.android.smoketest > /dev/null &&
      adb uninstall com.android.smoketest.tests > /dev/null &&
      adb install $ANDROID_PRODUCT_OUT/data/app/SmokeTestApp.apk &&
      adb install $ANDROID_PRODUCT_OUT/data/app/SmokeTest.apk &&
      adb shell am instrument -w com.android.smoketest.tests/android.test.InstrumentationTestRunner
}

