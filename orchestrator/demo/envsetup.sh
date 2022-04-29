#!/bin/bash

function buffet()
{
    local product variant selection
    if [[ $# -ne 1 ]]; then
        echo "usage: buffet [target]" >&2
        return 1
    fi

    selection=$1
    product=${selection%%-*} # Trim everything after first dash
    variant=${selection#*-} # Trim everything up to first dash

    if [ -z "$product" ]
    then
        echo
        echo "Invalid lunch combo: $selection"
        return 1
    fi

    if [ -z "$variant" ]
    then
        if [[ "$product" =~ .*_(eng|user|userdebug) ]]
        then
            echo "Did you mean -${product/*_/}? (dash instead of underscore)"
        fi
        return 1
    fi

    BUFFET_BUILD_TOP=$(pwd) python3 tools/build/orchestrator/buffet_helper.py $1 || return 1

    export BUFFET_BUILD_TOP=$(pwd)
    export BUFFET_COMPONENTS_TOP=$BUFFET_BUILD_TOP/components
    export BUFFET_TARGET_PRODUCT=$product
    export BUFFET_TARGET_BUILD_VARIANT=$variant
    export BUFFET_TARGET_BUILD_TYPE=release
}

function m()
{
    if [ -z "$BUFFET_BUILD_TOP" ]
    then
        echo "Run \"buffet [target]\" first"
        return 1
    fi
    python3 $BUFFET_BUILD_TOP/tools/build/orchestrator/build_helper.py "$@"
}
