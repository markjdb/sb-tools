:
# RCSid:
#	$Id: sb-funcs.sh,v 1.87 2026/01/24 06:14:38 sjg Exp $
#
#	@(#) Copyright (c) 2009-2026 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

_SB_FUNCS_SH=:

Myname=${Myname:-`basename $0 .sh`}
Mydir=${Mydir:-`dirname $0`}
pwd=${pwd:-'pwd'}
case "$Mydir" in
.) Mydir=`$pwd`;;
esac
SB_TOOLS=${SB_TOOLS:-$Mydir}
# order of some of these matters
$_SOURCE_SH . $SB_TOOLS/source.sh
$_HAVE_SH . $SB_TOOLS/have.sh
$_isPOSIX_SHELL_SH . $SB_TOOLS/isposix-shell.sh
$_DEBUG_SH . $SB_TOOLS/debug.sh
$_OS_SH . $SB_TOOLS/os.sh
$_HOOKS_SH . $SB_TOOLS/hooks.sh
$_ADD_PATH_SH . $SB_TOOLS/add_path.sh
$_TEST_OPTS_SH . $SB_TOOLS/test_opt.sh
$_FIND_IT_SH . $SB_TOOLS/find_it.sh
$_MKOPT_SH . $SB_TOOLS/mkopt.sh

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

Error() {
    error_more "$@"
    Exit 1
}

error() {
    Error "$@"
}

##
# sb_run_hooks name [args]
# we run sb_${name}_hooks ${varMyname}_${name}_hooks and
# ${varMYNAME}_${name}_hooks (if different)
# passing any args provided.
#
sb_run_hooks() {
    eval $_local _n _p _p1
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
# sb_project_init
#
# we call this after we know $SB_PROJECT.
# Under $SB_TOOLS and any directories in $SB_RC_DIR_LIST,
# we look in sb-project.d/ and ${MYNAME}-project.d/
# for $SB_PROJECT.rc or its lower case version if needed.
# We also trim $SB_PROJECT at any '-*' and look for that
# (and its lower case version) too.
#
# If we are 'mksb' SB_PROJECT may not yet have its canonical value
# so we also look for all the above as prefixes eg $SB_PROJECT*.rc
# etc.
#
# Finally we run project_init and project hooks
#
sb_project_init() {
    DebugOn sb_project_init
    eval $_local prefixes p bp bs
    prefixes=$SB_PROJECT

    for bs in . - $SB_PROJECT_SEPARATOR_LIST
    do
        : bs=$bs
        case "$SB_PROJECT" in
        *$bs*)
            if $isPOSIX_SHELL; then
                bp=${SB_PROJECT%%$bs*}
            else
                bp="`IFS=$bs; set -- $SB_PROJECT; echo $1`"
            fi
            add_list_once prefixes $bp
            ;;
        esac
    done

    case "$SB_PROJECT" in
    *[A-Z]*) p=`echo $prefixes | toLower`
        add_list_once prefixes $p
        ;;
    esac
    : is MYNAME=$MYNAME = mksb
    case "$MYNAME" in
    mksb) # SB_PROJECT may not yet be canonical
        # remember the original
        _SB_PROJECT=$SB_PROJECT
        for p in $prefixes
        do
            add_list_once prefixes "$p*"
        done
        ;;
    esac
    for top in $SB_TOOLS $SB_RC_DIR_LIST
    do
        for p in $prefixes
        do
            source_rc --once $top/sb-project.d/${p}.rc
            source_rc --once $top/${MYNAME}-project.d/${p}.rc
        done
    done
    sb_run_hooks project_init
    sb_run_hooks project
    DebugOff project_init
}

##
# sb_hooks sb
#
# cd "sb"
# set SB SB_BASE SB_NAME
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
    SB_BASE=`dirname "$SB"`
    SB_NAME=`basename "$SB"`
    export SB SB_BASE SB_NAME

    source_rc --once ../$rc ./$rc
    sb_run_hooks init
    case "$MYNAME" in
    mksb) ;;
    *) source_rc ./$ev;;
    esac
    # no guarantee we have SB_PROJECT!
    test -z "$SB_PROJECT" || sb_project_init
    sb_run_hooks setup
    DebugOff sb_hooks
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

newer() {
    'ls' -1t "$@" 2> /dev/null | head -1
}

is_newer() {
    case `newer "$@"` in
    $1) return 0;;
    esac
    return 1
}

$_HELP_FUNCS_SH . $SB_TOOLS/help-funcs.sh
add_hooks docs_hooks help_docs_hook
add_docs $SB_TOOLS/sb-funcs.sh $SB_TOOLS/help-funcs.sh

case "/$0" in
*sb-funcs*) op=$1; shift; $op "$@";;
esac
