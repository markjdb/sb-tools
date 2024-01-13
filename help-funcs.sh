: -*- mode: ksh -*-

# RCSid:
#	$Id: help-funcs.sh,v 1.15 2022/08/18 04:29:19 sjg Exp $
#
#	@(#) Copyright (c) 2009-2022 Simon J. Gerraty
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

_HELP_FUNCS_SH=:

$_HOOKS_SH . hooks.sh

case "`type Exit 2> /dev/null`" in
*func*) ;;
*)  Exit() {
        ExitStatus=$1
        exit $1
    }
;;
esac

##
# add_docs file [...]
#
# add "file" to list of files to be processed by _docs_
#
add_docs() {
    docs_list="$docs_list $@"
}

# add this to docs_hooks
help_docs_hook() {
    if [ -n "$docs_list" ]; then
        extract_doc_comments section=-- $docs_list |
        doc_comment_format_sections
    fi
    return 0
}

##
# extract_doc [eod=eod] file
#
# extract documentation from initial comment in "file"
# "eod" indicates the end of the initial doc comment
# the default is 'RCSid' or value of $END_HELP_MARKER
#
extract_doc() {
    eod="${END_HELP_MARKER:-RCSid}"
    while :
    do
        case "$1" in
        *=*) eval "$1"; shift;;
        *) break;;
        esac
    done
    sed -n -e "1d;/$eod/,\$d" -e '/^#\.[a-z]/d' -e '/^#/s,^# *,,p' "$@"
}

##
# extract_doc_comments [vars=value ...] file
#
# Relevant "vars" are 'section_markers', 'section', and 'title'
#
# Extract all block comments that begin with '##' or '##[$section_markers]'
# "section_markers" defaults to $HELP_SECTION_MARKERS (*=~_-).
# "section" defaults to $HELP_SECTION_MARKER (empty).
# "title" defaults to $HELP_PRE_COMMENTS_TITLE (Functions).
#
# If "section" is '--' or two "section_markers", '##' is replaced by that,
# this allows for more complicated formatting see doc_comment_format_sections
#
# Any other value of "section" just replaces '##' lines with that.
#
extract_doc_comments() {
    section="$HELP_SECTION_MARKER"
    section_markers="${HELP_SECTION_MARKERS:-*=~_-}"
    title="${HELP_PRE_COMMENTS_TITLE:-Functions}"
    while :
    do
        case "$1" in
        *=*) eval "$1"; shift;;
        *) break;;
        esac
    done
    case "$section" in
    [$section_markers][$section_markers]) section_sed="s/^##/$section/"
        if [ -z "$extract_doc_comments_pre_hooks" ]; then
            add_hooks extract_doc_comments_pre_hooks default_pre_doc_comments_hook
	fi
        ;;
    *)  section_sed="s/^##.*/$section/";;
    esac
    for f in "$@"
    do
        run_hooks extract_doc_comments_pre_hooks $f
        sed -n "/^##[$section_markers]*\$/,/^[^#]/ {
            /^[^#]/d
            $section_sed
            /^#\.[a-z]/d
            s/^# *//
            p
            }" $f
    done
}

##
# default_pre_doc_comments_hook file
#
# If section marker is -- etc and extract_docs_pre_comment_hooks is
# empty this will be used - to try and ensure our rst section
# hierarchy is used (ie. '*' '=' '-' '~' '_')
# Its output is in the same format as extract_doc_comments and should
# result in the file basename underlined with '*'
# and a title underlined with '='
# 
default_pre_doc_comments_hook() {
    cat <<EOH
${section}*
`basename $1`
${section}=
$title
EOH
}

##
# extract_docs [var=value ...] file ...
#
# for each "file" extract initial doc comment
# as well as all the block comments starting with '##'
#
# Relevant "vars" are 'eod', 'section_markers', 'section', and 'title'
# 
extract_docs() {
    __flags=
    while :
    do
        case "$1" in
        *=*) __flags="$__flags $1"; shift;;
        *) break;;
        esac
    done
    
    for f in "$@"
    do
        extract_doc $__flags $f
        extract_doc_comments $__flags $f |
        doc_comment_format_sections $__flags
    done
}

##
# doc_section_header under title
#
# output "title" underlined with "under"
#
doc_section_header() {
    u="$1"; shift
    echo
    echo "$@"
    echo "$@" | sed "s/./$u/g"
}
        
