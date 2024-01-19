:
# NAME:
#	hooks.sh - provide hooks for customization
#
# SYNOPSIS:
#	hooks_add_all HOOKS func [...]
#	hooks_add_once HOOKS func [...]
#	hooks_add_default_set {all,once}
#	hooks_add HOOKS func [...]
#	hooks_run [--lifo] HOOKS ["args"]
#	hooks_run_all [--lifo] HOOKS ["args"]
#	hooks_has HOOKS func
#
#	add_hooks HOOKS func [...]
#	run_hooks HOOKS [LIFO] ["args"]
#	run_hooks_all HOOKS [LIFO] ["args"]
#
# DESCRIPTION:
#	The functions add_hooks and run_hooks are retained for
#	backwards compatibility.  They are aliases for hooks_add_all and
#	hooks_run.
#	
#	hooks_add_all simply adds the "func"s to the list "HOOKS".
#	hooks_add_once does the same but only if "func" is not in "HOOKS".
#	hooks_add uses one of the above based on "option", '--all' (default)
#	or '--once'.
#	hooks_add_default_set sets the default behavior of hooks_add
#	hooks_has indicates whether "func" in in "HOOKS"
#	hooks_run runs each "func" in $HOOKS and stops if any of them
#	return a bad status.
#	hooks_run_all does the same but does not stop on error.
#	If run_hooks or run_hooks_all is given a 2nd argument of LIFO
#	the hooks are run in the reverse order of calls to add_hooks.
#	Any "args" specified are passed to each hook function.

# RCSid:
#	$Id: hooks.sh,v 1.15 2023/05/06 16:36:32 sjg Exp $
#
#	@(#)Copyright (c) 2000-2022 Simon J. Gerraty
#
#	This file is provided in the hope that it will
#	be of use.  There is absolutely NO WARRANTY.
#	Permission to copy, redistribute or otherwise
#	use this file is hereby granted provided that 
#	the above copyright notice and this notice are
#	left intact. 

# avoid multiple inclusion
_HOOKS_SH=:

# We want to use local if we can
# if isposix-shell.sh has been sourced isPOSIX_SHELL will be set
case "$isPOSIX_SHELL" in
"") if (echo ${PATH%:*}) > /dev/null 2>&1; then
        local=local
    else
        local=:
    fi
    ;;
esac

##
# hooks_add_all list func ...
#
# add "func"s to "list" regardless
#
hooks_add_all() {
    eval $local __h
    __h=$1; shift
    eval "$__h=\"\$$__h $*\""
}

##
# hooks_add_once list func ...
#
# add "func"s to "list" if not already there
#
hooks_add_once() {
    eval $local __h __hh
    __h=$1; shift
    eval "__hh=\$$__h"
    while [ $# -gt 0 ]
    do
        : __hh="$__hh" 1="$1"
        case " $__hh " in
        *" $1 "*) ;;    # dupe
        *) __hh="$__hh $1";;
        esac
        shift
    done
    eval "$__h=\"$__hh\""
}

##
# hooks_add_default_set [--]{all,once}
#
# change the default method of hooks_add
#
hooks_add_default_set() {
    case "$1" in
    once|--once) HOOKS_ADD_DEFAULT=once;;
    *) HOOKS_ADD_DEFAULT=all;;
    esac
}

##
# hooks_add [--{all,once}] list func ...
#
# add "func"s to "list"
#
# If '--once' use hooks_add_once,
# default is hooks_add_all.
#
hooks_add() {
    case "$1" in
    --all) shift; hooks_add_all "@";;
    --once) shift; hooks_add_once "$@";;
    *) hooks_add_${HOOKS_ADD_DEFAULT:-all} "$@";;
    esac
}

##
# hooks_has list func
#
# is func in $list ?
#
hooks_has() {
    eval $local __h
    eval "__h=\$$1"
    case " $__h " in
    *" $1 "*) return 0;;
    esac
    return 1
}

##
# hooks_run [--all] [--lifo] list [LIFO] [args]
#
# pass "args" to each function in "list"
# Without '--all'; if any return non-zero return that immediately
#
hooks_run() {
    eval $local __a e __h __h2 __l
    __a=return
    __l=

    while :
    do
        case "$1" in
        --all) __a=:; shift;;
        --lifo) __l=:; shift;;
        *) break;;
        esac
    done
    eval "__h=\$$1"
    shift
    case "$1" in
    LIFO) __l=:; shift;;
    esac
    if [ x$__l != x ]; then
        __h2="$__h"
        __h=
        for e in $__h2
        do
            __h="$e $__h"
        done
    fi
    for e in $__h
    do
        $e "$@" || $__a $?
    done
}

##
# hooks_run_all [--lifo] list [LIFO] [args]
#
# pass "args" to each function in "list"
#
hooks_run_all() {
    hooks_run --all "$@"
}

##
# add_hooks,run_hooks[_all] aliases
#
add_hooks() {
    hooks_add_all "$@"
}

run_hooks() {
    hooks_run "$@"
}

run_hooks_all() {
    hooks_run --all "$@"
}


case /$0 in
*/hooks.sh)
    # simple unit-test
    list=
    for f in "$@"
    do
        case "$f" in
        --*|LIFO) ;;
        *HOOKS|*hooks) list=$f;;
        false|true) ;;
        *) eval "$f() { echo This is $f; }";;
        esac
    done
    echo hooks_add "$@"
    hooks_add "$@"
    echo hooks_run $list
    hooks_run $list
    echo hooks_run --all --lifo $list
    hooks_run --all --lifo $list
    echo hooks_run $list LIFO
    hooks_run $list LIFO
    ;;
esac
