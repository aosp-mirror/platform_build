function hmm() {
cat <<EOF
Invoke ". build/envsetup.sh" from your shell to add the following functions to your environment:
- lunch:   lunch <product_name>-<build_variant>
- tapas:   tapas [<App1> <App2> ...] [arm|x86|mips|armv5|arm64|x86_64|mips64] [eng|userdebug|user]
- croot:   Changes directory to the top of the tree.
- m:       Makes from the top of the tree.
- mm:      Builds all of the modules in the current directory, but not their dependencies.
- mmm:     Builds all of the modules in the supplied directories, but not their dependencies.
           To limit the modules being built use the syntax: mmm dir/:target1,target2.
- mma:     Builds all of the modules in the current directory, and their dependencies.
- mmma:    Builds all of the modules in the supplied directories, and their dependencies.
- cgrep:   Greps on all local C/C++ files.
- ggrep:   Greps on all local Gradle files.
- jgrep:   Greps on all local Java files.
- resgrep: Greps on all local res/*.xml files.
- sgrep:   Greps on all local source files.
- godir:   Go to the directory containing a file.

Look at the source to view more functions. The complete list is:
EOF
    T=$(gettop)
    local A
    A=""
    for i in `cat $T/build/envsetup.sh | sed -n "/^[ \t]*function /s/function \([a-z_]*\).*/\1/p" | sort | uniq`; do
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
    (\cd $T; CALLED_FROM_SETUP=true BUILD_SYSTEM=build/core \
      command make --no-print-directory -f build/core/config.mk dumpvar-abs-$1)
}

# Get the exact value of a build variable.
function get_build_var()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
    (\cd $T; CALLED_FROM_SETUP=true BUILD_SYSTEM=build/core \
      command make --no-print-directory -f build/core/config.mk dumpvar-$1)
}

# check to see if the supplied product is one we can build
function check_product()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
        TARGET_PRODUCT=$1 \
        TARGET_BUILD_VARIANT= \
        TARGET_BUILD_TYPE= \
        TARGET_BUILD_APPS= \
        get_build_var TARGET_DEVICE > /dev/null
    # hide successful answers, but allow the errors to show
}

VARIANT_CHOICES=(user userdebug eng)

# check to see if the supplied variant is valid
function check_variant()
{
    for v in ${VARIANT_CHOICES[@]}
    do
        if [ "$v" = "$1" ]
        then
            return 0
        fi
    done
    return 1
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

    # Note: on windows/cygwin, ANDROID_BUILD_PATHS will contain spaces
    # due to "C:\Program Files" being in the path.

    # out with the old
    if [ -n "$ANDROID_BUILD_PATHS" ] ; then
        export PATH=${PATH/$ANDROID_BUILD_PATHS/}
    fi
    if [ -n "$ANDROID_PRE_BUILD_PATHS" ] ; then
        export PATH=${PATH/$ANDROID_PRE_BUILD_PATHS/}
        # strip leading ':', if any
        export PATH=${PATH/:%/}
    fi

    # and in with the new
    prebuiltdir=$(getprebuilt)
    gccprebuiltdir=$(get_abs_build_var ANDROID_GCC_PREBUILTS)

    # defined in core/config.mk
    targetgccversion=$(get_build_var TARGET_GCC_VERSION)
    targetgccversion2=$(get_build_var 2ND_TARGET_GCC_VERSION)
    export TARGET_GCC_VERSION=$targetgccversion

    # The gcc toolchain does not exists for windows/cygwin. In this case, do not reference it.
    export ANDROID_TOOLCHAIN=
    export ANDROID_TOOLCHAIN_2ND_ARCH=
    local ARCH=$(get_build_var TARGET_ARCH)
    case $ARCH in
        x86) toolchaindir=x86/x86_64-linux-android-$targetgccversion/bin
            ;;
        x86_64) toolchaindir=x86/x86_64-linux-android-$targetgccversion/bin
            ;;
        arm) toolchaindir=arm/arm-linux-androideabi-$targetgccversion/bin
            ;;
        arm64) toolchaindir=aarch64/aarch64-linux-android-$targetgccversion/bin;
               toolchaindir2=arm/arm-linux-androideabi-$targetgccversion2/bin
            ;;
        mips|mips64) toolchaindir=mips/mips64el-linux-android-$targetgccversion/bin
            ;;
        *)
            echo "Can't find toolchain for unknown architecture: $ARCH"
            toolchaindir=xxxxxxxxx
            ;;
    esac
    if [ -d "$gccprebuiltdir/$toolchaindir" ]; then
        export ANDROID_TOOLCHAIN=$gccprebuiltdir/$toolchaindir
    fi

    if [ -d "$gccprebuiltdir/$toolchaindir2" ]; then
        export ANDROID_TOOLCHAIN_2ND_ARCH=$gccprebuiltdir/$toolchaindir2
    fi

    unset ANDROID_KERNEL_TOOLCHAIN_PATH
    case $ARCH in
        arm)
            # Legacy toolchain configuration used for ARM kernel compilation
            toolchaindir=arm/arm-eabi-$targetgccversion/bin
            if [ -d "$gccprebuiltdir/$toolchaindir" ]; then
                 export ARM_EABI_TOOLCHAIN="$gccprebuiltdir/$toolchaindir"
                 ANDROID_KERNEL_TOOLCHAIN_PATH="$ARM_EABI_TOOLCHAIN":
            fi
            ;;
        *)
            # No need to set ARM_EABI_TOOLCHAIN for other ARCHs
            ;;
    esac

    export ANDROID_DEV_SCRIPTS=$T/development/scripts:$T/prebuilts/devtools/tools
    export ANDROID_BUILD_PATHS=$(get_build_var ANDROID_BUILD_PATHS):$ANDROID_TOOLCHAIN:$ANDROID_TOOLCHAIN_2ND_ARCH:$ANDROID_KERNEL_TOOLCHAIN_PATH$ANDROID_DEV_SCRIPTS:

    # If prebuilts/android-emulator/<system>/ exists, prepend it to our PATH
    # to ensure that the corresponding 'emulator' binaries are used.
    case $(uname -s) in
        Darwin)
            ANDROID_EMULATOR_PREBUILTS=$T/prebuilts/android-emulator/darwin-x86_64
            ;;
        Linux)
            ANDROID_EMULATOR_PREBUILTS=$T/prebuilts/android-emulator/linux-x86_64
            ;;
        *)
            ANDROID_EMULATOR_PREBUILTS=
            ;;
    esac
    if [ -n "$ANDROID_EMULATOR_PREBUILTS" -a -d "$ANDROID_EMULATOR_PREBUILTS" ]; then
        ANDROID_BUILD_PATHS=$ANDROID_BUILD_PATHS$ANDROID_EMULATOR_PREBUILTS:
        export ANDROID_EMULATOR_PREBUILTS
    fi

    export PATH=$ANDROID_BUILD_PATHS$PATH

    unset ANDROID_JAVA_TOOLCHAIN
    unset ANDROID_PRE_BUILD_PATHS
    if [ -n "$JAVA_HOME" ]; then
        export ANDROID_JAVA_TOOLCHAIN=$JAVA_HOME/bin
        export ANDROID_PRE_BUILD_PATHS=$ANDROID_JAVA_TOOLCHAIN:
        export PATH=$ANDROID_PRE_BUILD_PATHS$PATH
    fi

    unset ANDROID_PRODUCT_OUT
    export ANDROID_PRODUCT_OUT=$(get_abs_build_var PRODUCT_OUT)
    export OUT=$ANDROID_PRODUCT_OUT

    unset ANDROID_HOST_OUT
    export ANDROID_HOST_OUT=$(get_abs_build_var HOST_OUT)

    # needed for building linux on MacOS
    # TODO: fix the path
    #export HOST_EXTRACFLAGS="-I "$T/system/kernel_headers/host_include
}

