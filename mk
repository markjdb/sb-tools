#!/bin/sh

# NAME:
#	mk - simple wrapper around make
#
# SYNOPSIS:
#	mk ...
#
# DESCRIPTION:
#	This script simply searches upwards for a file called
#	'.sandbox-env' and sources it, as well as setting the variable
#	$SB to the directory where it is found.
#
#	If invoked as 'mk-'"MACHINE"* we behave the same as for 'mk
#	--machine' below.
#	
#	Options:
#
#	Normally we pass the full command line onto $REAL_MAKE or
#	whatever command we are configured to run.
#
#	The following are exceptions, but are only recognized as the
#	first argument(s).  The options below that take an argument
#	can also be given as '--option='"arg".
#
#	--machine ["MAKELEVEL",]"MACHINE"[,...]
#
#		If a tupple is provided and the first element is
#		numeric we set $MAKELEVEL to that.
#		If the rest is a tuple we set $TARGET_SPEC and
#		REQUESTED_TARGET_SPEC to that value.
#		Then for each variable V in TARGET_SPEC_VARS
#		(default is just MACHINE), we set $V and REQUESTED_$V
#		to the appropriate element.
#		This allows makefiles to unambiguously know where MACHINE
#		and TARGET_SPEC came from.
#
#	--make "REQUESTED_MAKE"
#		Sometimes it is handy to override REAL_MAKE.
#
#	--doc
#		Call the function '__doc'.
#		The default version just displays this information
#		and then runs doc_hooks and exits.
#
#	--docs
#		Call the function '__docs'.
#		The default version displays this information
#		followed by any block comments marked by '##[*=~-]'.
#		It then runs docs_hooks and exits.
#
#	--help ["topic"]
#	
#		Call the function '__help', the default version with
#		no argument displays this information and then exits.
#
#		If a $topic is provided we look for and run the first
#		of the following found and then exit.
#
#		${varMyname}_help_${topic}_hooks
#		${varMyname}_help_hooks
#		help_${topic}_hooks
#		${varMYNAME}_help_${topic}_hooks
#		${varMYNAME}_help_hooks
#
#		If no help hooks are found we look for a function
#		named:
#
#		${varMyname}_help_$topic
#		help_$topic
#		${varMYNAME}_help_$topic
#
#	Adding options:
#
#	You can actually add options ('--*') to the above, by adding a
#	function to $mk_option_hooks.
#
#	If such a function returns non-zero the arg is consumed,
#	otherwise it and the rest of the command line are passed on to
#	$REAL_MAKE or whatever.
#
#	Conditioning environment:
#
#	We set $Myname to the basename we were invoked as,
#	$MYNAME to our canonical name ('mk'), $varMyname and
#	$varMYNAME are the safe versions of the same (guaranteed to be
#	valid variable names).
#
#	We set $SB_VARMYNAME_LIST to $varMyname and add $varMYNAME if
#	it is different.  This avoids checking more than once.
#	So where we state below that we check for both, that is only
#	in the case that they are different.
#	
#	We first look for and load 'sb-env.rc' and '$MYNAME.rc'
#	then run a series of hook functions via 'sb_run_hooks $stage'
#	which will run 'sb_${stage}_hooks', '${varMyname}_${stage}_hooks' and
#	'${varMYNAME}_${stage}_hooks' (if '${varMyname}' is different
#	from '${varMYNAME}').
#
#	For example: 'sb_run_hooks begin' will run 'sb_begin_hooks',
#	'${varMyname}_begin_hooks' and finally '${varMYNAME}_begin_hooks'.
#
#	So first we do any 'begin' hooks.
#	
#	We then look for $SB (by finding '.sandbox-env')
#	and look for '.sandboxrc' in $SB/.. and $SB
#	and run any 'init' hooks.
#
#	Next we read $SB/'.sandbox-env', then run any 'setup' hooks.
#
#	After any application specific hooks (see below) we run
#	'finish' hooks.
#
#	The above is common to all apps that include 'mk' for
#	environmental setup.
#
#	In the case of 'mk' we will run 'mk_target_machine' with no
#	argument if it was not already called via '--machine' flag
#	above.
#
#	Just before running 'finish' hooks, 'mk' adds 'sb_set_make'
#	and before running 'mk_run_hooks', it adds 'mk_exec_make'.
#	Any of the rc scripts can add 'mk_run_make' to 'mk_run_hooks'
#	before then to cause that to be used instead.
#
#	We pass '$MK_MAKEFLAGS' as well as any command line args to
#	any 'run' hooks.
#	
#	Both 'mk_exec_make' and 'mk_run_make' will call
#	'mk_pre_run_hooks' just before they exec or run make (actually
#	'$REAL_MAKE', '$MAKE' or 'make'), but 'mk_run_make' will save
#	the exit status of make, then run 'mk_post_run_hooks' before
#	exiting with the saved status.
#
#
# FILES:
#	${SB_TOOLS}/sb-env.rc	site global setup
#	${SB_TOOLS}/${MYNAME}.rc	per app setup
#	${HOME}/.sandboxrc	user global setup
#	${SB}/../.sandboxrc	sb group setup
#	${SB}/.sandboxrc	extra setup in $SB
#	${SB}/.sandbox-env	sb setup in $SB see mksb(1)
#
# SEE ALSO:
#	mksb(1), workon(1)
#
# AUTHOR:
#	Simon J. Gerraty <sjg@crufty.net>
#

