
# RCSid:
#	$Id: isposix-shell.sh,v 1.12 2025/08/07 21:59:54 sjg Exp $
#
#	@(#) Copyright (c) 2021 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

_isPOSIX_SHELL_SH=:

# does local *actually* work?
local_works() {
    local _fu
}

##
# test if we have local that works
#
# 'local' is not actually part of POSIX
# though most POSIX shells support it,
# but that does not ensure it actually works.
if local_works > /dev/null 2>&1; then
    _local=local
else
    _local=:
fi
# for backwards compatability
local=$_local

##
# set isPOSIX_SHELL
#
# Some features of the POSIX shell are very useful.
# We need to be able to know if we can use them.
#
# We set isPOSIX_SHELL={true,false}
# so we can use 'if $isPOSIX_SHELL; then'
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

is_posix_shell() {
    $isPOSIX_SHELL
    return
}
