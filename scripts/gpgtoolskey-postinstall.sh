#!/bin/bash

/usr/local/bin/gpg --import /private/tmp/GPGTools_Key/0x76D78F0500D026C4.asc && \
echo 85E38F69046B44C1EC9FB07B76D78F0500D026C4:6: | /usr/local/bin/gpg --import-ownertrust
echo "Installing GPGTools key: $? (error code)";
exit 0
