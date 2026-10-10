# A reorder lands only the tree it began with, a clean replay included; a rebase failing with
# nothing to resolve refuses with git's words and pauses nothing; a split resolves a stale SHA and
# refuses a file turned directory named on one side; an undo blocked by a peer's run names the
# caller's own way back; a squash names the commit its target became; a reader gone mid-run stops
# nothing – and the summaries, hints and refusals around them name what is so
_ST_SCENARIO "\e[1;96m[166] older modes land what they built, refuse git's own failures and say so\e[0m"
local ZR_A ZR_B ZR_C ZR_X ZR_T ZR_WT ZR_N ZR_PIPE
# Commits <file> holding <line>... as <subject>
_ZR_C () {
	# Args: <file> <subject> <line>...
	print -l -- "${@:3}" > "$1" && git add -- "$1" && git commit -qm "$2"
}
# Answers whether the repo holds no pause and no worktree but its own
_ZR_CLEAN () {
	[ ! -f "$(git rev-parse --git-common-dir)/git-edit-state" ] && [ "$(git worktree list | wc -l | tr -d ' ')" = 1 ]
}

# A revert moved before what it reverts replays clean yet ends elsewhere – refused, by
# --reorder and --move alike, nothing landed and nothing left behind
_ST_PZ_NEW zr1
_ZR_C f.txt "ZR1 base" a b c d e
_ZR_C f.txt "ZR1 A: c to C" a b C d e
_ZR_C f.txt "ZR1 B: revert C, add Z" a b c d e Z
ZR_A=$(git rev-parse HEAD~1) ZR_B=$(git rev-parse HEAD) ZR_T=$(git rev-parse HEAD)
_ST_RUN --reorder "$ZR_B" "$ZR_A"
_ST_EQ "a clean reorder ending on another tree refuses" "$RC" "1"
_ST_OUT_HAS "saying it no longer ends on the tree it began with, naming the file" 'reorder no longer ends on the tree it began with: moving the commits changes the content of f\.txt'
_ST_OUT_HAS "and the way out" 'Keep each commit after the ones it changes back or builds on'
_ST_OUT_LACKS "never calling it a resolution's doing" 'conflict resolutions changed content'
_ST_EQ "landing nothing" "$(git rev-parse HEAD)" "$ZR_T"
_ST_CHECK "leaving no pause or worktree" _ZR_CLEAN
_ST_RUN --move="$ZR_B" --before="$ZR_A"
_ST_EQ "a move doing the same refuses too" "$RC:$(git rev-parse HEAD)" "1:$ZR_T"
_ST_OUT_HAS "naming itself a move" 'The move no longer ends on the tree it began with'
# Its neighbour: commits on files of their own reorder as ever, the tree proven identical
_ZR_C g.txt "ZR1 G" g
_ZR_C h.txt "ZR1 H" h
_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
_ST_EQ "a reorder keeping the tree lands" "$RC:$(git log -2 --format=%s | tr '\n' '|')" "0:ZR1 G|ZR1 H|"
_ST_OUT_HAS "its tree identical" '^Tip tree identical ✓ – new order (oldest-first):'

# A span from the root has no merge base, and its new order is listed all the same
_ST_PZ_NEW zr7
_ZR_C r.txt "ZR7 root" r
_ZR_C a.txt "ZR7 A" a
_ZR_C b.txt "ZR7 B" b
_ST_RUN --move="$(git rev-list --max-parents=0 HEAD)" --after=HEAD
_ST_EQ "a move of the root commit lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:ZR7 root|ZR7 B|ZR7 A|"
_ST_EQ "listing its new order under the summary" "$(print -r -- "$OUT" | grep -A3 'new order (oldest-first):' | grep -c '^  [0-9a-f]\{7,\} ZR7 ')" "3"

