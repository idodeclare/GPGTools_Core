#!/bin/sh
#
# This skript runs GKA if no private key was found.
#

[ -r "$HOME/.profile" ] && . "$HOME/.profile"
PATH=$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/local/bin

if [ "`which gpg`" == "" ]; then
  echo "[Keys] No GPG found"
  exit 0;
fi

if [ ! -e "/Applications/GPG Keychain Access.app" ]; then
  echo "[Keys] No GKA"
  exit 0;
fi

keys="`gpg --homedir=$HOME/.gnupg -K 2>/dev/null`";
sudo chown -R $USER "$HOME/.gnupg"

if [ "$keys" == "" ]; then
  # open -a ... doesn't work as root
  open "/Applications/GPG Keychain Access.app" --args --gen-key
else
  echo "[Keys] Sec-Key found"
fi

exit 0;
