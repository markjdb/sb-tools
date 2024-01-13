#!/bin/sh

# NAME:
#	clear-depend-conflicts.sh - clear conflicts in Makefile.depend*
#
# SYNOPSIS:
#	clear-depend-conflicts.sh list
#
# DESCRIPTION:
#	The DIRDEPS build is generally self repairing.
#	Conflicts in Makefile.depend files can generally be ignored
#	since the worst case is an extra (possibly bogus) dependency
#	which will be ignored if it does not exists.
#
#	Thus we can simply delete conflict markers in any
#	Makefile.depend files in "list", and proceed to build the
#	impacted directories, and the Makefile.depend should be
#	updated correctly after that.
#
#	Different SCMs require different operations to indicate that
#	we have resolved conflicts, or in the cases where that will
#	not work, revert the files.
#
# SEE ALSO:
#	scm-funcs.sh

# RCSid:
#	$Id: clear-depend-conflicts.sh,v 1.4 2021/04/20 18:58:51 sjg Exp $
#
#	@(#) Copyright (c) 2020 Simon J. Gerraty
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

Mydir=`dirname $0`

Error() {
    echo "ERROR: $@" >&2
    exit 1
}

Note() {
    echo "NOTICE: $@" >&2
}

CL=${1:-cl}

test -s $CL || Error "need a list of conflicted files"

TF=/tmp/cdc$$

# get a *sorted* (for benefit of comm) list of Makefile.depend files
grep Makefile.depend $CL | sort > $TF.mcl
if [ -s $TF.mcl ]; then
    # we need to know the SCM
    . $Mydir/scm-funcs.sh
    # this is more useful/portable than sed -i
    $Mydir/sedem.sh -v '/^[<>=|]/d' < $TF.mcl > $TF.fmcl
    # now get a list of the files not fixed
    comm -3 $TF.mcl $TF.fmcl > $TF.cmcl
    if [ -s $TF.fmcl ]; then
        n=`wc -l < $TF.fmcl`
        Note resolved $n
        flags=
	case "$SCM" in
	git) op=add;;
	hg) op=resolve flags=-m;;
	svn) op=resolved;;
	esac
        case "$SCM" in
	cvs) ;;
	*) xargs $SCM_CMD $op $flags < $TF.fmcl;;
	esac
    fi
    if [ -s $TF.cmcl ]; then
        n=`wc -l < $TF.cmcl`
        Note reverted $n
        flags=
        case "$SCM" in
	cvs) op=update;;
	git) op=checkout;;
	hg|svn) op=revert;;
	esac
        xargs rm < $TF.cmcl
        xargs $SCM_CMD $op $flags < $TF.cmcl
    fi
fi
rm -f $TF.*