function printconfig()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
    get_build_var report_config
}

function set_stuff_for_environment()
{
    settitle
    set_java_home
    setpaths
    set_sequence_number

    export ANDROID_BUILD_TOP=$(gettop)
    # With this environment variable new GCC can apply colors to warnings/errors
    export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
}

function set_sequence_number()
{
    export BUILD_ENV_SEQUENCE_NUMBER=10
}

function settitle()
{
    if [ "$STAY_OFF_MY_LAWN" = "" ]; then
        local arch=$(gettargetarch)
        local product=$TARGET_PRODUCT
        local variant=$TARGET_BUILD_VARIANT
        local apps=$TARGET_BUILD_APPS
        if [ -z "$apps" ]; then
            export PROMPT_COMMAND="echo -ne \"\033]0;[${arch}-${product}-${variant}] ${USER}@${HOSTNAME}: ${PWD}\007\""
        else
            export PROMPT_COMMAND="echo -ne \"\033]0;[$arch $apps $variant] ${USER}@${HOSTNAME}: ${PWD}\007\""
        fi
    fi
}

function addcompletions()
{
    local T dir f

    # Keep us from trying to run in something that isn't bash.
    if [ -z "${BASH_VERSION}" ]; then
        return
    fi

    # Keep us from trying to run in bash that's too old.
    if [ ${BASH_VERSINFO[0]} -lt 3 ]; then
        return
    fi

    dir="sdk/bash_completion"
    if [ -d ${dir} ]; then
        for f in `/bin/ls ${dir}/[a-z]*.bash 2> /dev/null`; do
            echo "including $f"
            . $f
        done
    fi
}

function choosetype()
{
    echo "Build type choices are:"
    echo "     1. release"
    echo "     2. debug"
    echo

    local DEFAULT_NUM DEFAULT_VALUE
    DEFAULT_NUM=1
    DEFAULT_VALUE=release

    export TARGET_BUILD_TYPE=
    local ANSWER
    while [ -z $TARGET_BUILD_TYPE ]
    do
        echo -n "Which would you like? ["$DEFAULT_NUM"] "
        if [ -z "$1" ] ; then
            read ANSWER
        else
            echo $1
            ANSWER=$1
        fi
        case $ANSWER in
        "")
            export TARGET_BUILD_TYPE=$DEFAULT_VALUE
            ;;
        1)
            export TARGET_BUILD_TYPE=release
            ;;
        release)
            export TARGET_BUILD_TYPE=release
            ;;
        2)
            export TARGET_BUILD_TYPE=debug
            ;;
        debug)
            export TARGET_BUILD_TYPE=debug
            ;;
        *)
            echo
            echo "I didn't understand your response.  Please try again."
            echo
            ;;
        esac
        if [ -n "$1" ] ; then
            break
        fi
    done

    set_stuff_for_environment
}

#
# This function isn't really right:  It chooses a TARGET_PRODUCT
# based on the list of boards.  Usually, that gets you something
# that kinda works with a generic product, but really, you should
# pick a product by name.
#
function chooseproduct()
{
    if [ "x$TARGET_PRODUCT" != x ] ; then
        default_value=$TARGET_PRODUCT
    else
        default_value=full
    fi

    export TARGET_PRODUCT=
    local ANSWER
    while [ -z "$TARGET_PRODUCT" ]
    do
        echo -n "Which product would you like? [$default_value] "
        if [ -z "$1" ] ; then
            read ANSWER
        else
            echo $1
            ANSWER=$1
        fi

        if [ -z "$ANSWER" ] ; then
            export TARGET_PRODUCT=$default_value
        else
            if check_product $ANSWER
            then
                export TARGET_PRODUCT=$ANSWER
            else
                echo "** Not a valid product: $ANSWER"
            fi
        fi
        if [ -n "$1" ] ; then
            break
        fi
    done

    set_stuff_for_environment
}

function choosevariant()
{
    echo "Variant choices are:"
    local index=1
    local v
    for v in ${VARIANT_CHOICES[@]}
    do
        # The product name is the name of the directory containing
        # the makefile we found, above.
        echo "     $index. $v"
        index=$(($index+1))
    done

    local default_value=eng
    local ANSWER

    export TARGET_BUILD_VARIANT=
    while [ -z "$TARGET_BUILD_VARIANT" ]
    do
        echo -n "Which would you like? [$default_value] "
        if [ -z "$1" ] ; then
            read ANSWER
        else
            echo $1
            ANSWER=$1
        fi

        if [ -z "$ANSWER" ] ; then
            export TARGET_BUILD_VARIANT=$default_value
        elif (echo -n $ANSWER | grep -q -e "^[0-9][0-9]*$") ; then
            if [ "$ANSWER" -le "${#VARIANT_CHOICES[@]}" ] ; then
                export TARGET_BUILD_VARIANT=${VARIANT_CHOICES[$(($ANSWER-1))]}
            fi
        else
            if check_variant $ANSWER
            then
                export TARGET_BUILD_VARIANT=$ANSWER
            else
                echo "** Not a valid variant: $ANSWER"
            fi
        fi
        if [ -n "$1" ] ; then
            break
        fi
    done
}

function choosecombo()
{
    choosetype $1

    echo
    echo
    chooseproduct $2

    echo
    echo
    choosevariant $3

    echo
    set_stuff_for_environment
    printconfig
}

# Clear this variable.  It will be built up again when the vendorsetup.sh
# files are included at the end of this file.
unset LUNCH_MENU_CHOICES
function add_lunch_combo()
{
    local new_combo=$1
    local c
    for c in ${LUNCH_MENU_CHOICES[@]} ; do
        if [ "$new_combo" = "$c" ] ; then
            return
        fi
    done
    LUNCH_MENU_CHOICES=(${LUNCH_MENU_CHOICES[@]} $new_combo)
}

