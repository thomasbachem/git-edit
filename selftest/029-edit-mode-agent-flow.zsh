# Non-interactive edit mode: pause, author, continue
_ST_SCENARIO "\e[1;96m[29] edit mode (agent flow)\e[0m"
# Reconcile the scratch checkout so later commits carry no phantom reverts
git reset -q --hard
printf 'e1\nEDIT-ME\ne2\n' > ed.txt && git add ed.txt && git commit -qm "ED target"
local ED_TARGET=$(git rev-parse HEAD)
echo "ed-later" > ed2.txt && git add ed2.txt && git commit -qm "ED later"
local ED_TIP=$(git rev-parse HEAD)
_ST_RUN "$ED_TARGET"
_ST_EQ "edit pauses (exit 2)" "$RC" "2"
_ST_OUT_HAS "emits a paused trailer" 'git-edit: paused'
_ST_EQ "branch untouched while authoring" "$(git rev-parse HEAD)" "$ED_TIP"
local ED_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – edit [0-9a-f]* in \(.*\); then.*/\1/p')
_ST_CHECK "worktree sits at the target" test "$(git -C "$ED_WT" rev-parse HEAD)" = "$ED_TARGET"
_ST_RUN --status
_ST_OUT_HAS "status names the authoring phase" 'Authoring phase'
_ST_RUN --continue
_ST_EQ "empty continue refused" "$RC" "1"
_ST_OUT_HAS "explains nothing to amend" 'Nothing to amend'
printf 'e1\nEDITED\ne2\n' > "${ED_WT:-$ST_NO_WT}/ed.txt"
# A commit landing on the branch during authoring must be absorbed
echo "mid" > ed-mid.txt && git add ed-mid.txt && git commit -qm "ED mid-pause"
_ST_RUN --continue --text "ED target, edited"
_ST_EQ "continue completes the edit" "$RC" "0"
_ST_OUT_HAS "prints the net history change" 'Net history change'
local ED_NEW=$(git log --format='%H %s' | grep 'ED target, edited' | cut -d' ' -f1)
_ST_CHECK "reword applied" test -n "$ED_NEW"
_ST_EQ "content edited at the target" "$(git show "${ED_NEW}:ed.txt" 2>/dev/null | sed -n 2p)" "EDITED"
_ST_CHECK "mid-pause commit absorbed" sh -c "git log --format=%s | grep -q 'ED mid-pause'"
_ST_CHECK "state cleared" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
# Abort leaves everything untouched
git reset -q --hard
local ED_TIP2=$(git rev-parse HEAD)
_ST_RUN "$(git rev-parse HEAD~1)"
_ST_RUN --abort
_ST_EQ "abort exits 0" "$RC" "0"
_ST_EQ "abort leaves the branch untouched" "$(git rev-parse HEAD)" "$ED_TIP2"
