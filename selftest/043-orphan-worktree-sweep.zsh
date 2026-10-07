# The orphan sweep takes debris and nothing else
_ST_SCENARIO "\e[1;96m[43] orphan worktree sweep\e[0m"
git reset -q --hard
# A temp dir of the run's own – any git-edit on the machine sweeps the shared one, and one
# getting there first would leave this run nothing to report
local GCBASE="$TMP/gc-tmp"
mkdir -p "$GCBASE"
# Provable debris: pointer dangles, and it has sat around for a day
local GC_DEAD="$GCBASE/git-edit-gctest-dead.$$"
mkdir -p "$GC_DEAD" && echo "gitdir: /nonexistent/repo/.git/worktrees/x" > "$GC_DEAD/.git"
touch -t 202601010000 "$GC_DEAD"
# Same dangling pointer but fresh – could be an operation starting right now
local GC_FRESH="$GCBASE/git-edit-gctest-fresh.$$"
mkdir -p "$GC_FRESH" && echo "gitdir: /nonexistent/repo/.git/worktrees/y" > "$GC_FRESH/.git"
# Old, but its repo is still there – a paused resolution must never be swept
local GC_LIVE="$GCBASE/git-edit-gctest-live.$$"
mkdir -p "$GC_LIVE" && echo "gitdir: $(git rev-parse --absolute-git-dir)" > "$GC_LIVE/.git"
touch -t 202601010000 "$GC_LIVE"
# Any mutating invocation runs the sweep
TMPDIR=$GCBASE _ST_RUN -M --text="Sweep trigger" HEAD
_ST_EQ "the run itself succeeds" "$RC" "0"
_ST_CHECK "orphaned debris is swept" sh -c "[ ! -d '$GC_DEAD' ]"
_ST_OUT_HAS "and the sweep is reported, never silent" 'Swept.*orphaned temp worktree'
_ST_CHECK "a fresh one is left alone" sh -c "[ -d '$GC_FRESH' ]"
_ST_CHECK "a registered worktree is never swept" sh -c "[ -d '$GC_LIVE' ]"
rm -rf "$GC_FRESH" "$GC_LIVE"
git reset -q --hard
