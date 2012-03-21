#!/bin/bash
unset name version appName appPath bundleName pkgProj rmName appsLink \
        dmgName dmgPath imgBackground html bundlePath rmPath releaseDir \
        volumeName downloadUrl downloadUrlPrefix sshKeyname localizeDir \
        mountPoint buildNumber


if [ ! -e Makefile.config ]; then
   echo "Wrong directory..."
   exit 1
fi

if [ ! -d "$1" ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

echo "Reading config..."
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

if [ "$name" == "GPGMail" ] ;then
	buildNumber="-$(/usr/libexec/PlistBuddy -c "print BuildNumber" "$appPath/Contents/Info.plist")" || unset buildNumber
fi
baseName="${name}${bbSpecial}"
bbName="${baseName}-trunk${buildNumber}.dmg"
linkName="${baseName}-latest.dmg"

if [ ! -e "$dmgPath" ] ;then
	echo "\"$dmgPath\" couldn't be found!"
	exit 2	
fi

echo "Remove old disk images..."
rm -f "$1/${baseName}"*".dmg"

echo "Copying '$dmgPath' to '$1/$bbName'..."
cp "$dmgPath" "$1/$bbName"

echo "Create link '$linkName'..."
ln -s "$bbName" "$1/$linkName"

echo "Fixing permissions..."
chmod +r "$1/$bbName" "$1/$linkName"
