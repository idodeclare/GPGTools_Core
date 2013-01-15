#!/bin/bash

if [ ! -d "$1" ]; then
	echo "Usage: $0 <directory>"
	exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
parseConfig

baseName="$name$bbSpecial"
bbName="$baseName-trunk.dmg"
linkName="$baseName-latest.dmg"

[[ -e "$dmgPath" ]] ||
	errExit "\"$dmgPath\" couldn't be found!"

echo "Remove old disk images..."
rm -f "$1/$baseName"*".dmg"

echo "Copying '$dmgPath' to '$1/$bbName'..."
cp "$dmgPath" "$1/$bbName"

echo "Create link '$linkName'..."
ln -s "$bbName" "$1/$linkName"

echo "Fixing permissions..."
chmod +r "$1/$bbName" "$1/$linkName"
