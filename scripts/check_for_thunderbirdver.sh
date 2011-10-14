#! /usr/bin/env bash
# Iterate over all parameters

thunderbirddir=$HOME/Library/Thunderbird/Profiles/$(ls $HOME/Library/Thunderbird/Profiles | grep default)/
thunderbirdver=`grep LastVersion $thunderbirddir/compatibility.ini|cut -f2 -d=|cut -f1 -d.`;

if [ "$thunderbirdver" == "$1" ]; then
    exit 0
fi
if [ "$thunderbirdver" == "$2" ]; then
    exit 0
fi

exit 1
