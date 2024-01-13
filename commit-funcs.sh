: -*- mode: ksh -*-

# NAME:
#	commit-funcs.sh - commit related functions
#

# RCSid:
#	$Id: commit-funcs.sh,v 1.2 2022/07/26 17:49:43 sjg Exp $
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
        cl_base=`echo $1 | sed 's,diff$,,'`
        cl_diff=$1
        ;;
    $COMMIT_LOGS/*log)
        cl_base=`echo $1 | sed 's,log$,,'`
        cl_diff=${cl_base}diff
        cl_log=$1
        ;;
    $COMMIT_LOGS/*) cl_base=$1${COMMIT_LOG_SEPARATOR:-.};;
    */)	cl_base=$COMMIT_LOGS/${1}
        cl_diff=${cl_base}diff
        cl_log=${cl_base}log        
        ;;
    */*)
        if [ -s $1 ]; then
            case "$1" in
	    *diff)
                cl_base=`echo $1 | sed 's,diff$,,'`
                cl_diff=$1
                ;;
	    *log)
                cl_base=`echo $1 | sed 's,log$,,'`
                cl_diff=${cl_base}diff
		cl_log=$1
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
        cl_log=${cl_base}log
        ;;
    esac
    cl_id=`dirname $cl_diff | sed "s,$COMMIT_LOGS/,,"`
    cl_dl=${cl_base}dl
    case "$cl_log" in
    *.) cl_log=`echo $cl_log | sed 's,\.$,,'`;;
    esac
    
    run_hooks cl_parts_hooks "$1"

    case "/$cl_id" in
    */[1-9][0-9]*)
        PR=${PR:-`echo $cl_diff | sed 's,.*/\([1-9][0-9][0-9][0-9][0-9]*\).*,\1,'`}
        ;;
    esac
}
