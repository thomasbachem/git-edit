# A fold's final conflicted step resolves itself, mid steps pause

# The finished tip is the pre-op tip plus the staged changes, so the final
# step's resolution is provable (staged-tree identity) before anything is
# committed – earlier steps have no such answer and must keep pausing
_ST_SCENARIO "\e[1;96m[55] fold final-step auto-resolve\e[0m"
local R55="$TMP/fold55"
git init -q -b main "$R55"
git -C "$R55" config user.email selftest@git-edit
git -C "$R55" config user.name "git-edit selftest"
cd "$R55"
printf 'g1\n' > g.txt && git add g.txt && git commit -qm "G one"
printf 'g2\n' > g.txt && git commit -qam "G two"
printf 'g3\n' > g.txt && git commit -qam "G three"
printf 'g9\n' > g.txt && git add g.txt
local G_STAGED=$(git write-tree)

# Fold into the root: the fixup conflicts (mid step – must pause)
_ST_RUN --amend-into="$(git rev-parse HEAD~2)"
_ST_EQ "fixup step pauses" "$RC" "2"
local WT55=$(print -r -- "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ (;]*\).*/\1/p' | head -1)
_ST_CHECK "conflict worktree exists" test -d "$WT55"
printf 'g9\n' > "$WT55/g.txt" && git -C "$WT55" add g.txt

# "G two" replays next – still not the final step, so it pauses too
_ST_RUN --continue
_ST_EQ "mid pick still pauses" "$RC" "2"
_ST_OUT_LACKS "and is not auto-resolved" 'auto-resolved'
WT55=$(print -r -- "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ (;]*\).*/\1/p' | head -1)
printf 'g8\n' > "$WT55/g.txt" && git -C "$WT55" add g.txt

# "G three" is the final step – its result is the staged tree, so this
# continue resolves it itself and completes in one go
_ST_RUN --continue
_ST_EQ "final step completes without another pause" "$RC" "0"
_ST_OUT_HAS "names the auto-resolution" 'auto-resolved'
_ST_OUT_HAS "emits ok trailer" '^git-edit: ok'
_ST_EQ "tip content is the staged content" "$(git show HEAD:g.txt)" "g9"
_ST_EQ "tip tree is the staged tree" "$(git rev-parse 'HEAD^{tree}')" "$G_STAGED"
_ST_EQ "no commit was lost" "$(git rev-list --count HEAD)" "3"
_ST_OUT_LACKS "and no drop was counted" 'resolved to empty'
cd "$TMP/repo"