# RCSid:
#	$Id: mk,v 1.70 2023/05/18 22:48:15 sjg Exp $
#
#	@(#) Copyright (c) 2009-2022 Simon J. Gerraty
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

# this is our canonical name
MYNAME=${MYNAME:-mk}

# clear some well known stuff
unset SB SB_NAME SB_BASE SB_SRC SB_OBJROOT SB_OBJTOP SB_MAKE
unset SRCTOP OBJTOP OBJROOT
unset sb_begin_hooks sb_init_hooks sb_setup_hooks
unset ${MYNAME}_begin_hooks
unset ${MYNAME}_init_hooks 
unset ${MYNAME}_setup_hooks 
unset ${MYNAME}_finish_hooks 
unset ${MYNAME}_help_hooks
unset mk_cmd_hooks
unset DEFAULT_MACHINE DEFAULT_TARGET_SPEC
unset REQUESTED_MACHINE REQUESTED_MAKE REQUESTED_TARGET_SPEC
unset REAL_MAKE MAKE MAKESYSPATH
unset MAKEOBJDIRPREFIX MAKEOBJDIR
unset MAKEFILES
unset MK_MAKEFLAGS

# inline test_opt.sh
case `(test -L /) 2>&1` in
*:*) test_L=-h;;
*) test_L=-L;;
esac

read_link() {
    if test $test_L $1; then
        'ls' -l $1 | sed 's,.*-> ,,'
    else
        echo $1
    fi
}

