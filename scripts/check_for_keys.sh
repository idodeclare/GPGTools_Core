#!/bin/sh
#
# This skript runs GKA if no private key was found.
#

echo "[GCK] Setup environment..."

#This happen to break the installer on some systems
#[ -r "$HOME/.profile" ] && . "$HOME/.profile"

PATH=$PATH:/usr/local/MacGPG2/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/local/bin
if test "$USER" == ""
then
  USER=$(id -un)
fi

echo "Test for gpg..."
if [ "`which gpg`" == "" ]; then
  echo "[GCK] No GPG found"
  exit 0;
fi

echo "[GCK] Test for GKA..."
if [ ! -e "/Applications/GPG Keychain Access.app" ]; then
  echo "[GCK] No GKA"
  exit 0;
fi

echo "[GCK] Test for keys..."
keys="`su \"$USER\" -c 'gpg --homedir=\"$HOME/.gnupg\" -K 2>/dev/null'`"

echo "[GCK] Open GKA..."
if [ "$keys" == "" ]; then
  sudo -u "$USER" osascript <<-EOT
	tell application "GPG Keychain Access"
	generate new key
	activate
	end tell
EOT
  
  echo "[GCK] Open First Steps page..."
  sudo -u "$USER" open http://support.gpgtools.org/kb/how-to/first-steps-where-do-i-start-where-do-i-begin
else
  echo "[GCK] Sec-Key found"
fi

exit 0;
