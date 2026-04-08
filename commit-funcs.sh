: -*- mode: ksh -*-

# NAME:
#	commit-funcs.sh - commit related functions
#

# RCSid:
#	$Id: commit-funcs.sh,v 1.4 2025/08/07 21:59:54 sjg Exp $
#
#	@(#) Copyright (c) 2020-2025 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

# all need to agree on what's what and where.
set_cl_parts() {
    COMMIT_LOGS=${COMMIT_LOGS:-$HOME/commit-logs}
    cl_base=
    cl_diff=
    cl_log=
    cl_id=
    cl_dl=

    : token=$1
    case "$1" in
    "") return;;
    $COMMIT_LOGS/*diff)
        cl_diff=$1
        if is_posix_shell; then
            cl_base=${1%diff}
        else
            cl_base=`echo $1 | sed 's,diff$,,'`
        fi
        ;;
    $COMMIT_LOGS/*log)
        cl_log=$1
        if is_posix_shell; then
            cl_base=${1%log}
        else
            cl_base=`echo $1 | sed 's,log$,,'`
        fi
        cl_diff=${cl_base}diff
        ;;
    $COMMIT_LOGS/*) cl_base=$1${COMMIT_LOG_SEPARATOR:-.};;
    */) cl_base=$COMMIT_LOGS/${1}
        cl_diff=${cl_base}diff
        cl_log=${cl_base}${COMMIT_LOG_EXT:-log}
        ;;
    */*)
        if [ -s $1 ]; then
            case "$1" in
            *diff)
                cl_diff=$1
                if is_posix_shell; then
                    cl_base=${1%diff}
                else
                    cl_base=`echo $1 | sed 's,diff$,,'`
                fi
                ;;
            *log)
                cl_log=$1
                if is_posix_shell; then
                    cl_base=${1%log}
                else
                    cl_base=`echo $1 | sed 's,log$,,'`
                fi
                cl_diff=${cl_base}diff
                ;;
            *)
                cl_base=$1${COMMIT_LOG_SEPARATOR:-.}
                cl_diff=${cl_base}diff
                cl_log=$1
                ;;
            esac
        else
            cl_base=$COMMIT_LOGS/$1${COMMIT_LOG_SEPARATOR:-.}
            cl_diff=${cl_base}diff
            cl_log=${cl_base}${COMMIT_LOG_EXT}
        fi
        ;;
    *)  # we do not want everything in one directory!
        cl_base=$COMMIT_LOGS/$1/
        cl_diff=${cl_base}diff
        cl_log=${cl_base}${COMMIT_LOG_EXT:-log}
        ;;
    esac
    cl_id=`dirname $cl_diff | sed "s,$COMMIT_LOGS/,,"`
    cl_dl=${cl_base}dl
    case "$cl_log" in
    *.)
        if is_posix_shell; then
            cl_log=${cl_log%.}
        else
            cl_log=`echo $cl_log | sed 's,\.$,,'`
        fi
        ;;
    esac

    run_hooks cl_parts_hooks "$1"

    case "$cl_id" in
    [1-9][0-9]*[0-9]) PR=${PR:-$cl_id};;
    esac
}
