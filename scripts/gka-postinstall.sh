#!/bin/bash

# config #######################################################################
USER=$(id -un)
tempdir="/private/tmp/GKA_Installation";
appname="GPG Keychain Access.app";
targetdefault="/Applications/";
################################################################################


# determine where to install the app to ########################################
echo "Finding target..."
_target=`find /Applications -maxdepth 2 -name "$appname"`;
_target=`dirname "$_target"`

if [ "$_target" == "." ]; then
  _target="$targetdefault"
fi
echo "Found: $_target"
################################################################################


# Cleanup ######################################################################
echo "Cleanup 1..."
if [ ! -e "$tempdir/$appname" ]; then
    echo "Installation failed. GKA was not found at $tempdir/$appname";
    exit 1;
fi

echo "Removing old versions of the app..."
if [ "`dirname "$_target/$appname"`" != "/" ]; then rm -rf "$_target/$appname"; fi
################################################################################


# Install ######################################################################
echo "Install..."
mkdir -p "$_target"
mv "$tempdir/$appname" "$_target"
################################################################################


# Cleanup ######################################################################
echo "Cleanup 2..."
if [ `dirname "$tempdir/$appname"` != "/" ]; then rm -fr "$tempdir/$appname"; fi
rm -d "$tempdir"
################################################################################

echo "Changing permissions..."
chown -Rh "$USER" "$_target/$appname"
exit 0
