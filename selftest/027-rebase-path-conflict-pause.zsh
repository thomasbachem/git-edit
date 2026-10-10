# Rebase-path conflicts pause into --continue/--abort
# Dropping a commit whose successor edits the same line conflicts, and the
# isolated rebase must pause like the plumbing modes rather than bail
_ST_SCENARIO "\e[1;96m[27] rebase-path conflict pause\e[0m"
printf 'x\nb\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ base"
printf 'x\nMID\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ mid"
printf 'x\nTIP\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ tip"
local PZ_TIP=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~1
_ST_EQ "conflicting drop pauses (exit 2)" "$RC" "2"
_ST_OUT_HAS "names the action" 'Conflict during drop'
_ST_EQ "branch untouched while paused" "$(git rev-parse HEAD)" "$PZ_TIP"
local PZ_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
printf 'x\nTIP\nz\n' > "${PZ_WT:-$ST_NO_WT}/pz.txt" && git -C "$PZ_WT" add pz.txt
_ST_RUN --continue
_ST_EQ "continue completes the drop" "$RC" "0"
_ST_EQ "dropped commit is gone" "$(git log --format=%s -2 | tr '\n' ' ')" "PZ tip PZ base "
_ST_CHECK "state cleared after continue" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"
printf 'x\nMID2\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ mid2"
printf 'x\nTIP2\nz\n' > pz.txt && git add pz.txt && git commit -qm "PZ tip2"
local PZ_TIP2=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~1
_ST_EQ "second conflicting drop pauses" "$RC" "2"
_ST_RUN --abort
_ST_EQ "abort exits 0" "$RC" "0"
_ST_OUT_HAS "abort reports nothing to roll back" 'never touched'
_ST_EQ "abort leaves the branch untouched" "$(git rev-parse HEAD)" "$PZ_TIP2"
