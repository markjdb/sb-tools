#!/bin/sh

# NAME:
#	sb-save-diffs - save diffs for sandbox
#
# SYNOPSIS:
#	sb-save-diffs.sh ["options"] "sb" [...]
#
# DESCRIPTION:
#	This script runs 'mkdiff' in each "sb" to save all current
#	changes in a file under "opt_d".
#
#	Options:
#
#	-d "opt_d"
#		Where to save diffs under (default
#		'${SB_SAVE:-~/sb-save}').
#
#	-f "fmt"
#		format for naming each saved diff
#		('{opt_d}/{opt_p}{sb_name}{opt_t}.diff')
#		any '{' is replaced by '${' so we can eval.
#
#	-p "opt_p"
#		optional prefix.
#
#	-q	passed to 'mkdiff'.
#
#	-t "opt_t"
#		A subdir named for the current date ('/%Y%m%d').
#
#
# AUTHOR:
#	Simon J. Gerraty <sjg@crufty.net>
#

# RCSid:
#	$Id: sb-save-diffs.sh,v 1.4 2025/09/05 20:36:44 sjg Exp $
#
#	@(#) Copyright (c) 2020-2025 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

Mydir=`dirname $0`

opt_d=$HOME/sb-save
opt_t=`date '+/%Y%m%d'`
opt_f='{opt_d}/{opt_p}{sb_name}{opt_t}.diff'
opt_q=

opt_str=d:f:p:qt:
. $Mydir/setopts.sh

MKDIFF=${MKDIFF:-$Mydir/mkdiff}

# so we can eval it below
fmt=`echo $opt_f | sed 's,{,\${,g'`

# avoid interfering
unset Mydir

for sb in "$@"
do
    [ -s $sb/.sandbox-env ] || continue
    [ -d $sb/src ] || continue
    sb_name=`basename $sb`
    eval "f=$fmt"
    mkdir -p `dirname $f`
    echo "$sb -> $f"
    (cd $sb/src && $MKDIFF $opt_q -f $f)
done
