# Bare, two commits read as a squash – named, the mode refuses a second one and any other mode
_ST_SCENARIO "\e[1;96m[68] -e names the edit mode, refusing what the bare form squashes\e[0m"
cd "$TMP/repo"
git checkout -q main 2>/dev/null
git reset -q --hard
local EE_N
for EE_N in 1 2 3; do
	printf 'ee%s\n' "$EE_N" > "ee$EE_N.txt" && git add "ee$EE_N.txt" && git commit -qm "EE $EE_N"
done
local EE_TIP=$(git rev-parse HEAD)
_ST_RUN -e HEAD~1 HEAD
_ST_EQ "-e with two commits exits 1" "$RC" "1"
_ST_OUT_HAS "rather than squashing them" 'takes exactly one <commit>'
_ST_EQ "and the branch stays put" "$(git rev-parse HEAD)" "$EE_TIP"
_ST_RUN --edit HEAD~2..HEAD
_ST_EQ "a range under --edit is refused alike" "$RC" "1"
_ST_RUN -e -d HEAD~1
_ST_EQ "-e beside another mode exits 1" "$RC" "1"
_ST_OUT_HAS "naming the conflict" 'cannot be combined with another mode'
_ST_RUN -e HEAD~1
_ST_EQ "-e on one commit pauses as the bare form does" "$RC" "2"
_ST_OUT_HAS "into an edit" 'git-edit: paused – edit'
_ST_RUN --abort
_ST_EQ "and aborts clean" "$RC" "0"
_ST_CHECK "leaving no operation in flight" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"
