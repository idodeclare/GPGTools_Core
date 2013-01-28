#!/bin/bash

_log="/tmp/`basename $0`.log"
_path="/usr/local/MacGPG2/bin"

echo -n "[Files installed] "
[ -d "${_path}" ] && echo "OK" || (echo "ERROR"; exit 1)

echo -n "[Executable] "
"${_path}"/gpg2 --version > "${_log}" 2>&1 && echo "OK" || (echo "ERROR:"; cat "${_log}"; exit 1)
