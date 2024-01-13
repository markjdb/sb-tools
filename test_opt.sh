:
# RCSid:
#	$Id: test_opt.sh,v 1.3 2021/10/16 21:21:17 sjg Exp $
#
#	@(#) Copyright (c) 2009 Simon J. Gerraty
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

_TEST_OPT_SH=:

# shell's typically have test(1) as built-in
# and not all support all options.
test_opt() {
    _o=$1
    _a=$2
    _t=${3:-/}
    
    case `(test -$_o $_t) 2>&1` in
    *:*) eval test_$_o=$_a;;
    *) eval test_$_o=-$_o;;
    esac
}

case /$0 in
*/test_opt*) test_opt "$@";;
esac

