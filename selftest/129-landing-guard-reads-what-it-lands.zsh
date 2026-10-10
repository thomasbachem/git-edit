_ST_SCENARIO "\e[1;96m[129] a landing guard reads what it lands, and a held lock waits\e[0m"
local LG_T LG_B LG_REAL LG_GD LG_WT LG_HOLD
# Edits on top of a file another caller added, then rewrote, hold most of what the tip has
_ST_PZ_NEW lg1
_ST_PZ_C base.txt b "LG base"
print -l {1..10} > n.txt
GIT_EDIT_ACTOR=lg-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "LG peer adds" -- n.txt </dev/null >/dev/null 2>&1
print -l a b c d e f g h i j > n.txt
GIT_EDIT_ACTOR=lg-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "LG peer rewrites" -- n.txt </dev/null >/dev/null 2>&1
print -l a b c d e f g h i j k > n.txt
GIT_EDIT_ACTOR=lg-self _ST_RUN --commit --text "LG self" -- n.txt
_ST_EQ "edits on top of a file another caller added and rewrote land" "$RC:$(git log -1 --format=%s)" "0:LG self"
# The fold carries what was staged as the run read it – staging changed meanwhile stays staged
_ST_PZ_NEW lg2
_ST_PZ_C a.txt a "LG2 a" && LG_T=$(git rev-parse HEAD)
_ST_PZ_C b.txt b "LG2 b"
print -r -- a1 > a.txt && git add a.txt
LG_REAL=$(whence -p git)
mkdir -p "$TMP/lg-shim"
printf '#!/bin/sh\ncase " $* " in *" --summary "*) [ -e "%s/lg-shim-done" ] || { : > "%s/lg-shim-done"; echo a2 > a.txt; "%s" add a.txt; } ;; esac\nexec "%s" "$@"\n' \
	"$TMP" "$TMP" "$LG_REAL" "$LG_REAL" > "$TMP/lg-shim/git"
chmod +x "$TMP/lg-shim/git"
rm -f "$TMP/lg-shim-done"
PATH="$TMP/lg-shim:$PATH" _ST_RUN --amend-into="$LG_T"
_ST_EQ "a fold carries the staging it read, not what was staged meanwhile" "$RC:$(git show HEAD~1:a.txt):$(git show :a.txt)" "0:a1:a2"
_ST_CHECK "the staging changed meanwhile was taken" test -e "$TMP/lg-shim-done"
git restore -q --staged a.txt; git checkout -q -- a.txt
# A held index lock is waited out, as a `git status` holds it a moment – the re-sync lands then
_ST_PZ_NEW lg3
_ST_PZ_C x.txt x1 "LG3 x1"
_ST_PZ_C x.txt x2 "LG3 x2"
_ST_PZ_C y.txt y "LG3 y"
LG_GD=$(git rev-parse --absolute-git-dir)
printf '#!/bin/sh\n[ "$1" = committed ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\n[ -e "%s/lg-arm" ] || exit 0\nrm -f "%s/lg-arm"\n: > "%s/index.lock"\n( sleep 1; rm -f "%s/index.lock" ) >/dev/null 2>&1 &\n' \
	"$LG_GD" "$LG_GD" "$LG_GD" "$LG_GD" > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
