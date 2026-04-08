:
# RCSid:
#	$Id: source.sh,v 1.24 2026/03/14 04:45:27 sjg Exp $
#
#	@(#) Copyright (c) 1994-2026 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

# this one can cause some shell's to segfault if loaded recursively
# so always use
# $_SOURCE_SH . source.sh
_SOURCE_SH=:

$_HAVE_SH . ${SB_TOOLS:+$SB_TOOLS/}have.sh

# these are from rc.sh, but others can use them too.
Which() {
    case "$1" in
    -*) t=$1; shift;;
    *) t=-x;;
    esac
    case "$1" in
    /*) test $t $1 && echo $1;;
    *)
        for d in `IFS=:; echo ${2:-$PATH}`
        do
            test $t $d/$1 && { echo $d/$1; break; }
        done
        ;;
    esac
}

# does local *actually* work?
local_works() {
    local _fu
}

# We expect this to be a POSIX shell
# but do we have local that works ?
if local_works > /dev/null 2>&1; then
    _local=local
else
    _local=:
fi
# for backwards compatability
local=$_local

##
# dot file ...
#
# for each file (if it exists) set its source_dir
# and source_file, add it to dotted list and read it in.
#         
dot() {
    eval $_local f source_dir source_file rc

    rc=1
    for f in "$@"
    do
        if test -s $f; then
            dotted="$dotted $f"
            case $f in
            */*) source_dir=`dirname $f` source_file=`basename $f`;;
            *) source_dir=. source_file=$f;;
            esac
            # cd dir && pwd can fail on nfs
            # if a parent dir is not readable
            if have realpath; then
                source_dir=`realpath "$source_dir"`
            else
                source_dir=`'cd' "$source_dir" && 'pwd'`
            fi
            case " $dotted " in
            *" $source_dir/$source_file "*) ;;
            *) dotted="$dotted $source_dir/$source_file";;
            esac
            case " $source_dirs " in
            *" $source_dir "*) ;;
            *) source_dirs="$source_dirs $source_dir";;
            esac
            : dotting $f
            . $f
            : dotted $f rc=$?
            rc=0
        fi
    done
    return $rc
}

##
# dot_once file ...
#
# only dot file if we have not already
#
dot_once() {
    eval $_local f

    for f in "$@"
    do
        : skip if $f in "$dotted"
        case " $dotted " in
        *" $f "*) continue;;
        esac
        dot $f
    done
}

##
# dot_find [--once] file ...
#
# for each file if it does not exist relative to cwd
# try each directory we have sourced things from.
#
dot_find() {
    eval $_local d dot f rc

    rc=1
    dot=dot
    while :
    do
        case "$1" in
        --once) dot=dot_once; shift;;
        *) break;;
        esac
    done

    for f in "$@"
    do
        for d in "" $source_dirs
        do
            $dot ${d:+$d/}$f || continue
            rc=0
            break
        done
    done
    return $rc
}

dot_find_once() {
    dot_find --once "$@"
}

##
# source_rc [options] file ...
#
# read in each file if it exists
# --find search source_dirs
# --once avoids repeats
# --one	 stops after first one we find
#
source_dirs="${source_dirs:-$Mydir}"
source_rc() {
    eval $_local dot f _1 rc

    dot=dot
    _1=: rc=1
    while :
    do
	case "$1" in
	--find) dot=dot_find; shift;;
	--find-once) dot=dot_find_once; shift;;
	--once) dot=dot_once; shift;;
	--one) _1=break; shift;;
	*) break;;
	esac
    done
    for f in "$@"
    do
        $dot $f || continue
        rc=0
	$_1
    done
    return $rc
}

##
# _source [--once] file [dir ...]
#
# if no dirs specified we use $PATH
#
# avoid conflicting with builtin source in some shells.
# just leverages dot
#
_source() {
    eval $_local d dot f

    dot=dot
    while :
    do
        case "$1" in
        --once) dot=dot_once; shift;;
        *) break;;
        esac
    done
    f=$1; shift
    for d in "" `IFS=:; echo ${*:-$PATH}`
    do
        $dot ${d:+$d/}$f || continue
        return 0
    done
    return 1
}

# for compatability with others
source_all() { source_rc "$@"; }
source_first() { source_rc --one "$@"; }
source_one_rc() { source_rc --one "$@"; }
source_once() { source_rc --once "$@"; }

case "`type source 2>&1`" in
*builtin*) ;;
*) source() { _source "$@"; };;
esac

case ./$0 in
*/source*)
    op=_source
    case "$1" in
    [Ww]hich|source*) op=$1; shift;;
    esac
    $op "$@"
    ;;
*/[Ww]hich*) Which "$@";;
esac
