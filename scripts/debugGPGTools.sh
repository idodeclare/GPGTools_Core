#!/bin/bash

disclaimer="A lot of your personal info is contained in this log! Please consider to edit it before sending if you don't wish to send us all that!"

echo "=============================================="
echo "DISCLAIMER"
echo "=============================================="
echo ""
echo "$disclaimer"
echo ""
echo "Press 'y' to continue..."
read -rsn 1 n

if [ "y" != "$n" ] && [ "Y" != "$n" ]; then
  exit 1
fi

echo ""
echo "=============================================="
echo "If you're asked for a user ID just press enter"
echo "=============================================="
:> $0.log
exec 3>&1 4>&2 >$0.log 2>&1


GNUPG_DIR="${GNUPGHOME:-$HOME/.gnupg}"


echo -e "\n*** Applications...\n========================================================================="
[ ! -d /Applications/GPG\ Keychain\ Access.app ]; echo "  * GKA: $?"
[ ! -d /Library/Services/GPGServices.service ]; echo "  * GPGServices in /: $?"
[ ! -d "$HOME/Library/Services/GPGServices.service" ]; echo "  * GPGServices in \"$HOME\": $?"
[ ! -d /usr/local/MacGPG1 ]; echo "  * MacGPG1: $?"
[ ! -d /usr/local/MacGPG2 ]; echo "  * MacGPG2: $?"
[ ! -d /Library/Mail/Bundles/GPGMail.mailbundle ]; echo "  * GPGMail in /: $?"
[ ! -d "$HOME/Library/Mail/Bundles/GPGMail.mailbundle" ]; echo "  * GPGMail in \"$HOME\": $?"
[ ! -d /Library/PreferencePanes/GPGPreferences.prefPane ]; echo "  * GPGPref in /: $?"
[ ! -d "$HOME/Library/PreferencePanes/GPGPreferences.prefPane" ]; echo "  * GPGPref in \"$HOME\": $?"
echo "========================================================================="


echo -e "\n*** gpg-agent...\n========================================================================="
[ ! -f /Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist ]; echo "  * gpg-agent.plist in /: $?"
[ ! -f "$HOME/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist" ]; echo "  * gpg-agent.plist in \"$HOME\": $?"
[ ! -S "$GNUPG_DIR/S.gpg-agent" ]; echo "  * gpg-agent has the default socket: $?"
launchctl list | grep gpg-agent >/dev/null; echo "  * gpg-agent in launchd: $?"
ps axo command | grep '^gpg-agent' >/dev/null; echo "  * gpg-agent running: $?"
echo -n "  * Path to gpg-agent: "; which gpg-agent
echo -n "  * Is gpg-agent running (directly): "; /usr/local/MacGPG2/bin/gpg-agent
echo -n "  * Version of gpg-agent: "; gpg-agent --version
echo -n "  * Version of gpg-agent (directly): "; /usr/local/MacGPG2/bin/gpg-agent --version
echo "========================================================================="


echo -e "\n*** Permissions...\n========================================================================="
ls -lade /Library/Services/ \
	/Library/Services/GPGServices.service \
	"$HOME/Library/Services/" \
	"$HOME/Library/Services/GPGServices.service" \
	/usr/local/ \
	/usr/local/MacGPG1 \
	/usr/local/MacGPG2 \
	/Library/Mail/Bundles \
	"$HOME/Library/Mail/Bundles" \
	/Library/Mail/Bundles/GPGMail.mailbundle \
	"$HOME/Library/Mail/Bundles/GPGMail.mailbundle" \
	"$GNUPG_DIR" \
	"$GNUPG_DIR/S.gpg-agent"
echo "========================================================================="

echo -e "\n*** List '.gnupg'...\n========================================================================="
ls -lae "$GNUPG_DIR"
echo "========================================================================="


echo -e "\n*** GPG1...\n========================================================================="
ls -lade "$(which gpg)"
gpg --version
gpg -K
echo "========================================================================="


echo -e "\n*** GPG2...\n========================================================================="
ls -lade "$(which gpg2)"
gpg2 --version
gpg2 -K
echo "========================================================================="


echo -e "\n*** Print gpg.conf...\n========================================================================="
cat "$GNUPG_DIR/gpg.conf"
echo "========================================================================="


echo -e "\n*** Print gpg-agent.conf...\n========================================================================="
cat "$GNUPG_DIR/gpg-agent.conf"
echo "========================================================================="


echo -e "\n*** Testing encryption (1/2)...\n========================================================================="
if [ ! ""  == "$YOURKEY" ]; then
  echo "  * GPG1:"
  echo "test"|gpg -aer "$YOURKEY"|gpg
  echo "  * GPG2:"
  echo "test"|gpg2 -aer "$YOURKEY"|gpg2
fi
echo "========================================================================="


echo -e "\n*** Testing encryption (2/2)...\n========================================================================="
echo "  * GPG1:"
echo "test"|gpg -ae --default-recipient-self|gpg
echo "  * GPG2:"
echo "test"|gpg2 -ae --default-recipient-self|gpg2
echo "test"|gpg2 --default-recipient-self -ae
echo "test"|gpg2 -as
echo "test"|gpg2 --default-recipient-self -aes
echo "========================================================================="


echo -e "\n*** Showing installed mail bundles...\n========================================================================="
echo "  * /L/M/B:"
ls -lad /Library/Mail/Bundles*
ls -l /Library/Mail/Bundles*
echo "  * \"$HOME/L/M/B\":"
ls -lad "$HOME"/Library/Mail/Bundles*
ls -l "$HOME"/Library/Mail/Bundles*
echo "========================================================================="


echo -e "\n*** Mail bundle configuration...\n========================================================================="
echo "  * Bundles enabled: "
defaults read com.apple.mail EnableBundles
echo "  * Bundles compatibility: "
defaults read com.apple.mail BundleCompatibilityVersion
echo "========================================================================="

echo "*** More about the configuration...";
mount
set

echo -e "\n*** Some debugging information from Mail...\n========================================================================="
defaults write org.gpgtools.gpgmail GPGMailDebug -int 1
/Applications/Mail.app/Contents/MacOS/Mail &
pid=$!
sleep 5
kill "$pid"
defaults write org.gpgtools.gpgmail GPGMailDebug -int 0
exec 1>&3 2>&4
echo "========================================================================="


echo "Thank you. Please send the file $PWD/$0.log to private@gpgtools.org"

echo "tell application \"Mail\"
    activate
    set MyEmail to make new outgoing message with properties {visible:true, subject:\"Debugging GPGTools\", content:\"DISCLAIMER: $disclaimer\n\n\n\"}
    tell MyEmail
        make new to recipient at end of to recipients with properties {address:\"private@gpgtools.org\"}
        make new attachment with properties {file name:((\"$PWD/$0.log\" as POSIX file) as alias)}
    end tell
end tell
" | osascript
