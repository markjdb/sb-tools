:
# RCSid:
#	$Id: atexit.sh,v 1.12 2025/08/07 21:59:54 sjg Exp $
#
#	@(#) Copyright (c) 1993 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

# a semi-reliable atexit() facility
atexit() {
    case "$1" in
    ""|:) # someone just wants to initialize us
        # this is deprecated due to ksh silliness.
	;;
    *)	at_exit="$*;$at_exit"
        ;;
    esac
}

# ensure ExitStatus is accurate
Exit() {
	ExitStatus=$1
	exit $1
}

if test x$_ATEXIT_SH = x; then
    # we have to do this out here, because if done within
    # the function, ksh exits on return from the function!
    at_exit="trap 0; eval exit '\${ExitStatus:-${ExitStatus:-0}}'"
    trap "Exit 1" 1 2 3 15
    trap 'eval $at_exit' 0
fi
_ATEXIT_SH=:
