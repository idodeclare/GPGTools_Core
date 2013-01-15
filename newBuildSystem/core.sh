#!/usr/bin/env bash
# Enthällt standard Funktionen für die verschiedenen Shell-Skripte.

function errExit() {
	msg="$* (${BASH_SOURCE[1]##*/}: line ${BASH_LINENO[0]})"
	if [[ -t 1 ]] ;then
		echo -e "\033[1;31m$msg\033[0m" >&2
	else
		echo "$msg" >&2
	fi
	exit 1
}
function echoBold() {
	if [[ -t 1 ]] ;then
		echo -e "\033[1m$*\033[0m"
	else
		echo -e "$*"
	fi
}



function parseConfig() {
	buildDir="build"
	pkgBin="packagesbuild"
	cfFile="Makefile.config"
	verString="__VERSION__"
	buildString="__BUILD__"
	coreDir="${BASH_SOURCE[0]%/*}/.."
	infoPlist=${infoPlist:-"Contents/Info.plist"}


	[ -e "$cfFile" ] ||
		errExit "Can't find $cfFile - wrong directory or can't create DMG from this project..."

	source "$cfFile"
	
	if [[ -f "build/Release/$appName/$infoPlist" ]] ;then
		appVersion=$(/usr/libexec/PlistBuddy -c "print CFBundleVersion" "build/Release/$appName/$infoPlist")
	else
		appVersion=$version
	fi
	
	
	pkgPath="$buildDir/$pkgName"
	dmgName=${dmgName:-"$name-$appVersion.dmg"}
	dmgPath=${dmgPath:-"build/$dmgName"}
	volumeName=${volumeName:-"$name"}
	downloadUrl=${downloadUrl:-"${downloadUrlPrefix}${dmgName}"}

	if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
		PATH="$PATH:/usr/local/bin"
	fi

	#echo "config parsed"
}

#echo "core.sh loaded from '${BASH_SOURCE[1]##*/}'"