# A pre-rebase hook's veto is no conflict – refused with its words by a move, a fold and a
# placed commit, nothing paused, the staging kept
_ST_PZ_NEW zr2
_ZR_C a.txt "ZR2 base" a
_ZR_C b.txt "ZR2 B" b
_ZR_C d.txt "ZR2 C" d
ZR_T=$(git rev-parse HEAD)
print -l '#!/bin/sh' 'echo "zr2 hook: no rebasing here" >&2' 'exit 1' > .git/hooks/pre-rebase
chmod +x .git/hooks/pre-rebase
_ST_RUN --move=HEAD --before=HEAD~1
_ST_EQ "a move whose rebase a hook vetoes refuses" "$RC:$(git rev-parse HEAD)" "1:$ZR_T"
_ST_OUT_HAS "in git's own words" 'git rebase failed without a conflict to resolve: The pre-rebase hook refused to rebase'
_ST_OUT_HAS "the hook's own line too" 'zr2 hook: no rebasing here'
_ST_OUT_HAS "and that nothing paused" 'Nothing was applied and nothing paused – fix what git names, then run the move again'
_ST_OUT_LACKS "never a conflict" 'Conflict while reordering'
_ST_CHECK "leaving no pause or worktree" _ZR_CLEAN
print bb > b.txt && git add b.txt
_ST_RUN --amend-into=HEAD~1
_ST_EQ "a fold the hook vetoes refuses" "$RC:$(git rev-parse HEAD)" "1:$ZR_T"
_ST_OUT_HAS "its staging named untouched" 'fold again – your staged changes are untouched'
_ST_EQ "and still staged" "$(git diff --cached --name-only)" "b.txt"
_ST_CHECK "nothing paused" _ZR_CLEAN
git reset -q && git checkout -q -- b.txt
print n > n.txt
_ST_RUN --commit --text "ZR2 N" --before=HEAD~1 -- n.txt
_ST_EQ "a placed commit the hook vetoes refuses" "$RC:$(git rev-parse HEAD)" "1:$ZR_T"
_ST_OUT_HAS "as the move does" 'git rebase failed without a conflict to resolve'
_ST_CHECK "nothing paused" _ZR_CLEAN
rm -f n.txt .git/hooks/pre-rebase
# A failed signature stops the rebase midway, its state on disk – refused all the same
git config commit.gpgSign true && git config gpg.program false
_ST_RUN --move=HEAD --before=HEAD~1
_ST_EQ "a move whose commit cannot be signed refuses" "$RC:$(git rev-parse HEAD)" "1:$ZR_T"
_ST_OUT_HAS "naming the signature" 'without a conflict to resolve: gpg failed to sign the data'
_ST_CHECK "nothing paused" _ZR_CLEAN
git config --unset commit.gpgSign && git config --unset gpg.program
# Its neighbours: a conflict and a step left empty still pause
_ZR_C f.txt "ZR2 F1" 1
_ZR_C f.txt "ZR2 F2" 2
_ZR_C f.txt "ZR2 F3" 1
_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
_ST_EQ "a step the new order leaves empty still pauses" "$RC" "2"
_ST_OUT_HAS "as a conflict to settle" '^git-edit: conflict – resolve in '
_ST_RUN --abort
_ZR_C f.txt "ZR2 F4" 4
_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
_ST_EQ "a real conflict still pauses" "$RC" "2"
_ST_OUT_HAS "naming the file" 'Conflicted files:'
# A resume whose continue fails with nothing to resolve keeps its pause, in git's words – a stand-in
# fails it, as a hook or signer would
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt 4
mkdir -p "$TMP/zr2-git"
print -l '#!/bin/sh' 'case " $* " in *" rebase --continue "*) echo "error: zr2 stand-in refused the commit" >&2; exit 1 ;; esac' \
	"exec ${(q)commands[git]} \"\$@\"" > "$TMP/zr2-git/git"
