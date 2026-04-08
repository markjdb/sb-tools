#!/bin/sh

# NAME:
#	scm-funcs.sh - scm wrapper funcs
#
# SYNOPSIS:
#	scm-funcs.sh ["options"] "op" "args"
#	scm ["options"] "op" "args"
#	scm-"op" "args"
#
# DESCRIPTION:
#	It can be annoying to keep track of which SCM a given project
#	is using, and while some SCMs like GIT automatically pipe
#	outout through a pager, not all do.
#	This script provides a number of functions to compensate.
#
#	It can be read into a shell, and the functions used directly,
#	or it can be run as a separate process, in which case the "op"
#	is either included in the name or is the first argument.
#
#	If run as 'scm' or 'scm-funcs.sh' the following options are
#	supported:
#
#	-C "dir"
#		chdir to "dir"
#
# NOTE:
#	Only the common operations: 'blame' 'diff' 'help' 'log'
#	'status' are provided by default.
#	
#	A simple 'revert' operation is provided for CVS.
#	

# RCSid:
#	$Id: scm-funcs.sh,v 1.35 2026/03/04 20:05:15 sjg Exp $
#
#	@(#) Copyright (c) 2020-2025 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

case "/$0" in
*/scm*)
    # make sure we can find have.sh
    _this=`realpath $0 2> /dev/null`
    _this=${_this:-$0}
    Mydir=`dirname $_this`
    PATH=$Mydir:$PATH

    case "/$0" in
    */scm|*/scm-funcs*)
        # we need to handle these options early
        while :
        do
            : 1=$1
            case "$1" in
            -C) cd "$2" || exit 1; shift 2;;
            *) break;;
            esac
        done
        ;;
    esac
    ;;
esac

if [ -z "$SB$SCM$SRCTOP" ]; then
    # we will need find_it for ...
    $_SB_FUNCS_SH . sb-funcs.sh
fi
$_HAVE_SH . have.sh
$_isPOSIX_SHELL_SH . isposix-shell.sh

get_SCM() {
    clues="CVS/Entries .hg .svn .git"
    for d in . .. ${SRCTOP:-${SB_SRC:-$SB/src}} $SB ...
    do
        for clue in $clues
        do
            : d=$d
            case "$d" in
            ...)
                if have find_it; then
                    find_it --start .. --path $clues |
			sed 's,.*[./],,;s,Entries,cvs,'
                fi
                return
                ;;
            esac
            test -s $d/$clue || continue
            case "$clue" in
            CVS/*) echo cvs; return;;
            .*) echo ${clue#.}; return;;
            esac
        done
    done
}

# tr is insanely non-portable wrt char classes, so we need to
# spell out the alphabet. sed y/// would work too.
toUpper() {
	${TR:-tr} abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ
}

toLower() {
	${TR:-tr} ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz
}

# a simple revert method for CVS
cvs_revert() {
    t=/tmp/.$USER.cr$$
    d=$t.d
    
    for p in "$@"
    do
        test -f $p || continue
        ${CVS:-cvs} diff -u $p > $d
        test -s $d || continue
        ${PATCH:-patch} -p0 -R < $d > $t.p 2>&1  &&
        echo Reverted $p
    done
    rm -f $t.*
}
        
scm_op() {
    op=$1; shift
    case "$SCM,$op" in
    cvs,blame) op=annotate;;
    cvs,revert) cvs_revert "$@"; return;;
    cvs,up*) ${CVS:-cvs} update -dP "$@"; return;;
    *,up) $SCM_CMD $op "$@"; return;;
    esac
    $SCM_CMD $op "$@" | ${PAGER}
}

scm_ops() {
    op=$1; shift
    for f in "$@"
    do
        scm_op $op $f || break
    done
}

# a convenience wrapper
scm() {
    op=$1; shift
    case "$op" in
    commit) $SCM_CMD $op "$@"; return;;
    diffl*) diff2list "$@"; return;;
    up*) scm_op $op "$@"; return;;
    esac
    for f in scm_$op ${SCM}_$op
    do
        if have $f; then
            $f "$@"
            return
        fi
    done
}

_scm_diff() {
    case "$1" in
    --xargs) _xargs=xargs; shift;;
    *) _xargs=;;
    esac
    diff_opts=
    case "$SCM" in
    cvs) diff_opts="-up";;
    git) diff_opts="--full-index";;
    hg) diff_opts="-p";;
    svn) diff_opts="-x -p";;
    esac
    $_xargs $SCM_CMD diff $diff_opts "$@"
}

diff2list() {
    # do not assume SCM that generated patch
    sed -n \
    -e '/^diff.* -r[1-9][0-9]*\.[1-9]/d' \
    -e '/^diff.*--git/s,.* b/,,p' \
    -e '/^diff/s,.* \(b/\)*,,p' \
    -e '/^\+\+\+/s,+++ b/\([^[:space:]]*\)[[:space:]].*,\1,p' \
    -e '/^Index:/s,Index: ,,p' \
    -e '/^Property changes on:/s,Property changes on: ,,p' \
    "$@" | sort -u
}

PAGER=${PAGER:-more}
SCM=${SB_SCM:-${SCM:-`get_SCM`}}
SCM_VAR=`echo $SCM | toUpper`
eval SCM_CMD=\${$SCM_VAR:-$SCM}

# if we run patch with a diff from scm, what
# arg should we give -p ?
case "$SCM" in
git|hg) PATCH_p=1;;
*)      PATCH_p=0;;
esac

# git & hg do not need PAGER for most things
# but it doesn't hurt and lends consistency
# also allows use of scm_*
for op in blame diff help log status $SCM_OPS
do
    case "$op" in
    diff) _scm_op=_scm_diff;;
    *) _scm_op="$SCM_CMD $op";;
    esac
    eval "scm_$op() { $_scm_op \"\$@\"| ${PAGER}; }"
    eval "${SCM}_$op() { $_scm_op \"\$@\"| ${PAGER}; }"
    case "$op" in
    log) # multiple args handle each with PAGER individually
        eval "scm_${op}s() { scm_ops $op \"\$@\"; }"
        eval "${SCM}_${op}s() { scm_ops $op \"\$@\"; }"
        ;;
    esac
done

case "/$0" in
*/diffl*|*/diff2l*)
    diff2list "$@"
    ;;
*/scm*)
    MYNAME=scm
    if is_posix_shell; then
        Myname=${0##*/}
        Myname=${Myname%.sh}
    else
        Myname=`basename $0 .sh`
    fi
    case "$Myname" in
    scm-funcs|scm)
        scm "$@"
        ;;
    scm-*)
        if is_posix_shell; then
            op=${Myname#scm-}
        else
            op=`expr $Myname : 'scm-\(.*\)'`
        fi
        scm $op "$@"
        ;;
    esac
esac
