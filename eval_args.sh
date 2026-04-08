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
#	$long_opt_str.
#
#	Each entry in $long_opt_str consists of
#	"__option_name"[:"option_type"].
#
#	Where "option_type" will be one of:
#
#	'a'	option takes an arg either via '=' or consuming the
#		next word, a variable "__option_name" is set to $arg.
#		On the command line '--option-name' and
#		'--option_name' are equivalent.
#
#	'a.'	as for 'a' but the args accumulate using
#		$opt_dot_$__option_name if set, or $opt_dot
#		(space) as separator.
#
#	'a,'	as for 'a.' but using $opt_comma (,) as separator
#
#	'b'	a boolean; "__option_name" will be set to 1.
#
#	'f'	a function named "__option_name" will be called and
#		passed $arg which will be empty unless a value
#		provided via '='.  Thus $arg is optional.
#	
#	'fa'	a combination of 'f' and 'a'; a function named
#		"__option_name" will be called and passed $arg which
#		if not provided via '=' will consume the next word.
#		Thus $arg is not optional.
#
#	If no "option_type" is specified, then "__option_name" is set
#	to $arg or itself.
#
#	For example:
#.nf
#
#	long_opt_str="__prefix:a __dot:a. __comma:a, __flag:b __doit:f __func_arg:fa __q __*"
#	
#	__prefix will get $arg (consuming next word if needed).
#	__dot will accumulate $args separated by $opt_dot (space)
#	__comma will accumulate $args separated by $opt_comma (,)
#	__flag will get $arg or 1.
#	__doit will be called with $arg (if any).
#	__func_arg will be called with $arg either provided by '=' or
#	by consuming the next word.
#	__q will get $arg or --q which is handy for passing it on.
#.fi
#
#	__* means that any unrecognized option will be treated in the
#	same manner as --q.  Without this an error will result.
#	
#	If --unknown-opts=func is seen before any user args,
#	it sets __unknown_opts to func and any unknown options will be
#	passed to that.  The default is $opt_unknown which is not set
#	by default.
#
#	If __unknown_opts is not set we use '_unknown_opt' which will throw
#	an error.
#
#	A possibly useful alternative is '_copy_unknown_opt' which
#	will accumulate them in '__copy_opts' for later use.
#
#	If __unknown_opts is set to break, we simply stop processing when an
#	unknown option is encountered.  This allows for passing any
#	remaining args to another process.
#	
#	A rather complex chain of option handlers can be constructed
#	by using hooks(1). For example:
#
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
#
#.fi
#
#	We also handle single character options - provided they are
#	not bunched together.  Use opt_str in the manner of
#	setopts.sh(1).  For example:
#.nf
#
#	opt_str=a:b^l.p,S.v
#	opt_dot_S=';'
#
#	Means
#
#	-a expects an arg and opt_a will be set to that.
#	-b is a boolean and opt_b will be set to 1
#	-l expects an arg and opt_l will have it appended using
#	   $opt_dot (space) as separator.
#	-p expects an arg and opt_p will have it appended using
#	   $opt_comma (,) as separator.
#	-S expects an arg and opt_S will have it appended using ';'
#	   as separator.
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
#	command line is important as it ensures __shift is set
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
#	$Id: eval_args.sh,v 1.55 2026/02/12 04:09:24 sjg Exp $
#
#	@(#) Copyright (c) 1999-2026 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
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

