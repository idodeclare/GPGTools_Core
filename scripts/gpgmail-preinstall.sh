#!/bin/sh

# Quit Apple Mail
osascript -e "quit app \"Mail\""

# Remove possible leftovers of previous installations
rm -rf "/private/tmp/GPGMail_Installation"
