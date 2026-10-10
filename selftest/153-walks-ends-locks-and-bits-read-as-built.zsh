# An `--exec` result is traced to what it was built on, `--move` resolves stale ends as a range
# does, a `:/` tree names its paths, a `-C` lock stays put while held, a bit a landing added
# counts and is taken back as hinted, and a case clash names a directory's files or a tree's
_ST_SCENARIO "\e[1;96m[153] exec builds traced, stale moves, :/ trees, held locks, landed bits, case clashes\e[0m"
local WE_T WE_I WE_O3 WE_O4 WE_TC WE_GD WE_DEAD WE_H
local -a WE_PIDS WE_ARGS
# An `--exec` building below its start tip, then passing back through it on the way to that result,
# still needs `--base`
_ST_PZ_NEW we1
_ST_PZ_C a.txt a "WE1 a" && _ST_PZ_C b.txt b "WE1 b" && _ST_PZ_C c.txt c "WE1 c"
WE_T=$(git rev-parse HEAD)
_ST_RUN --exec -- sh -c 'O=$(git rev-parse HEAD) && git reset -q --hard HEAD~1 && git commit -q --allow-empty -m "WE1 below" && X=$(git rev-parse HEAD) && git checkout -q "$O" && git checkout -q "$X"'
_ST_EQ "a result built below the start tip, passed back through it, refuses" "${RC}:$(git rev-parse HEAD)" "1:$WE_T"
_ST_OUT_HAS "naming where HEAD went" 'below the tip this run started on'
_ST_RUN --exec -- sh -c 'O=$(git rev-parse HEAD) && git reset -q --hard HEAD~1 && git commit -q --allow-empty -m "WE1 below" && X=$(git rev-parse HEAD) && git checkout -q "$O" && git commit -q --allow-empty -m "WE1 on tip" && git reset -q --hard "$X"'
_ST_EQ "as does one returning to it after building on the start tip" "${RC}:$(git rev-parse HEAD)" "1:$WE_T"
# While a result built on the start tip lands, a detour before or after it included
_ST_RUN --exec -- sh -c 'git checkout -q HEAD~2 && git checkout -q - && git commit -q --amend -m "WE1 c amended" && Y=$(git rev-parse HEAD) && git checkout -q HEAD~1 && git checkout -q "$Y"'
_ST_EQ "an amend between two detours lands" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:WE1 c amended|WE1 b|WE1 a|"
_ST_RUN --exec -- sh -c 'git checkout -q HEAD~2 && git checkout -q - && GIT_SEQUENCE_EDITOR="sed -i.bak 1d" git rebase -q -i HEAD~2'
_ST_EQ "as does a rebase after a detour, its todo naming what it drops" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:WE1 c amended|WE1 a|"
# A `--move` run whose two ends a rewrite staled moves the commits it named, not one a peer put
# between their current identities
_ST_PZ_NEW we2
for WE_I in a b c d e f; do _ST_PZ_C "$WE_I" "line $WE_I" "WE2 $WE_I"; done
WE_O3=$(git rev-parse --short HEAD~3) WE_O4=$(git rev-parse --short HEAD~2)
_ST_RUN -M --text "WE2 b reworded" HEAD~4
print peer > p.txt
_ST_RUN --commit --text "WE2 peer" --after=HEAD~3 -- p.txt
_ST_EQ "the peer's commit sits between the stale ends' current identities" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:WE2 f|WE2 e|WE2 d|WE2 peer|WE2 c|WE2 b reworded|WE2 a|"
_ST_RUN --move="$WE_O3..$WE_O4" --after=HEAD
_ST_EQ "a --move run with both ends stale moves those commits alone" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:WE2 d|WE2 c|WE2 f|WE2 e|WE2 peer|WE2 b reworded|WE2 a|"
_ST_RUN --move="$(git rev-parse HEAD~4)..$(git rev-parse HEAD~2)" --after="$(git rev-parse HEAD)"
_ST_EQ "while a live run moves every commit between its ends" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:WE2 f|WE2 e|WE2 peer|WE2 d|WE2 c|WE2 b reworded|WE2 a|"
# A `--tree` given as a `:/<text>` search reads a bracketed name as the tree holds it – that path
# alone, never `app/i.tsx` beside it
_ST_PZ_NEW we3
mkdir app && print 1 > 'app/[id].tsx' && print 1 > app/i.tsx && git add app && git commit -qm "WE3 app"
_ST_PZ_C t.txt t "WE3 tip"
WE_T=$(git rev-parse HEAD)
print other >> app/i.tsx && git add -A
WE_TC=$(git commit-tree "$(git write-tree)" -p HEAD -m "WE3 composed i")
git reset -q --hard && git update-ref refs/keep/we3-i "$WE_TC"
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --tree=':/WE3 composed i' -- 'app/[id].tsx'
_ST_EQ "a :/ tree changing only app/i.tsx folds nothing under app/[id].tsx" "${RC}:$(git rev-parse HEAD)" "1:$WE_T"
_ST_OUT_HAS "naming that path literal" 'differs from HEAD in nothing under :(literal)app/\[id\]\.tsx'
print mine >> 'app/[id].tsx' && print other >> app/i.tsx && git add -A
WE_TC=$(git commit-tree "$(git write-tree)" -p HEAD -m "WE3 composed both")
git reset -q --hard && git update-ref refs/keep/we3-both "$WE_TC"
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --tree=':/WE3 composed both' -- 'app/[id].tsx'
_ST_EQ "while one changing both folds the bracketed path alone" "${RC}:$(git show HEAD~1:'app/[id].tsx' | tail -1):$(git show HEAD~1:app/i.tsx)" "0:mine:1"
# A `-C` lock is never missing while its holder runs – a run that read it stale and acts late, after
# another took it, leaves it in place, so a third finds it held
_ST_PZ_NEW we4
_ST_PZ_C a.txt a "WE4 a"
git worktree add -q --detach "$TMP/we4-wt" HEAD
WE_GD=$(git -C "$TMP/we4-wt" rev-parse --absolute-git-dir)
functions _HOLD_RUN_WORKTREE _RUN_WORKTREE_UNLOCK _LOCK_STALE _LOCK_BREAK _LOCK_MARK_SET _PID_START > "$TMP/we4-fns.zsh" 2>/dev/null
mkdir -p "$TMP/we4-g"
# Each claimant its own process, as runs are – `r2` held at its stale check and its link by gates
print -r -- '
FN=$1 WORKTREE_DIR=$2 NAME=$3 G=$4
PRINT_ERR () { : }
_WE_UNTIL () { local -i N=0; until [ -e "$1" ] || (( ++N > 300 )); do sleep 0.05; done; }
if [ "$NAME" = r2 ]; then
	kill () { : > "$G/r2-at-kill"; _WE_UNTIL "$G/r1-holds"; builtin kill "$@"; }
	ln () { : > "$G/r2-at-ln"; _WE_UNTIL "$G/r3-done"; command ln "$@"; }
