#!/bin/sh
find . -name MODULE_LICENSE_\* | sed 's/\/MODULE_LICENSE_/\ /' | sed 's/\.\///' | awk '{ print $2 " " $1; }' | sort
