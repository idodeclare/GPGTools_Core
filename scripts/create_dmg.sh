#!/bin/bash
#
# This script creates a DMG for GPGTools
#
# (c) by Felix Co & Alexander Willner & Roman Zechmeister
#

#pushd "$1" > /dev/null

function errExit() {
	echo -e "\033[1;31m$* (line ${BASH_LINENO[0]})\033[0m" >&2

	if [ -n "$mountPoint"] ;then
		hdiutil detach -quiet "$mountPoint"
	fi

	exit 1
}
function echoBold() {
	echo -e "\033[1m$*\033[0m"
}

#config ------------------------------------------------------------------
setIcon="./Dependencies/GPGTools_Core/bin/setfileicon"
imgDmg="./Dependencies/GPGTools_Core/images/icon_dmg.icns"
imgTrash="./Dependencies/GPGTools_Core/images/icon_uninstaller.icns"
imgInstaller="./Dependencies/GPGTools_Core/images/icon_installer.icns"

tempPath="$(mktemp -d -t dmgBuild)"
tempDMG="$tempPath/temp.dmg"
dmgTempDir="$tempPath/dmg"


appPos="160, 220"
rmPos="370, 220"
appsLinkPos="410, 130"
iconSize=80
textSize=13

unset name version appName appPath bundleName pkgProj rmName appsLink \
	dmgName dmgPath imgBackground html bundlePath rmPath releaseDir \
	volumeName downloadUrl downloadUrlPrefix sshKeyname localizeDir mountPoint



[ -e Makefile.config ] ||
	errExit "Wrong directory..."

source "Makefile.config"


releaseDir=${releaseDir:-"build/Release"}
appName=${appName:-"$name.app"}
appPath=${appPath:-"$releaseDir/$appName"}
bundleName=${bundleName:-"$appName"}
bundlePath=${bundlePath:-"$releaseDir/$bundleName"}
if [ -z "$version" ]; then
	version=$(/usr/libexec/PlistBuddy -c "print CFBundleShortVersionString" "$appPath/Contents/Info.plist")
fi
dmgName=${dmgName:-"$name-$version.dmg"}
dmgPath=${dmgPath:-"build/$dmgName"}
volumeName=${volumeName:-"$name"}
downloadUrl=${downloadUrl:-"${downloadUrlPrefix}${dmgName}"}
#-------------------------------------------------------------------------

auto="0";
forcetag="-f"
buildbot="n"
for var in "$@"; do
	if [ "$var" == "auto" ]; then
		auto="1"; input="y"
	elif [ "$var" == "no-force-tag" ]; then
		forcetag=""
	elif [ "$var" == "buildbot" ]; then
		buildbot="y"
	fi
done



#-------------------------------------------------------------------------
# doesn't work reliable
#read -p "Update version strings to '$version' [y/n]? " input
#if [ "x$input" == "xy" -o "x$input" == "xY" ]; then
#    if [ "$pkgReadme" == "" ]; then
#      echo "Add 'pkgReadme' to Makefile.config";
#    exit 2;
#    fi
#    if [ ! "$pkgInfo" == "" ]; then
#        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion '${version}'" $pkgInfo
#    fi
#    if [ ! "$pkgProj" == "" ]; then
#      /usr/libexec/PlistBuddy -c "Set :PACKAGES:0:PACKAGE_SETTINGS:VERSION '${version}'" $pkgProj
#    fi
#    if [ ! "$pkgReadme" == "" ]; then
#      sed -i '' "s/^Version: .*/Version: $version/g" $pkgReadme
#    fi
#fi



#-------------------------------------------------------------------------
if [ "$auto" != "1" ]; then
	read -p "Create github tag for version '$version' [y/n]? " input
fi
if [ "x$input" == "xy" -o "x$input" == "xY" ] && [ "$buildbot" == "n" ]; then
	git pull && git commit -m "Missing commits for version $version" .
	git push
	git tag $forcetag -u 76D78F0500D026C4 -m "Version $version" "$version" || errExit "ERROR: Can not create github tag!" # Prevent unwanted overriding of an existing tag.
	git push --tags
fi
#-------------------------------------------------------------------------




if [ "$auto" != "1" ]; then
  read -p "Create DMG [y/n]? " input
fi

