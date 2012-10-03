#!/bin/bash
################################################################################
#
# GPG auto fix.
#
# @author   Alexander Willner <alex@willner.ws>
################################################################################


################################################################################
# setup
################################################################################
if test "$USER" == ""
then
  USER=$(id -un)
fi
_bundleId="gpg";
################################################################################

################################################################################
# Precoditions
################################################################################
  if [ ! -e "/usr/local/MacGPG2/bin/gpg2" ]; then
    echo "[$_bundleId] Please install MacGPG2 first (http://gpgtools.org)";
    exit 1;
  fi

function hasPinentryEntryInConfig {
	current_pinentry=$(grep -o 'pinentry-program.*' "$HOME/.gnupg/gpg-agent.conf" | sed 's/pinentry-program\([^/]*\)\(.*\)/\2/g' | sed 's/"//g')
	if [ $? -ne 0 ]; then
		echo "no"
	else
		echo "yes"
	fi
}

function hasWorkingPinentry {
	# Some versions of the fix_gpg and gpgtools-autofix included a bug which caused
	# the pinentry-program config variable to be commented.
	# The following line fixes this problem.
	[ -e "$HOME/.gnupg/gpg-agent.conf" ] && sed -i '' 's/^#pinentry-program/pinentry-program/g' "$HOME/.gnupg/gpg-agent.conf"

	current_pinentry=$(grep -o 'pinentry-program.*' "$HOME/.gnupg/gpg-agent.conf" | sed 's/pinentry-program\([^/]*\)\(.*\)/\2/g' | sed 's/"//g')
	if [ $? -ne 0 ]; then
		echo "no"
		return 1
	fi
	# Test if pinentry is a file, executable, redable, and manages to print a version.
	if [ ! -f "$current_pinentry" ] || [ ! -r "$current_pinentry" ] || [ ! -x "$current_pinentry" ]; then
		echo "no"
		return 1
	fi
	"$current_pinentry" --version 2>/dev/null 1>&2
	# Check if the version test succeeded.
	if [ $? -ne 0 ]; then
		echo "no"
		return 1
	fi

	echo "yes"
}

function findWorkingPinentry {
	# Pinentry binary
	PINENTRY_BINARY_PATH="pinentry-mac.app/Contents/MacOS/pinentry-mac"
	# Pinentry in MacGPG2
	PINENTRY_PATHS[0]="/usr/local/MacGPG2/libexec"
	# Pinentry in GPGServices
	PINENTRY_PATHS[1]="/Library/Services/GPGServices.service/Contents/Frameworks/Libmacgpg.framework/Resources"
	# Pinentry in GPGMail /Library/
	PINENTRY_PATHS[2]="/Library/Mail/Bundles/GPGMail.mailbundle/Contents/Frameworks/Libmacgpg.framework/Resources"
	# Pinentry in GPGMail $HOME/Library/
	PINENTRY_PATHS[3]="$HOME/Library/Mail/Bundles/GPGMail.mailbundle/Contents/Frameworks/Libmacgpg.framework/Resources"
	# Pinentry in GPG Keychain Access
	PINENTRY_PATHS[4]="/Applications/GPG Keychain Access.app/Contents/Frameworks/Libmacgpg.framework/Resources"

	for pinentry_path in "${PINENTRY_PATHS[@]}"; do
		full_pinentry_path="${pinentry_path}/${PINENTRY_BINARY_PATH}"
		if [ -f "$full_pinentry_path" ] && [ -x "$full_pinentry_path" ] && [ -r "$full_pinentry_path" ]; then
			# Try to run it and check the result
			"$full_pinentry_path" --version  2>/dev/null 1>&2
			if [ $? -eq 0 ]; then
				echo "$full_pinentry_path"
				return 1
			fi
		fi
	done

	echo "no"
}