# add the default one here
add_lunch_combo aosp_arm-eng
add_lunch_combo aosp_arm64-eng
add_lunch_combo aosp_mips-eng
add_lunch_combo aosp_mips64-eng
add_lunch_combo aosp_x86-eng
add_lunch_combo aosp_x86_64-eng

function print_lunch_menu()
{
    local uname=$(uname)
    echo
    echo "You're building on" $uname
    echo
    echo "Lunch menu... pick a combo:"

    local i=1
    local choice
    for choice in ${LUNCH_MENU_CHOICES[@]}
    do
        echo "     $i. $choice"
        i=$(($i+1))
    done

    echo
}

function lunch()
{
    local answer

    if [ "$1" ] ; then
        answer=$1
    else
        print_lunch_menu
        echo -n "Which would you like? [aosp_arm-eng] "
        read answer
    fi

    local selection=

    if [ -z "$answer" ]
    then
        selection=aosp_arm-eng
    elif (echo -n $answer | grep -q -e "^[0-9][0-9]*$")
    then
        if [ $answer -le ${#LUNCH_MENU_CHOICES[@]} ]
        then
            selection=${LUNCH_MENU_CHOICES[$(($answer-1))]}
        fi
    elif (echo -n $answer | grep -q -e "^[^\-][^\-]*-[^\-][^\-]*$")
    then
        selection=$answer
    fi

    if [ -z "$selection" ]
    then
        echo
        echo "Invalid lunch combo: $answer"
        return 1
    fi

    export TARGET_BUILD_APPS=

    local product=$(echo -n $selection | sed -e "s/-.*$//")
    check_product $product
    if [ $? -ne 0 ]
    then
        echo
        echo "** Don't have a product spec for: '$product'"
        echo "** Do you have the right repo manifest?"
        product=
    fi

    local variant=$(echo -n $selection | sed -e "s/^[^\-]*-//")
    check_variant $variant
    if [ $? -ne 0 ]
    then
        echo
        echo "** Invalid variant: '$variant'"
        echo "** Must be one of ${VARIANT_CHOICES[@]}"
        variant=
    fi

    if [ -z "$product" -o -z "$variant" ]
    then
        echo
        return 1
    fi

    export TARGET_PRODUCT=$product
    export TARGET_BUILD_VARIANT=$variant
    export TARGET_BUILD_TYPE=release

    echo

    set_stuff_for_environment
    printconfig
}

# Tab completion for lunch.
function _lunch()
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    COMPREPLY=( $(compgen -W "${LUNCH_MENU_CHOICES[*]}" -- ${cur}) )
    return 0
}
complete -F _lunch lunch

# Configures the build to build unbundled apps.
# Run tapas with one or more app names (from LOCAL_PACKAGE_NAME)
function tapas()
{
    local arch="$(echo $* | xargs -n 1 echo | \grep -E '^(arm|x86|mips|armv5|arm64|x86_64|mips64)$' | xargs)"
    local variant="$(echo $* | xargs -n 1 echo | \grep -E '^(user|userdebug|eng)$' | xargs)"
    local density="$(echo $* | xargs -n 1 echo | \grep -E '^(ldpi|mdpi|tvdpi|hdpi|xhdpi|xxhdpi|xxxhdpi|alldpi)$' | xargs)"
    local apps="$(echo $* | xargs -n 1 echo | \grep -E -v '^(user|userdebug|eng|arm|x86|mips|armv5|arm64|x86_64|mips64|ldpi|mdpi|tvdpi|hdpi|xhdpi|xxhdpi|xxxhdpi|alldpi)$' | xargs)"

    if [ $(echo $arch | wc -w) -gt 1 ]; then
        echo "tapas: Error: Multiple build archs supplied: $arch"
        return
    fi
    if [ $(echo $variant | wc -w) -gt 1 ]; then
        echo "tapas: Error: Multiple build variants supplied: $variant"
        return
    fi
    if [ $(echo $density | wc -w) -gt 1 ]; then
        echo "tapas: Error: Multiple densities supplied: $density"
        return
    fi

    local product=full
    case $arch in
      x86)    product=full_x86;;
      mips)   product=full_mips;;
      armv5)  product=generic_armv5;;
      arm64)  product=aosp_arm64;;
      x86_64) product=aosp_x86_64;;
      mips64)  product=aosp_mips64;;
    esac
    if [ -z "$variant" ]; then
        variant=eng
    fi
    if [ -z "$apps" ]; then
        apps=all
    fi
    if [ -z "$density" ]; then
        density=alldpi
    fi

    export TARGET_PRODUCT=$product
    export TARGET_BUILD_VARIANT=$variant
    export TARGET_BUILD_DENSITY=$density
    export TARGET_BUILD_TYPE=release
    export TARGET_BUILD_APPS=$apps

    set_stuff_for_environment
    printconfig
}

function gettop
{
    local TOPFILE=build/core/envsetup.mk
    if [ -n "$TOP" -a -f "$TOP/$TOPFILE" ] ; then
        # The following circumlocution ensures we remove symlinks from TOP.
        (cd $TOP; PWD= /bin/pwd)
    else
        if [ -f $TOPFILE ] ; then
            # The following circumlocution (repeated below as well) ensures
            # that we record the true directory name and not one that is
            # faked up with symlink names.
            PWD= /bin/pwd
        else
            local HERE=$PWD
            T=
            while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
                \cd ..
                T=`PWD= /bin/pwd -P`
            done
            \cd $HERE
            if [ -f "$T/$TOPFILE" ]; then
                echo $T
            fi
        fi
    fi
}

# Return driver for "make", if any (eg. static analyzer)
function getdriver()
{
    local T="$1"
    test "$WITH_STATIC_ANALYZER" = "0" && unset WITH_STATIC_ANALYZER
    if [ -n "$WITH_STATIC_ANALYZER" ]; then
        echo "\
$T/prebuilts/misc/linux-x86/analyzer/tools/scan-build/scan-build \
--use-analyzer $T/prebuilts/misc/linux-x86/analyzer/bin/analyzer \
--status-bugs \
--top=$T"
    fi
}

function m()
{
    local T=$(gettop)
    local DRV=$(getdriver $T)
    if [ "$T" ]; then
        $DRV make -C $T -f build/core/main.mk $@
    else
        echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
}

function findmakefile()
{
    TOPFILE=build/core/envsetup.mk
    local HERE=$PWD
    T=
    while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
        T=`PWD= /bin/pwd`
        if [ -f "$T/Android.mk" ]; then
            echo $T/Android.mk
            \cd $HERE
            return
        fi
        \cd ..
    done
    \cd $HERE
}

