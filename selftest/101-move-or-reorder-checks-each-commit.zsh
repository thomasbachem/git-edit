# A move named the gate no commit of its own, so its tip alone ran – a commit carried below
# a file its new check needs landed green, the tip still holding that file
_ST_SCENARIO "\e[1;96m[101] a move or reorder checks each commit it puts below one that came before it\e[0m"
local MV
for MV in base filler dep one needs; do
	echo "$MV" > "mv_$MV.txt" && git add "mv_$MV.txt" && git commit -qm "MV $MV"
done
local MV_TIP=$(git rev-parse HEAD) MV_BASE=$(git rev-parse ':/MV base')
# Fails wherever the check a commit adds runs without the file it needs
git config edit.verifyCmd "sh -c '[ ! -f mv_needs.txt ] || [ -f mv_dep.txt ]'"
# The first commit it moves passes, the second is the one carried below what it needs
_ST_RUN --move="$(git rev-parse ':/MV one')" --move="$(git rev-parse ':/MV needs')" --after="$MV_BASE"
_ST_EQ "a move carrying a commit below what it needs pauses" "$RC" "2"
_ST_OUT_HAS "at that commit, not the first one it moved" '^  failing: [0-9a-f]* MV needs$'
_ST_EQ "applying nothing" "$(git rev-parse HEAD)" "$MV_TIP"
# A resume compares the same two orders, so it checks the same commits
_ST_RUN --continue
_ST_EQ "a resume stops there again" "$RC" "2"
_ST_OUT_HAS "at the same commit" '^  failing: [0-9a-f]* MV needs$'
_ST_RUN --abort
# Moved up past what needs it, a commit leaves the first one rebuilt short – set up by a move
# that passes, then undone by the one under test
_ST_RUN --move="$(git rev-parse ':/MV one')" --after="$(git rev-parse ':/MV needs')"
_ST_EQ "a move that breaks nothing lands" "$RC" "0"
MV_TIP=$(git rev-parse HEAD)
_ST_RUN --move="$(git rev-parse ':/MV dep')" --after="$(git rev-parse ':/MV one')"
_ST_EQ "a move leaving the commit above it short pauses" "$RC" "2"
_ST_OUT_HAS "at the first commit it rebuilt" '^  failing: [0-9a-f]* MV needs$'
_ST_EQ "applying nothing either" "$(git rev-parse HEAD)" "$MV_TIP"
_ST_RUN --abort
# Further up, the commit that needs it passes the first rebuilt one by – and still fails at the
# one the moved commit now sits on, since nothing between them brings back what it carried
_ST_RUN --move="$(git rev-parse ':/MV filler')" --after="$(git rev-parse ':/MV dep')"
_ST_EQ "a move keeping it below what needs it lands" "$RC" "0"
MV_TIP=$(git rev-parse HEAD)
_ST_RUN --move="$(git rev-parse ':/MV dep')" --after="$(git rev-parse ':/MV one')"
_ST_EQ "a move leaving a commit further up short pauses" "$RC" "2"
_ST_OUT_HAS "at the commit the moved one now sits on" '^  failing: [0-9a-f]* MV one$'
_ST_OUT_HAS "naming the moved commit as what it lacks" '^  first green: [0-9a-f]* MV dep$'
_ST_EQ "applying nothing there either" "$(git rev-parse HEAD)" "$MV_TIP"
_ST_RUN --continue
_ST_OUT_HAS "and a resume stops there again" '^  failing: [0-9a-f]* MV one$'
_ST_RUN --abort
# A plain reorder names no moved commit and stops there all the same
_ST_RUN --reorder "$(git rev-parse ':/MV filler')" "$(git rev-parse ':/MV needs')" "$(git rev-parse ':/MV one')" "$(git rev-parse ':/MV dep')"
_ST_EQ "a reorder leaving a commit further up short pauses" "$RC" "2"
_ST_OUT_HAS "at the commit below the one it lifted" '^  failing: [0-9a-f]* MV one$'
_ST_EQ "applying nothing with it either" "$(git rev-parse HEAD)" "$MV_TIP"
_ST_RUN --abort
# Moved down, the commit itself sits below one that came before it, so it alone joins the tip
git config edit.verifyCmd "sh -c 'git log -1 --format=%s \"\$GIT_EDIT_VERIFY_COMMIT\" >> \"$TMP/mv-verified\"'"
rm -f "$TMP/mv-verified"
_ST_RUN --move="$(git rev-parse ':/MV one')" --before="$(git rev-parse ':/MV filler')"
_ST_EQ "a move down lands" "$RC" "0"
_ST_EQ "checking the moved commit and the tip alone" "$(tr '\n' ' ' < "$TMP/mv-verified")" "MV one MV needs "
# Commits sharing author, time and subject can't be placed, so each counts as out of order
local MV_TWIN
for MV_TWIN in a b; do
	echo "$MV_TWIN" > "mv_twin_$MV_TWIN.txt" && git add "mv_twin_$MV_TWIN.txt"
	GIT_AUTHOR_DATE='2026-01-01T00:00:00Z' git commit -qm "MV twin"
done
echo last > mv_last.txt && git add mv_last.txt && git commit -qm "MV last"
rm -f "$TMP/mv-verified"
_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~2)" "$(git rev-parse HEAD~1)"
_ST_EQ "a reorder of commits it can't place lands" "$RC" "0"
_ST_EQ "checking each of them" "$(tr '\n' ' ' < "$TMP/mv-verified")" "MV last MV twin MV twin "
git config --unset edit.verifyCmd
