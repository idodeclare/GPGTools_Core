#!/bin/bash


# config #######################################################################
if test "$USER" == ""
then
  USER=$(id -un)
fi
sysdir="/Library/Mail/Bundles/"
netdir="/Network/Library/Mail/Bundles/"
homedir="$HOME/Library/Mail/Bundles/"
bundle="GPGMail.mailbundle"
################################################################################


# check source #################################################################
sourcedir="/private/tmp/GPGMail_Installation"
echo "[gpgmail] Searching in ${sourcedir}..."
if [ ! -e "$sourcedir/$bundle" ]; then
    echo " * GPGMail was not found at $sourcedir/$bundle"
    sourcedir="${PACKAGE_PATH%/*/*}/Resources"
    echo "[gpgmail] Searching in ${sourcedir}..."
    if [ ! -e "$sourcedir/$bundle" ]; then
        echo " * GPGMail was not found at $sourcedir/$bundle"
        echo "Installation failed. GPGMail was not found at $sourcedir/$bundle"
        exit 1
    fi
fi
################################################################################


# Quit Apple Mail ##############################################################
echo "[gpgmail] Quitting Mail..."
osascript -e "quit app \"Mail\""
################################################################################


# determine where to install the bundle to #####################################
if [[ -d "$netdir/$bundle" ]]; then
    _target="$netdir"
elif [[ -d "$homedir/$bundle" ]]; then
    _target="$homedir"
else
    _target="$sysdir"
fi
echo "[gpgmail] Target is ${_target}..."
################################################################################


# Cleanup ######################################################################
echo "[gpgmail] Removing old versions of the bundle..."
rm -rf "$netdir/$bundle"
rm -rf "$sysdir/$bundle"
rm -rf "$homedir/$bundle"
################################################################################


# Install ######################################################################
mkdir -p "$_target"
cp -R "$sourcedir/$bundle" "$_target"

#if ! diff -r "$sourcedir/$bundle" "$_target/$bundle" >/dev/null; then
if ! [ -f "$_target/$bundle/Contents/Info.plist" ]; then
    echo "Installation failed. GPGMail bundle was not installed or updated at $_target"
    exit 1
fi
################################################################################


# Permissions ##################################################################
# see http://gpgtools.lighthouseapp.com/projects/65764-gpgmail/tickets/134
# see http://gpgtools.lighthouseapp.com/projects/65764-gpgmail/tickets/169
echo "[gpgmail] Fixing permissions..."
if [ "$_target" == "$homedir" ]; then
    sudo chown "$USER:staff" "$HOME/Library/Mail"
    sudo chown -R "$USER:staff" "$homedir"
fi
sudo chmod -R 755 "$_target"
################################################################################


# enable bundles in Mail #######################################################
echo "[gpgmail] Enabling bundle..."
######
# Mail must NOT be running by the time this script executes
######

case "$(sw_vers -productVersion | cut -d . -f 2)" in
	7) bundleCompVer=5 ;;
	6) bundleCompVer=4 ;;
	*) bundleCompVer=3 ;;
esac

defaults write "/Library/Preferences/com.apple.mail" EnableBundles -bool YES
defaults write "/Library/Preferences/com.apple.mail" BundleCompatibilityVersion -int $bundleCompVer
################################################################################



# Add the PluginCompatibilityUUIDs #############################################
echo "[gpgmail] Adding PluginCompatibilityUUIDs..."
_plistBundle="$_target/$bundle/Contents/Info"
_plistMail="/Applications/Mail.app/Contents/Info"
_plistFramework="/System/Library/Frameworks/Message.framework/Resources/Info"

uuid1=$(defaults read "$_plistMail" "PluginCompatibilityUUID")
uuid2=$(defaults read "$_plistFramework" "PluginCompatibilityUUID")

if [ -z "$uuid1" -o -z "$uuid2" ] ;then
    echo "No UUIDs found."
    exit 0
fi

if ! grep -q $uuid1 "${_plistBundle}.plist" || ! grep -q $uuid2 "${_plistBundle}.plist" ;then
    defaults write "$_plistBundle" "SupportedPluginCompatibilityUUIDs" -array-add "$uuid1"
    defaults write "$_plistBundle" "SupportedPluginCompatibilityUUIDs" -array-add "$uuid2"
    plutil -convert xml1 "$_plistBundle.plist"
    echo "GPGMail successfully patched."
fi
################################################################################
