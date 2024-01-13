:
# NAME:
#	add_path.sh - add dir to path
#
# SYNOPSIS:
#	add_path "dir" ["list"]
#	del_path "dir" ["list"]
#	pre_path "dir" ["list"]
#	Which ["test"] "file" ["path"]
#	
# DESCRIPTION:
#	These functions originated in /etc/profile and ksh.kshrc, but
#	are more useful in a separate file.
#
#	'add_path' will append "dir" to the colon separated "list"
#	(PATH) but only if "dir" exists and is not already in "list".
#	
#	'pre_path' as for 'add_path' but prepends "dir".
#
#	'del_path' removes "dir" from "list"
#
#	'Which' will search the colon separated "path" (PATH)
#	for "file".  If found and "test" (-x) succeeds it echos the
#	path found.
#
#
# SEE ALSO:
#	/etc/profile
#	
# AUTHOR:
#	Simon J. Gerraty <sjg@crufty.net>

# RCSid:
#	$Id: add_path.sh,v 1.6 2002/05/08 05:11:08 sjg Exp $
#
#	@(#)Copyright (c) 1991 Simon J. Gerraty
#
#	This file is provided in the hope that it will
#	be of use.  There is absolutely NO WARRANTY.
#	Permission to copy, redistribute or otherwise
#	use this file is hereby granted provided that 
#	the above copyright notice and this notice are
#	left intact. 

# avoid multiple inclusion
_ADD_PATH_SH=:

# is $1 missing from $2 (or PATH) ?
no_path() {
	eval "__p=\$${2:-PATH}"
	case :$__p: in *:$1:*) return 1;; *) return 0;; esac
}

# if $1 exists and is not in path, append it
add_path () {
	case "$1" in
	-*) t=$1; shift;;
	*) t=-d;;
	esac
	[ $t ${1:-.} ] && no_path $* && eval ${2:-PATH}="$__p${__p:+:}$1"
}
# if $1 exists and is not in path, prepend it
pre_path () {
	case "$1" in
	-*) t=$1; shift;;
	*) t=-d;;
	esac
	[ $t ${1:-.} ] && no_path $* && eval ${2:-PATH}="$1${__p:+:}$__p"
}
# if $1 is in path, remove it
del_path () {
	no_path $* || eval ${2:-PATH}=`echo :${__p}: | 
		sed -e "s;:$1:;:;g" -e "s;^:;;" -e "s;:\$;;"`
}

# we use this all the time too
Which() {
	case "$1" in
	-*) t=$1; shift;;
	*) t=-x;;
	esac
	case "$1" in
	/*)	test $t $1 && echo $1;;
	*)
		for d in `IFS=:; echo ${2-$PATH}`
		do
			test $t $d/$1 && { echo $d/$1; break; }
		done
		;;
	esac
}

case "$0" in
*_path.sh)
        f=`basename $0 .sh`
        $f $*
        ;;
esac
