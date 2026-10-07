# Untrapped, the signal ended zsh without its exit trap, so the operation's worktree stayed
# registered while --status reported nothing in flight for --abort to clean up
_ST_SCENARIO "\e[1;96m[93] a TERM mid-check leaves no worktree behind\e[0m"
local VT
for VT in base one two; do
	echo "$VT" > "vt_$VT.txt" && git add "vt_$VT.txt" && git commit -qm "VT $VT"
done
local VT_TIP=$(git rev-parse HEAD)
local VT_WORKTREES=$(git worktree list | wc -l | tr -d ' ')
# The check names its own process, so none outlives the scenario whatever the signal reaches,
# and marks its own end, since a signal to the run alone waits for the check it is running
git config edit.verifyCmd "sh -c 'echo \$\$ > \"$TMP/vt-check\"; \"$TMP/st-hold\" \"$TMP/vt-release\"; echo done > \"$TMP/vt-done\"'"
rm -f "$TMP/vt-check" "$TMP/vt-done" "$TMP/vt-release"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --move="$(git rev-parse ':/VT two')" --after="$(git rev-parse ':/VT base')" </dev/null >"$TMP/vt-out" 2>&1 &
local VT_PID=$!
local -i VT_WAIT=0
until [ -s "$TMP/vt-check" ] || ! kill -0 $VT_PID 2>/dev/null || (( ++VT_WAIT > 1200 )); do
	sleep 0.1
done
kill -TERM $VT_PID
: > "$TMP/vt-release"
wait $VT_PID
RC=$?
kill "$(cat "$TMP/vt-check" 2>/dev/null)" 2>/dev/null
OUT=$(<"$TMP/vt-out")
_ST_EQ "the run exits as terminated" "$RC" "143"
_ST_CHECK "once the check it was running ended on its own" test -s "$TMP/vt-done"
_ST_OUT_HAS "naming the signal in its trailer" '^git-edit: error – stopped by SIGTERM$'
_ST_EQ "moving nothing" "$(git rev-parse HEAD)" "$VT_TIP"
_ST_EQ "and removing its worktree" "$(git worktree list | wc -l | tr -d ' ')" "$VT_WORKTREES"
_ST_RUN --status
_ST_OUT_HAS "with nothing left in flight" 'no operation in flight'
git config --unset edit.verifyCmd
