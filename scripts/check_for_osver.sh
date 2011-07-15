#! /usr/bin/env bash

## Test for Mac OS X
SW_VERS=`which sw_vers`
if test -x "$SW_VERS"; then
    os=OSX
    osx_version=`sw_vers -productVersion | cut -f1,2 -d.`
    osx_major=`echo $osx_version | cut -f1 -d.`
    osx_minor=`echo $osx_version | cut -f2 -d.`
    distribution="mac$osx_major$osx_minor"
fi

if [ "$osx_major" == "10" ] && [ "$osx_minor" == "$1" ]; then
    exit 0
else
    exit 1
fi