function replacePinentryInConfig {
	# Let's find a working pinentry
	working_pinentry=$(findWorkingPinentry)
	echo "Found working pinentry at: $working_pinentry"
	if [ "$working_pinentry" == "no" ]; then
		# FUCK WHAT NOW?!
		echo "No working pinentry found. Abort?"
		return 1
	fi
	# Replace the current pinentry program with a new one in the config file.
	# Has to escape / with \/ for sed to work
	escaped_pinentry=$(echo $working_pinentry | sed 's/\//\\\//g')
	if [ "$(hasPinentryEntryInConfig)" == "yes" ]; then
		echo "Replacing existing pinentry"
		[ -e "$HOME/.gnupg/gpg-agent.conf" ] && sed -i '' "s/^[ 	]*\(pinentry-program\).*$/pinentry-program \"$escaped_pinentry\"/g" "$HOME/.gnupg/gpg-agent.conf"
	else
		echo "Add new pinentry"
		[ -e "$HOME/.gnupg/gpg-agent.conf" ] && echo -e "pinentry-program \"$working_pinentry\"" >> "$HOME/.gnupg/gpg-agent.conf"
	fi
}

################################################################################
# Clean up (also clean up bad GPGTools behaviour)
################################################################################
  echo "[$_bundleId] Removing invalid symbolic links...";
  [ -h "$HOME/.gnupg/S.gpg-agent" ] && rm -f "$HOME/.gnupg/S.gpg-agent"
  [ -h "$HOME/.gnupg/S.gpg-agent.ssh" ] && rm -f "$HOME/.gnupg/S.gpg-agent.ssh"


################################################################################
# Add some links (force the symlink to be sure)
################################################################################
  echo "[$_bundleId] Linking gpg2...";
  mkdir -p /usr/local/bin/
  rm -f /usr/local/bin/gpg2; ln -s /usr/local/MacGPG2/bin/gpg2 /usr/local/bin/gpg2
  [ ! -e /usr/local/bin/gpg ] && ln -s /usr/local/MacGPG2/bin/gpg2 /usr/local/bin/gpg


################################################################################
# Create a new gpg.conf if none is existing from the skeleton file
################################################################################
  echo "[$_bundleId] Checking gpg.conf...";
    if ( ! test -e "$HOME/.gnupg/gpg.conf" ) then
		echo "[$_bundleId] Not found!";
    	mkdir -m 0700 -p "$HOME/.gnupg"
    	cp /usr/local/MacGPG2/share/gnupg/gpg-conf.skel "$HOME/.gnupg/gpg.conf"
        [ -e "$HOME/.gnupg" ] && chown -R "$USER" "$HOME/.gnupg"
        [ -e "$HOME/.gnupg" ] && chmod -R -N "$HOME/.gnupg" 2> /dev/null;
        [ -e "$HOME/.gnupg" ] && chmod -R u+rwX,go= "$HOME/.gnupg"
    fi
    if ( ! /usr/local/MacGPG2/bin/gpg2 --gpgconf-test ) then
		echo "[$_bundleId] Was invalid!";
        mv "$HOME/.gnupg/gpg.conf" "$HOME/.gnupg/gpg.conf.moved-by-gpgtools-installer"
        cp /usr/local/MacGPG2/share/gnupg/gpg-conf.skel "$HOME/.gnupg/gpg.conf"
    fi
    if [ "" == "`grep 'comment GPGTools' \"$HOME/.gnupg/gpg.conf\"`" ]; then
        echo "comment GPGTools - http://gpgtools.org" >> "$HOME/.gnupg/gpg.conf"
    fi
    if [ "" == "`grep '^[ 	]*keyserver ' \"$HOME/.gnupg/gpg.conf\"`" ]; then
        echo "keyserver pool.sks-keyservers.net" >> "$HOME/.gnupg/gpg.conf"
    fi

    # Remove any gpg-agent pinentry program options
[ -e "$HOME/.gnupg/gpg-agent.conf" ] && sed -i '' 's/^[ 	]*\(pinentry-program\)/#\1/g' "$HOME/.gnupg/gpg-agent.conf"
[ -e "$HOME/.gnupg/gpg-agent.conf" ] && sed -i '' 's/^[ 	]*\(no-use-standard-socket\)/#\1/g' "$HOME/.gnupg/gpg-agent.conf"
	
	# It was removed, now let's add a working pinentry again so we can be sure
	# that pinentry ALWAYS runs!
	if [ "$(hasWorkingPinentry)" != "yes" ]; then
		replacePinentryInConfig
	fi
	
	killall gpg-agent 2> /dev/null

################################################################################
# Fix permissions (just to be sure)
################################################################################
  echo "[$_bundleId] Fixing permissions...";
  osascript -e 'do shell script "sh ./fix_gpg_permissions.sh" with administrator privileges'

exit 0
