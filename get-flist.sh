:
# NAME:
#	get-flist - get a list of files
#
# DESCRIPTION:
#	I run:
#
#.nf
#		get-flist.sh */* > flist
#
#.fi
#	in most of my source trees so I can just run grep(1)
#	on "flist" rather than repeatedly run find(1).
#

#	@(#)Copyright (c) 2000 Simon J. Gerraty
#
#	SPDX-License-Identifier: BSD-2-Clause

find ${@:-*} -type f |
egrep -iv '~|\.#|CVS/|\.(git|hg|svn)/|\.(old|log|bak|mine|orig|r[1-9][0-9]*|rej|core)$|#$' |
sort -u