function mm()
{
    local T=$(gettop)
    local DRV=$(getdriver $T)
    # If we're sitting in the root of the build tree, just do a
    # normal make.
    if [ -f build/core/envsetup.mk -a -f Makefile ]; then
        $DRV make $@
    else
        # Find the closest Android.mk file.
        local M=$(findmakefile)
        local MODULES=
        local GET_INSTALL_PATH=
        local ARGS=
        # Remove the path to top as the makefilepath needs to be relative
        local M=`echo $M|sed 's:'$T'/::'`
        if [ ! "$T" ]; then
            echo "Couldn't locate the top of the tree.  Try setting TOP."
        elif [ ! "$M" ]; then
            echo "Couldn't locate a makefile from the current directory."
        else
            for ARG in $@; do
                case $ARG in
                  GET-INSTALL-PATH) GET_INSTALL_PATH=$ARG;;
                esac
            done
            if [ -n "$GET_INSTALL_PATH" ]; then
              MODULES=
              ARGS=GET-INSTALL-PATH
            else
              MODULES=all_modules
              ARGS=$@
            fi
            ONE_SHOT_MAKEFILE=$M $DRV make -C $T -f build/core/main.mk $MODULES $ARGS
        fi
    fi
}

function mmm()
{
    local T=$(gettop)
    local DRV=$(getdriver $T)
    if [ "$T" ]; then
        local MAKEFILE=
        local MODULES=
        local ARGS=
        local DIR TO_CHOP
        local GET_INSTALL_PATH=
        local DASH_ARGS=$(echo "$@" | awk -v RS=" " -v ORS=" " '/^-.*$/')
        local DIRS=$(echo "$@" | awk -v RS=" " -v ORS=" " '/^[^-].*$/')
        for DIR in $DIRS ; do
            MODULES=`echo $DIR | sed -n -e 's/.*:\(.*$\)/\1/p' | sed 's/,/ /'`
            if [ "$MODULES" = "" ]; then
                MODULES=all_modules
            fi
            DIR=`echo $DIR | sed -e 's/:.*//' -e 's:/$::'`
            if [ -f $DIR/Android.mk ]; then
                local TO_CHOP=`(\cd -P -- $T && pwd -P) | wc -c | tr -d ' '`
                local TO_CHOP=`expr $TO_CHOP + 1`
                local START=`PWD= /bin/pwd`
                local MFILE=`echo $START | cut -c${TO_CHOP}-`
                if [ "$MFILE" = "" ] ; then
                    MFILE=$DIR/Android.mk
                else
                    MFILE=$MFILE/$DIR/Android.mk
                fi
                MAKEFILE="$MAKEFILE $MFILE"
            else
                case $DIR in
                  showcommands | snod | dist | incrementaljavac) ARGS="$ARGS $DIR";;
                  GET-INSTALL-PATH) GET_INSTALL_PATH=$DIR;;
                  *) echo "No Android.mk in $DIR."; return 1;;
                esac
            fi
        done
        if [ -n "$GET_INSTALL_PATH" ]; then
          ARGS=$GET_INSTALL_PATH
          MODULES=
        fi
        ONE_SHOT_MAKEFILE="$MAKEFILE" $DRV make -C $T -f build/core/main.mk $DASH_ARGS $MODULES $ARGS
    else
        echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
}

function mma()
{
  local T=$(gettop)
  local DRV=$(getdriver $T)
  if [ -f build/core/envsetup.mk -a -f Makefile ]; then
    $DRV make $@
  else
    if [ ! "$T" ]; then
      echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
    local MY_PWD=`PWD= /bin/pwd|sed 's:'$T'/::'`
    $DRV make -C $T -f build/core/main.mk $@ all_modules BUILD_MODULES_IN_PATHS="$MY_PWD"
  fi
}

function mmma()
{
  local T=$(gettop)
  local DRV=$(getdriver $T)
  if [ "$T" ]; then
    local DASH_ARGS=$(echo "$@" | awk -v RS=" " -v ORS=" " '/^-.*$/')
    local DIRS=$(echo "$@" | awk -v RS=" " -v ORS=" " '/^[^-].*$/')
    local MY_PWD=`PWD= /bin/pwd`
    if [ "$MY_PWD" = "$T" ]; then
      MY_PWD=
    else
      MY_PWD=`echo $MY_PWD|sed 's:'$T'/::'`
    fi
    local DIR=
    local MODULE_PATHS=
    local ARGS=
    for DIR in $DIRS ; do
      if [ -d $DIR ]; then
        if [ "$MY_PWD" = "" ]; then
          MODULE_PATHS="$MODULE_PATHS $DIR"
        else
          MODULE_PATHS="$MODULE_PATHS $MY_PWD/$DIR"
        fi
      else
        case $DIR in
          showcommands | snod | dist | incrementaljavac) ARGS="$ARGS $DIR";;
          *) echo "Couldn't find directory $DIR"; return 1;;
        esac
      fi
    done
    $DRV make -C $T -f build/core/main.mk $DASH_ARGS $ARGS all_modules BUILD_MODULES_IN_PATHS="$MODULE_PATHS"
  else
    echo "Couldn't locate the top of the tree.  Try setting TOP."
  fi
}

function croot()
{
    T=$(gettop)
    if [ "$T" ]; then
        \cd $(gettop)
    else
        echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
}

function cproj()
{
    TOPFILE=build/core/envsetup.mk
    local HERE=$PWD
    T=
    while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
        T=$PWD
        if [ -f "$T/Android.mk" ]; then
            \cd $T
            return
        fi
        \cd ..
    done
    \cd $HERE
    echo "can't find Android.mk"
}

# simplified version of ps; output in the form
# <pid> <procname>
function qpid() {
    local prepend=''
    local append=''
    if [ "$1" = "--exact" ]; then
        prepend=' '
        append='$'
        shift
    elif [ "$1" = "--help" -o "$1" = "-h" ]; then
		echo "usage: qpid [[--exact] <process name|pid>"
		return 255
	fi

    local EXE="$1"
    if [ "$EXE" ] ; then
		qpid | \grep "$prepend$EXE$append"
	else
		adb shell ps \
			| tr -d '\r' \
			| sed -e 1d -e 's/^[^ ]* *\([0-9]*\).* \([^ ]*\)$/\1 \2/'
	fi
}

function pid()
{
    local prepend=''
    local append=''
    if [ "$1" = "--exact" ]; then
        prepend=' '
        append='$'
        shift
    fi
    local EXE="$1"
    if [ "$EXE" ] ; then
        local PID=`adb shell ps \
            | tr -d '\r' \
            | \grep "$prepend$EXE$append" \
            | sed -e 's/^[^ ]* *\([0-9]*\).*$/\1/'`
        echo "$PID"
    else
        echo "usage: pid [--exact] <process name>"
		return 255
    fi
}

# coredump_setup - enable core dumps globally for any process
#                  that has the core-file-size limit set correctly
#
# NOTE: You must call also coredump_enable for a specific process
#       if its core-file-size limit is not set already.
# NOTE: Core dumps are written to ramdisk; they will not survive a reboot!

