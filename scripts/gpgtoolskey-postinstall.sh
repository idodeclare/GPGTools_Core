#!/bin/bash

_path="/private/tmp/GPGTools_Key";
_file="0x76D78F0500D026C4.asc";
_fp="85E38F69046B44C1EC9FB07B76D78F0500D026C4";
_trust="6";

/usr/local/bin/gpg --import "$_path/$_file" && \
echo $_fp:_$trust: | /usr/local/bin/gpg --import-ownertrust
echo "Installing GPGTools key: $? (error code)";
rm "$_path/$_file";
rm -r "$_path";
exit 0
