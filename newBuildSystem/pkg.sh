#!/usr/bin/env bash
# Erstellt ein oder mehrere pkg(s). Wenn als pkg-core.sh aufgerufen, werden die entsprechenden core-pkgs erzeugt.

source "${0%/*}/core.sh"
setStandardVars


command -v "$pkgBin" >/dev/null 2>&1 ||
	errExit "I require '$pkgBin' but it's not installed.  Aborting."
[[ -f "$cfFile" ]] ||
	errExit "I require file '$cfFile' but it does not exit.  Aborting."

source "$cfFile"



if [[ "${0##*/}" == "pkg-core.sh" ]] ;then
	# Call as "pkg-core.sh" to build the core pkg.
	varName_pkgProj_name=pkgProj_corename
	pkgProj_names=("${pkgProj_corename[@]}")
else
	# Call with any other name to build the main pkg.
	varName_pkgProj_name=pkgProj_name
	pkgProj_names=("${pkgProj_name[@]}")
fi




[[ -n "$pkgProj_names" ]] ||
	errExit "I require environment variable '$varName_pkgProj_name' to be set but it's not.  Aborting."
[[ -n "$pkgProj_dir" ]] ||
	errExit "I require environment variable 'pkgProj_dir' to be set but it's not.  Aborting."
[[ -d "$pkgProj_dir" ]] ||
	errExit "I require directory '$pkgProj_dir' but it does not exit.  Aborting."
[[ -d "$buildDir" ]] ||
	errExit "I require directory '$buildDir' but it does not exit.  Aborting."
[[ -n "$version" ]] ||
	errExit "I require environment variable 'version' to be set but it's not.  Aborting."
[[ -n "$commitHash" ]] ||
	errExit "I require environment variable 'commitHash' to be set but it's not.  Aborting."


# Auskommentiert in der Hoffnung, dass nicht so viel unnützes, kopiert werden muss.
#cp -R "$pkgProj_dir/" "$buildDir/"


i=0
while [[ -n "${pkgProj_names[$i]}" ]] ;do
	pkgProj="$buildDir/${pkgProj_names[$i]}"
	origPkgProj="$pkgProj_dir/${pkgProj_names[$i]}"

	[[ -f "$origPkgProj" ]] ||
		errExit "I require file '$origPkgProj' but it does not exit.  Aborting."

	sed "s/$verString/$version/g;s/$buildString/$commitHash/g" "$origPkgProj" > "$pkgProj"

	"$pkgBin" "$pkgProj" ||
		errExit "Build of '$pkgProj' failed.  Aborting."
	
	((i++))
done

exit 0
