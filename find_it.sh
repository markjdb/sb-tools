:
# RCSid:
#	$Id: find_it.sh,v 1.7 2026/03/14 04:33:25 sjg Exp $
#
#	@(#) Copyright (c) 2015-2022 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

_FIND_IT_SH=:

_HAVE_SH=:
# do we have something ?
have() {
    # we cannot always rely on type to exit with bad status
    case "`(type $1) 2> /dev/null`" in
    *builtin*|*function*|*/*) return 0;;
    esac
    return 1
}

# find_it [--start $dir][-$test][--{parent,path,dir}] $path ...
# find the first $path in $start or above
# if --path report $dir/$path otherwise just $dir where $path found
# if --parent report $dir/.. where $path found
find_it() {
    _t=-s
    _start=.
    _stop=/
    _what=dir
    while :
    do
	case "$1" in
	-?) _t=$1; shift;;
	--parent) _what=parent; shift;;
	--path) _what=path; shift;;
	--dir) _what=dir; shift;;
	--start) _start=$2; shift; shift;;
	--stop) _stop=$2; shift; shift;;
	*) break;;
	esac
    done
    test -d $_start || return
    # try to make sure we start in the right place
    # symlinks can wreak havoc
    if have realpath; then
        _start=`realpath $_start`
    fi
    'cd' "$_start" > /dev/null 2>&1 || return 1
    pwd=${pwd:-'pwd'}		# avoid aliasing
    here=`$pwd`
    while :
    do
	for it in "$@"
	do
	    if test $_t $it; then
		case "$_what" in
		parent) ('cd' "$here/.." && $pwd);;
		path) echo $here/$it;;
		*) echo $here;;
		esac
		return
	    fi
	done
	'cd' "$here/.."
	here=`$pwd`
	case $here in
	$_stop|/) return;;
	esac
    done
}

case "/$0" in
*/find?it*) find_it "$@";;
esac
