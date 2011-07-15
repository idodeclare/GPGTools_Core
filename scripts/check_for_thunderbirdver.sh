#! /usr/bin/env bash

thunderbirddir=$HOME/Library/Thunderbird/Profiles/$(ls $HOME/Library/Thunderbird/Profiles | grep default)/
thunderbirdver=`grep LastVersion $thunderbirddir/compatibility.ini|cut -f2 -d=|cut -f1 -d.`;

if [ "$thunderbirdver" == "$1" ]; then
    exit 0
else
    exit 1
fi
