# A staged resolution with conflict markers must not continue
_ST_SCENARIO "\e[1;96m[34] conflict-marker guard\e[0m"
git reset -q --hard
printf 'm1\nm2\nm3\n' > mk.txt && git add mk.txt && git commit -qm "MK base"
printf 'm1\nMT\nm3\n' > mk.txt && git add mk.txt && git commit -qm "MK target"
local MK_TARGET=$(git rev-parse HEAD)
printf 'm1\nML\nm3\n' > mk.txt && git add mk.txt && git commit -qm "MK later"
printf 'm1\nMS\nm3\n' > mk.txt && git add mk.txt
_ST_RUN --amend-into="$MK_TARGET"
_ST_EQ "fold conflicts as set up" "$RC" "2"
local MK_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
_ST_CHECK "worktree file carries markers" sh -c "grep -q '^<<<<<<<' '$MK_WT/mk.txt'"
# The mistake this guards: a failed resolver, then a blanket `git add`
git -C "$MK_WT" add mk.txt
_ST_RUN --continue
_ST_EQ "continue refused (exit 2)" "$RC" "2"
_ST_OUT_HAS "names the marker problem" 'still contains conflict markers'
_ST_CHECK "markers never reached history" sh -c "! git log -p --all | grep -q '^+<<<<<<< '"
# Past the pipe buffer too, where a piped read lost its writer at the first marker
print -r -- "${(l:1000000::x:)}" >> "${MK_WT:-$ST_NO_WT}/mk.txt" && git -C "$MK_WT" add mk.txt
_ST_RUN --continue
_ST_EQ "a resolution past the pipe buffer is refused too" "$RC" "2"
_ST_OUT_HAS "naming the same problem" 'still contains conflict markers'
# A marker-free resolution is not blocked
printf 'm1\nMS\nm3\n' > "${MK_WT:-$ST_NO_WT}/mk.txt" && git -C "$MK_WT" add mk.txt
_ST_RUN --continue
_ST_OUT_LACKS "clean resolution passes the guard" 'still contains conflict markers'
_ST_RUN --abort
_ST_CHECK "state cleared afterwards" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"
git reset -q --hard
