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


echo "Linking"
# The link isn't for download! It's only to know, which are the lastest builds.
ln -fs "$dmgName" "$1/$name-latest.dmg"


echo "Fixing permissions..."
chmod +r "$1/$dmgName"

if [[ -e "$dmgPath.sig" ]] ;then
	echo "Copying '$dmgPath.sig' to '$1/$dmgName.sig'..."
	cp "$dmgPath.sig" "$1/$dmgName.sig"

	echo "Fixing permissions..."
	chmod +r "$1/$dmgName.sig"
fi


# Update nightly-info repo.
echo "Updating nightly-info..."
pushd "$1" >/dev/null

lf="
"
latest="$lf"
for dmgName in *-latest.dmg ;do
	dest="$(basename "$(readlink "$dmgName")")"
	latest="$latest$dest$lf"
done

content='['
for filename in *.dmg ;do
	tmp=${filename%.dmg}
	toolname=${tmp%-*}
	version=${tmp:${#toolname+1}}

	[[ "$version" == 'latest' ]] && continue

	echo "$latest : $filename"
	if [[ "$latest" == *"$lf$filename$lf"* ]] ;then
		last='true'
	else
		last='false'
	fi
	
	if [[ -e "$filename.sig" ]] ;then
		signature='true'
	else
		signature='false'
	fi
		
	content="$content{\"name\":\"$toolname\",\"version\":\"$version\",\"file\":\"$filename\",\"signature\":$signature,\"latest\":$last},"
done
content="${content%,}]";


if cd nightly-info && echo "$content" > nightlies.json ;then
	git reset
	git add nightlies.json
	git commit -m "New nightly: '$dmgName'"
	git push origin master
else
	echo "Unable to write nightlies.json"
fi


popd >/dev/null



