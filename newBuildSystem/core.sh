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



function setStandardVars() {
	buildDir="build"
	pkgBin="packagesbuild"
	cfFile="Makefile.config"
	verString="__VERSION__"
	buildString="__BUILD__"
	coreDir="${0%/*}/.."
}

function parseConfig() {
	[ -e "$cfFile" ] ||
		errExit "Can't find $cfFile - wrong directory or can't create DMG from this project..."

	source "$cfFile"
	
	pkgPath="$buildDir/$pkgName"
	dmgName=${dmgName:-"$name-$version.dmg"}
	dmgPath=${dmgPath:-"build/$dmgName"}
	volumeName=${volumeName:-"$name"}
	downloadUrl=${downloadUrl:-"${downloadUrlPrefix}${dmgName}"}
}


