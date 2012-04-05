USER=$(id -un)
chown -R "$USER:staff" "$HOME/.gnupg"
chown -R "$USER:staff" "$HOME/Library/Services/GPGServices.service"
chown -R "$USER:staff" "$HOME/Library/PreferencePanes/GPGPreferences.prefPane"
chown root:wheel /Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist

# fix permissions (http://gpgtools.lighthouseapp.com/projects/65764-gpgmail/tickets/134)
mkdir -p "$HOME/Library/Mail/Bundles"
chown -R "$USER:staff" "$HOME/Library/Mail/Bundles"
chmod 755 "$HOME/Library/Mail/Bundles"
