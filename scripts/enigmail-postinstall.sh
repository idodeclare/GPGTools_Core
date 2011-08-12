#!/bin/sh
tempdir=/private/tmp/Enigmail_Installation
thunderbirdextensiondir=$HOME/Library/Thunderbird/Profiles/$(ls $HOME/Library/Thunderbird/Profiles | grep default)/extensions
enigmailid="{847b3a00-7ab1-11d4-8f02-006008948af5}";
enigmaildir="$thunderbirdextensiondir/$enigmailid/";

mkdir -p "$enigmaildir";
unzip $tempdir/enigmail*.xpi -d "$enigmaildir";
rm $tempdir/enigmail*.xpi
chown -R "$USER:staff" "$enigmaildir";

# cleanup tempdir "rm -d" deletes the temporary installation dir only if empty.
# that is correct because if eg. /tmp is you install dir, there can be other stuff
# in there that should not be deleted
rm -d "$tempdir"

if [ -e "$enigmaildir/chrome.manifest" ]; then
  exit 0
else
  exit 1;
fi
