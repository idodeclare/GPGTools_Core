#!/bin/sh

stdDir="/usr/local";
gpgDir="/usr/local/MacGPG1";

[ -L $stdDir/bin/gpg ] && rm $stdDir/bin/gpg
[ -f $stdDir/bin/gpg ] || ln -s $gpgDir/bin/gpg $stdDir/bin/gpg

exit 0
