#!/bin/bash

_log="/tmp/`basename $0`.log"
_path="/Applications/GPG Keychain Access.app/Contents/MacOS/GPG Keychain Access"


echo -n "[Files installed] "
[ -x "${_path}" ] && echo "OK" || (echo "ERROR"; exit 1)

#echo -n "[Executable] "
#"${_path}" --version > "${_log}" 2>&1 && echo "OK" || (echo "ERROR:"; cat "${_log}"; exit 1)
