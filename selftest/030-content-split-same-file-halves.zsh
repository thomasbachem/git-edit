# Content split: pause, author the split point, continue
_ST_SCENARIO "\e[1;96m[30] content split (same-file halves)\e[0m"
git reset -q --hard
printf 'first\nsecond\n' > cs.txt && git add cs.txt && git commit -qm "CS base"
printf 'FIRST\nsecond\nthird\n' > cs.txt && git add cs.txt && git commit -qm "CS mixed commit"
local CS_TARGET=$(git rev-parse HEAD)
echo "cs-later" > cs2.txt && git add cs2.txt && git commit -qm "CS later"
local CS_TIP=$(git rev-parse HEAD)
local CS_TIP_TREE=$(git rev-parse 'HEAD^{tree}')
_ST_RUN --split="$CS_TARGET"
_ST_EQ "pathspec-less split pauses (exit 2)" "$RC" "2"
_ST_OUT_HAS "emits a paused trailer" 'git-edit: paused – split'
_ST_EQ "branch untouched while authoring" "$(git rev-parse HEAD)" "$CS_TIP"
local CS_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – split [0-9a-f]* in \(.*\); then.*/\1/p')
_ST_CHECK "worktree sits at the target" test "$(git -C "$CS_WT" rev-parse HEAD)" = "$CS_TARGET"
_ST_RUN --status
_ST_OUT_HAS "status names the authoring phase" 'Authoring phase'
_ST_OUT_HAS "status reports it as paused, not conflicted" 'git-edit: paused – split'
_ST_RUN --continue
_ST_EQ "continue without a message refused" "$RC" "1"
_ST_OUT_HAS "asks for --text" 'needs a message'
_ST_RUN --continue --text "CS extracted"
_ST_EQ "unedited worktree refused" "$RC" "1"
_ST_OUT_HAS "names the empty remainder" 'remainder commit would be empty'
echo "debris" > "${CS_WT:-$ST_NO_WT}/cs-stray.txt"
_ST_RUN --continue --text "CS extracted"
_ST_EQ "stray path refused" "$RC" "1"
_ST_OUT_HAS "names the stray path" 'cs-stray.txt'
rm -f "$CS_WT/cs-stray.txt"
printf 'first\nsecond\n' > "${CS_WT:-$ST_NO_WT}/cs.txt"
_ST_RUN --continue --text "CS extracted"
_ST_EQ "worktree back at the parent refused" "$RC" "1"
_ST_OUT_HAS "names the empty extraction" 'extracted commit would be empty'
# The real split point: the uppercase half only, third line left for the remainder
printf 'FIRST\nsecond\n' > "${CS_WT:-$ST_NO_WT}/cs.txt"
# A commit landing on the branch during authoring must be absorbed
echo "cs-mid" > cs-mid.txt && git add cs-mid.txt && git commit -qm "CS mid-pause"
# Run the final continue from inside the worktree – its detached `HEAD` must
# not stand in for the branch as the trailer's "before"
local CS_PRE=$(git rev-parse HEAD)
OUT=$(cd "$CS_WT" && GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue --text "CS extracted" </dev/null 2>&1)
RC=$?
_ST_EQ "continue completes the split" "$RC" "0"
_ST_OUT_HAS "states tree identity" 'Tip tree identical'
_ST_OUT_HAS "trailer anchors on the branch, not the worktree HEAD" "moved $CS_PRE"
# The resumed path reaches the same summary as the pathspec one
_ST_EQ "names the commit it split within a 'tail -3'" \
	"$(print -r -- "$OUT" | tail -3 | grep -c 'split: ')" "1"
_ST_CHECK "mid-pause commit absorbed" sh -c "git log --format=%s | grep -q 'CS mid-pause'"
local CS_KEPT=$(git log --format='%H %s' | grep 'CS mixed commit' | cut -d' ' -f1)
_ST_EQ "extracted commit sits below the remainder" "$(git log --format=%s -1 "$CS_KEPT^")" "CS extracted"
_ST_EQ "extracted carries only the first half" "$(git show "$CS_KEPT^:cs.txt")" "$(printf 'FIRST\nsecond')"
_ST_EQ "remainder carries the rest" "$(git show "${CS_KEPT}:cs.txt")" "$(printf 'FIRST\nsecond\nthird')"
_ST_CHECK "descendants rebuilt" git cat-file -e 'HEAD:cs2.txt'
_ST_CHECK "worktree cleaned up" test ! -d "$CS_WT"
_ST_CHECK "state cleared" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
# The tip tree is only unchanged relative to the pre-split tip, so compare
# against the commit that was `HEAD` before the mid-pause commit landed
_ST_EQ "pre-split tip tree preserved" "$(git rev-parse 'HEAD~1^{tree}')" "$CS_TIP_TREE"
