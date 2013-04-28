#!/usr/bin/env bash
# Klont Libmacgpg auf die gleiche Ebene,
# auf der das aktuelle Projekt bzw. dessen Über-Projekt liegt
# und erstellt die nötigen Symlinks.

# Beispiel 1: Aktuelles Projekt /foo/bar/GPGServices
# Legt /foo/bar/Libmacgpg an.
# Beispiel 2: Aktuelles Projekt /foo/bar/GPGServices/Dependencies/x/Dependencies/y
# Legt ebenfalls /foo/bar/Libmacgpg an.

# Call with bash -c "$(curl -fsSL https://raw.github.com/GPGTools/GPGTools_Core/master/newBuildSystem/prepare-libmacgpg.sh)"


if [[ ${PWD:0:1} != "/" ]] ;then
	echo '$PWD is not an absolut path. Shit!'
	exit 1 # Should never happen. But...
fi


# Search for the topmost project and Libmacgpg repo.
currentRepo=""
topRepo=""
libRepo=""
pathToTest=$PWD
while [[ -n "$pathToTest" ]] ;do
	if [[ -e "$pathToTest/.git" ]] ;then
		if [[ "$pathToTest" == "/" ]] ;then
			echo "Your root directory is a git repo. We can't work with this. Aborting"
			exit 1
		fi
		if [[ -z "$currentRepo" ]] ;then
			currentRepo=$pathToTest
		fi
		topRepo=$pathToTest
	fi
	if [[ -d "$pathToTest/Libmacgpg" ]] ;then
		libRepo=$pathToTest/Libmacgpg
	fi
	pathToTest=${pathToTest%/*}
done


if [[ -z "$currentRepo" ]] ;then
	echo "No git repo found. Aborting"
	exit 1
fi

if [[ -z "$libRepo" ]] ;then
	libRepo=${topRepo%/*}/Libmacgpg
	git clone -b dev --recursive git://github.com/GPGTools/Libmacgpg.git "$libRepo"
fi

depsDir=$currentRepo/Dependencies
if [[ -d "$depsDir" ]] ;then
	relPath=$(python -c "import os.path; print os.path.relpath('$libRepo', '$depsDir')")
	ln -Fs "$relPath" "$depsDir/"
fi

cd "$currentRepo"
git submodule foreach 'make -q init 2>/dev/null && make init ||:'


