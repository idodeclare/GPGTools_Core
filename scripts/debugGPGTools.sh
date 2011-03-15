#!/bin/sh

if [ "$1" == "" ]; then
  echo "Usage: $0 <0xYOURKEY>";
  exit 1;
fi

exec 3>&1 4>&2 >$0.log 2>&1

echo "*** Setup...";
YOURKEY="$1"
echo "  * $YOURKEY";

echo "*** Showing installed binaries...";
echo "  * GPG1:"
which gpg; gpg --version; 
echo "  * GPG2:"
which gpg2; gpg2 --version

echo "*** Testing configuration...";
gpg2 --gpgconf-test; echo $?

echo "*** Testing encryption...";
echo "  * GPG1:"
echo "test"|gpg -aer "$YOURKEY"|gpg
echo "  * GPG2:"
echo "test"|gpg2 -aer "$YOURKEY"|gpg2

echo "*** Showing installed bundles...";
echo "  * /L/M/B:"
ls -l /Library/Mail/Bundles*
echo "  * ~/L/M/B:"
ls -l ~/Library/Mail/Bundles*

echo "*** Some debugging information...";
defaults write org.gpgtools.gpgmail GPGMailDebug -int 1
/Applications/Mail.app/Contents/MacOS/Mail &
exec 1>&3 2>&4

echo "Please send the file '$0.log' to the developers." 

