#!/bin/bash
########################################
# Cleanup and fixes for GnuPG on OS X.
#
# @author	Alex (alex@gpgtools.org)
# @see		http://gpgtools.org
# @todo		Invoke this script from other scripts
########################################

if test "$USER" == ""
then
  USER=$(id -un)
fi

function fixEnigmail {
    echo "[gpgtools] Fixing Enigmail...";
    enigmail_profiles="$HOME/Library/Thunderbird/Profiles"
    [ -e "$enigmail_profiles" ] && sudo chown -R "$USER" "$enigmail_profiles";
}

function fixGPGToolsPreferences {
    echo "[gpgtools] Fixing Preferences...";
    gpgp_dir="$HOME/Library/PreferencePanes"
    [ -e "$gpgp_dir" ] && sudo chown -R "$USER" "$gpgp_dir";
}

function fixGPGServices {
    echo "[gpgtools] Fixing Services...";
    gpgs_dir="$HOME/Library/Services/GPGServices.service";
    [ -e "$gpgs_dir" ] && sudo chown -R "$USER" "$gpgs_dir"
    [ -e "/private/tmp/ServicesRestart" ] && sudo /private/tmp/ServicesRestart
    sudo rm -f /private/tmp/ServicesRestart
}

function updateGPGMail {
    # config ###################################################################
    sysdir="/Library/Mail/Bundles/"
    netdir="/Network/Library/Mail/Bundles/"
    homedir="$HOME/Library/Mail/Bundles/"
    bundle="GPGMail.mailbundle";
    ############################################################################

    # modify the defaults ######################################################
    defaults write org.gpgtools.gpgmail DecryptMessagesAutomatically -bool YES
    defaults write com.apple.mail DecryptMessagesAutomatically -bool YES
    ############################################################################

    # determine the bundle is located ##########################################
    if ( test -e "$netdir/$bundle" ) then
        _target="$netdir";
    elif ( test -e "$sysdir/$bundle" ) then
        _target="$sysdir";
    elif ( test -e "$homedir/$bundle" ) then
         _target="$homedir";
    else
        return 0
    fi
    ############################################################################

    ############################################################################
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
        foundDisabled=`find "$_bundleRootPath ("* -type d -name "$_bundleName" 2>/dev/null|head -n1`
        if [ "" != "$foundDisabled" ]; then
            mkdir -p "$_bundleRootPath";
            mv "$foundDisabled" "$_bundleRootPath";
           echo "[$_bundleId] was reinstalled";
        else
            echo "[$_bundleId] not found";
        fi
    fi
    
    echo "[$_bundleId] Setting the correct permissions in '$_bundlePath'..."
    [ -e "$_bundlePath" ] && chmod -R u+rwX,go=rX "$_bundlePath";

    uuid1=`defaults read "$_plistMail" "PluginCompatibilityUUID"`
    uuid2=`defaults read "$_plistFramework" "PluginCompatibilityUUID"`
    if [ "" == "$uuid1" ] || [ "" == "$uuid2" ] ; then
        echo "[$_bundleId] Warning: could not patch GPGMail. No UUIDs found.";
        return;
    fi
    if [ ! -f "$_plistBundle.plist" ]; then
        echo "[$_bundleId] Warning: could not patch GPGMail. No bundle found.";
        return;
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
}

function fixGPGMail {
    echo "[gpgtools] Fixing Mail...";
	
	domain="com.apple.mail"
	case "$(sw_vers -productVersion | cut -d . -f 2)" in
	    7) bundleCompVer=5 ;;
	    6) bundleCompVer=4 ;;
	    *) bundleCompVer=3 ;;
    esac
	
	echo " * Writing '$bundleCompVer' to '$domain'..."
	defaults write "$domain" EnableBundles -bool YES
	defaults write "$domain" BundleCompatibilityVersion -int $bundleCompVer
	
	echo " * Writing '$bundleCompVer' to '$domain' as '$USER'..."
	su - "$USER" -c "defaults write '$domain' EnableBundles -bool YES"
	su - "$USER" -c  "defaults write '$domain' BundleCompatibilityVersion -int $bundleCompVer"
	
    if [ `whoami` == root ] ; then
	    #defaults acts funky when asked to write to the root domain but seems to work with a full path
		domain=/Library/Preferences/com.apple.mail
	fi	

	echo " * Writing '$bundleCompVer' to '$domain'..."
	defaults write "$domain" EnableBundles -bool YES
	defaults write "$domain" BundleCompatibilityVersion -int $bundleCompVer

    gpgm_dir="$HOME/Library/Mail/";
	echo " * Fixing permissions in '$gpgm_dir'..."
    [ -e "$gpgm_dir" ] && sudo chown "$USER" "$gpgm_dir";
    [ -e "$gpgm_dir/Bundles" ] && sudo chown -R "$USER" "$gpgm_dir/Bundles";

    gpgm_dir="/Library/Mail/";
	echo " * Fixing permissions in '$gpgm_dir'..."
    [ -e "$gpgm_dir" ] && sudo chmod -R u+rwX,go=rX "$gpgm_dir";
    
    updateGPGMail
}

function fixMacGPG2permissions {
    [ -e "$HOME/.gnupg" ] || mkdir -m 0700 "$HOME/.gnupg"
    [ -e "$HOME/.gnupg" ] && chown -R "$USER" "$HOME/.gnupg"
    [ -e "$HOME/.gnupg" ] && chmod -R -N "$HOME/.gnupg" 2> /dev/null;
    [ -e "$HOME/.gnupg" ] && chmod -R u+rwX,go= "$HOME/.gnupg"
}

