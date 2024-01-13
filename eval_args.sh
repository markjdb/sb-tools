:
# NAME:
#	eval_args.sh - handle command line overrides
#
# DESCRIPTION:
#	This module provides a means of consistently handling command
#	line variable assignments.
#
#	Example:
#
#		MAKE=
#		CMD=echo
#		. eval_args.sh
#		require_vars MAKE
#		run_overrides $CMD
#
#	Will ensure that a value is provided for MAKE and run $CMD
#	while replicating any command line assignments to it.
#
#	It also provides a generic means of supporting --long-options
#	An arg of the form "--long-opt"[="arg"] is converted to
#	an assignment or function call depending the content of
#	$long_opt_str.  For example:
#.nf
#
#	long_opt_str="__prefix:a __dot:a. __comma:a, __flag:b __doit:f __q __*"
#	
#	__prefix will get $arg (consuming next word if needed).
#	__dot will accumulate $args separated by $opt_dot (space)
#	__comma will accumulate $args separated by $opt_comma (,)
#	__flag will get $arg or 1.
#	__doit will be called with $arg (if any).
#	__q will get $arg or --q which is handy for passing it on.
#.fi
#
#	__* means that any unrecognized option will be treated in the
#	same manner as --q.  Without this an error will result.
#	If --unknown-opts=func is seen before any user args, any
#	unknown options will be passed to func.
#	Default is $opt_unknown (_unknown_opt), a useful alternative
#	is _copy_unknown_opt.  A rather complex chain of option
#	handlers can be constructed by using hooks(1).
#	For example:
#.nf
#
#	. hooks.sh
#	add_hooks option_hooks _unknown_opt
#	add_hooks option_hooks my_options
#	opt_unknown=do_options
#
#	do_options() {
#	    run_hooks option_hooks LIFO "$@"
#	}
#	my_options() {
#	    case "$1" in
#	    -owner) owner=$2; _shift=2;;
#	    *) return 0;;	# next hook will run
#	    esac
#	    return 1		# stop running hooks - we consumed it
#	}
#.fi
#
#	We also handle single character options - provided they are
#	not bunched together.  Use opt_str in the maner of
#	setopts.sh(1).  For example:
#.nf
#
#	opt_str=a:b^l.p,v
#
#	Means
#
#	-a expects an arg and opt_a will be set to that.
#	-b is a boolean and opt_b will be set to 1
#	-l expects an arg and opt_l will have it appended using
#	   $opt_dot (space) as separator.
#	-p expects an arg and opt_p will have it appended using
#	   $opt_comma (,) as separator.
#	-v is a flag and opt_v will be set to -v.
#.fi
#
#	You can set opt_prefix (or pass --opt-prefix="$opt_prefix")
#	to have the variables created for single character options
#	named other than opt_*.
#
#	If opt_str is empty, single character opts will not be
#	processed - they will just be treated as data.
#
#	You can also use eval_args from a function.  In fact that's
#	what happens when you source this file.  It does:
#.nf
#	
#	eval_args --long-opts="$long_opt_str" --opts="$opt_str" \\
#		--eval=${__eval_func:-eval_override} -- "$@"
#	shift $__shift
#.fi
#
#	The '--' between the args that we add and the ones from the
#	command line is important as it ensure __shift is set
#	correctly.  Also, the options used internally can only be set
#	if seen before the '--'.  Set _EVAL_ARGS_DELAY to avoid
#	calling eval_args when this file is sourced.
#
#	Note that the following variables are all reserved:
#	__long_opts __opts __eval __shift __opt __opt_dot __opt_comma
#	__opt_prefix __unknown_opts __copy_opts __opt_spec
#	__eval_args_opts __eval_func and __
#
#	If --opt-prefix is used, it must appear before --opts.
#
# AUTHOR:
#	Simon J. Gerraty <sjg@crufty.net>
#

# RCSid:
#	$Id: eval_args.sh,v 1.38 2022/08/28 00:51:20 sjg Exp $
#
#	@(#) Copyright (c) 1999-2022 Simon J. Gerraty
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

_EVAL_ARGS_SH=:

Mydir=${Mydir:-`dirname $0`}
Myname=${Myname:-`basename $0 .sh`}

if [ -z "$_DEBUG_SH" ]; then
DebugOn() { :; }
DebugOff() { :; }
fi

# indicate no need for isposix-shell.sh
_isPOSIX_SHELL_SH=:

