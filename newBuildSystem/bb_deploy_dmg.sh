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
name=${dmgNamePrefix:-$name}
# Delete the old dmg's. Ignore files listed in hashes/save.txt.
ls -1 "$1/$name"-*.dmg | grep -vf "$1/hashes/save.txt" | tr "\n" "\0" | xargs -0 rm -f

echo "Remove old signatures..."
for signature in "$1/$name"-*.dmg.sig ;do
	if [[ ! -e "${signature%.sig}" ]] ;then
		rm "$signature"
	fi
done

echo "Copying '$dmgPath' to '$1/$dmgName'..."
cp "$dmgPath" "$1/$dmgName"

if [[ -e "$dmgPath.sig" ]] ;then
	echo "Copying '$dmgPath.sig' to '$1/$dmgName.sig'..."
	cp "$dmgPath.sig" "$1/$dmgName.sig"
fi

echo "Linking"
ln -fs "$1/$dmgName" "$1/$name-latest.dmg"

echo "Fixing permissions..."
chmod +r "$1/$dmgName"