function fixMacGPG2 {
    echo "[gpgtools] Fixing GPG...";
    killall gpg-agent 2> /dev/null
    fixMacGPG2permissions
    
    # Lion: pinentry Mac "Save in Keychain" doesn't work
    # http://gpgtools.lighthouseapp.com/projects/65764/tickets/292
    _key="LimitLoadToSessionType"
    _value="Aqua";
    _file="$HOME/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist";
    [ -e "$_file" ] && defaults write "$_file" "$_key" "$_value";
    _file="/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist";
    [ -e "$_file" ] && sudo defaults write "$_file" "$_key" "$_value";

    [ -h "$HOME/.gnupg/S.gpg-agent" ] && sudo rm -f "$HOME/.gnupg/S.gpg-agent"
    [ -h "$HOME/.gnupg/S.gpg-agent.ssh" ] && sudo rm -f "$HOME/.gnupg/S.gpg-agent.ssh"
    [ -e "/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist" ] && sudo chown root:wheel "/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist";
    [ -e "/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist" ] && sudo chmod 644 "/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist";
    [ -e "$HOME/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist" ] && sudo chown "$USER" "$HOME/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist";
    [ -e "$HOME/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist" ] && sudo chmod 644 "$HOME/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist";
    sudo mkdir -p "/usr/local/bin"
    sudo chmod +rX "/usr" "/usr/local" "/usr/local/bin" "/usr/local/MacGPG2" "/usr/local/MacGPG1" 2>/dev/null
    if [ -e "/usr/local/MacGPG2/bin/gpg2" ]; then
        sudo rm -f "/usr/local/bin/gpg2";
        sudo ln -s "/usr/local/MacGPG2/bin/gpg2" "/usr/local/bin/gpg2";
        sudo rm -f "/usr/local/bin/gpg-agent";
        sudo ln -s "/usr/local/MacGPG2/bin/gpg-agent" "/usr/local/bin/gpg-agent";
        [ ! -e "/usr/local/bin/gpg" ] && sudo ln -s "/usr/local/MacGPG2/bin/gpg2" "/usr/local/bin/gpg";
    fi

    # Create a new gpg.conf if none is existing from the skeleton file
    if [ -e "/usr/local/MacGPG2/share/gnupg/gpg-conf.skel" ] && ( ! test -e "$HOME/.gnupg/gpg.conf" ) then
    	# ~/.gnupg is ensured above
    	cp /usr/local/MacGPG2/share/gnupg/gpg-conf.skel "$HOME/.gnupg/gpg.conf"
    	fixMacGPG2permissions
    	echo "[MacGPG2] Created gpg.conf"
    fi
    # Create a new gpg.conf if the existing is corrupt
    if [ -e "/usr/local/MacGPG2/bin/gpg2" ] && ( ! /usr/local/MacGPG2/bin/gpg2 --gpgconf-test ) then
        echo "Fixing gpg.conf"
        mv "$HOME/.gnupg/gpg.conf" "$HOME/.gnupg/gpg.conf.moved-by-gpgtools-installer"
        cp /usr/local/MacGPG2/share/gnupg/gpg-conf.skel "$HOME/.gnupg/gpg.conf"
        fixMacGPG2permissions
    fi
    # Add our comment if it doesn't exit
    if [ -e "$HOME/.gnupg/gpg.conf" ] && [ "" == "`grep 'comment GPGTools' \"$HOME/.gnupg/gpg.conf\"`" ]; then
        echo "comment GPGTools - http://gpgtools.org" >> "$HOME/.gnupg/gpg.conf";
    fi
    # Add a keyserver if none exits
    if [ -e "$HOME/.gnupg/gpg.conf" ] && [ "" == "`grep '^[ 	]*keyserver ' \"$HOME/.gnupg/gpg.conf\"`" ]; then
        echo "keyserver x-hkp://pool.sks-keyservers.net" >> "$HOME/.gnupg/gpg.conf";
    fi

    # Remove any gpg-agent pinentry program options
    touch "$HOME/.gnupg/gpg-agent.conf"
    [ -e "$HOME/.gnupg/gpg-agent.conf" ] && sed -i '' 's/^[ 	]*\(pinentry-program\)/#\1/g' "$HOME/.gnupg/gpg-agent.conf"
    [ -e "$HOME/.gnupg/gpg-agent.conf" ] && sed -i '' 's/^[ 	]*\(no-use-standard-socket\)/#\1/g' "$HOME/.gnupg/gpg-agent.conf"

    # Ascertain whether using obsolete login/out scripts and remove
    defaults read com.apple.loginwindow LoginHook 2>&1  | grep --quiet "$OldMacGPG2/sbin/gpg-login.sh"  && defaults delete com.apple.loginwindow LoginHook
    defaults read com.apple.loginwindow LogoutHook 2>&1 | grep --quiet "$OldMacGPG2/sbin/gpg-logout.sh" && defaults delete com.apple.loginwindow LogoutHook

    # Now remove the gpg-agent helper AppleScript from login items:
    osascript -e 'tell application "System Events" to delete login item "start-gpg-agent"' 2> /dev/null

    # "$HOME/.gnupg" on NFS volumes
    # http://gpgtools.lighthouseapp.com/projects/66001-macgpg2/tickets/55
    if [ -e /private/tmp/testSockets.py ]; then
      /private/tmp/testSockets.py "$HOME/.gnupg/" || echo "no-use-standard-socket" >> "$HOME/.gnupg/gpg-agent.conf"
    fi
}

fixEnigmail
fixGPGToolsPreferences
fixGPGServices
fixGPGMail
fixMacGPG2

exit 0
