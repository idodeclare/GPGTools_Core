#!/bin/bash
#
# This script uploads a DMG for GPGTools
#
# @author   Alex
#

#pushd "$1" > /dev/null

if [ ! -e Makefile.config ]; then
	echo "Wrong directory..." >&2
	exit 1
fi

#config ------------------------------------------------------------------
source "Makefile.config"

releaseDir=${releaseDir:-"build/Release"}
appName=${appName:-"$name.app"}
appPath=${appPath:-"$releaseDir/$appName"}
if [ -z "$version" ]; then
	version=$(/usr/libexec/PlistBuddy -c "print CFBundleShortVersionString" "$appPath/Contents/Info.plist")
fi
dmgName=${dmgName:-"$name-$version.dmg"}
dmgPath=${dmgPath:-"build/$dmgName"}
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
if [ "`which github_upload`" == "" ]; then
  echo "ERROR: You need the Application \"github_upload\"!" >&2
  echo "get it at https://github.com/GPGTools/upload" >&2
  exit 1
fi

if [ "$dmgPath" == "" -o "$dmgUrl" == "" -o "$version" == "" -o ! -e "$dmgPath" ] ; then
  echo "ERROR: config not complete".
  exit 2
fi

github_upload "$dmgPath" "$dmgUrl"
#-------------------------------------------------------------------------
