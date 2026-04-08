:
# RCSid:
#	$Id: on-error.sh,v 1.7 2026/01/15 02:12:41 sjg Exp $
#
#	@(#) Copyright (c) 2002-2012 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

_ON_ERROR_SH=:

on_error_cmds=:
on_error() {
    on_error_cmds="$@;$on_error_cmds"
}

Error() {
    case "$1" in
    0) ExitStatus=1; shift;;	# some apps exit 0 in error
    [1-9]|[1-9][0-9]) ExitStatus=$1; shift;;
    *) ExitStatus=1;;
    esac
    echo "ERROR: $@" >&2
    eval "$on_error_cmds"
    exit $ExitStatus
}

error() {
    Error "$@"
}
