#!/bin/sh
#
# This skript runs GKA if no private key was found.
#

[ -r "$HOME/.profile" ] && . "$HOME/.profile"
PATH=$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/local/bin

keys="`gpg --homedir=$HOME/.gnupg  --list-secret-keys 2>/dev/null`";

if [ "$keys" == "" ]; then
  open -a "GPG Keychain Access" --args --gen-key
fi

exit 0;
