#!/bin/sh

mkdir -p $HOME/Library/PreferencePanes/
chown -R $USER /private/tmp/GPGTools.prefPane $HOME/Library/PreferencePanes
rm -fr $HOME/Library/PreferencePanes/GPGTools.prefPane
mv /private/tmp/GPGTools.prefPane $HOME/Library/PreferencePanes/

exit 0;
