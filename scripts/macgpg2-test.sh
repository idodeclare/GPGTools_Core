#!/bin/bash

_log="/tmp/`basename $0`.log"
_path="/usr/local/MacGPG2/bin"
_tmp="/tmp/`basename $0`.tmp"
_key="0x00D026C4"
_server="hkp://pool.sks-keyservers.net"

echo -n "[Files installed] "
[ -d "${_path}" ] && echo "OK" || (echo "ERROR"; exit 1)

echo -n "[Executable] "
"${_path}"/gpg2 --version > "${_log}" 2>&1 && echo "OK" || (echo "ERROR:"; cat "${_log}"; exit 1)

echo -n "[Importing Key] "
gpg --keyserver "${_server}" --recv-keys "${_key}" > "${_log}" 2>&1 && echo "OK" || (echo "ERROR:"; cat "${_log}"; exit 1)

echo -n "[Encrypting] "
echo "test" > "${_tmp}"
gpg --yes -e -r "${_key}" "${_tmp}" > "${_log}" 2>&1 && echo "OK" || (echo "ERROR:"; cat "${_log}"; exit 1)