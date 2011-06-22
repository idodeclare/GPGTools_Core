#!/bin/bash

#-------------------------------------------------------------------------
read -p "Compile sources [y/n]? " input

if [ "x$input" == "xy" -o "x$input" == "xY" ] ;then
    back="`pwd`";
    echo "Compiling GPGTools_Preferences...";
    mkdir -p payload/gpgtoolspreferences
    (cd ../GPGTools_Preferences && git pull && git submodule foreach git pull origin master && make && cd "$back" && rm -rf payload/gpgtoolspreferences/GPGTools.prefPane && cp -R ../GPGTools_Preferences/build/Release/GPGTools.prefPane payload/gpgtoolspreferences/) > build.log 2>&1
    if [ ! "$?" == "0" ]; then echo "ERROR. Look at build.log"; exit 1; fi
    echo "Compiling GPGServices...";
    mkdir -p payload/gpgservices
    (cd ../GPGServices && git pull && git submodule foreach git pull origin master && make && cd "$back" && rm -rf payload/gpgservices/GPGServices.service && cp -R ../GPGServices/build/Release/GPGServices.service payload/gpgservices/) > build.log 2>&1
    if [ ! "$?" == "0" ]; then echo "ERROR. Look at build.log"; exit 1; fi
    echo "Compiling GPGKeychainAccess..."
    mkdir -p payload/keychain_access
    (cd ../GPGKeychainAccess && git pull && git submodule foreach git pull origin master && make && cd "$back" && rm -rf payload/keychain_access/Applications/GPG\ Keychain\ Access.app && cp -R ../GPGKeychainAccess/build/Release/GPG\ Keychain\ Access.app payload/keychain_access/Applications/)  > build.log 2>&1
    if [ ! "$?" == "0" ]; then echo "ERROR. Look at build.log"; exit 1; fi
    echo "Compiling GPGMail...";
    mkdir -p payload/gpgmail
    (cd ../GPGMail && git pull && git submodule foreach git pull origin master && make && cd "$back" && rm -rf payload/gpgmail/GPGMail.mailbundle && cp -R ../GPGMail/build/Release/GPGMail.mailbundle payload/gpgmail/)  > build.log 2>&1
    if [ ! "$?" == "0" ]; then echo "ERROR. Look at build.log"; exit 1; fi
    echo "Compiling MacGPG2...";
    echo "tbd";
    #mkdir -p payload/gpg2
    #(cd ../MacGPG2 && git pull && git submodule foreach git pull origin master && make && cd "$back" && rm -rf payload/gpg2/* && cp -R ../MacGPG2/build/* payload/gpg2/) > build.log 2>&1
    #if [ ! "$?" == "0" ]; then echo "ERROR. Look at build.log"; exit 1; fi
fi
#-------------------------------------------------------------------------

