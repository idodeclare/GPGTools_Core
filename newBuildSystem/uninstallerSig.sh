#!/usr/bin/env bash
# Erstellt eine Sparkle-Signatur für das dmg.

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
parseConfig

devID="Developer ID Application: Lukas Pitschl"

[[ "$PKG_SIGN" == "1" ]] || echo "Warning: PKG_SIGN not enabled. Skipping."

#TODO: Test auf Jenkins einbauen ($JENKINS ist nur ein Platzhalter!)
if [[ "$PKG_SIGN" == "1" && -z "$JENKINS" ]]; then
    echo "Checking the environment..."
	[[ -d "$rmPath" ]] || errExit "I require app '$rmPath' but it does not exit. Aborting."
    
    echo "Signing '$rmPath'..."
    codesign -s "${devID}" -f "$rmPath" || errExit "Can't sign '$rmPath'. Aborting."

    echo "Validating '$rmPath' signature..."
    codesign -v "$rmPath" || errExit "New signature of app '$rmPath' is invalid. Aborting."
fi