chmod +x "$TMP/zr2-git/git"
OUT=$(PATH="$TMP/zr2-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null 2>&1)
RC=$?
_ST_EQ "a resume failing without a conflict refuses" "$RC" "1"
_ST_OUT_HAS "in git's words" 'without a conflict to resolve: zr2 stand-in refused the commit'
_ST_OUT_HAS "naming the retry" 'fix what git names, then git edit --continue, or abort the operation: git edit --abort'
_ST_OUT_LACKS "never as a conflict that continues" 'Conflict continues'
_ST_CHECK "keeping its pause" test -f .git/git-edit-state
_ST_RUN --abort

# A split by pathspec of a SHA a reword staled resolves it, as every other mode does
_ST_PZ_NEW zr3
_ZR_C a.txt "ZR3 base" a
_ZR_C b.txt "ZR3 B" b
print x > x.txt && print y > y.txt && git add -A && git commit -qm "ZR3 X two files"
ZR_X=$(git rev-parse HEAD)
_ST_RUN -M --text "ZR3 B reworded" HEAD~1
_ST_RUN --split="${ZR_X:0:7}" --text "ZR3 x alone" -- x.txt
_ST_EQ "a pathspec split of a stale SHA lands" "$RC:$(git log -3 --format=%s | tr '\n' '|')" "0:ZR3 X two files|ZR3 x alone|ZR3 B reworded|"
_ST_OUT_HAS "resolving it first" "Commit ${ZR_X:0:7} was rewritten – using its current identity"
_ST_OUT_LACKS "never calling it a branch that moved mid-run" 'The branch moved while this run read it'

# A file turned directory, the pathspec naming one side, refuses with both named; naming both
# splits, and a directory turned back to a file splits by its path
_ST_PZ_NEW zr5
_ZR_C a.txt "ZR5 base" a
print old > d && git add d && git commit -qm "ZR5 d as file"
git rm -q d && mkdir d && print x > d/x && print y > y.txt && git add -A && git commit -qm "ZR5 d becomes a dir"
ZR_T=$(git rev-parse HEAD)
_ST_RUN --split=HEAD --text "ZR5 d dir" -- d/x
_ST_EQ "a split taking a directory's file without the file it replaces refuses" "$RC:$(git rev-parse HEAD)" "1:$ZR_T"
_ST_OUT_HAS "naming the side left out" 'turns a file into a directory at one path, and the pathspec takes d/x but leaves out d'
_ST_OUT_HAS "and the split naming both" "git edit --split=${ZR_T:0:7} --text <msg> -- d/x d"
_ST_OUT_LACKS "never git's raw error" 'appears as both a file and as a directory'
_ST_RUN --split=HEAD --text "ZR5 d dir" -- d/x d
_ST_EQ "naming both sides splits" "$RC:$(git log -2 --format=%s | tr '\n' '|')" "0:ZR5 d becomes a dir|ZR5 d dir|"
git rm -rq d && print f > d && print z > z.txt && git add -A && git commit -qm "ZR5 d back to a file"
_ST_RUN --split=HEAD --text "ZR5 d file" -- d
_ST_EQ "a directory turned file splits by its path" "$RC:$(git show --name-only --format= HEAD~1 | LC_ALL=C sort | tr '\n' ' ')" "0:d d/x "

# An undo blocked by a peer's run on another branch names the caller's own way back where
# its branch still stands on its run, and the rewrite where it moved on
_ST_PZ_NEW zr4
_ZR_C a.txt "ZR4 base" a
_ZR_C b.txt "ZR4 B" b
git branch zr4-feat
_ZR_C d.txt "ZR4 C" d
ZR_T=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=zr4a _ST_RUN -M --text "ZR4 B by a" HEAD~1
ZR_A=$(git rev-parse HEAD)
git checkout -q zr4-feat
_ZR_C f.txt "ZR4 F" f
GIT_EDIT_ACTOR=zr4b _ST_RUN -M --text "ZR4 F by b" HEAD
git checkout -q main
GIT_EDIT_ACTOR=zr4a _ST_RUN --undo
_ST_EQ "an undo blocked by a peer's run refuses" "$RC:$(git rev-parse HEAD)" "1:$ZR_A"
_ST_OUT_HAS "naming the caller's own run" 'Your own last run (reword .*) is still where main stands'
_ST_OUT_HAS "and the command taking it back, writing the undo's reflog message" "^    git update-ref -m 'git edit: undo reword .* \[zr4a\]' refs/heads/main $ZR_T $ZR_A\$"
_ST_OUT_LACKS "never a branch having moved on" 'having moved on'
GIT_EDIT_ACTOR=zr4c _ST_RUN --undo
_ST_OUT_HAS "a caller with no run on record is told so" 'No run of yours is on record to take back'
_ZR_C z.txt "ZR4 Z" z
GIT_EDIT_ACTOR=zr4a _ST_RUN --undo
_ST_OUT_HAS "and one whose branch moved on since is sent to a rewrite" 'Your own last run (reword .*) no longer moves back by ref, main having moved on since'

# A squash on the rebase path names the commit its target became, not the one it replaced
_ST_PZ_NEW zr6
_ZR_C f.txt "ZR6 base" 1 2 3 4 5 6 7 8 9
_ZR_C f.txt "ZR6 A" 1 2a 3 4 5 6 7 8 9
_ZR_C g.txt "ZR6 B" g
_ZR_C f.txt "ZR6 C" 1 2a 3 4 5 6 7 8c 9
_ZR_C h.txt "ZR6 D" h
ZR_T=$(git rev-parse HEAD) ZR_A=$(git rev-parse HEAD~3) ZR_C=$(git rev-parse HEAD~1)
_ST_RUN -s="$ZR_C" "$ZR_A" --text "ZR6 A+C"
_ST_EQ "a squash into a newer target lands" "$RC" "0"
_ST_EQ "its target's place taken by the fold" "$(git log -1 --format=%s HEAD~1)" "ZR6 A+C"
_ST_OUT_HAS "naming the commit its target became" "squashed into: $(git rev-parse --short HEAD~1) ZR6 A+C\$"
git update-ref refs/heads/main "$ZR_T" && git reset -q --hard
_ST_RUN -s "$ZR_A" "$ZR_C"
_ST_OUT_HAS "and one into the older" "squashed into: $(git rev-parse --short HEAD~2) ZR6 A\$"

# A dumped record whose message holds a `--- ` line names the way that keeps the batch
_ST_PZ_NEW zr8
_ZR_C a.txt "ZR8 base" a
_ZR_C b.txt "ZR8 B" b
git commit -q --allow-empty -m "ZR8 C" -m "--- a/foo"
_ZR_C d.txt "ZR8 D" d
_ST_RUN_IN "$(git log --format='--- %h%n%B' HEAD~3..HEAD | sed 's/^ZR8 B$/ZR8 B reworded/')" -M --text -
_ST_EQ "a batch holding such a record refuses" "$RC" "1"
_ST_OUT_HAS "sending it to leave that record out" 'leave its record out of the batch where it keeps its message, or reword it on its own: git edit -M '
_ST_RUN_IN "$(git log -1 --format='--- %h%n%B' HEAD~2 | sed 's/^ZR8 B$/ZR8 B reworded/')" -M --text -
_ST_EQ "and one leaving it out rewords" "$RC:$(git log -3 --format=%s | tr '\n' '|')" "0:ZR8 D|ZR8 C|ZR8 B reworded|"

# A branch on a split commit is offered the remainder as what the rewrite made of it, one on
# a commit above as the same change
_ST_PZ_NEW zr9
_ZR_C a.txt "ZR9 base" a
mkdir -p src && print i > src/i.svg && print j > j.js && git add -A && git commit -qm "ZR9 mixed"
git branch zr9-on-split
git branch zr9-live && git worktree add -q "$TMP/zr9-live" zr9-live
_ZR_C b.txt "ZR9 above" b
git branch zr9-above
_ZR_C c.txt "ZR9 top" c
_ST_RUN --split=HEAD~2 --text "ZR9 icons" -- src/
_ST_EQ "the split lands" "$RC" "0"
_ST_OUT_HAS "a branch on the split commit is offered what the rewrite made of it" 'Branch zr9-on-split points into the rewritten span – if it should follow the rewrite, to its counterpart, what the rewrite made of it: ZR9 mixed'
_ST_OUT_HAS "one above it the same change" 'Branch zr9-above points into the rewritten span – if it should follow the rewrite, to its counterpart, the same change: ZR9 above'
_ST_OUT_HAS "and one checked out in a worktree the same way" "its counterpart here is $(git rev-parse --short=12 HEAD~2) – what the rewrite made of it: ZR9 mixed\$"
git worktree remove --force "$TMP/zr9-live"

# A reader gone, as `| head` leaves, stops nothing – the run lands or refuses as it would
_ST_PZ_NEW zr11
_ZR_C a.txt "ZR11 base" a
_ZR_C b.txt "ZR11 B" b
_ZR_C c.txt "ZR11 C" c
ZR_T=$(git rev-parse HEAD)
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text "ZR11 B piped" HEAD~1 </dev/null 2>&1 | head -1 >/dev/null
ZR_PIPE=${pipestatus[1]}
_ST_EQ "a run piped into head lands" "$ZR_PIPE:$(git log -1 --format=%s HEAD~1)" "0:ZR11 B piped"
_ST_CHECK "and cleans up" _ZR_CLEAN
_ST_RUN --status
_ST_OUT_HAS "its landing journaled" 'Last completed: reword '
_ZR_C f.txt "ZR11 F1" a b c d e
_ZR_C f.txt "ZR11 F2" a b C d e
_ZR_C f.txt "ZR11 F3" a b c d e Z
ZR_T=$(git rev-parse HEAD)
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --reorder HEAD HEAD~1 </dev/null 2>&1 | head -1 >/dev/null
ZR_PIPE=${pipestatus[1]}
_ST_EQ "one refusing refuses" "$ZR_PIPE:$(git rev-parse HEAD)" "1:$ZR_T"
_ST_CHECK "and cleans up too" _ZR_CLEAN
cd "$TMP/repo"
