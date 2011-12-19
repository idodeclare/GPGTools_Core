#!/usr/bin/env PATH=$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/local/bin bash

## Test for Mac OS X
SW_VERS=`which sw_vers`
if test -x "$SW_VERS"; then
    os=OSX
    osx_version=`sw_vers -productVersion | cut -f1,2 -d.`
    osx_major=`echo $osx_version | cut -f1 -d.`
    osx_minor=`echo $osx_version | cut -f2 -d.`
    distribution="mac$osx_major$osx_minor"
fi

if [ "$osx_major" == "10" ] && [ "$osx_minor" == "5" ]; then
    #osascript -e 'tell app "System Events" to display dialog "Due to a bug in OS X 10.5 we need admin priviledges now..." buttons "OK" default button 1'
    osascript -e 'do shell script "pkgutil --regexp --forget org.gpgtools.*" with administrator privileges'
fi

exit 0;