function coredump_setup()
{
	echo "Getting root...";
	adb root;
	adb wait-for-device;

	echo "Remounting root parition read-write...";
	adb shell mount -w -o remount -t rootfs rootfs;
	sleep 1;
	adb wait-for-device;
	adb shell mkdir -p /cores;
	adb shell mount -t tmpfs tmpfs /cores;
	adb shell chmod 0777 /cores;

	echo "Granting SELinux permission to dump in /cores...";
	adb shell restorecon -R /cores;

	echo "Set core pattern.";
	adb shell 'echo /cores/core.%p > /proc/sys/kernel/core_pattern';

	echo "Done."
}

# coredump_enable - enable core dumps for the specified process
# $1 = PID of process (e.g., $(pid mediaserver))
#
# NOTE: coredump_setup must have been called as well for a core
#       dump to actually be generated.

function coredump_enable()
{
	local PID=$1;
	if [ -z "$PID" ]; then
		printf "Expecting a PID!\n";
		return;
	fi;
	echo "Setting core limit for $PID to infinite...";
	adb shell prlimit $PID 4 -1 -1
}

# core - send SIGV and pull the core for process
# $1 = PID of process (e.g., $(pid mediaserver))
#
# NOTE: coredump_setup must be called once per boot for core dumps to be
#       enabled globally.

function core()
{
	local PID=$1;

	if [ -z "$PID" ]; then
		printf "Expecting a PID!\n";
		return;
	fi;

	local CORENAME=core.$PID;
	local COREPATH=/cores/$CORENAME;
	local SIG=SEGV;

	coredump_enable $1;

	local done=0;
	while [ $(adb shell "[ -d /proc/$PID ] && echo -n yes") ]; do
		printf "\tSending SIG%s to %d...\n" $SIG $PID;
		adb shell kill -$SIG $PID;
		sleep 1;
	done;

	adb shell "while [ ! -f $COREPATH ] ; do echo waiting for $COREPATH to be generated; sleep 1; done"
	echo "Done: core is under $COREPATH on device.";
}

# systemstack - dump the current stack trace of all threads in the system process
# to the usual ANR traces file
function systemstack()
{
    stacks system_server
}

function stacks()
{
    if [[ $1 =~ ^[0-9]+$ ]] ; then
        local PID="$1"
    elif [ "$1" ] ; then
        local PIDLIST="$(pid $1)"
        if [[ $PIDLIST =~ ^[0-9]+$ ]] ; then
            local PID="$PIDLIST"
        elif [ "$PIDLIST" ] ; then
            echo "more than one process: $1"
        else
            echo "no such process: $1"
        fi
    else
        echo "usage: stacks [pid|process name]"
    fi

    if [ "$PID" ] ; then
        # Determine whether the process is native
        if adb shell ls -l /proc/$PID/exe | grep -q /system/bin/app_process ; then
            # Dump stacks of Dalvik process
            local TRACES=/data/anr/traces.txt
            local ORIG=/data/anr/traces.orig
            local TMP=/data/anr/traces.tmp

            # Keep original traces to avoid clobbering
            adb shell mv $TRACES $ORIG

            # Make sure we have a usable file
            adb shell touch $TRACES
            adb shell chmod 666 $TRACES

            # Dump stacks and wait for dump to finish
            adb shell kill -3 $PID
            adb shell notify $TRACES >/dev/null

            # Restore original stacks, and show current output
            adb shell mv $TRACES $TMP
            adb shell mv $ORIG $TRACES
            adb shell cat $TMP
        else
            # Dump stacks of native process
            local USE64BIT="$(is64bit $PID)"
            adb shell debuggerd$USE64BIT -b $PID
        fi
    fi
}

function gdbwrapper()
{
    local GDB_CMD="$1"
    shift 1
    $GDB_CMD -x "$@"
}

function get_symbols_directory()
{
    echo $(get_abs_build_var TARGET_OUT_UNSTRIPPED)
}

