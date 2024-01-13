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
#	$Id: sedem.sh,v 1.7 2013/03/27 15:52:57 sjg Exp $
#
#	@(#) Copyright (c) 1992,1996 Simon J. Gerraty
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
