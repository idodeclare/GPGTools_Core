#!/bin/bash
################################################################################
# Cleanup and fixes for GnuPG on OS X.
#
# @author	Alex (alex@gpgtools.org) and Mento (mento@gpgtools.org)
# @see		http://gpgtools.org
# @todo		Invoke this script from other scripts
################################################################################


# Helper functions #############################################################
function errReturn {
	msg="$* (${BASH_SOURCE[1]##*/}: line ${BASH_LINENO[0]})"
	if [[ -t 1 ]] ;then
		echo -e "\033[1;31m$msg\033[0m" >&2
	else
		echo "$msg" >&2
	fi
	return 1
}
function errExit {
	msg="$* (${BASH_SOURCE[1]##*/}: line ${BASH_LINENO[0]})"
	if [[ -t 1 ]] ;then
		echo -e "\033[1;31m$msg\033[0m" >&2
	else
		echo "$msg" >&2
	fi
	exit 1
}
function myEcho {
	echo "${SCRIPT_NAME:+[$SCRIPT_NAME] }$*"
}
function myChown {
	# chown -R "$USER", if the file exists.
    [[ -e "$1" ]] && sudo chown -R "$USER" "$1"
}
function myChmod {
	# chmod, if the file exists.
	eval [[ -e "\${$#}" ]] && sudo chmod "$@"
}
################################################################################


function fixGPGToolsPreferences {
    myEcho "Fixing Preferences..."
    gpgp_dir="$HOME/Library/PreferencePanes"
	myChown "$gpgp_dir"
}

function fixGPGServices {
    myEcho "Fixing Services..."
    gpgs_dir="$HOME/Library/Services/GPGServices.service"
    myChown "$gpgs_dir"
    [[ -e "/private/tmp/ServicesRestart" ]] && sudo /private/tmp/ServicesRestart
    sudo rm -f /private/tmp/ServicesRestart
}

function updateGPGMail {
    # config
    sysdir="/Library/Mail/Bundles"
    netdir="/Network/Library/Mail/Bundles"
    homedir="$HOME/Library/Mail/Bundles"
    bundle="GPGMail.mailbundle"

    # modify the defaults 
    defaults write org.gpgtools.gpgmail DecryptMessagesAutomatically -bool YES
    defaults write com.apple.mail DecryptMessagesAutomatically -bool YES

	# Find GPGMail
	normalDirs=("$sysdir" "$netdir" "$homedir")
	disabledDirs=("$sysdir ("* "$netdir ("* "$homedir ("*)
	found=""

	for dir in "${normalDirs[@]}" ;do
		bundlePath="$dir/$bundle"
		if [[ -d "$bundlePath" ]] ;then
			if [[ -z "$found" ]] ;then
				myEcho "Found GPGMail at '$bundlePath'"
				found=$bundlePath
			else
				myEcho "Deleting duplicate bundle '$bundlePath'."
				rm -rf "$bundlePath"
			fi
		fi
	done
	
	if [[ -z "$found" ]] ;then
		for dir in "${disabledDirs[@]}" ;do
			bundlePath="$dir/$bundle"
			if [[ -d "$bundlePath" ]] ;then
				myEcho "Found disabled GPGMail at '$bundlePath', moving it..."
				newDir="${dir%/*}/Bundles"
				found="$newDir/$bundle"
				mkdir -p "$newDir"
				mv "$bundlePath" "$newDir"
				myEcho "GPGMail was reinstalled."
				break;
			fi
		done
		if [[ -z "$found" ]] ;then
			myEcho "GPGMail not found"
			return 1
		fi
	fi
	bundlePath=$found

	# Setting permissions
    myEcho "Setting the correct permissions in '$bundlePath'..."
    myChmod -R u+rwX,go=rX "$bundlePath"

	# Fix UUIDs
	updateGPGMailUUIDs "$bundlePath"
}