# Read the ELF header from /proc/$PID/exe to determine if the process is
# 64-bit.
function is64bit()
{
    local PID="$1"
    if [ "$PID" ] ; then
        if [[ "$(adb shell cat /proc/$PID/exe | xxd -l 1 -s 4 -ps)" -eq "02" ]] ; then
            echo "64"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

function adb_get_product_device() {
  echo `adb shell getprop ro.product.device | sed s/.$//`
}

# returns 0 when process is not traced
function adb_get_traced_by() {
  echo `adb shell cat /proc/$1/status | grep -e "^TracerPid:" | sed "s/^TracerPid:\t//" | sed s/.$//`
}

function gdbclient() {
  # TODO:
  # 1. Check for ANDROID_SERIAL/multiple devices
  local PROCESS_NAME="n/a"
  local PID=$1
  local PORT=5039
  if [ -z "$PID" ]; then
    echo "Usage: gdbclient <pid|processname> [port number]"
    return -1
  fi
  local DEVICE=$(adb_get_product_device)

  if [ -z "$DEVICE" ]; then
    echo "Error: Unable to get device name. Please check if device is connected and ANDROID_SERIAL is set."
    return -2
  fi

  if [ -n "$2" ]; then
    PORT=$2
  fi

  local ROOT=$(gettop)
  if [ -z "$ROOT" ]; then
    # This is for the situation with downloaded symbols (from the build server)
    # we check if they are available.
    ROOT=`realpath .`
  fi

  local OUT_ROOT="$ROOT/out/target/product/$DEVICE"
  local SYMBOLS_DIR="$OUT_ROOT/symbols"

  if [ ! -d $SYMBOLS_DIR ]; then
    echo "Error: couldn't find symbols: $SYMBOLS_DIR does not exist or is not a directory."
    return -3
  fi

  # let's figure out which executable we are about to debug

  # check if user specified a name -> resolve to pid
  if [[ ! "$PID" =~ ^[0-9]+$ ]] ; then
    PROCESS_NAME=$PID
    PID=$(pid --exact $PROCESS_NAME)
    if [ -z "$PID" ]; then
      echo "Error: couldn't resolve pid by process name: $PROCESS_NAME"
      return -4
    fi
  fi

  local EXE=`adb shell readlink /proc/$PID/exe | sed s/.$//`
  # TODO: print error in case there is no such pid
  local LOCAL_EXE_PATH=$SYMBOLS_DIR$EXE

  if [ ! -f $LOCAL_EXE_PATH ]; then
    echo "Error: unable to find symbols for executable $EXE: file $LOCAL_EXE_PATH does not exist"
    return -5
  fi

  local USE64BIT=""

  if [[ "$(file $LOCAL_EXE_PATH)" =~ 64-bit ]]; then
    USE64BIT="64"
  fi

  local GDB=
  local GDB64=
  local CPU_ABI=`adb shell getprop ro.product.cpu.abilist | sed s/.$//`
  # TODO: we assume these are available via $PATH
  if [[ $CPU_ABI =~ (^|,)arm64 ]]; then
    GDB=arm-linux-androideabi-gdb
    GDB64=aarch64-linux-android-gdb
  elif [[ $CPU_ABI =~ (^|,)arm ]]; then
    GDB=arm-linux-androideabi-gdb
  elif [[ $CPU_ABI =~ (^|,)x86_64 ]]; then
    GDB=x86_64-linux-androideabi-gdb
  elif [[ $CPU_ABI =~ (^|,)x86 ]]; then
    GDB=x86_64-linux-androideabi-gdb
  elif [[ $CPU_ABI =~ (^|,)mips64 ]]; then
    GDB=mipsel-linux-android-gdb
    GDB64=mips64el-linux-android-gdb
  elif [[ $CPU_ABI =~ (^|,)mips ]]; then
    GDB=mipsel-linux-android-gdb
  else
    echo "Error: unrecognized cpu.abilist: $CPU_ABI"
    return -6
  fi

  # TODO: check if tracing process is gdbserver and not some random strace...
  if [ $(adb_get_traced_by $PID) -eq 0 ]; then
    # start gdbserver
    echo "Starting gdbserver..."
    # TODO: check if adb is already listening $PORT
    # to avoid unnecessary calls
    echo ". adb forward for port=$PORT..."
    adb forward tcp:$PORT tcp:$PORT
    echo ". starting gdbserver to attach to pid=$PID..."
    adb shell gdbserver$USE64BIT :$PORT --attach $PID &
    echo ". give it couple of seconds to start..."
    sleep 2
    echo ". done"
  else
    echo "It looks like gdbserver is already attached to $PID (process is traced), trying to connect to it using local port=$PORT"
  fi

  local OUT_SO_SYMBOLS=$SYMBOLS_DIR/system/lib$USE64BIT
  local OUT_VENDOR_SO_SYMBOLS=$SYMBOLS_DIR/vendor/lib$USE64BIT
  local ART_CMD=""

  echo >|"$OUT_ROOT/gdbclient.cmds" "set solib-absolute-prefix $SYMBOLS_DIR"
  echo >>"$OUT_ROOT/gdbclient.cmds" "set solib-search-path $OUT_SO_SYMBOLS:$OUT_SO_SYMBOLS/hw:$OUT_SO_SYMBOLS/ssl/engines:$OUT_SO_SYMBOLS/drm:$OUT_SO_SYMBOLS/egl:$OUT_SO_SYMBOLS/soundfx:$OUT_VENDOR_SO_SYMBOLS:$OUT_VENDOR_SO_SYMBOLS/hw:$OUT_VENDOR_SO_SYMBOLS/egl"
  local DALVIK_GDB_SCRIPT=$ROOT/development/scripts/gdb/dalvik.gdb
  if [ -f $DALVIK_GDB_SCRIPT ]; then
    echo >>"$OUT_ROOT/gdbclient.cmds" "source $DALVIK_GDB_SCRIPT"
    ART_CMD="art-on"
  else
    echo "Warning: couldn't find $DALVIK_GDB_SCRIPT - ART debugging options will not be available"
  fi
  echo >>"$OUT_ROOT/gdbclient.cmds" "target remote :$PORT"
  if [[ $EXE =~ (^|/)(app_process|dalvikvm)(|32|64)$ ]]; then
    echo >> "$OUT_ROOT/gdbclient.cmds" $ART_CMD
  fi

  echo >>"$OUT_ROOT/gdbclient.cmds" ""

  local WHICH_GDB=$GDB

  if [ -n "$USE64BIT" -a -n "$GDB64" ]; then
    WHICH_GDB=$GDB64
  fi

  gdbwrapper $WHICH_GDB "$OUT_ROOT/gdbclient.cmds" "$LOCAL_EXE_PATH"
}

# gdbclient now determines whether the user wants to debug a 32-bit or 64-bit
# executable, set up the approriate gdbserver, then invokes the proper host
# gdb.
function gdbclient_old()
{
   local OUT_ROOT=$(get_abs_build_var PRODUCT_OUT)
   local OUT_SYMBOLS=$(get_abs_build_var TARGET_OUT_UNSTRIPPED)
   local OUT_SO_SYMBOLS=$(get_abs_build_var TARGET_OUT_SHARED_LIBRARIES_UNSTRIPPED)
   local OUT_VENDOR_SO_SYMBOLS=$(get_abs_build_var TARGET_OUT_VENDOR_SHARED_LIBRARIES_UNSTRIPPED)
   local OUT_EXE_SYMBOLS=$(get_symbols_directory)
   local PREBUILTS=$(get_abs_build_var ANDROID_PREBUILTS)
   local ARCH=$(get_build_var TARGET_ARCH)
   local GDB
   case "$ARCH" in
       arm) GDB=arm-linux-androideabi-gdb;;
       arm64) GDB=arm-linux-androideabi-gdb; GDB64=aarch64-linux-android-gdb;;
       mips|mips64) GDB=mips64el-linux-android-gdb;;
       x86) GDB=x86_64-linux-android-gdb;;
       x86_64) GDB=x86_64-linux-android-gdb;;
       *) echo "Unknown arch $ARCH"; return 1;;
   esac

   if [ "$OUT_ROOT" -a "$PREBUILTS" ]; then
       local EXE="$1"
       if [ "$EXE" ] ; then
           EXE=$1
           if [[ $EXE =~ ^[^/].* ]] ; then
               EXE="system/bin/"$EXE
           fi
       else
           EXE="app_process"
       fi

       local PORT="$2"
       if [ "$PORT" ] ; then
           PORT=$2
       else
           PORT=":5039"
       fi

       local PID="$3"
       if [ "$PID" ] ; then
           if [[ ! "$PID" =~ ^[0-9]+$ ]] ; then
               PID=`pid $3`
               if [[ ! "$PID" =~ ^[0-9]+$ ]] ; then
                   # that likely didn't work because of returning multiple processes
                   # try again, filtering by root processes (don't contain colon)
                   PID=`adb shell ps | \grep $3 | \grep -v ":" | awk '{print $2}'`
                   if [[ ! "$PID" =~ ^[0-9]+$ ]]
                   then
                       echo "Couldn't resolve '$3' to single PID"
                       return 1
                   else
                       echo ""
                       echo "WARNING: multiple processes matching '$3' observed, using root process"
                       echo ""
                   fi
               fi
           fi
           adb forward "tcp$PORT" "tcp$PORT"
           local USE64BIT="$(is64bit $PID)"
           adb shell gdbserver$USE64BIT $PORT --attach $PID &
           sleep 2
       else
               echo ""
               echo "If you haven't done so already, do this first on the device:"
               echo "    gdbserver $PORT /system/bin/$EXE"
                   echo " or"
               echo "    gdbserver $PORT --attach <PID>"
               echo ""
       fi

       OUT_SO_SYMBOLS=$OUT_SO_SYMBOLS$USE64BIT
       OUT_VENDOR_SO_SYMBOLS=$OUT_VENDOR_SO_SYMBOLS$USE64BIT

       echo >|"$OUT_ROOT/gdbclient.cmds" "set solib-absolute-prefix $OUT_SYMBOLS"
       echo >>"$OUT_ROOT/gdbclient.cmds" "set solib-search-path $OUT_SO_SYMBOLS:$OUT_SO_SYMBOLS/hw:$OUT_SO_SYMBOLS/ssl/engines:$OUT_SO_SYMBOLS/drm:$OUT_SO_SYMBOLS/egl:$OUT_SO_SYMBOLS/soundfx:$OUT_VENDOR_SO_SYMBOLS:$OUT_VENDOR_SO_SYMBOLS/hw:$OUT_VENDOR_SO_SYMBOLS/egl"
       echo >>"$OUT_ROOT/gdbclient.cmds" "source $ANDROID_BUILD_TOP/development/scripts/gdb/dalvik.gdb"
       echo >>"$OUT_ROOT/gdbclient.cmds" "target remote $PORT"
       # Enable special debugging for ART processes.
       if [[ $EXE =~ (^|/)(app_process|dalvikvm)(|32|64)$ ]]; then
          echo >> "$OUT_ROOT/gdbclient.cmds" "art-on"
       fi
       echo >>"$OUT_ROOT/gdbclient.cmds" ""

       local WHICH_GDB=
       # 64-bit exe found
       if [ "$USE64BIT" != "" ] ; then
           WHICH_GDB=$ANDROID_TOOLCHAIN/$GDB64
       # 32-bit exe / 32-bit platform
       elif [ "$(get_build_var TARGET_2ND_ARCH)" = "" ]; then
           WHICH_GDB=$ANDROID_TOOLCHAIN/$GDB
       # 32-bit exe / 64-bit platform
       else
           WHICH_GDB=$ANDROID_TOOLCHAIN_2ND_ARCH/$GDB
       fi

       gdbwrapper $WHICH_GDB "$OUT_ROOT/gdbclient.cmds" "$OUT_EXE_SYMBOLS/$EXE"
  else
       echo "Unable to determine build system output dir."
   fi

}

