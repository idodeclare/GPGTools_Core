#!/bin/sh
#
# This skript runs GKA if no private key was found.
#

keys="`gpg --list-secret-keys 2>/dev/null`";

if [ "$keys" == "" ]; then
  open -a "GPG Keychain Access" --args --gen-key
  exit 1;
fi

exit 0;
