#!/bin/sh

# NAME:
#	sb-opt - set and query knobs that affect sb
#
# SYNOPSIS:
#	sb-opt.sh show
#	sb-opt.sh rm FOO
#	sb-opt.sh FOO=yes GOO=no ...
#	. sb-opt.sh; sb_opt FOO=yes GOO=no
#
# DESCRIPTION:
#	This script provides functions for manipulating options stored
#	in ``$SB/sbopt-*.inc``
#
#	Background:
#	
#	With ``options.mk`` (or ``bsd.mkopt.mk``) and ``mkopt.sh`` we
#	can sanely handle options in makefiles and scripts.
#
#	For any option ``FOO``, we ultimately want to set ``MK_FOO`` to
#	``yes`` or ``no``, making life simpler for scripts and makefiles.
#
#	The value can be controlled by a number of factors.
#	With ``options.mk`` options are introduced via
#	``__DEFAULT_YES_OPTIONS`` and ``__DEFAULT_NO_OPTIONS`` which
#	control their default value.
#
#	In addition users can set ``WITH_FOO`` and ``WITHOUT_FOO`` to
#	influence the value.
#	If ``FOO`` appears in the ``__DEFAULT_NO_OPTIONS``, and ``WITH_FOO``
#	is defined, ``MK_FOO`` will be set to ``yes`` rather than ``no``.
#
#	If ``WITHOUT_FOO`` is defined though, ``MK_FOO`` will be set to
#	``no`` regardless.
#	That is, ``WITHOUT_FOO`` wins over ``WITH_FOO``.
#
#	In addition a makefile can set ``NO_FOO`` to indicate that it
#	simply cannot do ``FOO``, it can also directly set ``MK_FOO=no``.
#
#	If the above all sounds complicated - it is; but it allows for
#	dealing with options and command line overrides in a sane
#	manner.
#
#	For example, it would be a bad idea to do::
#
#		make MK_FOO=yes
#
#	since ``MK_FOO`` set that way cannot be overridden by the
#	makefiles which can result in problems when a makefile has
#	``NO_FOO`` defined.
#
#	By contrast::
#
#		make -DWITH_FOO
#
#	is safe - it indicates a desire for ``MK_FOO=yes`` while
#	allowing the makefiles to do their thing.
#	
#	Which brings us to this.
#
#	``sb-opt.sh`` allows us to persistently configure options.
#	When run as a standalone script it just calls the function 'sb_opt'
#	with any args provided.
#	
#	For example::
#
#		sb_opt FOO=yes
#
#	results in creation of ``$SB/sbopt-FOO.inc``
#	containing::
#
#		export WITH_FOO=1
#		unset WITHOUT_FOO
#
#	The ``unset`` is to guard against WITHOUT_FOO in the environment
#	(from when ``workon`` was run for example).
#
#	Similarly::
#
#		sb-opt.sh FOO=no
#
#	results in ``$SB/sbopt-FOO.inc`` containing::
#
#		export WITHOUT_FOO=1
#	
#	when ``$SB/sbopt-FOO.inc`` is first created we also::
#
#		echo ". \$SB/sbopt-FOO.inc" >> $SB/.sandboxrc
#
#	
#	thus ensuring that when ``mk`` is run all our options will be
#	reflected in the environment.
#
#	The indirection allows the value of ``FOO`` to be changed
#	repeatedly and only ``$SB/sbopt-FOO.inc`` is updated.
#	This avoids having both ``WITH_FOO`` and ``WITHOUT_FOO``
#	set at the same time.
#
#
# SEE ALSO:
#	mk(1), mkopt.sh(1)

# RCSid:
#	$Id: sb-opt.sh,v 1.8 2024/01/10 04:30:59 sjg Exp $
#	
#	@(#)Copyright (c) 2017 Simon J. Gerraty
#
#	This file is provided in the hope that it will
#	be of use.  There is absolutely NO WARRANTY.
#	Permission to copy, redistribute or otherwise
#	use this file is hereby granted provided that 
#	the above copyright notice and this notice are
#	left intact. 

_SB_OPT_SH=:

if ! type Error > /dev/null 2>&1; then
    # be compatible with atexit
    Exit() {
	ExitStatus=$1
	exit $1
    }

    Error() {
	echo "ERROR: $@" >&2
	Exit 1
    }
fi

rm_opt() {
    i=sbopt-$1.inc
    if [ -s $SB/.sandboxrc ]; then
        (
            cd $SB
            rm -f $i
            grep -v $i .sandboxrc > .sandboxrc.new
            if cmp -s .sandboxrc .sandboxrc.new; then
                rm -f .sandboxrc.new
            else
                mv .sandboxrc.new .sandboxrc
            fi
        )
    fi
}


show_opts() {
    grep = $SB/sbopt-*.inc | sort | sed 's,.*inc:,,;s,export ,,'
}

sb_opt() {
    while :
    do
        case "$1" in
        "") break;;
        rm) rm_opt $2; shift 2;;
        show) show_opts; exit 0;;
        *=*)
            o=${1%=*}
            v=${1#*=}
            u=
            case "$v" in
            [YyTt1]*) w=WITH_ u=WITHOUT_;;
            [NnFf0]*) w=WITHOUT_;;
            *) Error "unknown: $1";;
            esac
            i=sbopt-$o.inc
            if [ ! -s $SB/$i ]; then
                echo ". \${SB}/$i" >> $SB/.sandboxrc
            fi
            echo "export $w$o=1" > $SB/$i
            # WITH_ has no effect if WITHOUT_
            # happens to be in the env.
            test -z "$u" || echo "unset $u$o" >> $SB/$i
            shift
            ;;
            *) Error "unknown: $1";;
        esac
    done
}


case "/$0" in
*/sb-opt*)
    Mydir=`dirname $0`
    MYNAME=sb_opt

    for x in $Mydir/sb-env.sh $Mydir/mk
    do
        test -s $x || continue
        . $x
        break
    done
    sb_opt "$@"
    exit $?
    ;;
esac
    
SB_OPTS=

# sbopt_sb_opts allows us to defer processing 
# of SB_OPTS
add_hooks mksb_env_setup_hooks sbopt_sb_opts
sbopt_sb_opts() {
    sb_opt $SB_OPTS
    :
}

add_hooks mksb_options_hooks sbopt_opt
sbopt_opt() {
    case "$1" in
    --sb-opt-*=[01YyNnTtFf]*)
        # just accumulate them for now
        SB_OPTS="$SB_OPTS ${1#--sb-opt-}"
        return 1	     # we consumed it
        ;;
    esac
    return 0
}
