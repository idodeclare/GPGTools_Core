#!/bin/bash
#
# This script creates a DMG for GPGTools
#
# (c) by Felix Co & Alexander Willner & Roman Zechmeister
#
# Erstellt aus dem pkg ein dmg.

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
echo "Parsing configuration..."
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
parseConfig



makeDmg="$(dirname "${BASH_SOURCE[0]}")/../perl/make_dmg.pl"

echo "Setting configuration parameter..."
iconDmg="$coreDir/images/icon_dmg.icns"
iconInstaller="$coreDir/images/icon_installer.icns"


pkgPos=${pkgPos:-"226,212"}
rmPos=${rmPos:-"369,212"}
iconSize=${iconSize:-"76"}
textSize=${textSize:-"13"}
windowPos=${windowPos:-"400,200"}
windowSize=${windowSize:-"600,420"}


echo "Checking environment..."
if [[ -e "$dmgPath" ]] ;then
	echo -e "The image '$dmgPath' already exists.\nUse 'make clean' to force rebuild."
	exit 0
fi

[[ -e "$pkgPath" ]] || errExit "ERROR: pkg not found: '$pkgPath'!"


echo "Creating temporary directory..."
tempPath="$(mktemp -d -t dmgBuild)"


echo "Running preDmgBuild script..."
if [[ -n "$preDmgBuild" ]]; then
	echo "Run preDmgBuild..."
	"$preDmgBuild"
fi

echo "Building parameters array..."
fileParams=(-file "$pkgPos" "$pkgPath")

if [[ -n "$rmPath" ]] ;then
	echo "Adding the Uninstaller..."
	if [ "$PKG_SIGN" == "1" ] || [ "$CODE_SIGN" == "1" ]; then
		# Copy the uninstaller into the build folder to sign it.
		uninstallerPath="build/$(basename $rmPath)"
		cp -R "$rmPath" "$uninstallerPath"
		# Code sign the uninstaller.
		$SCRIPT_DIR/uninstallerSig.sh "$uninstallerPath"
		rmPath="$uninstallerPath"
	fi
	fileParams=("${fileParams[@]}" -file "$rmPos" "$rmPath")
fi

if [[ -n "$localizeDir" ]]; then
	echo "Adding the localization..."
	mkdir "$tempPath/.localized"
	cp -PR "$localizeDir/" "$tempPath/.localized/"
	fileParams=("${fileParams[@]}" -file "0,0" "$tempPath/.localized")
fi



echo "Creating dmg..."
"$makeDmg" \
	-icon-size "$iconSize" \
	-label-size "$textSize" \
	-window-pos "$windowPos" \
	-window-size "$windowSize" \
	-volname "$volumeName" \
	-image $imgBackground \
	-volicon "$iconDmg" \
	"${fileParams[@]}" \
	"$dmgPath" ||
		errExit "Unable to create dmg!"


echo "Running postDmgBuild script..."
if [[ -n "$postDmgBuild" ]]; then
	"$postDmgBuild"
fi
#-------------------------------------------------------------------------

echo "Information...";
date=$(LC_TIME=en_US date +"%a, %d %b %G %T %z")
size=$(stat -f "%z" "$dmgPath")
sha1=$(shasum "$dmgPath" | cut -d " " -f 1)
echoBold " * Filename: $dmgPath";
echoBold " * Size: $size";
echoBold " * Date: $date";
echoBold " * SHA1: $sha1";
#-------------------------------------------------------------------------


echo "Cleaning up..."
rm -rf "$tempPath" 2>/dev/null

echo "Finish!"

exit 0
