#!/usr/bin/env bash
# Ermittelt den aktuellen Branch und führt ein "git pull origin branch" aus.


commit=$(git rev-parse HEAD) || exit 1
branch=$(git show-ref | sed -En "/HEAD/d;s#$commit .*/##p") || exit 2
if [ -z "$branch" ]; then
	branch="master"
fi
git pull ${branch:+origin $branch} || exit 3