: > "$LG_GD/lg-arm"
_ST_RUN -d -y HEAD~1
_ST_EQ "a drop's re-sync waits out an index lock held a moment" "$RC:$(git diff --cached --name-only | tr '\n' ' ')" "0:"
_ST_OUT_LACKS "naming no entry left locked" 'Index locked'
rm -f .git/hooks/reference-transaction "$LG_GD/index.lock"
# A staged fold refused for a landing hands back the staging, never the checkout's file
_ST_PZ_NEW lg4
_ST_PZ_C root.txt r "LG4 root"
print -l {1..10} > n.txt
GIT_EDIT_ACTOR=lg-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "LG4 peer adds" -- n.txt </dev/null >/dev/null 2>&1
# The target past the landing, which a fold below it would apply again
_ST_PZ_C base.txt b "LG4 base" && LG_T=$(git rev-parse HEAD)
print -l q r s > n.txt && git add n.txt
GIT_EDIT_ACTOR=lg-self _ST_RUN --amend-into="$LG_T" -- n.txt
_ST_EQ "a staged fold taking back an addition refuses" "$RC" "1"
_ST_OUT_HAS "offering to unstage it" 'git restore --staged -- n.txt'
_ST_OUT_LACKS "never to restore the checkout's file" 'restore --source=HEAD --worktree'
git restore -q --staged n.txt; git checkout -q -- n.txt
# As is a bare tree, which names no tip it was composed on
print -l q r s > n.txt
LG_B=$(GIT_INDEX_FILE="$TMP/lg-idx" sh -c "git read-tree '$LG_T' && git update-index --add n.txt && git write-tree")
git checkout -q -- n.txt
GIT_EDIT_ACTOR=lg-self _ST_RUN --amend-into="$LG_T" --tree="$LG_B" -- n.txt
_ST_EQ "a bare --tree taking back a landing refuses" "$RC:$(git log -1 --format=%s)" "1:LG4 base"
_ST_OUT_HAS "naming the tree" 'Folded from --tree'
# An undo hands the run it took back to the checkout as work, never as staleness to discard
_ST_PZ_NEW lg5
_ST_PZ_C base.txt b "LG5 base"
print -r -- w > w.txt
_ST_RUN --commit --text "LG5 adds" -- w.txt
_ST_RUN --undo
_ST_OUT_HAS "an undo hands its run back as the checkout's" 'what the undone run landed stays in your checkout'
_ST_EQ "its file kept, untracked" "$(<w.txt):$(git status --porcelain -- w.txt)" "w:?? w.txt"
_ST_OUT_LACKS "nothing offered to discard it" 'Keep it, or discard\|git clean\|git restore \(--source\|--worktree\|-- \)'
rm -f w.txt
# A journal lock whose holder is gone is broken at once, the landing journaling under it,
# while one a live run holds is waited on and then refused, moving nothing – that wait cut
# short here by a `sleep` returning at once
_ST_PZ_NEW lg6
_ST_PZ_C base.txt b "LG6 base"
sh -c 'exit 0' & LG_HOLD=$!
wait $LG_HOLD
print -r -- "$LG_HOLD Thu Jan 1 00:00:00 1970" > .git/git-edit-journal.lock
print -r -- j > j.txt
_ST_RUN --commit --text "LG6 journaled" -- j.txt
_ST_EQ "a gone run's journal lock is broken at once" "$RC:$(tail -1 .git/git-edit-journal | cut -d' ' -f5-)" "0:commit"
_ST_OUT_LACKS "the landing journaling under it" 'Journaled without its lock'
LG_T=$(git rev-parse HEAD)
# A live process the run does not run under – the suite's own would read as the one it runs under
sleep 30 & LG_HOLD=$!
_PID_START $LG_HOLD
print -r -- "$LG_HOLD $REPLY" > .git/git-edit-journal.lock
mkdir -p "$TMP/lg-nap" && print -l '#!/bin/sh' 'exit 0' > "$TMP/lg-nap/sleep" && chmod +x "$TMP/lg-nap/sleep"
PATH="$TMP/lg-nap:$PATH" _ST_RUN --undo
_ST_EQ "an undo under a held journal lock moves nothing" "$RC:$(git rev-parse HEAD)" "1:$LG_T"
_ST_OUT_HAS "naming the lock" "journal is locked by another run (pid $LG_HOLD)"
kill $LG_HOLD; wait $LG_HOLD 2>/dev/null
# One naming no holder, as a run killed while writing it leaves, is broken once 10 s old
: >| .git/git-edit-journal.lock
touch -t 200001010000 .git/git-edit-journal.lock
_ST_RUN --undo
_ST_EQ "a stale journal lock is broken" "$RC:$(tail -1 .git/git-edit-journal | awk '{print $5}')" "0:undo"
_ST_CHECK "and goes" test ! -e .git/git-edit-journal.lock
rm -f j.txt
# A pause is its own caller's – another label refuses, and a resume journals under the pause's
_ST_PZ_NEW lg7
_ST_PZ_C a.txt a "LG7 a" && _ST_PZ_C b.txt b "LG7 b"
GIT_EDIT_ACTOR=lg-a _ST_RUN HEAD~1
LG_WT=$(_ST_PZ_WT)
print -r -- a2 > "${LG_WT:-$ST_NO_WT}/a.txt"
GIT_EDIT_ACTOR=lg-b _ST_RUN --continue
_ST_EQ "another label's continue refuses" "$RC:$(git log -1 --format=%s HEAD~1):$(git show HEAD~1:a.txt)" "1:LG7 a:a"
_ST_OUT_HAS "naming whose it is" "The paused edit is lg-a's"
GIT_EDIT_ACTOR=lg-b _ST_RUN --abort
_ST_EQ "as does its abort" "$RC:$(_ST_PZ_WT)" "1:$LG_WT"
_ST_RUN --continue
_ST_EQ "a person may finish an agent's pause" "$RC:$(git show HEAD~1:a.txt)" "0:a2"
_ST_EQ "journaled as the pause's own run" "$(tail -1 .git/git-edit-journal | awk -F'\t' '{print $2}')" "lg-a"
# A labeled run is an agent's – no prompt at a terminal, whatever its stdin
_ST_TTY GIT_EDIT_ACTOR=lg-a -- HEAD~1
_ST_EQ "a labeled run at a terminal pauses as an agent's" "$RC" "2"
_ST_OUT_LACKS "asking nothing" 'press Enter to continue'
_ST_RUN --abort
# An exec that changed nothing names a peer's move beside "unchanged"
_ST_PZ_NEW lg8
_ST_PZ_C a.txt a "LG8 a"
LG_T=$(git rev-parse HEAD)
_ST_RUN --exec -- git -C "$TMP/pz-lg8" commit -q --allow-empty -m "LG8 peer"
_ST_OUT_HAS "an exec that changed nothing says so beside a peer's move" "^git-edit: ok – refs/heads/main unchanged, moved meanwhile by another run, ${LG_T:0:7} → "
# A hook vetoing the landing says so where it happens, not in the trailer alone
printf '#!/bin/sh\n[ "$1" = prepared ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\necho "LG8 frozen" >&2\nexit 1\n' > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
_ST_RUN -d -y HEAD
_ST_EQ "a vetoed landing refuses" "$RC" "1"
_ST_EQ "naming the veto above the trailer too" "$(print -r -- "$OUT" | grep -c 'git refused to move main')" "2"
rm -f .git/hooks/reference-transaction
cd "$TMP/repo"
