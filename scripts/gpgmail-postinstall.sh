#!/bin/bash


# config #######################################################################
tempdir="/private/tmp/GPGMail_Installation"
sysdir="/Library/Mail/Bundles/"
netdir="/Network/Library/Mail/Bundles/"
homedir="$HOME/Library/Mail/Bundles/"
bundle="GPGMail.mailbundle";
################################################################################


# determine where to install the bundle to #####################################
if ( test -d "$netdir" ) then
    _target="$netdir";
elif ( test -d "$sysdir" ) then
    _target="$sysdir";
else
    _target="$homedir";
fi
################################################################################


# Cleanup ######################################################################
if [ ! -e "$tempdir/$bundle" ]; then
    echo "Installation failed. GPGMail was not found at $tempdir/$bundle";
    exit 1;
fi
# remove old versions of the bundle
rm -rf "$netdir/$bundle"
rm -rf "$sysdir/$bundle"
rm -rf "$homedir/$bundle"
################################################################################


# Install ######################################################################
mkdir -p "$_target"
mv "$tempdir/$bundle" "$_target"

if [ ! "`diff -r $tempdir/$bundle $_target/$bundle`" == "" ]; then
    echo "Installation failed. GPGMail bundle was not installed or updated at $_target";
    rm -fr "$tempdir/$bundle"
    exit 1;
fi
################################################################################


# Permissions ##################################################################
# see http://gpgtools.lighthouseapp.com/projects/65764-gpgmail/tickets/134
# see http://gpgtools.lighthouseapp.com/projects/65764-gpgmail/tickets/169
if [ "$_target" == "$homedir" ]; then
    sudo chown $USER:staff "$HOME/Library/Mail"
    sudo chown -R $USER:staff "$homedir"
fi
sudo chmod 755 "$_target"
################################################################################


# Cleanup ######################################################################
rm -fr "$tempdir/GPGMail.mailbundle"
# cleanup tempdir "rm -d" deletes the temporary installation dir only if empty.
# that is correct because if eg. /tmp is you install dir, there can be other stuff
# in there that should not be deleted
rm -d "$tempdir"
################################################################################


# enable bundles in Mail #######################################################
######
# Note that we are running sudo'd, so these defaults will be written to
# /Library/Preferences/com.apple.mail.plist
#
# Mail must NOT be running by the time this script executes
######
if [ `whoami` == root ] ; then
    #defaults acts funky when asked to write to the root domain but seems to work with a full path
	domain=/Library/Preferences/com.apple.mail
else
    domain=com.apple.mail
fi

bundleCompVer="3"
SW_VERS=`which sw_vers`
if test -x "$SW_VERS"; then
    os=OSX
    osx_version=`sw_vers -productVersion | cut -f1,2 -d.`
    osx_major=`echo $osx_version | cut -f1 -d.`
    osx_minor=`echo $osx_version | cut -f2 -d.`
    if [ "7" == "$osx_minor" ]; then bundleCompVer="5"; fi
    if [ "6" == "$osx_minor" ]; then bundleCompVer="4"; fi
    if [ "5" == "$osx_minor" ]; then bundleCompVer="3"; fi
fi

defaults write "$domain" EnableBundles -bool YES
defaults write "$domain" BundleCompatibilityVersion -int $bundleCompVer
################################################################################


################################################################################
# To auto-fix GPGMail after an OS update.
# Copied from GPGPreferences. This should be avoided:
# http://gpgtools.lighthouseapp.com/projects/65162/tickets/30
################################################################################

_bundleId="gpgmail";
_bundleName="$bundle";
_bundleRootPath="$_target";
_bundlePath="$_bundleRootPath/$_bundleName";
_plistBundle="$_bundlePath/Contents/Info";
_plistMail="/Applications/Mail.app/Contents/Info";
_plistFramework="/System/Library/Frameworks/Message.framework/Resources/Info";

isInstalled=`if [ -d "$_bundlePath" ]; then echo "1"; else echo "0"; fi`

if [ "1" == "$isInstalled" ]; then
  echo "[$_bundleId] is installed";
else
  foundDisabled=`find "$_bundleRootPath ("* -type d -name "$_bundleName"|head -n1`
  if [ "" != "$foundDisabled" ]; then
    mkdir -p "$_bundleRootPath";
    mv "$foundDisabled" "$_bundleRootPath";
  else
    echo "[$_bundleId] not found";
  fi
    echo "[$_bundleId] was reinstalled";
fi

uuid1=`defaults read "$_plistMail" "PluginCompatibilityUUID"`
uuid2=`defaults read "$_plistFramework" "PluginCompatibilityUUID"`

if [ "" == "$uuid1" ] || [ "" == "$uuid2" ] ; then
  echo "[$_bundleId] Warning: could not patch GPGMail. No UUIDs found.";
  exit 0;
fi

isPatched1=`grep $uuid1 "$_bundlePath/Contents/Info.plist" 2>/dev/null`
isPatched2=`grep $uuid2 "$_bundlePath/Contents/Info.plist" 2>/dev/null`

if [ "" != "$isPatched1" ] && [ "" != "$isPatched2" ] ; then
  echo "[$_bundleId] already patched";
else
  defaults write "$_plistBundle" "SupportedPluginCompatibilityUUIDs" -array-add "$uuid1"
  defaults write "$_plistBundle" "SupportedPluginCompatibilityUUIDs" -array-add "$uuid2"
  plutil -convert xml1 "$_plistBundle.plist"
  echo "[$_bundleId] successfully patched";
fi

chown -R $USER "$_target"
exit 0