if [ -z "$_isPOSIX_SHELL_SH" ]; then
    # indicate no need for isposix-shell.sh
    _isPOSIX_SHELL_SH=:
    # nor have.sh
    _HAVE_SH=:

    ##
    # have that does not rely on return code of type
    #
    have() {
        case `(type "$1") 2>&1` in
        *" found") return 1;;
        esac
        return 0
    }

    ##
    # set isPOSIX_SHELL
    #
    # Some features of the POSIX shell are very useful.
    # We need to be able to know if we can use them.
    #
    # We set isPOSIX_SHELL={true,false}
    # so we can use 'if $isPOSIX_SHELL; then'
    #
    #
    if (echo ${PATH%:*}) > /dev/null 2>&1; then
        # true should be a builtin, : certainly is
        isPOSIX_SHELL=:
        # reduce the cost of these
        basename() {
            eval $_local b
            b=${1%$2}
            echo ${b##*/}
        }
        dirname() {
            case "$1" in
            *?/*) echo ${1%/*};;
            /*) echo /;;
            *) echo .;;
            esac
        }
    else
        isPOSIX_SHELL=false
        false() {
            return 1
        }
    fi
fi

# does local *actually* work?
local_works() {
    local _fu
}

if local_works > /dev/null 2>&1; then
    _local=local
else
    _local=:
fi
# for backwards compatability
local=$_local

# avoid redefining a function while it is running!
if [ -z "$_SOURCE_SH" ] && [ -s $Mydir/source.sh ]; then
    . $Mydir/source.sh
fi
if [ -z "$_SOURCE_SH" ]; then
# from source.sh
_SOURCE_SH=:

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
            source_dir=`'cd' "$source_dir" && 'pwd'`
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
fi

_EXISTS_SH=:

Exists() {
    eval ${_local:-:} _af _bf _ls _rc _t
    _af=
    _bf=:
    _ls=
    : -=$-
    case "$-" in
    *e*) _rc=0;;		# avoid issues with set -e
    *)   _rc=1;;
    esac
    _t=-s
    while :
    do
        case "$1" in
        --all) _af=:; shift;;
        --bf) _rc=1 _bf=; shift;; # caller expects failure
        --lt) _ls=t; shift;;
        --lr|--ltr) _ls=tr; shift;;
        -?) _t=$1; shift;;
        *) break;;
        esac
    done
    if test x$_ls != x; then
        case "$_t" in
        -d) _ls=d$_ls;;
        esac
        set -- `'ls' -1$_ls "$@" 2> /dev/null`
    fi
    for f in "$@"
    do
        test $_t $f || continue
        _rc=0
        $_bf break
        echo $f
        $_af break
    done
    return $_rc
}

exists() {
    Exists --bf -e "$@"
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
    eval $_local __ __arg __eval __eval_args_opts __long_opts \
        __opt __opts __opt_dot __opt_comma __opt_prefix \
        __opt_spec __unknown_opts

    __=:
    __eval=
    __long_opts=
    __opt_comma=${opt_comma:-,}
    __opt_dot=${opt_dot:-" "}
    __opt_prefix=${opt_prefix:-opt_}
    __opts=
    __unknown_opts=$opt_unknown
    # these are not local
    __copy_opts=
    __shift=$#
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
	    *:f*) # function call
		case "$__opt_spec,$__arg" in
		*:f*a*,) __arg="$2"; _shift=2;; # consume another arg
		esac
		$__opt "$__arg"
		;;
	    *:a*) # litteral arg, consume next arg if needed
		case "$1" in
		*=*) ;;		# already got it above
		*) __arg="$2"; _shift=2;; # consume another arg
		esac
		case "$__opt_spec" in
		*.)  eval $__opt=\"\${$__opt:+\${$__opt}\${opt_dot_$__opt:-$__opt_dot}}$__arg\";;
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
		*)  : __unknown_opts=$__unknown_opts
		    case "$__unknown_opts" in
		    break) break;;
		    esac
		    ${__unknown_opts:-_unknown_opt} "$@"
		    ;;
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
		eval ${__opt_prefix}$__opt=\"\${${__opt_prefix}$__opt}\${${__opt_prefix}$__opt:+\${opt_dot_$__opt:-$__opt_dot}}$2\"; shift;;
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
	    *)	: __unknown_opts=$__unknown_opts
		case "$__unknown_opts" in
		break) break;;
		esac
		${__unknown_opts:-_unknown_opt} "$@"
		;;
	    esac
	    shift $_shift
	    ;;
	-*) # we told them not to group flags...
	    : __unknown_opts=$__unknown_opts
	    case "$__unknown_opts" in
	    break) break;;
	    esac
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
    sed -n -e "1d;/${END_HELP_MARKER:-RCSid}/,\$d" -e '/^[A-Za-z].*=/,$d' -e '/^#\.[a-z]/d' -e '/^# SPDX-License/d' -e '/^#/s,^# *,,p' $0
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
