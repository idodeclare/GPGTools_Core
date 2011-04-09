#!/bin/sh

:> $0.log
exec 3>&1 4>&2 >$0.log 2>&1

echo "*** Setup...";
YOURKEY="`grep ^default-key ~/.gnupg/gpg.conf|awk '{print $2}'`"
echo "  * Default key: $YOURKEY";

echo "*** Showing installed binaries...";
echo "  * GPG1:"
which gpg; gpg --version;
echo "  * GPG2:"
which gpg2; gpg2 --version

echo "*** Testing configuration...";
gpg2 --gpgconf-test; echo $?

echo "*** The secret keys:";
echo "  * GPG1:"
gpg -K
echo "  * GPG2:"
gpg2 -K

echo "*** Testing encryption (1/2)...";
if [ ! ""  == "$YOURKEY" ]; then
  echo "  * GPG1:"
  echo "test"|gpg -aer "$YOURKEY"|gpg
  echo "  * GPG2:"
  echo "test"|gpg2 -aer "$YOURKEY"|gpg2
fi

echo "*** Testing encryption (2/2)...";
echo "  * GPG1:"
echo "test"|gpg -ae --default-recipient-self|gpg
echo "  * GPG2:"
echo "test"|gpg2 -ae --default-recipient-self|gpg2
echo "test"|gpg2 --default-recipient-self -ae
echo "test"|gpg2 -as
echo "test"|gpg2 --default-recipient-self -aes

echo "*** Showing installed bundles...";
echo "  * /L/M/B:"
ls -l /Library/Mail/Bundles*
echo "  * ~/L/M/B:"
ls -l ~/Library/Mail/Bundles*

echo "*** Bundle configuration...";
echo "  * Bundles enabled: ";
defaults read com.apple.mail EnableBundles
echo "  * Bundles compatibility: ";
defaults read com.apple.mail BundleCompatibilityVersion

echo "*** Configuration...";
cat ~/.gnupg/gpg.conf

echo "*** Some debugging information...";
defaults write org.gpgtools.gpgmail GPGMailDebug -int 1
/Applications/Mail.app/Contents/MacOS/Mail &
exec 1>&3 2>&4

echo "Please send the file '$0.log' to the developers."

