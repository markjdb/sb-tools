:
# RCSid:
#	$Id: test_opt.sh,v 1.5 2025/08/07 21:59:54 sjg Exp $
#
#	@(#) Copyright (c) 2009-2024 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

_TEST_OPT_SH=:

##
# test_opt opt alternative target prefix
#
# shell's typically have test(1) as built-in
# and not all support all options.
# 
# This function can actually test options for other built-ins
# eg. test_opt P '' . cd
# will set cd_P=-P if cd supports that
#
# test_opt L -h
# will set test_L to -L or -h if -L isn't supported
# 
test_opt() {
    _o=$1
    _a=$2
    _t=${3:-/}
    _p=${4:-test}

    case `($_p -$_o $_t) 2>&1` in
    *:*) eval ${_p}_$_o=$_a;;
    *) eval ${_p}_$_o=-$_o;;
    esac
}

case /$0 in
*/test_opt*) test_opt "$@";;
esac

