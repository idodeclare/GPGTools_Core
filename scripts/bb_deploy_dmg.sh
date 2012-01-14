#!/bin/bash
unset name version appName appPath bundleName pkgProj rmName appsLink \
        dmgName dmgPath imgBackground html bundlePath rmPath releaseDir \
        volumeName downloadUrl downloadUrlPrefix sshKeyname localizeDir mountPoint



if [ ! -e Makefile.config ]; then
   echo "Wrong directory..."
   exit 1
fi

if [ ! -d "$1" ]; then
  echo "Usage: $0 <directory>"
  exit 2
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


echo "Copying '$dmgPath' to '$1'..."
cp "$dmgPath" "$1"

echo "Done."
exit 0
