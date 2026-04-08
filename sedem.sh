:
# NAME:
#	sedem.sh - sed a bunch of files.
#
# SYNOPSIS:
#	sedem.sh [-v] "args" < "list"
#
# DESCRIPTION:
#	This script is used to apply 'sed' "args" to a list of files
#	read from stdin.
#	If the edit affects a "file" then the original is renamed to
#	"file".bak otherwise it is left untouched.  If the '-v' option
#	is given (must be first arg), then modified file names are
#	echoed to stdout.
#
# SEE ALSO:
#	sed(1)
#	
# AUTHOR:
#	Simon J. Gerraty <sjg@crufty.net>

# RCSid:
#	$Id: sedem.sh,v 1.8 2025/08/07 21:59:54 sjg Exp $
#
#	@(#) Copyright (c) 1992,1996 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

verb=:
case "$1" in
-v)	verb=echo; shift;;
esac

[ $# -gt 0 ] || { echo "sedit sedargs < list" >&2; exit 1; }
  
while read file
do
  test -s $file || continue
  test -d $file && continue
  ${SED:-sed} "$@" $file > $file.$$ || { rm -f $file.$$; exit 1; }
  if cmp -s $file $file.$$; then
    # they're the same, skip rest
    rm -f $file.$$
  else
    trap "" 2 3 15
    # sed command above checked that we can write in the directory...
    mv $file $file.bak && mv $file.$$ $file
    # indicate that we have modified something
    $verb $file
    trap 2 3 15
  fi
done
exit 0
