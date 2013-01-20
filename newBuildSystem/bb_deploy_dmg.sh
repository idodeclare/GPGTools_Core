#!/bin/bash

if [ ! -d "$1" ]; then
	echo "Usage: $0 <directory>"
	exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
parseConfig


[[ -e "$dmgPath" ]] ||
	errExit "\"$dmgPath\" couldn't be found!"

echo "Remove old disk images..."
shopt -s extglob # Erweiterte Pfadnamen-Muster
rm -f "$1/$name-"+([0-9])n.dmg

echo "Copying '$dmgPath' to '$1/$dmgName'..."
cp "$dmgPath" "$1/$dmgName"

echo "Fixing permissions..."
chmod +r "$1/$dmgName"
