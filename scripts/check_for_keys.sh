#!/bin/sh
#
# This skript runs GKA if no private key was found.
#

keys="`gpg --homedir=$USER/.gnupg  --list-secret-keys 2>/dev/null`";

if [ "$keys" == "" ]; then
  open -a "GPG Keychain Access" --args --gen-key
fi

exit 0;
