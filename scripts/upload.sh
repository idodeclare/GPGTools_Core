#!/bin/bash
#
# This script uploads a DMG for GPGTools
#
# @author   Alex
#

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
if [ "`which ruby`" == "" ]; then
  echo "ERROR: You need ruby!" >&2
  exit 1
fi

if [ "$dmgPath" == "" -o "$dmgUrl" == "" -o "$version" == "" -o ! -e "$dmgPath" ] ; then
  echo "ERROR: config not complete" >&2
  echo " * dmgPath: $dmgPath" >&2
  echo " * dmgUrl: $dmgUrl" >&2
  echo " * version: $version" >&2
  exit 2
fi

ruby ./Dependencies/GPGTools_Core/scripts/github_upload.rb "$dmgPath" "$dmgUrl"
#-------------------------------------------------------------------------