##
# doc_comment_format_sections [vars=value ...]
#
# a filter to render the first line of ## block comments
# as an rst section heading
#
# Expects input from extract_doc_comments section=--
#
doc_comment_format_sections() {
    (
        set -f
        section_markers="${section_markers:-${HELP_SECTION_MARKERS:-*=~_-}}"
        while :
        do
            case "$1" in
            *=*) eval "$1"; shift;;
            *) break;;
            esac
        done
        markers="$section_markers"
        section=
        while read line
        do
            : section=$section,line=$line
            case "$section,$line" in
            ,[$markers][$markers]|,[$markers][$markers]?) section=`expr x$line : '.*\(.\)'`; continue;;
            ?,*)
                doc_section_header $section "$line"
                section=
                continue
                ;;
            esac
            echo "$line"
        done
    )
}

##
# _doc_ ["file"]
#
# extract documentation from initial comment in "file"
# (default $0).
# run doc_hooks
#
# An easy way to add --help support to shell scripts
# even those that use getopt(1) is (before that) do:
# # Yes I mean $* below, and the spaces.
# case " $* " in *" --help "*) __help;; esac
#
_doc_() {
    extract_doc "${@:-$0}"
    run_hooks doc_hooks
}

##
# _docs_ [file]
#
# extract all the doc comments from "file" (default $0)
# run docs_hooks
#
_docs_() {
    extract_docs section=-- "${@:-$0}"
    run_hooks docs_hooks
}

##
# _doc_comments_ [file]
#
# extract suitable comment blocks from "file" (default $0)
#
_doc_comments_() {
    extract_doc_comments section=-- "${@:-$0}" |
    doc_comment_format_sections
    run_hooks doc_comment_hooks
}

##
# _help_ [topic]
#
# Look for help functions to run for "topic".
#
# We expect SB_VARMYNAME_LIST to be set to versions of Myname
# which are valid variabled names, we ensure "topic" starts with '_'.
# 
# For each such name "n" we look for ${n}_help${topic}_hooks
# ${n}${topic:-_help}_hooks and help${topic}_hooks and
# run_hooks the first one found.
# 
# Failing that we look for functions named ${n}_help${topic}
# help${topic} and run the first one found
#
# If all else fails we call _docs_
#
_help_() {
    case "$1" in
    ""|help) topic=;;
    _*) topic=$1;;
    *) topic=_$1;;
    esac

    if [ -z "$SB_VARMYNAME_LIST" ]; then
        SB_VARMYNAME_LIST=`basename $0 .sh | sed 's,[^A-Za-z0-9_],_,g'`
    fi
    for n in $SB_VARMYNAME_LIST
    do
        # look for hooks
        for hl in ${n}_help${topic}_hooks ${n}${topic:-_help}_hooks help${topic}_hooks
        do
            eval hh=\$$hl
            if [ -n "$hh" ]; then
                run_hooks $hl
                return 0
            fi
        done
        # look for function
        for hf in ${n}_help${topic} help${topic}
        do
            # type is available in most shell's post 1980
            # users who alias ${n}_help to something
            # that does not exist, deserve to lose.
            : hf=$hf
            case `(type $hf) 2>&1` in
            *function*)
                $hf
                return 0
                ;;
            esac
        done
    done
    case "$topic" in
    "") _docs_;;
    *) error no help$topic found;;
    esac
}

##
# __doc [file]
#
# run _doc_ through $PAGER and exit 0
#
__doc() {
    _doc_ "$@" | ${PAGER:-more}
    Exit 0
}

##
# __docs [file]
#
# run _docs_ through $PAGER and exit 0
#
__docs() {
    _docs_ "$@" | ${PAGER:-more}
    Exit 0
}

##
# __doc_comments [file]
#
# run _doc_comments_ through $PAGER and exit 0
#
__doc_comments() {
    _doc_comments_ "$@" | ${PAGER:-more}
    Exit 0
}

##
# __help [file]
#
# run _help_ through $PAGER and exit 0
#

__help() {
    _help_ "$@" | ${PAGER:-more}
    Exit 0
}

case "/$0" in
*/help-funcs.sh)
    _docs_ "$@"
    ;;
esac
