#!/usr/bin/env bash
# Erstellt ein oder mehrere pkg(s). Wenn als pkg-core.sh aufgerufen, werden die entsprechenden core-pkgs erzeugt.

source "${0%/*}/core.sh"
parseConfig

echo "DEBUG========"
set
which packagesbuild
command -v packagesbuild
which "$pkgBin"
command -v "$pkgBin"

command -v "$pkgBin" >/dev/null 2>&1 ||
	errExit "I require '$pkgBin' but it's not installed.  Aborting."



if [[ "${0##*/}" == "pkg-core.sh" ]] ;then
	# Call as "pkg-core.sh" to build the core pkg.
	varName_pkgProj_name=pkgProj_corename
	pkgProj_names=("${pkgProj_corename[@]}")
	pkgNames=("${pkgCoreName[@]}")
else
	# Call with any other name to build the main pkg.
	varName_pkgProj_name=pkgProj_name
	pkgProj_names=("${pkgProj_name[@]}")
	pkgNames=("${pkgName[@]}")
fi




[[ -n "$pkgProj_names" ]] ||
	errExit "I require environment variable '$varName_pkgProj_name' to be set but it's not.  Aborting."
[[ -n "$pkgProj_dir" ]] ||
	errExit "I require environment variable 'pkgProj_dir' to be set but it's not.  Aborting."
[[ -d "$pkgProj_dir" ]] ||
	errExit "I require directory '$pkgProj_dir' but it does not exit.  Aborting."
[[ -d "$buildDir" ]] ||
	errExit "I require directory '$buildDir' but it does not exit.  Aborting."
[[ -n "$appVersion" ]] ||
	errExit "I require environment variable 'appVersion' to be set but it's not.  Aborting."
[[ -n "$commitHash" ]] ||
	errExit "I require environment variable 'commitHash' to be set but it's not.  Aborting."


# Auskommentiert in der Hoffnung, dass nicht so viel unnützes, kopiert werden muss.
#cp -R "$pkgProj_dir/" "$buildDir/"


i=-1
while [[ -n "${pkgProj_names[$((++i))]}" ]] ;do
	pkgProj="$buildDir/${pkgProj_names[$i]}"
	origPkgProj="$pkgProj_dir/${pkgProj_names[$i]}"
	pkgPath="${pkgNames[$i]:+build/${pkgNames[$i]}}"
	
	if [[ -n "$pkgPath" ]] ;then
		# pkg nicht neubauen wenn es schon existiert und die Version übereinstimmt.
		pkgPath="$buildDir/${pkgNames[$i]}"
		if [[ -f "$pkgPath" ]] ;then
			pkgVersion=$(xattr -p org.gpgtools.version "$pkgPath" 2>/dev/null)
			[[ "$pkgVersion" == "$appVersion" ]] && continue
		fi
	fi


	[[ -f "$origPkgProj" ]] ||
		errExit "I require file '$origPkgProj' but it does not exit.  Aborting."

	sed "s/$verString/$appVersion/g;s/$buildString/$commitHash/g" "$origPkgProj" > "$pkgProj"

	echo "Building '$pkgProj'..."
	"$pkgBin" "$pkgProj" ||
		errExit "Build of '$pkgProj' failed.  Aborting."

	if [[ -n "$pkgPath" ]] ;then
		xattr -w org.gpgtools.version "$appVersion" "$pkgPath"
	fi
done

exit 0
