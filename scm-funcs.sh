:
# NAME:
#	scm-funcs.sh - scm wrapper funcs
#

# RCSid:
#	$Id: scm-funcs.sh,v 1.17 2022/09/03 04:09:08 sjg Exp $
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

get_SCM() {
    clues="CVS/Entries .hg .svn .git"
    for d in . .. ${SRCTOP:-${SB_SRC:-$SB/src}} $SB ...
    do
        for clue in $clues
        do
            : d=$d
            case "$d" in
            ...)
                if type find_it > /dev/null 2>&1; then
                    find_it --start .. --path $clues | sed 's,.*[./],,;s,Entries,cvs,'
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

scm_op() {
    $SCM_CMD "$@" | ${PAGER}
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
        
scm_ops() {
    op=$1; shift
    for f in "$@"
    do
        scm_op $op $f || break
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
    -e '/^Index:/s,Index: ,,p' \
    -e '/^Property changes on:/s,Property changes on: ,,p' \
    "$@" | sort -u
}

PAGER=${PAGER:-more}
SCM=${SB_SCM:-${SCM:-`get_SCM`}}
SCM_VAR=`echo $SCM | toUpper`
eval SCM_CMD=\${$SCM_VAR:-$SCM}

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


    
