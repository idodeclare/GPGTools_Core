#!/bin/bash
#
# This script creates a DMG for GPGTools
#
# (c) by Felix Co & Alexander Willner & Roman Zechmeister
#
# Erstellt aus dem pkg ein dmg.

echo "Parsing configuration..."
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
parseConfig

echo "Defining functions..."
function unmount() {
	if [ -n "$mountPoint" ] ;then
		hdiutil detach -quiet "$mountPoint"
	fi	
}

echo "Setting configuration parameter..."
setIcon="$coreDir/bin/setfileicon"
iconDmg="$coreDir/images/icon_dmg.icns"
iconTrash="$coreDir/images/icon_uninstaller.icns"
iconInstaller="$coreDir/images/icon_installer.icns"

tempPath="$(mktemp -d -t dmgBuild)"
tempDmg="$tempPath/temp.dmg"
dmgTempDir="$tempPath/dmg"

pkgPos=${pkgPos:-"160, 220"}
rmPos=${rmPos:-"370, 220"}
iconSize=${iconSize:-"80"}
textSize=${textSize:-"13"}
windowBounds=${windowBounds:-"400, 200, 980, 520"}

echo "Checking environment..."
if [[ -e "$dmgPath" ]] ;then
	echo -e "The image '$dmgPath' already exists.\nUse 'make clean' to force rebuild."
	exit 0
fi

[[ -e "$pkgPath" ]] || errExit "ERROR: pkg not found: '$pkgPath'!"


echo "Hiding pkg file extension..."
xattr -xw com.apple.FinderInfo '0000000000000000001000000000000000000000000000000000000000000000' "$pkgPath"

echo "Trying to fix permissions..."
chmod -Rf +w "$tempPath" "$dmgPath" "$pkgPath" "$rmPath" 2>/dev/null

echo "Trying to fix issues when an on image is still mounted..."
if mountInfo="$(mount | grep -F "$volumeName")" ;then
	echo "Unmount old DMG..."
	hdiutil detach "${mountInfo%% *}"

	mount | grep -qF "$volumeName" &&
		errExit "ERROR: volume '$volumeName' is already mounted!"
fi

echo "Running preDmgBuild script..."
if [ -n "$preDmgBuild" ]; then
	echo "Run preDmgBuild..."
	"$preDmgBuild"
fi

#echo "Removing old files..."
#rm -f "$dmgPath"

echo "Creating temp directory..."
mkdir "$dmgTempDir"

echo "Copying files..."
cp -PR "$pkgPath" "$dmgTempDir/" ||
	errExit "ERROR: could not copy '$pkgPath'!"
if [ -n "$localizeDir" ]; then
	echo "Copy localization files..."
	mkdir "$dmgTempDir/.localized"
	cp -PR "$localizeDir/" "$dmgTempDir/.localized/"
fi

if [ -n "$rmPath" ]; then
	echo "Copy uninstaller..."
	cp -PR "$rmPath" "$dmgTempDir/$rmName"
fi

echo "Copying images..."
mkdir "$dmgTempDir/.background"
cp "$imgBackground" "$dmgTempDir/.background/Background.png"
cp "$iconDmg" "$dmgTempDir/.VolumeIcon.icns"


echo "Setting pkg icon..."
"$setIcon" "$iconInstaller" "$dmgTempDir/$pkgName"

if [ -n "$rmPath" ]; then
	echo "Setting uninstaller icon..."	
	"$setIcon" "$iconTrash" "$dmgTempDir/$rmName"
fi

echo "Fixing for Packages 1.1..."
chmod -R +w $dmgTempDir

echo "Creating DMG..."
hdiutil create -scrub -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -srcfolder "$dmgTempDir" -volname "$volumeName" "$tempDmg" ||
	errExit "ERROR: Create DMG failed!"

trap unmount EXIT

mountInfo=$(hdiutil attach -readwrite -noverify "$tempDmg") ||
	errExit "ERROR: Attach DMG failed!"

device=$(echo "$mountInfo" | head -1 | cut -d " " -f 1)
mountPoint=$(echo "$mountInfo" | tail -1 | sed -En 's/([^	]+[	]+){2}//p')

echo "Setting attributes..."
SetFile -a C "$mountPoint"

if ps -xo command | grep -q "[M]acOS/Finder" ;then # Try to fix the "-10810" error
	echo "Using Finder to set the attributes..."
	osascript >/dev/null <<-EOT
		tell application "Finder"
			tell disk "$volumeName"
				open
				set viewOptions to icon view options of container window
				set current view of container window to icon view
				set toolbar visible of container window to false
				set statusbar visible of container window to false
				set bounds of container window to {$windowBounds}
				set arrangement of viewOptions to not arranged
				set icon size of viewOptions to $iconSize
				set text size of viewOptions to $textSize
				set background picture of viewOptions to file ".background:Background.png"
				set position of item "$pkgName" of container window to {$pkgPos}
			end tell
		end tell
	EOT
	[ $? -eq 0 ] || errExit "ERROR: Set attributes failed!"

	if [ -n "$rmName" ]; then # Set position of the Uninstaller
		osascript >/dev/null <<-EOT
			tell application "Finder"
				tell disk "$volumeName"
					set position of item "$rmName" of container window to {$rmPos}
				end tell
			end tell
		EOT
		[ $? -eq 0 ] || errExit "ERROR: Set position of the Uninstaller failed!"
	fi

	osascript >/dev/null <<-EOT
		tell application "Finder"
			tell disk "$volumeName"
				update without registering applications
				close
			end tell
		end tell
	EOT
	[ $? -eq 0 ] || errExit "ERROR: Update attributes failed!"
else
    echo "Dynamically layouting the DMG is not possible. Looking for static information..."
    if [ -f "$volumeLayout" ]; then
        echo "Found static information. Using it..."
        cp "$volumeLayout" "$mountPoint/.DS_Store"
    else
        echo "Not found static information."
    fi
fi


chmod -Rf +r,go-w "$mountPoint" || errExit "ERROR: chmod failed!"
rm -r "$mountPoint/.Trashes" "$mountPoint/.fseventsd"


echo "Converting DMG..."
hdiutil detach -quiet "$mountPoint"
hdiutil convert "$tempDmg" -format UDZO -imagekey zlib-level=9 -o "$dmgPath" ||
	errExit "ERROR: Convert DMG failed!!"


echo "Running postDmgBuild script..."
if [ -n "$postDmgBuild" ]; then
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
chmod -Rf +w "$tempPath" "$dmgPath" "$pkgPath" "$rmPath" 2>/dev/null
rm -rf "$tempPath" 2>/dev/null

exit 0
