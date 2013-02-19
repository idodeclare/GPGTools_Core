#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
parseConfig


if [[ "$PKG_SIGN" == "1" ]]; then
    echo "Checking the environment..."
	[[ -d "$rmPath" ]] || errExit "I require app '$rmPath' but it does not exit. Aborting."
    
    echo "Signing '$rmPath'..."
    codesign -s "${certNameApp}" -f "$rmPath" || errExit "Can't sign '$rmPath'. Aborting."

    echo "Validating '$rmPath' signature..."
    codesign -v "$rmPath" || errExit "New signature of app '$rmPath' is invalid. Aborting."
else
	echo "uninstallerSig Warning: PKG_SIGN not enabled. Skipping."
fi
