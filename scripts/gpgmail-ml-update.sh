#!/bin/bash



dscl . -list /Users UniqueID | while read username uid ;do
	if [ $uid -ge 500 ]; then
		userHome=$(eval echo ~$username)
		oldLocation="$userHome/Library/Preferences"
		mailContainersLocation="$userHome/Library/Containers/com.apple.mail"
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
			# Add values from /Library/Preferences/com.apple.mail.plist
			defaults write "$newLocation/com.apple.mail.plist" "BundleCompatibilityVersion" -int 3
			defaults write "$newLocation/com.apple.mail.plist" "EnableBundles" -int 1
		fi
		
		if [ -d "$mailContainersLocation" ]; then
			sudo chown -R "$username":staff "$mailContainersLocation"
		fi
		
		obsoleteMailPlist="/Library/Preferences/com.apple.mail.plist"
		osver="$(echo `sw_vers`|cut -f2 -d.)"
        [[ "${osver}" -ge "8" ]] && sudo rm -f "$obsoleteMailPlist"
	fi
done
