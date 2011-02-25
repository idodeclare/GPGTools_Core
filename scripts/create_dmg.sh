#!/bin/bash
#
# This script creates a DMG for GPGTools
#
# (c) by Felix Co & Alexander Willner & Roman Zechmeister
#

pushd "$1" > /dev/null

if [ ! -e Makefile.config ]; then
	echo "Wrong directory..." >&2
	exit 1
fi



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

unset name version appName appPath bundleName pkgProj rmName appsLink dmgName dmgPath imgBackground html bundlePath rmPath releaseDir volumeName downloadUrl downloadUrlPrefix sshKeyname localizeDir


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





#-------------------------------------------------------------------------
read -p "Create DMG [y/n]? " input

if [ "x$input" == "xy" -o "x$input" == "xY" ]; then

	if [ -n "$pkgProj" ]; then
    	if [ -e /usr/local/bin/packagesbuild ]; then
	    	echo "Building the installer..."
		    /usr/local/bin/packagesbuild "$pkgProj"
    	else
	    	echo "ERROR: You need the Application \"Packages\"!" >&2
		    echo "get it at http://s.sudre.free.fr/Software/Packages.html" >&2
    		exit 1
	    fi
	fi


	echo "Removing old files..."
	rm -f "$dmgPath"


	echo "Creating temp directory..."
	mkdir "$dmgTempDir"

	echo "Copying files..."
    cp -PR "$bundlePath" "$dmgTempDir/"

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





	echo "Creating DMG..."
	hdiutil create -scrub -quiet -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -srcfolder "$dmgTempDir" -volname "$volumeName" "$tempDMG"
	mountInfo=$(hdiutil attach -readwrite -noverify "$tempDMG")
	device=$(echo "$mountInfo" | head -1 | cut -d " " -f 1)
	mountPoint=$(echo "$mountInfo" | tail -1 | sed -En 's/([^	]+[	]+){2}//p')



	echo "Setting attributes..."
	SetFile -a C "$mountPoint"

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

	if [ -n "$rmName" ]; then # Set position of the Uninstaller
		osascript >/dev/null <<-EOT
			tell application "Finder"
				tell disk "$volumeName"
					set position of item "$rmName" of container window to {$rmPos}
				end tell
			end tell
		EOT
	fi
	if [ "0$appsLink" -eq 1 ]; then # Set position of the Symlink to /Applications
		osascript >/dev/null <<-EOT
			tell application "Finder"
				tell disk "$volumeName"
					set position of item "Applications" of container window to {$appsLinkPos}
				end tell
			end tell
		EOT
	fi

	osascript >/dev/null <<-EOT
		tell application "Finder"
			tell disk "$volumeName"
				update without registering applications
				close
			end tell
		end tell
	EOT


	chmod -Rf +r,go-w "$mountPoint"
	rm -r "$mountPoint/.Trashes" "$mountPoint/.fseventsd"



	echo "Convert DMG..."
	hdiutil detach -quiet "$mountPoint"
	hdiutil convert "$tempDMG" -quiet -format UDZO -imagekey zlib-level=9 -o "$dmgPath"

	echo "Information...";
	date=$(LC_TIME=en_US date +"%a, %d %b %G %T %z")
	size=$(stat -f "%z" "$dmgPath")
    sha1=$(shasum "$dmgPath")
    echo " * Filename: $dmgPath";
    echo " * Size: $size";
    echo " * Date: $date";
    echo " * SHA1: $sha1";
fi
#-------------------------------------------------------------------------


#-------------------------------------------------------------------------
read -p "Create a detached signature [y/n]? " input

if [ "x$input" == "xy" -o "x$input" == "xY" ]; then
	echo "Removing old signature..."
	rm -f "$dmgPath.sig"

	echo "Signing..."
	gpg2 -bau 76D78F0500D026C4 -o "${dmgPath}.sig"  "$dmgPath"
fi
#-------------------------------------------------------------------------


#-------------------------------------------------------------------------
## todo: update Makefile.conf
####################################################
read -p "Create Sparkle appcast entry [y/n]? " input

if [ "x$input" == "xy" -o "x$input" == "xY" ]; then
	PRIVATE_KEY_NAME="$sshKeyname"

	signature=$(openssl dgst -sha1 -binary < "$dmgPath" |
	  openssl dgst -dss1 -sign <(security find-generic-password -g -s "$PRIVATE_KEY_NAME" 2>&1 >/dev/null | perl -pe '($_) = /<key>NOTE<\/key>.*<string>(.*)<\/string>/; s/\\012/\n/g') |
	  openssl enc -base64)

	date=$(LC_TIME=en_US date +"%a, %d %b %G %T %z")
	size=$(stat -f "%z" "$dmgPath")
	echo -e "\n====== Sparkle appcast: ======\n"

	cat <<-EOT
		<item>
			<title>Version ${version}</title>
			<description>Visit http://www.gpgtools.org/$html.html for further information.</description>
			<sparkle:releaseNotesLink>http://www.gpgtools.org/$html_sparkle.html</sparkle:releaseNotesLink>
			<pubDate>${date}</pubDate>
			<enclosure url="$downloadUrl"
					   sparkle:version="${version}"
					   sparkle:dsaSignature="${signature}"
					   length="${size}"
					   type="application/octet-stream" />
		</item>
	EOT

	echo -e "\n==============================\n"
fi
#-------------------------------------------------------------------------


#-------------------------------------------------------------------------
## todo: implement this
####################################################
read -p "Create github tag [y/n]? " input
if [ "x$input" == "xy" -o "x$input" == "xY" ]; then
    echo "to be implemented. start this e.g. for each release"
fi
#-------------------------------------------------------------------------


echo "Cleanup..."
rm -rf "$tempPath"


popd > /dev/null

