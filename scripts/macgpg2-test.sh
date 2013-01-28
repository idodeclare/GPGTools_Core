#!/bin/bash

_log="/tmp/`basename $0`.log"

echo -n "[Files installed] "
[ -d /usr/local/MacGPG2 ] && echo "OK" || (echo "ERROR"; exit 1)

echo -n "[Executable] "
gpg --version > "${_log}" 2>&1 && echo "OK" || (echo "ERROR:"; cat "${_log}"; exit 1)
