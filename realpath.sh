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
#	$Id: realpath.sh,v 1.11 2026/01/18 19:27:08 sjg Exp $
#
#	@(#) Copyright (c) 2012-2026 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

_REALPATH_SH=:

: ${SB_TOOLS:=`dirname $0`}

$_HAVE_SH . $SB_TOOLS/have.sh
$_isPOSIX_SHELL_SH . $SB_TOOLS/isposix-shell.sh
$_TEST_OPT_SH . $SB_TOOLS/test_opt.sh

have realpath
_trp=$?

case "/$0" in
*/realpath*)
    case "$1" in
    --force) shift; _trp=1;;
    esac
    ;;
esac

test_opt L -h

read_link() {
    if test $test_L $1; then
        'ls' -l $1 | sed 's,.*> ,,'
    else
        echo $1
    fi
}

if test $_trp = 1; then
    # if cd supports -P we need it
    test_opt P "" . cd
    
resolve_link() {
    case "$1" in
    */*) d=`dirname $1`;;
    *) d=`${pwd:-'pwd'}`;;
    esac
    x=`read_link $1`
    case "$x" in
    /*) echo $x;;
    *) echo $d/$x;;
    esac
}

realpath1() {
    # deal with the trivial case first
    if test -d "$1"; then
        ('cd' $cd_P "$1" && ${pwd:-'pwd'})
        return 0
    fi
    f=`resolve_link $1`
    while test -s $f -a $test_L $f
    do
        f=`resolve_link $f`
    done
    case "$f" in
    */*)
        d=`dirname $f`
        b=`basename $f`
        while :
        do
            if test -d $d; then
                d=`'cd' $cd_P $d/. && ${pwd:-'pwd'}`
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

realpath() {
    for p in "$@"
    do
        realpath1 "$p"
    done
}
fi

case "/$0" in
*/realpath*) realpath "$@";;
esac