case "$MYNAME" in
mk) unset ENV
    # it is possible that $0 is a symlink
    me=`read_link $0`
    # we actually want to know where $me is
    case "$me" in
    */*) SB_TOOLS=${SB_TOOLS:-`dirname $me`};;
    esac
    ;;
esac

Mydir=${Mydir:-`dirname $0`}

SB_TOOLS=${SB_TOOLS:-$Mydir}
. $SB_TOOLS/sb-funcs.sh

##
# mk_target_machine [MAKELEVEL][,MACHINE[,...]]
#
# Set MACHINE and REQUESTED_MACHINE 
# if more than MACHINE is provided set TARGET_SPEC and
# REQUESTED_TARGET_SPEC
#
# These can help makefiles know how to setup the environment.
#
# If no argument default MACHINE to DEFAULT_MACHINE, HOST_MACHINE or
# uname -m
# 
mk_target_machine() {
    DebugOn mk_target_machine
    case "$1" in
    [0-9]*,*)
        if $isPOSIX_SHELL; then
            MAKELEVEL=${1%%,*}
            set -- ${1#*,}
        else
            MAKELEVEL=`expr $1 : '\([0-9]*\)'`
            set -- `expr $1 : '[0-9]*,\(.*\)'`
        fi
        ;;
    [0-9]*) MAKELEVEL=$1; shift;;
    esac
    test -z "$MAKELEVEL" || export MAKELEVEL
    case "$1" in
    "") ;;
    *,*) # tuple
        REQUESTED_TARGET_SPEC=$1
        TARGET_SPEC=$1
        # MACHINE must always be first in TARGET_SPEC_VARS
        eval `_IFS="$IFS"; IFS=,; set -- $1; IFS="$_IFS"
        : set ${TARGET_SPEC_VARS:-MACHINE}
        for v in ${TARGET_SPEC_VARS:-MACHINE}
        do
            echo "REQUESTED_$v=$1; export REQUESTED_$v;"
            echo "$v=$1; export $v;"
            shift
        done`
        export REQUESTED_TARGET_SPEC TARGET_SPEC
        ;;
    *)  REQUESTED_MACHINE=$1
        export REQUESTED_MACHINE
        ;;
    esac
    MACHINE=${REQUESTED_MACHINE:-${DEFAULT_MACHINE:-${MACHINE:-${HOST_MACHINE:-`uname -m`}}}}
    export MACHINE

    run_hooks mk_target_machine_hooks "$@"
    DebugOff rc=$? mk_target_machine
}

##
# mk_no_sb
#
# Throw an errro when no .sandbox-env is found.
# This is the last entry on mk_no_sb_hooks, a prior function could
# return non-zero to block this being called.
#
mk_no_sb() {
    error "$Myname: cannot find $ev in or above $here"
}

##
# mk_find_sb
#
# Use find_sb to find sb (parent directory containing .sandbox-env)
# then run sb_hooks $sb
# 
mk_find_sb() {
    DebugOn mk_find_sb
    here=`$pwd`
    sb=`find_sb`
    case "$sb,$sb_cmd_args" in
    /*) ;;			# ok
    ,--help*|,--doc*) return 0;; # also ok
    *)  # we are not in an SB, this is normally fatal
        add_hooks mk_no_sb_hooks mk_no_sb
        run_hooks mk_no_sb_hooks $here
        ;;
    esac
    sb_hooks $sb
    'cd' "$here"
    DebugOff mk_find_sb
}

##
# sb_set_make
#
# set SB_MAKE, SB_MAKE_VAR and SB_MAKE_CMD
# Note: SB_MAKE is a flavor of make not a path to a binary
sb_set_make() {
    DebugOn sb_set_make
    # .sandox-env wins over default passed as arg
    case "$1" in
    *make*) SB_MAKE=${SB_MAKE:-${1:-make}};;
    *) SB_MAKE=${SB_MAKE:-make};;
    esac
    SB_MAKE_VAR=${SB_MAKE_VAR:-`echo $SB_MAKE | toUpper`}
    eval SB_MAKE_CMD=\${$SB_MAKE_VAR:-$SB_MAKE}
    DebugOff sb_set_make
}

# this is default
mk_exec_make() {
    run_hooks mk_pre_run_hooks
    exec ${REQUESTED_MAKE:-${REAL_MAKE:-${SB_MAKE_CMD:-${MAKE:-make}}}} "$@"
}

# use this when you have things to do after running make
mk_run_make() {
    run_hooks mk_pre_run_hooks
    ${REQUESTED_MAKE:-${REAL_MAKE:-${SB_MAKE_CMD:-${MAKE:-make}}}} "$@"
    rc=$?
    run_hooks mk_post_run_hooks
    Exit $rc
}

DebugOn sb_begin

# We may want to examine the command line in a customization hook,
# so make sure it is preserved.
sb_env_cmdline="$0 $@"
sb_cmd_args="$@"

curdir=`$pwd`			# so we don't forget
# global setup
source_rc $SB_TOOLS/sb-env.rc
source_rc $SB_TOOLS/sb-env.d/*.rc
# per app setup
source_rc $SB_TOOLS/${MYNAME}.rc
source_rc $SB_TOOLS/${MYNAME}.d/*.rc
# now let them set the hooks they want
source_rc ${SB_RCFILES:-$HOME/$rc}

# run these before doing *anything*
sb_run_hooks begin

DebugOff sb_begin

: MYNAME=$MYNAME
case "$MYNAME" in
mksb|workon) ;;		# these make their own arrangements
mk) mk_find_sb
    case "$Myname" in
    mk-*)
        mk_target_machine `expr $Myname : 'mk-\(.*\)'`
        ;;
    esac
    # we generally cannot afford to consume the command line
    # since virtually any option might be for $cmd
    # but we'll make an exception for these and
    # any other --* options known to mk_option_hooks
    while :
    do
        : 1="$1"
        case "$1" in
        --) shift; break;;          # stop trying to interpret anything
        --doc) __doc;;              # does not return
        --docs) __docs;;            # does not return
        --help) __help $2;;	    # does not return
        --machine) mk_target_machine $2; shift 2;;
        --make) REQUESTED_MAKE=$2; shift 2;;
        --help=*|--machine=*|--make=*)
            if $isPOSIX_SHELL; then
                arg=${1#*=}
            else
                arg=`expr x$1 : '.*=\(.*\)'`
            fi
            case "$1" in
            --help=*) __help $arg;;
            --machine=*) mk_target_machine $arg;;
            --make=*) REQUESTED_MAKE=$arg;;
            esac
            shift
            ;;
        --*) # if a mk_option hook consumes it, it returns !0
            run_hooks mk_option_hooks "$1" && break
            shift               # it was consumed
            ;;
        *) break;;
        esac
    done
    # set default if needed
    test -z "$REQUESTED_MACHINE" && mk_target_machine
    run_hooks mk_cmd_hooks
    add_hooks mk_finish_hooks sb_set_make
    sb_run_hooks finish
    # mk_exec_make is our default, make sure it is last
    # add mk_run_make before this point if need to
    # run mk_post_run_hooks
    add_hooks mk_run_hooks mk_exec_make
    sb_run_hooks run $MK_MAKEFLAGS "$@"
    ;;
*) $SKIP_FIND_SB mk_find_sb;;
esac
