#!/bin/sh

# NAME:
#	list-conflicts.sh list conflicted files after merge
#
# SYNOPSIS:
#	list-conflicts.sh [-l update.log]
#
# DESCRIPTION:
#	Use SCM specific method to list files in conflict
#
#	For some SCM (cvs,svn) it is more efficient to examine an
#	update.log
#

# RCSid:
#	$Id: list-conflicts.sh,v 1.6 2026/01/17 06:54:20 sjg Exp $
#
#	@(#) Copyright (c) 2020 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

Mydir=`dirname $0`

# we need to know the SCM
. $Mydir/scm-funcs.sh

opt_str=l:
. $Mydir/setopts.sh

# handle systems that deprecate egrep
case "`echo egrep | egrep 'e|g' 2>&1`" in
egrep) ;;
*) egrep() { grep -E "$@"; };;
esac

case "$SCM" in
cvs)
    if [ -s ${opt_l:-/dev/null} ]; then
        egrep '^C' $opt_l | sed 's,^..,,'
    else
        rep=`cat CVS/Repository`
        $SCM_CMD status "$@" 2> /dev/null |
        egrep 'Conflict|Repository' |
        grep -A1 Conflict |
        sed -n "/Repository/{s:.*$rep/::;s:,v::;p;}"
    fi
    ;;
git) $SCM_CMD status -s "$@" | sed '/^[^U][^U]/d;s,^...,,';;
hg) $SCM_CMD resolve -l "$@";;
svn)
    if [ -s ${opt_l:-/dev/null} ]; then
        egrep '^ *[CE][A-U ]* |remains in conflict' $opt_l |
        sed "s: -- .*::;s:^.* ::;s,^${SRCTOP:-$SB_SRC}/,,"
    else
        $SCM_CMD status "$@" 2> /dev/null |
	    egrep '^  *[CE][A-U ]* ' |
	    awk '{ print $NF }'
    fi
    ;;
esac
