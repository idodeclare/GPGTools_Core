#!/bin/bash

tbDir="$HOME/Library/Thunderbird";
tbProfile="`grep -A3 Name=default $tbDir/profiles.ini|grep Path=|sed s/Path=//`"
tbFull="$tbDir/$tbProfile";

if ( test -e "$tbFull/Mail" ) then
    mkdir -p "$tbFull/extensions";
    exit 0;
fi

## this doesn't work if there is more than one xxx.default directory
#thunderbirddir=$HOME/Library/Thunderbird/Profiles/$(ls $HOME/Library/Thunderbird/Profiles | grep default)/Mail
#thunderbirdextensiondir=$thunderbirddir/../extensions
#if ( test -e $thunderbirddir ) then
#    mkdir -p $thunderbirdextensiondir
#	exit 0
#fi

exit 1
