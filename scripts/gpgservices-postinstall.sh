#!/bin/sh

# Old version must not run in the background
killall GPGServices
sleep 1
killall -9 GPGServices

# Where to install it
_target="/Library/Services/"
if [ -e "$HOME/Library/Services/GPGServices.service" ]; then
    _target="$HOME/Library/Services/"
    chown -R "$USER" "$_target"
fi

# Remove (old) versions
rm -rf "$HOME/Library/Services/GPGServices.service"
rm -rf /Library/Services/GPGServices.service

# Install it
mkdir -p "$_target"
mv /private/tmp/GPGServices.service "$_target"

# Cleanup
if [ -e "$HOME/Library/Services/GPGServices.service" ]; then
    chown -R "$USER" "$_target"
else
    chown -R root:admin "$_target"
    chmod -R 755 "$_target"
fi

# Reload keyboard preferences
$_target/GPGServices.service/Contents/Resources/ServicesRestart
sleep 2
sudo $_target/GPGServices.service/Contents/Resources/ServicesRestart

exit 0
