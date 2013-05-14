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
	tPkgName=${pkgNames[$i]}
	tPkgProjName=${pkgProj_names[$i]}
	pkgProj=$buildDir/$tPkgProjName
	origPkgProj=$pkgProj_dir/$tPkgProjName
	pkgPath=$buildDir/$tPkgName
	pkgPathSigned=${pkgPath}.signed

	[[ -f "$origPkgProj" ]] ||
		errExit "I require file '$origPkgProj' but it does not exist.  Aborting."

	# pkg nicht neubauen wenn es schon existiert und die Version übereinstimmt.
	if [[ -f "$pkgPath" ]] ;then
		pkgVersion=$(xattr -p org.gpgtools.version "$pkgPath" 2>/dev/null)
		[[ "$pkgVersion" == "$appVersion" ]] && continue
	fi

	# Version und commit-hash ersetzen.
	sed "s/$verString/$appVersion/g;s/$buildString/$commitHash/g" "$origPkgProj" > "$pkgProj"


	# Signing informationen aus dem pkgproj entfernen.
	xmlPath="PROJECT:PROJECT_SETTINGS:CERTIFICATE"
	/usr/libexec/PlistBuddy -c "delete $xmlPath" "$pkgProj" 2>/dev/null


	echo "Building '$pkgProj'..."
	"$pkgBin" "$pkgProj" ||
		errExit "Build of '$pkgProj' failed.  Aborting."
		

	if [[ "$tPkgName" =~ 'Core' ]] ;then
		# Force upgrading instead of updating. See pkgbuild(1) BundleOverwriteAction.
		pkgTemp=${pkgPath}temp
		rm -rf "$pkgTemp"
		mkdir "$pkgTemp"
		xar -x -C "$pkgTemp" -f "$pkgPath" ||
			errExit "Unable to extract pkg.  Aborting."

		bundleId=$(sed -En '/.*<bundle .*id="([^"]*)".*/{s//\1/;p;q;}' "$pkgTemp/PackageInfo")
		if [[ -n "$bundleId" ]] ;then
			sed -i '' -E 's#</pkg-info>#<upgrade-bundle><bundle id="'"$bundleId"'"/></upgrade-bundle></pkg-info>#' "$pkgTemp/PackageInfo" ||
				errExit "Unable to fix PackageInfo.  Aborting."

			pkgutil --flatten "$pkgTemp" "$pkgPath" ||
				errExit "pkgutil --flatten failed.  Aborting."
		fi
	fi


	# pkg signieren.
	if [[ "$PKG_SIGN" == "1" ]] ;then
		keychain=$(security find-certificate -c "$certNameInst" | sed -En 's/^keychain: "(.*)"/\1/p')
		[[ -n "$keychain" ]] ||
			errExit "I require certificate '$certNameInst' but it can't be found.  Aborting."

		# Auskommentiert da direkt signiert wird, um mit 10.6 kompatibel zu sein.
		#/usr/libexec/PlistBuddy -c "add $xmlPath dict" -c "add $xmlPath:NAME string '$certNameInst'" -c "add $xmlPath:PATH string '$keychain'" "$pkgProj"
		
		# Unlock the keychain before using it if a password is given.
		[[ -n "$UNLOCK_PWD" ]] &&
			security unlock-keychain -p "$UNLOCK_PWD" "$keychain"

		# Sign the package
		/usr/bin/productsign --sign "$certNameInst" --keychain "$keychain" "$pkgPath" "$pkgPathSigned"
		# Check if the signing was successful.
		/usr/sbin/pkgutil --check-signature $pkgPathSigned >/dev/null || errExit "Failed to sign $pkgPath."
		# Replace original package with the signed package.
		mv -f "$pkgPathSigned" "$pkgPath"
	fi

	
	# Version als extended attribute setzen, damit das Abfragen der Version einfacher fällt.
	xattr -w org.gpgtools.version "$appVersion" "$pkgPath"
done

exit 0
