#!/bin/sh
tempdir=/private/tmp/Enigmail_Installation
thunderbirdextensiondir=$HOME/Library/Thunderbird/Profiles/$(ls $HOME/Library/Thunderbird/Profiles | grep default)/extensions

mv $tempdir/enigmail.xpi $thunderbirdextensiondir
chown $USER:Staff "$thunderbirdextensiondir/enigmail.xpi"

# cleanup tempdir "rm -d" deletes the temporary installation dir only if empty.
# that is correct because if eg. /tmp is you install dir, there can be other stuff
# in there that should not be deleted
rm -d "$tempdir"
