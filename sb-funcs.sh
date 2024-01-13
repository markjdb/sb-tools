:
# RCSid:
#	$Id: sb-funcs.sh,v 1.59 2023/05/12 17:37:22 sjg Exp $
#
#	@(#) Copyright (c) 2009-2020 Simon J. Gerraty
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

Myname=${Myname:-`basename $0 .sh`}
Mydir=${Mydir:-`dirname $0`}
pwd=${pwd:-'pwd'}
case "$Mydir" in
.) Mydir=`$pwd`;;
esac
SB_TOOLS=${SB_TOOLS:-$Mydir}
$_DEBUG_SH . $SB_TOOLS/debug.sh
$_OS_SH . $SB_TOOLS/os.sh
$_HOOKS_SH . $SB_TOOLS/hooks.sh
$_ADD_PATH_SH . $SB_TOOLS/add_path.sh
$_TEST_OPTS_SH . $SB_TOOLS/test_opt.sh
$_FIND_IT_SH . $SB_TOOLS/find_it.sh
$_isPOSIX_SHELL_SH . $SB_TOOLS/isposix-shell.sh

DebugOn ${MYNAME:-$Myname}

ev=.sandbox-env
rc=.sandboxrc

##
# varName name
#
# turn "name" something into a useful var name
varName() {
    case "$1" in
    *[!A-Za-z0-9_]*) vn=`echo $1 | sed 's,[^A-Za-z0-9_],_,g'`;;
    *) vn=$1;;
    esac
    echo $vn
}

##
# evalVar val
#
# if "val" contains '$' eval it
#
evalVar() {
    val="$@"
    while :
    do
        case "$val" in
	*\$*) eval "val=\"$val\"";;
	*) break;;
	esac
    done
    echo "$val"
}

DebugOn SB_VARMYNAME_LIST
# we sometimes need these as var names
# MYNAME is our canonical name
# Myname is from $0
for n in Myname MYNAME
do
    eval vn=\$$n
    vn=`varName $vn`
    eval var${n}=$vn
done
# compute this once
if test x$varMyname = x$varMYNAME; then
    SB_VARMYNAME_LIST=$varMyname
else
    SB_VARMYNAME_LIST="$varMyname $varMYNAME"
fi
DebugOff SB_VARMYNAME_LIST

##
# find_sb start
#
# Find .sandbox-env in "start" (.) or above.
#      
find_sb() {
    find_it --start ${1:-.} --dir $ev
    
}

# for compatability with atexit.sh
Exit() {
    ExitStatus=$1
    exit $1
}

warning() {
    echo "WARNING: $@" >&2
}

error_more() {
    echo "ERROR: $@" >&2
}

error() {
    error_more "$@"
    Exit 1
}

##
# source_rc [options] file ...
#
# requires 'local' for source_file etc to have correct values when
# used recursively.
# --all  include all we find (default)
# --once avoids repeats
# --one  stops after first one we find
sb_included=
source_rc() {
    eval $local f source_dir source_file _0 _1

    _0=: _1=:
    while :
    do
        case "$1" in
        --all) _1=:; shift;;
        --once) _0=; shift;;
        --one) _1=return; shift;;
        *) break;;
        esac
    done
    for f in "$@"
    do
        [ -s $f ] || continue
        case $f in
        */*) source_dir=`dirname $f` source_file=`basename $f`;;
        *) source_dir=. source_file=$f;;
        esac
        source_dir=`'cd' "$source_dir" && 'pwd'`
        : is $_0$source_dir/$source_file in ,$sb_included,
        case ",$sb_included," in
        *,$_0$source_dir/$source_file,*) continue;;
        esac
        sb_included=$sb_included,$source_dir/$source_file
        . $f
        $_1 $?
    done
}

# for compatability with others
dot() { source_rc "$@"; }
source_one_rc() { source_rc --one "$@"; }
source_once() { source_rc --once "$@"; }

##
# sb_run_hooks name [args]
# we run sb_${name}_hooks ${varMyname}_${name}_hooks and
# ${varMYNAME}_${name}_hooks passing args provided.
#
sb_run_hooks() {
    _n=$1; shift

    DebugOn sb_run_hooks:$_n run_hooks:$_n
    case "$_n" in
    run) _p1=;;
    *) _p1=sb;;
    esac
    for _p in $_p1 $SB_VARMYNAME_LIST
    do
        run_hooks ${_p}_${_n}_hooks "$@"
    done
    DebugOff rc=$? sb_run_hooks:$_n run_hooks:$_n
}

##
# sb_hooks sb
#
# cd "sb"
# source any of the following if they exist
# ../.sandboxrc
# ./.sandboxrc
# 
# run init hooks
# source ./.sandbox-env
# run setup hooks
# 
sb_hooks() {
    DebugOn sb_hooks
    'cd' "$1" || Exit 1
    SB=`$pwd`
    SB_NAME=`basename $SB`
    export SB SB_NAME

    source_rc --once ../$rc ./$rc
    sb_run_hooks init
    case "$MYNAME" in
    mksb) ;;
    *) source_rc ./$ev;;
    esac
    sb_run_hooks setup
    DebugOff sb_hooks
}

add_list() {
    _list=$1; shift
    eval "$_list=\"\$$_list $@\""
}

sort_list() {
    case "$1" in
    --) _u=; shift;;
    -[run]*) _u=$1; shift;;
    *) _u=;;
    esac
    case "$1" in
    "") return;;
    esac
    for i in "$@"
    do
        echo $i
    done | sort $_u
}

$_HELP_FUNCS_SH . $SB_TOOLS/help-funcs.sh
add_hooks docs_hooks help_docs_hook
add_docs $SB_TOOLS/sb-funcs.sh $SB_TOOLS/help-funcs.sh