function updateGPGMailUUIDs {
	# Usage: updateGPGMailUUIDs /Library/Mail/Bundles/GPGMail.mailbundle
	# The var PlistBuddy need to be set, to the path to PlistBuddy.
	plistBundle="$1/Contents/Info.plist"
	plistMail="/Applications/Mail.app/Contents/Info.plist"
    plistFramework="/System/Library/Frameworks/Message.framework/Resources/Info.plist"
	entry="SupportedPluginCompatibilityUUIDs"

	myEcho "Patching GPGMail UUIDs..."

	uuid1=$("$PlistBuddy" -c "print PluginCompatibilityUUID" "$plistMail")
	uuid2=$("$PlistBuddy" -c "print PluginCompatibilityUUID" "$plistFramework")
	
    [[ -n "$uuid1" && -n "$uuid2" ]] ||
		errReturn "Warning: could not patch GPGMail. No UUIDs found."
    [[ -f "$plistBundle" ]] ||
        errReturn "Warning: could not patch GPGMail. No bundle found."


	content=$("$PlistBuddy" -c "print $entry" "$plistBundle")

    if grep -q "$uuid1" <<<"$content" && grep -q "$uuid2" <<<"$content" ;then
        myEcho "GPGMail already patched"
    else
		"$PlistBuddy" -c "add $entry:0 string $uuid1" -c "add $entry:0 string $uuid2" "$plistBundle"
        myEcho "GPGMail successfully patched"
    fi
}



function fixGPGMail {
    myEcho "Fixing Mail..."
	
	domain="com.apple.mail"
	case "$(sw_vers -productVersion | cut -d . -f 2)" in
	    7) bundleCompVer=5 ;; 
	    6) bundleCompVer=4 ;; 
	    *) bundleCompVer=3 ;; 
    esac
	
	myEcho " * Writing '$bundleCompVer' to '$domain'..."
	defaults write "$domain" EnableBundles -bool YES
	defaults write "$domain" BundleCompatibilityVersion -int $bundleCompVer
	
	myEcho " * Writing '$bundleCompVer' to '$domain' as '$USER'..."
	sudo -u  "$USER" defaults write "$domain" EnableBundles -bool YES
	sudo -u  "$USER" defaults write "$domain" BundleCompatibilityVersion -int $bundleCompVer


    if [[ "$(whoami)" == root ]]  ;then
	    #defaults acts funky when asked to write to the root domain but seems to work with a full path
		domain=/Library/Preferences/com.apple.mail
		myEcho " * Writing '$bundleCompVer' to '$domain'..."
		defaults write "$domain" EnableBundles -bool YES
		defaults write "$domain" BundleCompatibilityVersion -int $bundleCompVer
	fi


    gpgm_dir="$HOME/Library/Mail/"
	myEcho " * Fixing permissions in '$gpgm_dir'..."
    [[ -e "$gpgm_dir" ]] && sudo chown "$USER" "$gpgm_dir"
    myChown "$gpgm_dir/Bundles"

    gpgm_dir="/Library/Mail/"
	myEcho " * Fixing permissions in '$gpgm_dir'..."
    myChmod -R u+rwX,go=rX "$gpgm_dir"
    
    updateGPGMail
}

function fixGnupgHomePermissions {
    [[ -e "$GNUPGHOME" ]] || mkdir -m 0700 "$GNUPGHOME"
    myChown "$GNUPGHOME"
    myChmod -R -N "$GNUPGHOME" 2>/dev/null
    myChmod -R u+rwX,go= "$GNUPGHOME"
}


function isPinentryWorking {
	# Check if the pinentry, passed to this function, works.
	sudo -u "$USER" "$1" --version 2>/dev/null 1>&2
	return $?
}


function findWorkingPinentry {
	# Pinentry binary
	PINENTRY_BINARY_PATH="pinentry-mac.app/Contents/MacOS/pinentry-mac"
	# Pinentry in Libmacgpg
	PINENTRY_PATHS[1]="/Library/Frameworks/Libmacgpg.framework/Versions/A/Resources"
	# Pinentry in MacGPG2
	PINENTRY_PATHS[0]="/usr/local/MacGPG2/libexec"

	for pinentry_path in "${PINENTRY_PATHS[@]}"; do
		full_pinentry_path="$pinentry_path/$PINENTRY_BINARY_PATH"

		if isPinentryWorking "$full_pinentry_path" ;then
			echo "$full_pinentry_path"
			return 0
		fi
	done
	
	return 1
}


