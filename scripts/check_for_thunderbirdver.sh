#! /usr/bin/env bash
#
# GPGTools Thunderbird detection script
#
# @author	Alex
# @version	2011-10-18
###################################################### 

tb_root="$HOME/Library/Thunderbird/";
if [ ! -d "$tb_root" ]; then exit 1; fi

tb_profile="$tb_root/Profiles/$(ls $tb_root/Profiles | grep default)/";
if [ ! -d "$tb_profile" ]; then exit 2; fi

tb_ini="$tb_profile/compatibility.ini";
if [ ! -f "$tb_ini" ]; then exit 3; fi

tb_ver=`grep LastVersion $tb_ini|cut -f2 -d=|cut -f1 -d.`;

for i in $*; do
  if [ "$tb_ver" == "$i" ]; then exit 0; fi
done

exit 99
