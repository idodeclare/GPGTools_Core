#!/usr/bin/env bash
# Erstellt eine detached signature für das dmg.

source "${0%/*}/core.sh"
setStandardVars
parseConfig


#TODO: Test auf Jenkins einbauen ($JENKINS ist nur ein Platzhalter!)
if [[ -z "$JENKINS" ]] ; then
	echo "Removing old signature..."
	rm -f "$dmgPath.sig"

	echo "Signing..."
	gpg2 -bau 76D78F0500D026C4 -o "$dmgPath.sig"  "$dmgPath"

	gpg2 --verify "$dmgPath.sig" "$dmgPath" >/dev/null 2>&1 ||
		errExit "ERROR: Sign failed!"
fi