function fixGPG {
    myEcho "Fixing GPG..."
    fixGnupgHomePermissions

    sudo mkdir -p /usr/local/bin
    sudo chmod +rX /usr /usr/local /usr/local/bin /usr/local/MacGPG2 /usr/local/MacGPG1 2>/dev/null

	if [[ -e /usr/local/MacGPG2/bin/gpg2 ]] ;then
		sudo rm -f /usr/local/bin/gpg2 /usr/local/bin/gpg-agent
		sudo ln -s /usr/local/MacGPG2/bin/gpg2 /usr/local/bin/gpg2
		sudo ln -s /usr/local/MacGPG2/bin/gpg-agent /usr/local/bin/gpg-agent
		[[ ! -e /usr/local/bin/gpg ]] && sudo ln -s /usr/local/MacGPG2/bin/gpg2 /usr/local/bin/gpg
		
		# Create a new gpg.conf if none is existing from the skeleton file
		if [[ ! -e "$GNUPGHOME/gpg.conf" ]] ;then
			cp "/usr/local/MacGPG2/share/gnupg/gpg-conf.skel" "$GNUPGHOME/gpg.conf"
			myEcho "Created gpg.conf"
		elif ! /usr/local/MacGPG2/bin/gpg2 --gpgconf-test ;then
			myEcho "Fixing gpg.conf"
			mv "$GNUPGHOME/gpg.conf" "$GNUPGHOME/gpg.conf.moved-by-gpgtools-installer"
			cp /usr/local/MacGPG2/share/gnupg/gpg-conf.skel "$GNUPGHOME/gpg.conf"
			myEcho "Replaced gpg.conf"
		fi
	fi

	fixGnupgHomePermissions
	
    # Add a keyserver if none exits
    if [[ -e "$GNUPGHOME/gpg.conf" ]] && ! grep -q '^[ 	]*keyserver ' "$GNUPGHOME/gpg.conf" ;then
        echo "keyserver hkp://pool.sks-keyservers.net" >> "$GNUPGHOME/gpg.conf"
    fi
}


function fixGPGAgent {
	gpgAgentConf="$GNUPGHOME/gpg-agent.conf"
	touch "$gpgAgentConf"

	# Fix pinentry.
	currentPinetry=$(sed -En '/^[ 	]*pinentry-program "?([^"]*)"?/{s//\1/p;q;}' "$gpgAgentConf")
	if ! isPinentryWorking "$currentPinetry" ;then
		# Let's find a working pinentry
		myEcho "Found working pinentry at: $working_pinentry"
		if ! working_pinentry=$(findWorkingPinentry) ;then
			myEcho "No working pinentry found. Abort!"
			return 1
		fi

		if [[ -n "$currentPinetry" ]] ;then
			myEcho "Replacing existing pinentry"
			sed -Ei '' '/^([ 	]*pinentry-program ).*/s@@\1'"$working_pinentry@" "$gpgAgentConf"
		else
			myEcho "Add new pinentry"
			echo "pinentry-program $working_pinentry" >> "$gpgAgentConf"
		fi
	fi


	# "$GNUPGHOME" on NFS volumes
    # http://gpgtools.lighthouseapp.com/projects/66001-macgpg2/tickets/55
    if ! grep -Eq '^[       ]*no-use-standard-socket' "$gpgAgentConf" ;then
		tempFile="$GNUPGHOME/test.tmp"
		rm -f "$tempFile"
		if ! mkfifo "$tempFile" >/dev/null 2>&1 && rm -f "$tempFile" ;then
			echo "no-use-standard-socket" >> "$gpgAgentConf"
		fi
    fi

	killall gpg-agent 2> /dev/null

    rm -f "$GNUPGHOME/S.gpg-agent" "$GNUPGHOME/S.gpg-agent.ssh"
}

function generalFixes {
	# Remove old plist files.
	rm -f "$HOME/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist" \
		"/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist" \
		"/Library/LaunchAgents/com.sourceforge.macgpg2.gpg-agent.plist"

    # Now remove the gpg-agent helper AppleScript from login items:
    osascript -e 'tell application "System Events" to delete login item "start-gpg-agent"' 2> /dev/null
	
    # Ascertain whether using obsolete login/out scripts and remove
    defaults read com.apple.loginwindow LoginHook 2>&1  | grep --quiet "$OldMacGPG2/sbin/gpg-login.sh"  && defaults delete com.apple.loginwindow LoginHook
    defaults read com.apple.loginwindow LogoutHook 2>&1 | grep --quiet "$OldMacGPG2/sbin/gpg-logout.sh" && defaults delete com.apple.loginwindow LogoutHook

	# Remove obsolete com.apple.mail.plist
	obsoleteMailPlist="/Library/Preferences/com.apple.mail.plist"
	osver="$(sw_vers -productVersion | cut -f2 -d.)"
	[[ "$osver" -ge 8 ]] && sudo rm -f "$obsoleteMailPlist"
}


GNUPGHOME=${GNUPGHOME:-"$HOME/.gnupg"}
PlistBuddy=/usr/libexec/PlistBuddy
SCRIPT_NAME=autofix

sudo echo >/dev/null || errExit "No root privileges! Aborting."


generalFixes
fixGPG
fixGPGAgent
fixGPGToolsPreferences
fixGPGServices
fixGPGMail

exit 0
