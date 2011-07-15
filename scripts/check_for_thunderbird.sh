#!/bin/bash

thunderbirddir=$HOME/Library/Thunderbird/Profiles/$(ls $HOME/Library/Thunderbird/Profiles | grep default)/Mail
thunderbirdextensiondir=$thunderbirddir/../extensions

if ( test -e $thunderbirddir ) then
    mkdir -p $thunderbirdextensiondir
	exit 0
fi

exit 1
