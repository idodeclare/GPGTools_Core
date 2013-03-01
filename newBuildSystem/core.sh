#!/usr/bin/env bash
# Enthällt standard Funktionen für die verschiedenen Shell-Skripte.

# global variables -------------------------------------------------------------
certNameApp="Developer ID Application: Lukas Pitschl"
certNameInst="Developer ID Installer: Lukas Pitschl"
# ------------------------------------------------------------------------------

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
	buildDir=build
	pkgBin=packagesbuild
	cfFile=Makefile.config
	verString=__VERSION__
	buildString=__BUILD__
	coreDir=$(dirname "${BASH_SOURCE[0]}")/..
	infoPlist=${infoPlist:-Contents/Info.plist}


	[ -e "$cfFile" ] ||
		errExit "Can't find $cfFile - wrong directory or can't create DMG from this project..."

	source "$cfFile"
	
	if [[ -f "build/Release/$appName/$infoPlist" ]] ;then
		appVersion=$(/usr/libexec/PlistBuddy -c "print CFBundleVersion" "build/Release/$appName/$infoPlist")
		hrVersion=$(/usr/libexec/PlistBuddy -c "print CFBundleShortVersionString" "build/Release/$appName/$infoPlist")
	else
		appVersion=$build_version
		hrVersion=$version
	fi

	#appVersion: internal Version. (15n or 15)
	#hrVersion: human-readable version. "2.0b5 (3fec296+)" or "2.0".

	pkgProj_dir=${pkgProj_dir:-Installer}
	pkgProj_corename=${pkgProj_corename:-${name}_Core.pkgproj}
	pkgCoreName=${pkgCoreName:-${name}_Core.pkg}
	pkgProj_name=${pkgProj_name:-${name}.pkgproj}
	pkgName=${pkgName:-${name}.pkg}
	pkgPath=$buildDir/$pkgName
	if $isMasterBranch ;then
		dmgName=${dmgName:-$name-$hrVersion.dmg}
	else
		dmgName=${dmgName:-$name-$appVersion.dmg}
	fi
	dmgPath=${dmgPath:-build/$dmgName}
	volumeName=${volumeName:-$name}
	[[ -n "$rmName" ]] && rmPath=${rmPath:-$pkgProj_dir/$rmName}

	if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
		PATH="$PATH:/usr/local/bin"
	fi

	#echo "config parsed"
}

printConfig() {
	parseConfig
	echo "name: ${name}"
	echo "pkgProj_dir: ${pkgProj_dir}"
	echo "pkgProj_corename: ${pkgProj_corename}"
	echo "pkgCoreName: ${pkgCoreName}"
	echo "pkgProj_name: ${pkgProj_name}"
	echo "pkgName: ${pkgName}"
	echo "pkgPath: ${pkgPath}"
	echo "dmgName: ${dmgName}"
	echo "dmgPath: ${dmgPath}"
	echo "volumeName: ${volumeName}"
	echo "rmPath: ${rmPath}"
	echo "appVersion: ${appVersion}"
	echo "hrVersion: $hrVersion"
	echo "MAJOR: ${MAJOR}"
	echo "MINOR: ${MINOR}"
	echo "REVISION: ${REVISION}"
	echo "PRERELEASE: ${PRERELEASE}"
	echo "commitHash: ${commitHash}"
	echo "versionType: ${versionType}"
	echo "version: ${version}"
	echo "build_version: ${build_version}"
}

if [ "$1" == "print-config" ]; then
	printConfig
fi

#echo "core.sh loaded from '${BASH_SOURCE[1]##*/}'"

