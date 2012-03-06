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



GNUPG_DIR="${GNUPGHOME:-$HOME/.gnupg}"
if [ "${0:0:1}" == "/" ] ;then
	LOGFILE="$0.log"
else
	LOGFILE="$PWD/$0.log"
fi
:> "$LOGFILE"
exec 3>&1 4>&2 >"$LOGFILE" 2>&1




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

echo -e "\n*** List '$GNUPG_DIR'...\n========================================================================="
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


echo -e "\n*** General system configuration...\n========================================================================="
set
echo
mount
echo "========================================================================="


echo -e "\n*** Testing encryption (1/2)...\n========================================================================="
if [ -n "$YOURKEY" ]; then
  echo "  * GPG1:"
  gpg -aer "$YOURKEY" <<<"test" | gpg 
  echo "  * GPG2:"
  gpg2 -aer "$YOURKEY" <<<"test" | gpg2
fi
echo "========================================================================="


echo -e "\n*** Testing encryption (2/2)...\n========================================================================="
echo "  * GPG1:"
gpg -ae --default-recipient-self <<<"test" | gpg

echo "  * GPG2:"
gpg2 -ae --default-recipient-self <<<"test" | gpg2
gpg2 -ae --default-recipient-self <<<"test"
gpg2 -as <<<"test"
gpg2 -aes --default-recipient-self <<<"test"
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





echo -e "\n*** Some debugging information from Mail...\n========================================================================="
osascript <<<'tell application "Mail" to quit'
defaults write org.gpgtools.gpgmail GPGMailDebug -int 1
/Applications/Mail.app/Contents/MacOS/Mail &
sleep 3
defaults write org.gpgtools.gpgmail GPGMailDebug -int 0
echo "========================================================================="


exec 1>&3 2>&4

echo -e "Thank you.\nPlease send the file \"$LOGFILE\" to private@gpgtools.org\n\n"


osascript >/dev/null <<-EOT
tell application "Mail"
    activate
    set MyEmail to make new outgoing message with properties {visible:true, subject:"Debugging GPGTools", content:"DISCLAIMER: $disclaimer\n\n\n"}
    tell MyEmail
        make new to recipient at end of to recipients with properties {address:"private@gpgtools.org"}
        make new attachment with properties {file name:(("$LOGFILE" as POSIX file) as alias)}
    end tell
end tell
EOT

