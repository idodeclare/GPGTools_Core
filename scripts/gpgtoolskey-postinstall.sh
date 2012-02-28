#!/bin/bash

echo "[gtk] Setting up environment..."
_path="/private/tmp/GPGTools_Key";
_file="0x76D78F0500D026C4.asc";
_fp="85E38F69046B44C1EC9FB07B76D78F0500D026C4";
_trust="6";

echo "[gtk] Importing key..."
su - $USER -c "/usr/local/bin/gpg --import $_path/$_file" && \
su - $USER -c "echo $_fp:$_trust: | /usr/local/bin/gpg --import-ownertrust"

echo "[gtk] Installing GPGTools key: $? (error code)";

echo "[gtk] Cleaning up..."
rm "$_path/$_file";
rm -r "$_path";

exit 0