fi
_RUN_LOCK_HELD=""
source "$FN"
_HOLD_RUN_WORKTREE
print -r -- held > "$G/$NAME"
if [ "$NAME" = r1 ]; then
	: > "$G/r1-holds"
	_WE_UNTIL "$G/end"
	_RUN_WORKTREE_UNLOCK
fi' > "$TMP/we4-claim.zsh"
sh -c 'exit 0' & WE_DEAD=$!
wait $WE_DEAD
print -r -- "$WE_DEAD" > "$WE_GD/git-edit-run.lock"
zsh "$TMP/we4-claim.zsh" "$TMP/we4-fns.zsh" "$TMP/we4-wt" r2 "$TMP/we4-g" 2>/dev/null & WE_PIDS+=($!)
WE_I=0; until [ -e "$TMP/we4-g/r2-at-kill" ] || (( ++WE_I > 300 )); do sleep 0.05; done
zsh "$TMP/we4-claim.zsh" "$TMP/we4-fns.zsh" "$TMP/we4-wt" r1 "$TMP/we4-g" 2>/dev/null & WE_PIDS+=($!)
WE_I=0; until [ -e "$TMP/we4-g/r2-at-ln" ] || (( ++WE_I > 300 )); do sleep 0.05; done
zsh "$TMP/we4-claim.zsh" "$TMP/we4-fns.zsh" "$TMP/we4-wt" r3 "$TMP/we4-g" 2>/dev/null
: > "$TMP/we4-g/r3-done"
WE_I=0; until [ -e "$TMP/we4-g/r2" ] || ! kill -0 "${WE_PIDS[1]}" 2>/dev/null || (( ++WE_I > 300 )); do sleep 0.05; done
: > "$TMP/we4-g/end"
for WE_I in "${WE_PIDS[@]}"; do wait "$WE_I"; done
_ST_EQ "a run breaking a stale -C lock late leaves the one another took held by it alone" "$(cd "$TMP/we4-g" && print -r -- r*(N.) | tr ' ' '\n' | grep -vx 'r[0-9]-.*' | tr '\n' ' ')" "r1 "
_ST_EQ "and lets go of it at its end" "$([ -e "$WE_GD/git-edit-run.lock" ] || echo released):$([ -e "$WE_GD/git-edit-run.lock.break" ] || echo clean)" "released:clean"
git worktree remove --force "$TMP/we4-wt"
# A stale lock that cannot be linked to break it refuses naming that file, never as in use for good
for WE_I in 1 2 3; do _ST_PZ_C "f$WE_I.txt" "$WE_I" "WE4 c$WE_I"; done
_ST_RUN -d -y HEAD~1 -C --no-verify
WE_GD=$(git -C "$(git rev-parse --show-toplevel).git-edit" rev-parse --absolute-git-dir 2>/dev/null)
mkdir -p "$TMP/we4-bin" && print -l '#!/bin/sh' 'exit 1' > "$TMP/we4-bin/ln" && chmod +x "$TMP/we4-bin/ln"
sh -c 'exit 0' & WE_DEAD=$!
wait $WE_DEAD
print -r -- "$WE_DEAD" > "$WE_GD/git-edit-run.lock"
WE_T=$(git rev-parse HEAD)
PATH="$TMP/we4-bin:$PATH" _ST_RUN -d -y HEAD~1 -C --no-verify
_ST_EQ "a stale lock no link can break refuses" "${RC}:$(git rev-parse HEAD)" "1:$WE_T"
_ST_OUT_HAS "naming the lock file and its holder gone" "lock .*git-edit-run\.lock names a holder (pid $WE_DEAD) that is gone"
_ST_OUT_LACKS "never as in use" 'is in use by another run'
WE_H=${(M)${(f)OUT}:#*Deleting that file is safe once no run is live*}
WE_H="rm -f -- ${${WE_H#*: rm -f -- }%%, then run this again*}"
_ST_CHECK "the deletion it names runs" sh -c "$WE_H"
_ST_RUN -d -y HEAD~1 -C --no-verify
_ST_EQ "after which the run lands" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:WE4 c3|WE4 a|"
# A file another caller added executable is taken back by a whole file without the bit – as a flip
# is, `--allow-mode-change` for another file's flip or not – while one added plain takes a bit
_ST_PZ_NEW we5
print x > other.sh && chmod +x other.sh && git add other.sh && git commit -qm "WE5 other" && git commit -q --allow-empty -m "WE5 two"
print -l l{01..06} > "$TMP/we5-src" && print -l p1 p2 > "$TMP/we5-plain"
OUT=$(GIT_EDIT_ACTOR=we-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "WE5 peer adds" --put run.sh="$TMP/we5-src" --chmod run.sh=+x --put plain.txt="$TMP/we5-plain" </dev/null 2>&1)
WE_T=$(git rev-parse HEAD)
git show HEAD:run.sh | sed 's/^l03$/THREE/' > run.sh && chmod -x run.sh other.sh
git show HEAD:plain.txt > plain.txt && print p3 >> plain.txt && chmod +x plain.txt
OUT=$(GIT_EDIT_ACTOR=we-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "WE5 self" --allow-mode-change -- run.sh other.sh plain.txt </dev/null 2>&1)
RC=$?
_ST_EQ "a file added executable, taken without the bit, refuses" "${RC}:$(git rev-parse HEAD)" "1:$WE_T"
_ST_OUT_HAS "naming the addition" 'run.sh – we-peer.*which added it executable'
_ST_OUT_HAS "and the chmod taking the bit" 'chmod -- +x run.sh'
chmod +x run.sh
OUT=$(GIT_EDIT_ACTOR=we-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "WE5 self" --allow-mode-change -- run.sh other.sh plain.txt </dev/null 2>&1)
RC=$?
_ST_EQ "while it lands with the bit, beside flips of its own" "${RC}:$(git ls-tree HEAD other.sh plain.txt run.sh | cut -c1-6 | tr '\n' ' ')" "0:100644 100755 100755 "
# A staged fold taking back a landed bit names setting it on the staging – staging again wouldn't
_ST_PZ_NEW we6
print -l l{01..06} > run.sh && git add -A && git commit -qm "WE6 init"
OUT=$(GIT_EDIT_ACTOR=we-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "WE6 peer chmod" --chmod run.sh=+x </dev/null 2>&1)
# The target past the landing, which a fold below it would apply again
git commit -q --allow-empty -m "WE6 two" && WE_T=$(git rev-parse HEAD)
print -l l01 l02 THREE l04 l05 l06 > run.sh && chmod -x run.sh && git add run.sh
OUT=$(GIT_EDIT_ACTOR=we-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --amend-into="$WE_T" --allow-mode-change -- run.sh </dev/null 2>&1)
RC=$?
_ST_EQ "a staged fold without a landed bit refuses" "${RC}:$(git rev-parse HEAD)" "1:$WE_T"
WE_H=${(M)${(f)OUT}:#*keeping what you staged, with: *}
WE_H=${${WE_H#*keeping what you staged, with: }%% – then run this again*}
_ST_EQ "naming the bit set on the staging" "$WE_H" "git update-index --chmod=+x -- run.sh"
_ST_OUT_LACKS "never an unstaging the next git add undoes" 'git restore --staged'
_ST_CHECK "which runs" sh -c "${WE_H:-false}"
_ST_EQ "keeping what was staged" "$(git ls-files -s run.sh | cut -c1-6):$(git show :run.sh | sed -n 3p)" "100755:THREE"
OUT=$(GIT_EDIT_ACTOR=we-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --amend-into="$WE_T" --allow-mode-change -- run.sh </dev/null 2>&1)
RC=$?
_ST_OUT_LACKS "so the fold no longer takes the bit back" 'would take back'
_ST_RUN --abort
git reset -q --hard
# Over 10 files, the bit's hint reads them from a file it names, and runs
_ST_PZ_NEW we7
for WE_I in {01..12}; do print -l a b > "s$WE_I.sh"; done
git add -A && git commit -qm "WE7 init" && git commit -q --allow-empty -m "WE7 two"
WE_ARGS=()
for WE_I in {01..12}; do WE_ARGS+=(--chmod "s$WE_I.sh=+x"); done
OUT=$(GIT_EDIT_ACTOR=we-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "WE7 peer chmod" "${WE_ARGS[@]}" </dev/null 2>&1)
for WE_I in {01..12}; do print c >> "s$WE_I.sh"; done
chmod -x s*.sh
OUT=$(GIT_EDIT_ACTOR=we-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "WE7 self" --allow-mode-change -- s*.sh </dev/null 2>&1)
RC=$?
WE_H=${(M)${(f)OUT}:#*Take the bit that landed with: *}
WE_H=${WE_H#*Take the bit that landed with: }
_ST_EQ "a bit taken back over 12 files refuses, its chmod fed from a file" "${RC}:${WE_H%%< *}" "1:xargs -0 chmod -- +x "
_ST_CHECK "which runs" sh -c "${WE_H:-false}"
_ST_EQ "setting each bit" "$(ls -l s*.sh | grep -c '^-rwx')" "12"
# Where case tells no names apart, a clash with a tip directory names its files, and a `--rm` of
# that directory says it is one
_ST_PZ_NEW we8
git config core.ignorecase true
mkdir Docs && print a > Docs/a.md && print b > Docs/b.md && print r > readme.md && git add -A && git commit -qm "WE8 base"
WE_T=$(git rev-parse HEAD)
mv Docs we8-t && mv we8-t docs
_ST_RUN --commit --text "WE8 lower" -- docs/a.md docs/b.md
_ST_EQ "a file under a new spelling of a tip directory refuses" "${RC}:$(git rev-parse HEAD)" "1:$WE_T"
_ST_OUT_HAS "naming the removal of each file under it" "differs from the tip's directory Docs only in case – .* removing each file under Docs/ by its tip spelling"
cp docs/a.md "$TMP/we8-a" && cp docs/b.md "$TMP/we8-b"
_ST_RUN --commit --text "WE8 lower" --rm Docs --put docs/a.md="$TMP/we8-a" --put docs/b.md="$TMP/we8-b"
_ST_OUT_HAS "a --rm of the directory says it is one" '--rm Docs: a directory at the tip – name its files'
_ST_RUN --commit --text "WE8 lower" --rm Docs/a.md --rm Docs/b.md --put docs/a.md="$TMP/we8-a" --put docs/b.md="$TMP/we8-b"
_ST_EQ "while removing each file renames it" "${RC}:$(git ls-tree -r --name-only HEAD | tr '\n' ' ')" "0:docs/a.md docs/b.md readme.md "
# And a `--tree` spelling a tip name another way refuses, a `--commit` and a fold alike, unless it
# removes the tip's spelling
WE_T=$(git rev-parse HEAD)
rm -f "$TMP/compose-index" && GIT_INDEX_FILE=$TMP/compose-index git read-tree HEAD
GIT_INDEX_FILE=$TMP/compose-index git update-index --add --cacheinfo "100644,$(git rev-parse HEAD:readme.md),README.md"
WE_TC=$(git commit-tree "$(GIT_INDEX_FILE=$TMP/compose-index git write-tree)" -p HEAD -m "WE8 both")
_ST_RUN --commit --text "WE8 tree" --tree="$WE_TC"
_ST_EQ "a --commit --tree adding a tip name in another case refuses" "${RC}:$(git rev-parse HEAD)" "1:$WE_T"
_ST_OUT_HAS "naming the tip's spelling" "README.md differs from the tip's readme.md only in case"
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --tree="$WE_TC"
_ST_EQ "as does an --amend-into --tree" "${RC}:$(git rev-parse HEAD)" "1:$WE_T"
_ST_OUT_HAS "named alike" "README.md differs from the tip's readme.md only in case"
rm -f "$TMP/compose-index" && GIT_INDEX_FILE=$TMP/compose-index git read-tree HEAD
GIT_INDEX_FILE=$TMP/compose-index git update-index --force-remove readme.md
GIT_INDEX_FILE=$TMP/compose-index git update-index --add --cacheinfo "100644,$(git rev-parse HEAD:readme.md),README.md"
WE_TC=$(git commit-tree "$(GIT_INDEX_FILE=$TMP/compose-index git write-tree)" -p HEAD -m "WE8 renamed")
_ST_RUN --commit --text "WE8 tree rename" --tree="$WE_TC"
_ST_EQ "while one renaming it lands" "${RC}:$(git ls-tree --name-only HEAD | grep -i '^readme.md$')" "0:README.md"
git config core.ignorecase false
cd "$TMP/repo"
