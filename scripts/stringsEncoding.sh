#!/bin/bash

function errExit() {
	msg="$* (${BASH_SOURCE[1]##*/}: line ${BASH_LINENO[0]})"
	if [[ -t 1 ]] ;then
		echo -e "\033[1;31m$msg\033[0m" >&2
	else
		echo "$msg" >&2
	fi
	exit 1
}

[[ -d Resources ]] || errExit "The directory 'Resources' could not be found!"
command -v "iconv" >/dev/null 2>&1 || errExit "iconv could not be found!" >&2


TEMPFILE=build/iconvTemp.strings
mkdir -p build

find Resources -name "*.strings" -print0 | xargs -0 file | sed -Ene 's/(.*\.strings):.*UTF-16.*/\1/p' |
while read file
do
	echo "Converting ${file#Resources/}"
	iconv -f UTF-16 -t UTF8 "$file" > "$TEMPFILE" || errExit "Failed to convert ${file#Resources/}"
	mv "$TEMPFILE" "$file" || errExit "Failed to rename ${file#Resources/}"
	
done

echo "Converting done"
