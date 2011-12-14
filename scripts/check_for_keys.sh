#!/bin/sh
#
# This skript runs GKA if no private key was found.
#

echo "Setup environment..."
[ -r "$HOME/.profile" ] && . "$HOME/.profile"
PATH=$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/local/bin

echo "Test for gpg..."
if [ "`which gpg`" == "" ]; then
  echo "[Keys] No GPG found"
  exit 0;
fi

echo "Test for GKA..."
if [ ! -e "/Applications/GPG Keychain Access.app" ]; then
  echo "[Keys] No GKA"
  exit 0;
fi

echo "Test for keys..."
keys="`gpg --homedir=$HOME/.gnupg -K 2>/dev/null`";
sudo chown -R $USER "$HOME/.gnupg"

echo "Open GKA..."
if [ "$keys" == "" ]; then
  su $USER -c "/Applications/GPG\ Keychain\ Access.app/Contents/MacOS/GPG\ Keychain\ Access --gen-key" &
else
  echo "[Keys] Sec-Key found"
fi

exit 0;
