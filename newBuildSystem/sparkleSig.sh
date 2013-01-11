#!/usr/bin/env bash
# Erstellt eine Sparkle-Signatur für das dmg.

source "${0%/*}/core.sh"
parseConfig


#TODO: Test auf Jenkins einbauen ($JENKINS ist nur ein Platzhalter!)
if [[ -n "$sshKeyname" && -z "$JENKINS" ]]; then
	[[ -f "$dmgPath" ]] || errExit "I require file '$dmgPath' but it does not exit.  Aborting."

	signature=$(openssl dgst -sha1 -binary < "$dmgPath" |
	  openssl dgst -dss1 -sign <(security find-generic-password -g -s "$sshKeyname" 2>&1 >/dev/null |
	  perl -pe '($_) = /<key>NOTE<\/key>.*<string>(.*)<\/string>/; s/\\012/\n/g') |
	  openssl enc -base64)

    echoBold " * Sparkle signature: $signature";
fi