##
# set isPOSIX_SHELL
#
# Some features of the POSIX shell are very useful.
# We need to be able to know if we can use them.
#
# We set isPOSIX_SHELL={true,false}
# so we can use 'if $isPOSIX_SHELL; then'
#
# Apart from setting isPOSIX_SHELL we set local={local,:}
# so that a function can do 'eval $local var' to make
# var a local variable if we can.
# In such cases any initialization of var should be on a separate line.
# 
if (echo ${PATH%:*}) > /dev/null 2>&1; then
    # true should be a builtin
    isPOSIX_SHELL=true
    # you need to eval $local var
    local=local
    # reduce the cost of these
    basename() {
	local b=${1%$2}
	echo ${b##*/}
    }
    dirname() {
	case "$1" in
	*?/*) echo ${1%/*};;
	/*) echo /;;
	*) echo .;;
	esac
    }
    case `type true 2>&1` in
    *built*) ;;
    *) isPOSIX_SHELL=: ;;
    esac
else
    isPOSIX_SHELL=false
    local=:
    false() {
	return 1
    }
fi

# requires 'local' for source_file etc to have correct values when
# used recursively.
# --once avoids repeats
# --one	 stops after first one we find
sb_included=
source_rc() {
    eval $local f source_dir source_file _0 _1

    _0=: _1=:
    while :
    do
	case "$1" in
	--once) _0=; shift;;
	--one) _1=; shift;;
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
	$_1 return $?
    done
}

Exists() {
    _t=-s
    while :
    do
        case "$1" in
        -?) _t=$1; shift;;
        *) break;;
        esac
    done
    for f in "$@"
    do
        test $_t $f || continue
        echo $f
        return 0
    done
    return 1
}

exists() {
    Exists -e "$@" > /dev/null
}

# Allow:
# trap 'at_exit; trap 0; exit $ExitStatus' 0
# trap 'Exit 1' 1 2 3 6 15
Exit() {
    ExitStatus=$1
    exit $1
}

error() {
    echo "ERROR: $Myname: $@" >&2
    Exit 1
}

warn() {
    echo "WARNING: $Myname: $@" >&2
}

inform() {
    echo "NOTICE: $Myname: $@" >&2
}


# This allows us to handle vars containing spaces.
eval_export() {
    eval `IFS==; set -- $*; unset IFS; _var=$1; shift; _val="$@"; echo "_var=$_var _val='$_val' $_var='$_val'; export $_var"`
}

eval_override() {
    eval_export "$@"
    OVERRIDES="$OVERRIDES $_var='$_val'"
}

require_vars() {
    DebugOn require_vars
    for _var in $*
    do
	eval _val="\$$_var"
	case "$_val" in
	"") inform "need values for each of: $*"
	    error "no value for $_var";;
	esac
    done
    DebugOff require_vars
}

_unknown_opt() {
    error "unknown option '$1'"
}

# its a nightmare preserving spaces through multiple
# evals, so we do lots of wrapping.  Which means you'll need to
# eval any command that uses $__copy_opts
_copy_unknown_opt() {
    case "$1" in
    *" "*) # a truely horrible dance to ensure [,"'] survive
        # don't try replacing this with \([,\'"]\) etc.
        __arg=`echo "$1" | sed -e 's/,/\\\\,/g' -e "s/'/\\\\'/g" -e 's/"/\\\\"/g'`;;
    *) __arg="$1";;
    esac
    __copy_opts="${__copy_opts:+$__copy_opts }\"$__arg\""
}

# now allow VAR=val on the command line to override
# provide generic handling of --long-opts and short ones too
eval_args() {
    DebugOn eval_args
    __shift=$#
    __eval=
    __long_opts=
    __copy_opts=
    __opts=
    __opt_prefix=${opt_prefix:-opt_}
    __opt_dot=${opt_dot:-" "}
    __opt_comma=${opt_comma:-,}
    __unknown_opts=$opt_unknown
    __=:
    # we don't want to accept these from user, ie they must appear
    # before first --.
    __eval_args_opts="__eval:a __long_opts:a __opts:a __opt_prefix:a __unknown_opts:a"

    while :
    do
	_shift=			# __unknown_opts may set this
	: echo "checking '$1'"
	case "$1" in
	# if the line below looks like noise - don't touch this file!
	--) shift; $__ break; __=; __eval_args_opts=; __shift=$#;;
	--*)
	    # we accept --some-option=val as well as --some_option=val
	    # they both end up as __opt=__some_option
	    __opt=`echo $1 | sed -e 's/=.*//' -e 'y/-=/_ /'`
	    for __opt_spec in $__eval_args_opts $__long_opts ""
	    do
		case "$__opt_spec" in
		$__opt:*|$__opt) break;;
		esac
	    done
	    case "$1" in
	    *=*)
		if $isPOSIX_SHELL; then
		    __arg="${1#*=}"
		else
		    __arg="`echo $1 | sed -n '/=/s,^[^=]*=,,p'`"
		fi
		;;
	    *) __arg=;;
	    esac
	    case "$__opt_spec" in
	    *:f*) $__opt "$__arg";; # function call
	    *:a*) # litteral arg, consume next arg if needed
		case "$1" in
		*=*) ;;		# already got it above
		*) __arg="$2"; _shift=2;; # consume another arg
		esac
		case "$__opt_spec" in
		*.)  eval $__opt=\"\${$__opt:+\${$__opt}$__opt_dot}$__arg\";;
		*,)  eval $__opt=\"\${$__opt:+\${$__opt}$__opt_comma}$__arg\";;
		*)   eval "$__opt='$__arg'";;
		esac
		;;
	    *:b*) eval "$__opt='${__arg:-1}'";; # boolean
	    $__opt) eval "$__opt='${__arg:-$1}'";; # default: arg or self
	    *)	# check for wild-card
		case " $__eval_args_opts $__long_opts " in
		*" __* "*)
		   eval "$__opt='${__arg:-$1}'";; # default: arg or self
		*) ${__unknown_opts:-_unknown_opt} "$@";;
		esac
		;;
	    esac
	    shift $_shift
	    case "$__opt" in
	    __opts)
		case "$__opts" in
		*\^*)	# need to set the booleans x,
		    eval `echo $__opts | sed -e 's/[^^]*$//' -e 's/[^^]*\([^^]^\)/\1/g' -e 's/\(.\)^/'${__opt_prefix}'\1=${'${__opt_prefix}'\1-0}; /g'`
		    ;;
		esac
		;;
	    esac
	    ;;
	-env) source_rc $2; shift 2;;
	-?) # this is the guts of setops.sh
	    __opt=`IFS=" -"; set -- $1; echo $*` # lose the '-'
	    case /$__opts/ in
	    //) break;;		# nothing to do with us
	    *${__opt}.*)
		eval ${__opt_prefix}$__opt=\"\${${__opt_prefix}$__opt}\${${__opt_prefix}$__opt:+$__opt_dot}$2\"; shift;;
	    *${__opt},*)
		eval ${__opt_prefix}$__opt=\"\${${__opt_prefix}$__opt}\${${__opt_prefix}$__opt:+$__opt_comma}$2\"; shift;;
	    *${__opt}:*)
		eval ${__opt_prefix}$__opt=\"$2\"; shift;;
	    *${__opt}=*)
		case "$2" in
		*=*) eval $__eval "$2"; shift;;
		*)  error "option '-$__opt' requires argument of form var=val";;
		esac
		;;
	    *${__opt}\^*)
		eval ${__opt_prefix}$__opt=1;;
	    *${__opt}*)
		eval ${__opt_prefix}$__opt=$1;;
	    *)	${__unknown_opts:-_unknown_opt} "$@";;
	    esac
	    shift $_shift
	    ;;
	-*) # we told them not to group flags...
	    ${__unknown_opts:-_unknown_opt} "$@"
	    shift $_shift
	    ;;
	*=*) eval $__eval "$1"; shift;;
	*) break;;
	esac
    done
    # let caller know how many args we consumed
    __shift=`expr $__shift - $#`
    DebugOff eval_args
}


