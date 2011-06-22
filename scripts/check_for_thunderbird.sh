#!/bin/bash

thunderbirdextensiondir=$HOME/Library/Thunderbird/Profiles/$(ls $HOME/Library/Thunderbird/Profiles | grep default)/extensions

if ( test -e $thunderbirdextensiondir ) then
	exit 0
fi

exit 1
