#!/usr/bin/env bash
# Klont GPGTools_Core auf die gleiche Ebene,
# auf der das aktuelle Projekt bzw. dessen Über-Projekt liegt
# und erstellt die nötigen Symlinks.

# Beispiel 1: Aktuelles Projekt /foo/bar/GPGServices
# Legt /foo/bar/GPGTools_Core an.
# Beispiel 2: Aktuelles Projekt /foo/bar/GPGServices/Dependencies/Libmacgpg/Dependencies/pinentry-mac
# Legt ebenfalls /foo/bar/GPGTools_Core an.

# Call with bash -c "$(curl -fsSL http://localhost/test/prepare-core.sh)"


if [[ ${PWD:0:1} != "/" ]] ;then
	echo '$PWD is not an absolut path. Shit!'
	exit 1 # Should never happen. But...
fi


# Search for the topmost project and GPGTools_Core repo.
currentRepo=""
topRepo=""
coreRepo=""
pathToTest=$PWD
while [[ -n "$pathToTest" ]] ;do
	if [[ -d "$pathToTest/.git" ]] ;then
		if [[ "$pathToTest" == "/" ]] ;then
			echo "Your root directory is a git repo. We can't work with this. Aborting"
			exit 1
		fi
		[[ -n "$currentRepo" ]] || currentRepo=$pathToTest
		topRepo=$pathToTest
	fi
	if [[ -d "$pathToTest/GPGTools_Core" ]] ;then
		coreRepo=$pathToTest/GPGTools_Core
	fi
	pathToTest=${pathToTest%/*}
done

if [[ -z "$currentRepo" ]] ;then
	echo "No git repo found. Aborting"
	exit 1
fi

if [[ -z "$coreRepo" ]] ;then
	coreRepo=${topRepo%/*}/GPGTools_Core
	git clone git://github.com/GPGTools/GPGTools_Core.git "$coreRepo"
fi

depsDir=$currentRepo/Dependencies
echo depsDir $depsDir
if [[ -d "$depsDir" ]] ;then
	relPath=$(python -c "import os.path; print os.path.relpath('$coreRepo', '$depsDir')")
	ln -Fs "$relPath" "$depsDir/"
fi

cd $currentRepo
git submodule foreach make init