if [ "x$input" == "xy" -o "x$input" == "xY" ]; then

	if [ -n "$pkgProj" ]; then
    	[ -e /usr/local/bin/packagesbuild ] ||
			errExit "ERROR: You need the Application \"Packages\"!\nget it at http://s.sudre.free.fr/Software/Packages.html"

		echo "Building the installer..."
		[ "$pkgProj_core" != "" ] && /usr/local/bin/packagesbuild "$pkgProj_core"
		/usr/local/bin/packagesbuild "$pkgProj" ||
			errExit "ERROR: installer failed!"
	fi
    if [ "`mount|grep $volumeName`" != "" ]; then
        errExit "ERROR: volume '$volumeName' is already mounted!"
    fi

	echo "Removing old files..."
	rm -f "$dmgPath"


	echo "Creating temp directory..."
	mkdir "$dmgTempDir"

	echo "Copying files..."
    cp -PR "$bundlePath" "$dmgTempDir/" ||
		errExit "ERROR: could not copy '$bundlePath'!"


	if [ -n "$localizeDir" ]; then
		mkdir "$dmgTempDir/.localized"
        cp -PR "$localizeDir/" "$dmgTempDir/.localized/"
    fi
    if [ -n "$rmPath" ]; then
        cp -PR "$rmPath" "$dmgTempDir/$rmName"
    fi
	if [ "0$appsLink" -eq 1 ]; then
		ln -s /Applications "$dmgTempDir/"
	fi
	mkdir "$dmgTempDir/.background"
	cp "$imgBackground" "$dmgTempDir/.background/Background.png"
	cp "$imgDmg" "$dmgTempDir/.VolumeIcon.icns"


	if [ -n "$pkgProj" ]; then
		"$setIcon" "$imgInstaller" "$dmgTempDir/$bundleName"
	fi
	if [ -n "$rmPath" ]; then
        "$setIcon" "$imgTrash" "$dmgTempDir/$rmName"
    fi

        # Fix for Packages 1.1
        chmod -R +w $dmgTempDir

	echo "Creating DMG..."
	hdiutil create -scrub -quiet -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -srcfolder "$dmgTempDir" -volname "$volumeName" "$tempDMG" ||
		errExit "ERROR: Create DMG failed!"

	mountInfo=$(hdiutil attach -readwrite -noverify "$tempDMG") ||
		errExit "ERROR: Attach DMG failed!"

	device=$(echo "$mountInfo" | head -1 | cut -d " " -f 1)
	mountPoint=$(echo "$mountInfo" | tail -1 | sed -En 's/([^	]+[	]+){2}//p')



	echo "Setting attributes..."
	echo "1"
	SetFile -a C "$mountPoint"

	echo "2"
	osascript >/dev/null <<-EOT
		tell application "Finder"
			tell disk "$volumeName"
				open
				set viewOptions to icon view options of container window
				set current view of container window to icon view
				set toolbar visible of container window to false
				set statusbar visible of container window to false
				set bounds of container window to {400, 200, 580 + 400, 320 + 200}
				set arrangement of viewOptions to not arranged
				set icon size of viewOptions to $iconSize
				set text size of viewOptions to $textSize
				set background picture of viewOptions to file ".background:Background.png"
				set position of item "$bundleName" of container window to {$appPos}
			end tell
		end tell
	EOT
	[ $? -eq 0 ] || errExit "ERROR: Set attributes failed!"

	echo "3"
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
	echo "4"
	if [ "0$appsLink" -eq 1 ]; then # Set position of the Symlink to /Applications
		osascript >/dev/null <<-EOT
			tell application "Finder"
				tell disk "$volumeName"
					set position of item "Applications" of container window to {$appsLinkPos}
				end tell
			end tell
		EOT
		[ $? -eq 0 ] || errExit "ERROR: Set position of Applications-Symlink failed!"
	fi

	echo "5"
	osascript >/dev/null <<-EOT
		tell application "Finder"
			tell disk "$volumeName"
				update without registering applications
				close
			end tell
		end tell
	EOT
	[ $? -eq 0 ] || errExit "ERROR: Update attributes failed!"


	echo "6"
	chmod -Rf +r,go-w "$mountPoint" || errExit "ERROR: chmod failed!"
	rm -r "$mountPoint/.Trashes" "$mountPoint/.fseventsd"


	echo "7"
	echo "Converting DMG..."
	hdiutil detach -quiet "$mountPoint"
	hdiutil convert "$tempDMG" -quiet -format UDZO -imagekey zlib-level=9 -o "$dmgPath" ||
		errExit "ERROR: Convert DMG failed!!"

fi
#-------------------------------------------------------------------------


[ -e "$dmgPath" ] || errExit "No DMG... Exiting"

echo "Information...";
date=$(LC_TIME=en_US date +"%a, %d %b %G %T %z")
size=$(stat -f "%z" "$dmgPath")
sha1=$(shasum "$dmgPath" | cut -d " " -f 1)
echoBold " * Filename: $dmgPath";
echoBold " * Size: $size";
echoBold " * Date: $date";
echoBold " * SHA1: $sha1";




#-------------------------------------------------------------------------

if [ "$auto" != "1" ]; then
  read -p "Create a detached signature [y/n]? " input
fi

if [ "x$input" == "xy" -o "x$input" == "xY" ] && [ "$buildbot" == "n"  ] ; then
	echo "Removing old signature..."
	rm -f "$dmgPath.sig"

	echo "Signing..."
	gpg2 -bau 76D78F0500D026C4 -o "${dmgPath}.sig"  "$dmgPath"

	gpg2 --verify "${dmgPath}.sig" "$dmgPath" >/dev/null 2>&1 ||
		errExit "ERROR: Sign failed!"
fi
#-------------------------------------------------------------------------


#-------------------------------------------------------------------------
if [ "$sshKeyname" != "" ] && [ "$buildbot" == "n" ]; then
	if [ "$auto" != "1" ]; then
		read -p "Create Sparkle signature [y/n]? " input
	fi
    if [ "x$input" == "xy" -o "x$input" == "xY" ]; then
	PRIVATE_KEY_NAME="$sshKeyname"

	signature=$(openssl dgst -sha1 -binary < "$dmgPath" |
	  openssl dgst -dss1 -sign <(security find-generic-password -g -s "$PRIVATE_KEY_NAME" 2>&1 >/dev/null | perl -pe '($_) = /<key>NOTE<\/key>.*<string>(.*)<\/string>/; s/\\012/\n/g') |
	  openssl enc -base64)

    echoBold " * Sparkle signature: $signature";
    fi
fi
#-------------------------------------------------------------------------


echo "Cleanup..."
chmod -R +w "$tempPath"
rm -rf "$tempPath"


#popd > /dev/null