# we need to eval $OVERRIDES for them to be passed on correctly
# use -nice n to run at lower priority, where "n" is a suitable
# arg for nice(1).
run_overrides() {
    DebugOn run_overrides
    __nice=
    eval_args --long-opts="__nice:a" -- "$@"
    shift $__shift
    _cmd=$1; shift
    eval ${__nice:+${NICE:-nice} $__nice} $_cmd $OVERRIDES "$@"
    DebugOff run_overrides
}

case `type __help 2>&1` in
*func*) ;;
*)
    # this is a useful model of a help function.
__help() {
    sed -n -e "1d;/${END_HELP_MARKER:-RCSid}/,\$d" -e '/^[A-Za-z].*=/,$d' -e '/^#\.[a-z]/d' -e '/^#/s,^# *,,p' $0
    Exit ${1:-0}
}
;;
esac

case ./$0 in
*/eval_args.sh) # unit test
    long_opt_str="__help:f"
    case "$1" in
    --help) __help;;
    __*) long_opt_str="$long_opt_str $1"; shift;;
    *)
	echo "Expect an error unless you supply MAKE=value"
	MAKE=
	eval_args --long-opts="$long_opt_str" --opts=n --eval=eval_override -- "$@"
	shift $__shift
	SKIP=${SKIP:-${opt_n:+:}}
	echo $0 $OVERRIDES "$@"
	echo "MAKE='$MAKE' OVERRIDES=<$OVERRIDES>"
	require_vars MAKE
	$SKIP run_overrides $0 SKIP=: "$@"
	$SKIP run_overrides ${CMD:-inform we got}
	eval_args --opt-prefix=sub_ --opts=vV:nx^ -- -v -V big oops
	echo "sub_v=$sub_v sub_V=$sub_V sub_x=$sub_x"
	Exit 0
	;;
    esac
    _EVAL_ARGS_DELAY=:
    ;;
esac

# you can do this in a function too
# the -- is important as it separates args that we add and which
# should not be included in the calculation of __shift
${_EVAL_ARGS_DELAY:+:} eval_args --long-opts="$long_opt_str" --opts="$opt_str" --eval=${__eval_func:-eval_override} -- "$@"
${_EVAL_ARGS_DELAY:+:} shift $__shift