case `uname -s` in
    Darwin)
        function sgrep()
        {
            find -E . -name .repo -prune -o -name .git -prune -o  -type f -iregex '.*\.(c|h|cc|cpp|S|java|xml|sh|mk|aidl)' -print0 | xargs -0 grep --color -n "$@"
        }

        ;;
    *)
        function sgrep()
        {
            find . -name .repo -prune -o -name .git -prune -o  -type f -iregex '.*\.\(c\|h\|cc\|cpp\|S\|java\|xml\|sh\|mk\|aidl\)' -print0 | xargs -0 grep --color -n "$@"
        }
        ;;
esac

function gettargetarch
{
    get_build_var TARGET_ARCH
}

function ggrep()
{
    find . -name .repo -prune -o -name .git -prune -o -name out -prune -o -type f -name "*\.gradle" -print0 | xargs -0 grep --color -n "$@"
}

function jgrep()
{
    find . -name .repo -prune -o -name .git -prune -o -name out -prune -o -type f -name "*\.java" -print0 | xargs -0 grep --color -n "$@"
}

function cgrep()
{
    find . -name .repo -prune -o -name .git -prune -o -name out -prune -o -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h' \) -print0 | xargs -0 grep --color -n "$@"
}

function resgrep()
{
    for dir in `find . -name .repo -prune -o -name .git -prune -o -name out -prune -o -name res -type d`; do find $dir -type f -name '*\.xml' -print0 | xargs -0 grep --color -n "$@"; done;
}

function mangrep()
{
    find . -name .repo -prune -o -name .git -prune -o -path ./out -prune -o -type f -name 'AndroidManifest.xml' -print0 | xargs -0 grep --color -n "$@"
}

function sepgrep()
{
    find . -name .repo -prune -o -name .git -prune -o -path ./out -prune -o -name sepolicy -type d -print0 | xargs -0 grep --color -n -r --exclude-dir=\.git "$@"
}

