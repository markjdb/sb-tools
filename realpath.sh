:
# NAME:
#	realpath - for systems that lack it
#
# DESCRIPTION:
#	If there is no 'realpath' binary, provide a function that
#	that achieves (generally) the same result.
#
#
# AUTHOR:
#	Simon J. Gerraty <sjg@crufty.net>

# RCSid:
#	$Id: realpath.sh,v 1.7 2022/06/20 21:15:05 sjg Exp $
#
#	@(#) Copyright (c) 2012 Simon J. Gerraty
#
#	This file is provided in the hope that it will
#	be of use.  There is absolutely NO WARRANTY.
#	Permission to copy, redistribute or otherwise
#	use this file is hereby granted provided that 
#	the above copyright notice and this notice are
#	left intact. 
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

_REALPATH_SH=:

_trp=`(type realpath) 2> /dev/null |
	sed '/not.*found/d;/function/d;s,.* /,/,'`

case "/$0" in
*/realpath*)
    case "$1" in
    --force) shift; _trp=;;
    esac
    ;;
esac

read_link() {
    if test -h $1; then
	'ls' -l $1 | sed 's,.*> ,,'
    else
	echo $1
    fi
}

if test -z "$_trp"; then
realpath() {

    if test -d "$1"; then
	('cd' $1 && ${pwd:-'pwd'})
	return
    fi
    f=`read_link $1`
    while test -s $f -a -h $f
    do
        f=`read_link $f`
    done
    case "$f" in
    */*)
	d=`dirname $f`
	b=`basename $f`
	while :
	do
	    if test -d $d; then
		d=`cd $d && ${pwd:-'pwd'}`
		break
	    fi
	    case "$d" in
	    */*)
		b=`basename $d`/$b
		d=`dirname $d`
		continue
		;;
	    esac
	    echo $1
	    return
	done
	;;
    *) d=`${pwd:-'pwd'}`; b=$1;;
    esac
    echo $d/$b
}
fi

case "/$0" in
*/realpath*) realpath "$@";;
esac
