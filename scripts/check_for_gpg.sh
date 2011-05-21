#!/bin/sh
#
# This skript returns 0 if either gpg or gpg2 is installed on the system.
#
# @todo     Refactor it.
#

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/local/bin

# default test
if ( /usr/bin/which -s gpg ) then
	exit 0;
fi
if ( /usr/bin/which -s gpg2 ) then
	exit 0;
fi

# double check in case the user has an incorrect .profile file
[ -r "$HOME/.profile" ] && . "$HOME/.profile"
if ( /usr/bin/which -s gpg ) then
	exit 0;
fi
if ( /usr/bin/which -s gpg2 ) then
	exit 0;
fi

exit 1;
