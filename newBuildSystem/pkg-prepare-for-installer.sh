#!/usr/bin/env bash

# Include some core helper methods.
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

if [ "$#" -lt 2 ]; then
	errExit "I require at least 2 arguments: CORE_PKG_DIR and PROJECT"
fi

CORE_PKG_DIR=$1
NAME=$2

if [ -z "$CORE_PKG_DIR" ]; then
	errExit "You have to specify CORE_PKG_DIR."
fi

# Create core packages dir if it doesn't exist.
mkdir -p "$CORE_PKG_DIR"

if [ ! -d "$CORE_PGK_DIR"]; then
	errExit "Core packages location doesn't exist: $CORE_PKG_DIR"
fi

if [ ! -w "$CORE_PKG_DIR" ]; then
	errExit "No permission to write to $CORE_PKG_DIR - that will lead to problems. Abort."
fi

if [ -z "$NAME" ]; then
	errExit "Project name can't be empty."
fi

ALT_NAME=""
if [ "$#" -eq 3 ]; then
	ALT_NAME="$3"
fi

# Find all _Core.pkg files in build directory.
CORE_PACKAGES="build/*_Core.pkg"

if [ -z "$CORE_PACKAGES" ]; then
	errExit "No core packages found. Abort."
fi

for package in $CORE_PACKAGES; do
	SOURCE_PATH="$package"
	if [ -n "$ALT_NAME" ]; then
		package=$(echo $package | sed s/$NAME/$ALT_NAME/)
	fi
	DEST_PATH="$CORE_PKG_DIR/$(basename $package)"
	
	cp "$SOURCE_PATH" "$DEST_PATH"
done