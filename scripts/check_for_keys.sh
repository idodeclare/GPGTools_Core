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


if [[ -z "$keys" ]]; then
	echo "[GCK] No Sec-Key found"
	
	if [[ "$COMMAND_LINE_INSTALL" -eq 1 ]] ;then
		echo "[GCK] No GUI"
	else
		echo "[GCK] Open GKA..."
		sudo -u "$USER" osascript <<-EOT
			tell application "GPG Keychain Access"
			generate new key
			activate
			end tell
EOT
	fi
  
else
    echo "[GCK] Sec-Key found"
fi


exit 0;
