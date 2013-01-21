#!/usr/bin/env bash
# Erstellt ein oder mehrere pkg(s). Wenn als pkg-core.sh aufgerufen, werden die entsprechenden core-pkgs erzeugt.

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
parseConfig


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


if [[ -z "$pkgProj_names" || ! -e "$pkgProj_dir/$pkgProj_names" ]] ;then
	echo "No pkgproj to build.  Exiting"
	exit 0
fi

command -v "$pkgBin" >/dev/null 2>&1 ||
	errExit "I require '$pkgBin' but it's not installed.  Aborting."
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
	pkgPathSigned="${pkgPath}.signed"

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

	# Signing informationen in das pkgproj schreiben oder entfernen.
	xmlPath="PROJECT:PROJECT_SETTINGS:CERTIFICATE"
	/usr/libexec/PlistBuddy -c "delete $xmlPath" "$pkgProj" 2>/dev/null
	if [[ "$PKG_SIGN" == "1" ]] ;then
		certName="Developer ID Installer: Lukas Pitschl"
		keychain=$(security find-certificate -c "$certName" | sed -En 's/^keychain: "(.*)"/\1/p')
		[[ -n "$keychain" ]] ||
			errExit "I require certificate '$certName' but it can't be found.  Aborting."

		/usr/libexec/PlistBuddy -c "add $xmlPath dict" -c "add $xmlPath:NAME string '$certName'" -c "add $xmlPath:PATH string '$keychain'" "$pkgProj"

		# Unlock the keychain before using it if a password is given.
		[[ -n "$UNLOCK_PWD" ]] &&
			security unlock-keychain -p "$UNLOCK_PWD" "$keychain"
	fi

	echo "Building '$pkgProj'..."
	"$pkgBin" "$pkgProj" ||
		errExit "Build of '$pkgProj' failed.  Aborting."
	
	# Version als extended attribute setzen, damit das Abfragen der Version einfacher fällt.
	xattr -w org.gpgtools.version "$appVersion" "$pkgPath"
done

exit 0
