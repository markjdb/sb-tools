
# RCSid:
#	$Id: isposix-shell.sh,v 1.2 2022/08/25 16:35:17 sjg Exp $
#
#	@(#) Copyright (c) 2021 Simon J. Gerraty
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
    case `type true` in
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
