#!/bin/sh

# NAME:
#	sb-symlink.sh - make a symlink in SB
#
# SYNOPSIS:
#	$_SB_SYMLINK_SH . sb-symlink.sh
#	make_raw_symlink [--check] src target
#	make_relative_symlink [--check] src target
#	make_symlink [--check] src target
#
# DESCRIPTION:
#	make_raw_symlink just makes the link with its args.
#
#	make_relative_symlink will make target point to src via a
#	relative path.
#
#	make_symlink will call one of the above based on setting of
#	MK_SYMLINKS_RELATIVE.
#
#	With '--check' we see if the symlink is already as desired
#	and if so, leave it alone.
#
# AUTHOR:
#	Simon J. Gerraty <sjg@crufty.net>

# RCSid:
#	$Id: sb-symlink.sh,v 1.9 2026/01/18 22:25:00 sjg Exp $
#
#	@(#) Copyright (c) 2024-2026 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

_SB_SYMLINK_SH=:

: ${SB_OBJROOT:=$SB/obj}
: ${SRCTOP:=$SB/src}
: ${SB_TOOLS:=`dirname $0`}

$_REALPATH_SH . $SB_TOOLS/realpath.sh

_sb_symlink_init_once=:
_sb_symlink_init() {
    $_sb_symlink_init_once 0
    _sb_symlink_init_once=return

    if test -d ${SB:-/dev/null} && test -d $SB_OBJROOT; then
        SB_src=`realpath $SRCTOP`
        SB_obj=`realpath $SB_OBJROOT`

        case "$SB_OBJROOT" in
        */) SB_obj=$SB_obj/;;
        esac
        
        if test $SB_obj != $SB_OBJROOT && test ! -L $SB_obj/src; then
            # if doing split-fs it is important that $SB/obj/src exists
            # and points to $SB/src
            make_raw_symlink $SRCTOP $SB_obj/src
        fi
    fi
}

##
# _reltop path
#
# compute relative path below src or obj
#
_reltop() {
    _sb_symlink_init
    for top in obj src
    do
        case "$top,$SB_src" in
        src,$SB) ;;
        *) test -d $SB/$top || continue;;
        esac
        eval sb_top=\${SB_$top}
        if $isPOSIX_SHELL; then
            reltop=${1#${sb_top%/}/}
        else
            case "$sb_top" in
            */) reltop=`echo $1 | sed "s,^$sb_top,,"`;;
            *) reltop=`echo $1 | sed "s,^$sb_top/,,"`;;
            esac
        fi
        case "$reltop" in
        /*) ;;
        *)
            dots=`echo $reltop | sed 's,[^/][^/]*,..,g'`
            return
            ;;
        esac
    done
    dots=
}

##
# make_raw_symlink [--check] src target
#
# just use the args as given.
# if --check return early if target already points to src
#
make_raw_symlink() {
    case "$1" in
    --check)
        shift
        case `read_link $2` in
        $1) return 0;;
        esac
        ;;
    esac
    ${LN:-ln} -${LN_s:-snf} "$@"
}

##
# make_relative_symlink [--check] src target
#
# make symlink using a relative path from target to src
# if --check return early if target already points to realpath of src
#
make_relative_symlink() {
    eval ${_local:-:} __check dots realtarget reltop \
	 s src srel stop t target tdir top trest
    if [ -z "$SB" ] || ! $isPOSIX_SHELL; then
        # we only work in $SB with a POSIX shell
        make_raw_symlink "$@"
        return $?
    fi
    case "$1" in
    --check) __check=$1; shift;;
    *) __check= ;;
    esac
    src=$1
    target=$2

    # we expect src to be realpath
    case "$src" in
    /*) ;;
    *) src=`realpath $src`;;
    esac
    case "$target" in
    /*|../*) ;;
    *) target=`'pwd'`/$target;;
    esac
    # see if src is even under $SB
    _reltop $src
    case "$reltop" in
    /*) # no
        make_raw_symlink $__check "$@"
        return $?
        ;;
    esac
    srel=$reltop
    stop=$top
    # we need realpath of at least the
    # initital part of target
    if test -d $target && test ! -d $src; then
        # making a symlink in a directory
        # we need the last part to get the ../'s right
        realtarget=`realpath $target`/${src##*/}
    else
        # find a directory that exists...
        # we always want to skip the last component
        # which should be a symlink to $src!
        tdir=${target%/*}
        trest=${target##*/}
        while test ! -d $tdir
        do
            trest=${tdir##*/}$trest
            tdir=${tdir%/*}
            case "$tdir" in
            */*) ;;
            *) break;;
            esac
        done
        realtarget=`realpath $tdir`/$trest
    fi
    # now we can compute the correct relpath from
    # target to $SB/{src,obj}/
    _reltop ${realtarget}
    if test $stop != $top; then
        # the simple case
        src=$dots/$stop/$srel
    else
        # we may be able to optimize
        # consume one level of ../ for $top
        dots=${dots#*/}
        while test "$dots" != ".."
        do
            s=${srel%%/*}
            t=${reltop%%/*}
            test $s = $t || break
            srel=${srel#*/}
            reltop=${reltop#*/}
            dots=${dots#*/}
        done
        src=$dots/$srel
    fi
    make_raw_symlink $__check $src $target
}

##
# make_symlink [--check] src target
#
# if $MK_SYMLINK_RELATIVE is "yes" call make_relative_symlink
# otherwise call make_raw_symlink
#
make_symlink() {
    if test ${MK_SYMLINK_RELATIVE:-no} = yes; then
        make_relative_symlink "$@"
    else
        make_raw_symlink "$@"
    fi
}

case /$0 in
*raw_symlink*) make_raw_symlink "$@";;
*relative_symlink*) make_relative_symlink "$@";;
*make_symlink*) make_symlink "$@";;
*/sb-symlink*)
    case "$1" in
    *symlink) eval "$@";;
    esac
    ;;
esac