case `uname -s` in
    Darwin)
        function mgrep()
        {
            find -E . -name .repo -prune -o -name .git -prune -o -path ./out -prune -o -type f -iregex '.*/(Makefile|Makefile\..*|.*\.make|.*\.mak|.*\.mk)' -print0 | xargs -0 grep --color -n "$@"
        }

        function treegrep()
        {
            find -E . -name .repo -prune -o -name .git -prune -o -type f -iregex '.*\.(c|h|cpp|S|java|xml)' -print0 | xargs -0 grep --color -n -i "$@"
        }

        ;;
    *)
        function mgrep()
        {
            find . -name .repo -prune -o -name .git -prune -o -path ./out -prune -o -regextype posix-egrep -iregex '(.*\/Makefile|.*\/Makefile\..*|.*\.make|.*\.mak|.*\.mk)' -type f -print0 | xargs -0 grep --color -n "$@"
        }

        function treegrep()
        {
            find . -name .repo -prune -o -name .git -prune -o -regextype posix-egrep -iregex '.*\.(c|h|cpp|S|java|xml)' -type f -print0 | xargs -0 grep --color -n -i "$@"
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
    local prebuiltdir=$(getprebuilt)
    local arch=$(gettargetarch)
    local KERNEL=$T/prebuilts/qemu-kernel/$arch/vmlinux-qemu

    local TRACE=$1
    if [ ! "$TRACE" ] ; then
        echo "usage:  tracedmdump  tracename"
        return
    fi

    if [ ! -r "$KERNEL" ] ; then
        echo "Error: cannot find kernel: '$KERNEL'"
        return
    fi

    local BASETRACE=$(basename $TRACE)
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

# communicate with a running device or emulator, set up necessary state,
# and run the hat command.
function runhat()
{
    # process standard adb options
    local adbTarget=""
    if [ "$1" = "-d" -o "$1" = "-e" ]; then
        adbTarget=$1
        shift 1
    elif [ "$1" = "-s" ]; then
        adbTarget="$1 $2"
        shift 2
    fi
    local adbOptions=${adbTarget}
    #echo adbOptions = ${adbOptions}

    # runhat options
    local targetPid=$1

    if [ "$targetPid" = "" ]; then
        echo "Usage: runhat [ -d | -e | -s serial ] target-pid"
        return
    fi

    # confirm hat is available
    if [ -z $(which hat) ]; then
        echo "hat is not available in this configuration."
        return
    fi

    # issue "am" command to cause the hprof dump
    local devFile=/data/local/tmp/hprof-$targetPid
    echo "Poking $targetPid and waiting for data..."
    echo "Storing data at $devFile"
    adb ${adbOptions} shell am dumpheap $targetPid $devFile
    echo "Press enter when logcat shows \"hprof: heap dump completed\""
    echo -n "> "
    read

    local localFile=/tmp/$$-hprof

    echo "Retrieving file $devFile..."
    adb ${adbOptions} pull $devFile $localFile

    adb ${adbOptions} shell rm $devFile

    echo "Running hat on $localFile"
    echo "View the output by pointing your browser at http://localhost:7000/"
    echo ""
    hat -JXmx512m $localFile
}

function getbugreports()
{
    local reports=(`adb shell ls /sdcard/bugreports | tr -d '\r'`)

    if [ ! "$reports" ]; then
        echo "Could not locate any bugreports."
        return
    fi

    local report
    for report in ${reports[@]}
    do
        echo "/sdcard/bugreports/${report}"
        adb pull /sdcard/bugreports/${report} ${report}
        gunzip ${report}
    done
}

function getsdcardpath()
{
    adb ${adbOptions} shell echo -n \$\{EXTERNAL_STORAGE\}
}

function getscreenshotpath()
{
    echo "$(getsdcardpath)/Pictures/Screenshots"
}

function getlastscreenshot()
{
    local screenshot_path=$(getscreenshotpath)
    local screenshot=`adb ${adbOptions} ls ${screenshot_path} | grep Screenshot_[0-9-]*.*\.png | sort -rk 3 | cut -d " " -f 4 | head -n 1`
    if [ "$screenshot" = "" ]; then
        echo "No screenshots found."
        return
    fi
    echo "${screenshot}"
    adb ${adbOptions} pull ${screenshot_path}/${screenshot}
}

function startviewserver()
{
    local port=4939
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

function key_home()
{
    adb shell input keyevent 3
}

function key_back()
{
    adb shell input keyevent 4
}

function key_menu()
{
    adb shell input keyevent 82
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

    (\cd "$T" && mmm tests/SmokeTest) &&
      adb uninstall com.android.smoketest > /dev/null &&
      adb uninstall com.android.smoketest.tests > /dev/null &&
      adb install $ANDROID_PRODUCT_OUT/data/app/SmokeTestApp.apk &&
      adb install $ANDROID_PRODUCT_OUT/data/app/SmokeTest.apk &&
      adb shell am instrument -w com.android.smoketest.tests/android.test.InstrumentationTestRunner
}

# simple shortcut to the runtest command
function runtest()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
    ("$T"/development/testrunner/runtest.py $@)
}

function godir () {
    if [[ -z "$1" ]]; then
        echo "Usage: godir <regex>"
        return
    fi
    T=$(gettop)
    if [[ ! -f $T/filelist ]]; then
        echo -n "Creating index..."
        (\cd $T; find . -wholename ./out -prune -o -wholename ./.repo -prune -o -type f > filelist)
        echo " Done"
        echo ""
    fi
    local lines
    lines=($(\grep "$1" $T/filelist | sed -e 's/\/[^/]*$//' | sort | uniq))
    if [[ ${#lines[@]} = 0 ]]; then
        echo "Not found"
        return
    fi
    local pathname
    local choice
    if [[ ${#lines[@]} > 1 ]]; then
        while [[ -z "$pathname" ]]; do
            local index=1
            local line
            for line in ${lines[@]}; do
                printf "%6s %s\n" "[$index]" $line
                index=$(($index + 1))
            done
            echo
            echo -n "Select one: "
            unset choice
            read choice
            if [[ $choice -gt ${#lines[@]} || $choice -lt 1 ]]; then
                echo "Invalid choice"
                continue
            fi
            pathname=${lines[$(($choice-1))]}
        done
    else
        pathname=${lines[0]}
    fi
    \cd $T/$pathname
}

# Force JAVA_HOME to point to java 1.7 or java 1.6  if it isn't already set.
#
# Note that the MacOS path for java 1.7 includes a minor revision number (sigh).
# For some reason, installing the JDK doesn't make it show up in the
# JavaVM.framework/Versions/1.7/ folder.
function set_java_home() {
    # Clear the existing JAVA_HOME value if we set it ourselves, so that
    # we can reset it later, depending on the version of java the build
    # system needs.
    #
    # If we don't do this, the JAVA_HOME value set by the first call to
    # build/envsetup.sh will persist forever.
    if [ -n "$ANDROID_SET_JAVA_HOME" ]; then
      export JAVA_HOME=""
    fi

    if [ ! "$JAVA_HOME" ]; then
      if [ -n "$LEGACY_USE_JAVA6" ]; then
        case `uname -s` in
            Darwin)
                export JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Versions/1.6/Home
                ;;
            *)
                export JAVA_HOME=/usr/lib/jvm/java-6-sun
                ;;
        esac
      else
        case `uname -s` in
            Darwin)
                export JAVA_HOME=$(/usr/libexec/java_home -v 1.7)
                ;;
            *)
                export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64
                ;;
        esac
      fi

      # Keep track of the fact that we set JAVA_HOME ourselves, so that
      # we can change it on the next envsetup.sh, if required.
      export ANDROID_SET_JAVA_HOME=true
    fi
}

# Print colored exit condition
function pez {
    "$@"
    local retval=$?
    if [ $retval -ne 0 ]
    then
        echo -e "\e[0;31mFAILURE\e[00m"
    else
        echo -e "\e[0;32mSUCCESS\e[00m"
    fi
    return $retval
}

function get_make_command()
{
  echo command make
}

function make()
{
    local start_time=$(date +"%s")
    $(get_make_command) "$@"
    local ret=$?
    local end_time=$(date +"%s")
    local tdiff=$(($end_time-$start_time))
    local hours=$(($tdiff / 3600 ))
    local mins=$((($tdiff % 3600) / 60))
    local secs=$(($tdiff % 60))
    echo
    if [ $ret -eq 0 ] ; then
        echo -n -e "#### make completed successfully "
    else
        echo -n -e "#### make failed to build some targets "
    fi
    if [ $hours -gt 0 ] ; then
        printf "(%02g:%02g:%02g (hh:mm:ss))" $hours $mins $secs
    elif [ $mins -gt 0 ] ; then
        printf "(%02g:%02g (mm:ss))" $mins $secs
    elif [ $secs -gt 0 ] ; then
        printf "(%s seconds)" $secs
    fi
    echo -e " ####"
    echo
    return $ret
}



if [ "x$SHELL" != "x/bin/bash" ]; then
    case `ps -o command -p $$` in
        *bash*)
            ;;
        *)
            echo "WARNING: Only bash is supported, use of other shell would lead to erroneous results"
            ;;
    esac
fi

# Execute the contents of any vendorsetup.sh files we can find.
for f in `test -d device && find -L device -maxdepth 4 -name 'vendorsetup.sh' 2> /dev/null` \
         `test -d vendor && find -L vendor -maxdepth 4 -name 'vendorsetup.sh' 2> /dev/null`
do
    echo "including $f"
    . $f
done
unset f

addcompletions
