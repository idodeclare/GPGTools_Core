#!/bin/bash



dscl . -list /Users UniqueID | while read username uid ;do
	if [ $uid -ge 500 ]; then
		userHome=$(eval echo ~$username)
		oldLocation="$userHome/Library/Preferences"
		newLocation="$userHome/Library/Containers/com.apple.mail/Data/Library/Preferences"
		
		if [[ -e "$oldLocation/org.gpgtools.gpgmail.plist" || -e "$oldLocation/org.gpgtools.common.plist" ]] ;then
			echo "Work on user \"$username\""
			mkdir -p "$newLocation"
			if [[ -e "$oldLocation/org.gpgtools.gpgmail.plist" ]] ;then
				# Move org.gpgtools.gpgmail.plist into Containers
				echo "Move org.gpgtools.gpgmail.plist"
				mv -f "$oldLocation/org.gpgtools.gpgmail.plist" "$newLocation/org.gpgtools.gpgmail.plist"
			fi
			if [[ -e "$oldLocation/org.gpgtools.common.plist" ]] ;then
				# Merge PublicKeyUserMap from org.gpgtools.common.plist into the new org.gpgtools.gpgmail.plist
				echo "Read PublicKeyUserMap"
				dict=$(defaults read "$oldLocation/org.gpgtools.common" PublicKeyUserMap 2>/dev/null)
				if [[ -n "$dict" ]] ;then
					echo "Write PublicKeyUserMap"
					defaults write "$newLocation/org.gpgtools.gpgmail" PublicKeyUserMap "$dict"
				fi
			fi
		fi
	fi
done


