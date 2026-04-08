
# RCSid:
#	$Id: have.sh,v 1.4 2025/08/07 21:59:54 sjg Exp $
#
#	@(#) Copyright (c) 2023 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net

_HAVE_SH=:

##
# have "thing"
#
# do we have "thing" - which might be a function
#
if (type /no/such/thing) > /dev/null 2>&1; then
    # we cannot trust return from type
    have() {
        case `(type "$1") 2>&1` in
        *" found") return 1;;
        esac
        return 0
    }
else
    # the return code is good
    have() {
        (type "$1") > /dev/null 2>&1
    }
fi

case /$0 in
*/have.sh)
    for x in "$@"
    do
        have "$x"
        echo "$x: $?"
    done
    ;;
esac
