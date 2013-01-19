#!/usr/bin/env bash
# Erstellt ein oder mehrere pkg(s). Wenn als pkg-core.sh aufgerufen, werden die entsprechenden core-pkgs erzeugt.

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
parseConfig

command -v "$pkgBin" >/dev/null 2>&1 ||
	errExit "I require '$pkgBin' but it's not installed.  Aborting."



if [[ "${0##*/}" == "pkg-core.sh" ]] ;then
	# Call as "pkg-core.sh" to build the core pkg.
	varName_pkgProj_name=pkgProj_corename
	varName_pkgName=pkgCoreName
	pkgProj_names=("${pkgProj_corename[@]}")
	pkgNames=("${pkgCoreName[@]}")
else
	# Call with any other name to build the main pkg.
	varName_pkgProj_name=pkgProj_name
	varName_pkgName=pkgName
	pkgProj_names=("${pkgProj_name[@]}")
	pkgNames=("${pkgName[@]}")
fi




[[ -n "$pkgProj_names" ]] ||
	errExit "I require environment variable '$varName_pkgProj_name' to be set but it's not.  Aborting."
[[ -n "$pkgProj_dir" ]] ||
	errExit "I require environment variable 'pkgProj_dir' to be set but it's not.  Aborting."
[[ -d "$pkgProj_dir" ]] ||
	errExit "I require directory '$pkgProj_dir' but it does not exist.  Aborting."
[[ -d "$buildDir" ]] ||
	errExit "I require directory '$buildDir' but it does not exist.  Aborting."
[[ -n "$appVersion" ]] ||
	errExit "I require environment variable 'appVersion' to be set but it's not.  Aborting."
[[ -n "$commitHash" ]] ||
	errExit "I require environment variable 'commitHash' to be set but it's not.  Aborting."

[[ ${#pkgProj_names[*]} -eq ${#pkgNames[*]} ]] ||
	errExit "The variables '$varName_pkgProj_name' and '$varName_pkgName' doesn't have the same number of items.  Aborting."




i=-1
while [[ -n "${pkgProj_names[$((++i))]}" ]] ;do
	pkgProj="$buildDir/${pkgProj_names[$i]}"
	origPkgProj="$pkgProj_dir/${pkgProj_names[$i]}"
	pkgPath="build/${pkgNames[$i]}"

	[[ -f "$origPkgProj" ]] ||
		errExit "I require file '$origPkgProj' but it does not exist.  Aborting."

	# pkg nicht neubauen wenn es schon existiert und die Version übereinstimmt.
	pkgPath="$buildDir/${pkgNames[$i]}"
	if [[ -f "$pkgPath" ]] ;then
		pkgVersion=$(xattr -p org.gpgtools.version "$pkgPath" 2>/dev/null)
		[[ "$pkgVersion" == "$appVersion" ]] && continue
	fi

	# Version und commit-hash ersetzen.
	sed "s/$verString/$appVersion/g;s/$buildString/$commitHash/g" "$origPkgProj" > "$pkgProj"

	xmlPath="PROJECT:PROJECT_SETTINGS:CERTIFICATE"
	if [[ "$PKG_SIGN" == "1" ]] ;then
		certificateName="Developer ID Installer: Lukas Pitschl"
		keychain=$(security find-certificate -c "$certificateName" | sed -En 's/^keychain: "(.*)"/\1/p')
		[[ -n "$keychain" ]] ||
			errExit "I require certificate '$certificateName' but it can't be found.  Aborting."

		/usr/libexec/PlistBuddy -c "delete $xmlPath" -c "add $xmlPath dict" -c "add $xmlPath:NAME string '$certName'" -c "add $xmlPath:PATH string '$keychain'" "$pkgProj"
	else
		/usr/libexec/PlistBuddy -c "delete $xmlPath" "$pkgProj"
	fi

	echo "Building '$pkgProj'..."
	"$pkgBin" "$pkgProj" ||
		errExit "Build of '$pkgProj' failed.  Aborting."
	
	# Version als extended attribute setzen, damit das Abfragen der Version einfacher fällt.
	xattr -w org.gpgtools.version "$appVersion" "$pkgPath"
done

exit 0
