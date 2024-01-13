:
# NAME:
#	git-up.sh - update a git repo
#
# SYNOPSIS:
#	git-up.sh [options]
#
# DESCRIPTION:
#	We first fetch the latest content of the upstream repo.
#	If that fails or there are no changes we are done.
#
#	If there are changes, and our tree is dirty, we stash
#	the current state.
#
#	Assuming we are on the same branch we originally checked out
#	we simply rebase and if that succeeds, we pop anything
#	stashed earlier.
#
#	If our current branch has no remote tracking and is NOT the
#	same as we originally checked out (assuming we used mksb(1)
#	which will have recorded that as SB_GIT_BRANCH), we report our
#	current branch and how to restore what we stashed, then
#	checkout SB_GIT_BRANCH and rebase.
#
#	Options:
#
#	-i	Pass to rebase.
#
#	-f	Proceed even if it does not appear there are changes
#		to consume.
#
#	-r	Rebase $SB_GIT_BRANCH to current branch
#		Without this we will just checkout current branch
#		again and restore what we stashed.
#	


# RCSid:
#	$Id: git-up.sh,v 1.16 2023/01/28 01:01:15 sjg Exp $
#
#	@(#) Copyright (c) 2018-2021 Simon J. Gerraty
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

case "/$0" in
*/git-up*)
    MYNAME=gitup
    Mydir=`dirname $0`
    # let this set SB_TOOLS if it wants
    rc=$Mydir/git-up.rc
    if [ -s $rc ]; then
        . $rc
    fi
    SB_TOOLS=${SB_TOOLS:-$Mydir}
    PATH=$SB_TOOLS:$PATH
    . debug.sh
    . sb-funcs.sh
    DebugOn gitup gituprc
    if [ -z "$SB" ]; then
        SB=`find_sb`
        if [ -s ${SB:-/dev/null} ]; then
            here=`$pwd`
            # we really only care about SB_GIT_BRANCH
            sb_hooks $SB
            'cd' $here
	fi
    fi
    for d in $HOME $SB/.. $SB
    do
        source_once $d/git-up.rc
    done
    DebugOff gituprc
    ;;
esac

GIT=${GIT:-git}
$_DEBUG_SH . debug.sh
$_HOOKS_SH . hooks.sh

git_work_tree_is_dirty () {
    ${GIT} rev-parse --verify HEAD >/dev/null || return 0
    ${GIT} update-index -q --ignore-submodules --refresh
    ${GIT} diff-files --quiet --ignore-submodules || return 0
    ${GIT} diff-index --cached --quiet --ignore-submodules HEAD -- || return 0
    return 1
}

git_up() {
    opt_i=
    opt_f=
    opt_r=
    stashpop=
    DebugOn gitup
    while :
    do
        case "$1" in
        -f) opt_f=-f; shift;;
        -i) opt_f=-f opt_u=-i; shift;;
        -r) opt_r=-r SB_GIT_BRANCH="$2"; shift 2;;
        -r*) opt_r=-r SB_GIT_BRANCH="${1#-r}"; shift;;
        --no-pop) stashpop=:; shift;;
        *) break;;
        esac
    done
    checkoutgit=:
    rebasegit=:
    stashgit=:
    stashecho=:
    $GIT fetch || return 1
    _b=`$GIT branch | sed -n '/\*/s,\* ,,p'`
    _v=`$GIT branch -v`
    case "$_b,$SB_GIT_BRANCH" in
    *"HEAD detached"*,) echo "ERROR: need -r SB_GIT_BRANCH"; exit 1;;
    *"HEAD detached"*)
        $GIT checkout $SB_GIT_BRANCH
        _b=$SB_GIT_BRANCH
        ;;
    esac
    echo "$_v"
    if $GIT config --get branch.$_b.remote > /dev/null; then
        # no fancy footwork needed
        unset SB_GIT_BRANCH
    fi
    # is current branch or $SB_GIT_BRANCH (what we originally checked out)
    # in need of rebase?
    case "$_v,$opt_f" in
    *" ${SB_GIT_BRANCH:-$_b} "*"["*behind*"]"*) ;;
    *" $_b "*"["*behind*"]"*) ;;
    *" ${SB_GIT_BRANCH:-$_b} "*"["*ahead*"]"*,-f) ;;
    *" $_b "*"["*ahead*"]"*,-f) ;;
    *) echo "Up to date"; return 0;;
    esac
    if git_work_tree_is_dirty; then
        stashgit=$GIT
        stashecho=echo
    fi
    DebugOn gitup_pre_hooks
    run_hooks gitup_pre_hooks
    DebugOff gitup_pre_hooks
    if [ ${SB_GIT_BRANCH:-$_b} != $_b ]; then
        $stashecho Stashing for $_b
        $stashgit stash
        $GIT checkout $SB_GIT_BRANCH
        if [ x$opt_r = x-r ]; then
            rebasegit=$GIT
        else
            checkoutgit=$GIT
        fi
    else
        $stashgit stash
    fi
    DebugOn gitup_rebase
    x=
    if $GIT rebase $opt_i; then
        $rebasegit rebase $opt_i $SB_GIT_BRANCH $_b || { x=$?; stashgit=:; }
        $checkoutgit checkout $_b || { x=$?; stashgit=:; }
        ${stashpop:-$stashgit} stash pop || x=$?
        case "$staspop" in
        :) $stashecho "Don't forget to: $GIT stash pop";;
        esac
    fi
    x=${x:-$?}
    if [ $x = 0 ]; then
        DebugOn gitup_post_hooks
        run_hooks gitup_post_hooks
        DebugOff gitup_post_hooks
    else
        $GIT status > s
        echo "See 's' for status"
    fi
    DebugOff gitup_rebase
    $GIT branch -v
    DebugOff gitup
    return $x
}

git_update() {
    DebugOn gitupdate
    git_up "$@" &&
    run_hooks gitupdate_hooks
    DebugOff gitupdate
}

case "/$0" in
*/git-up*) git_update "$@";;
esac

