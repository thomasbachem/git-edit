# A GUI quitting mid-run closes the pipe it read from, and the run's next line raised a SIGPIPE
# nothing trapped – zsh died without its exit trap, the worktree still registered
_ST_SCENARIO "\e[1;96m[99] a reader gone mid-run stops it before the branch moves, never after\e[0m"
local RG
for RG in base one two; do
	echo "$RG" > "rg_$RG.txt" && git add "rg_$RG.txt" && git commit -qm "RG $RG"
done
local RG_REF=$(git symbolic-ref HEAD) RG_HOOKS=$(git rev-parse --path-format=absolute --git-path hooks)
local RG_WORKTREES=$(git worktree list | wc -l | tr -d ' ')
local RG_TIP=$(git rev-parse HEAD) RG_LINE
git config edit.verifyCmd "'$TMP/st-hold' '$TMP/rg-release'"
# The reader leaves as the check starts, so the run's next line finds nobody – released only once
# the reading end is closed
local RG_PID RG_FD
rm -f "$TMP/rg-fifo" "$TMP/rg-release" && mkfifo "$TMP/rg-fifo"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --move="$(git rev-parse ':/RG two')" --after="$(git rev-parse ':/RG base')" </dev/null >"$TMP/rg-fifo" 2>&1 &
RG_PID=$!
exec {RG_FD}<"$TMP/rg-fifo"
while IFS= read -r -u $RG_FD RG_LINE; do
	[[ $RG_LINE == *'# verify'* ]] && break
done
exec {RG_FD}<&-
: > "$TMP/rg-release"
wait $RG_PID
RC=$?
git config --unset edit.verifyCmd
_ST_EQ "a reader gone mid-check stops the run" "$RC" "141"
_ST_EQ "moving nothing" "$(git rev-parse HEAD)" "$RG_TIP"
_ST_EQ "and removing its worktree" "$(git worktree list | wc -l | tr -d ' ')" "$RG_WORKTREES"
_ST_RUN --status
_ST_OUT_HAS "with nothing left in flight" 'no operation in flight'
# Once the branch moves the run finishes unheard – the hook holds the move open until the
# reader, leaving at the `update-ref` line, is gone
print -r -- "#!/bin/sh
[ \"\$1\" = committed ] || exit 0
while read -r old new ref; do [ \"\$ref\" = $RG_REF ] && '$TMP/st-hold' '$TMP/rg-release'; done
exit 0" > "$RG_HOOKS/reference-transaction"
chmod +x "$RG_HOOKS/reference-transaction"
rm -f "$TMP/rg-fifo" "$TMP/rg-release" && mkfifo "$TMP/rg-fifo"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --exec -- sh -c 'echo changed > rg_one.txt && git commit -qam "RG changed"' </dev/null >"$TMP/rg-fifo" 2>&1 &
RG_PID=$!
exec {RG_FD}<"$TMP/rg-fifo"
while IFS= read -r -u $RG_FD RG_LINE; do
	[[ $RG_LINE == *'git update-ref'* ]] && break
done
exec {RG_FD}<&-
: > "$TMP/rg-release"
wait $RG_PID
RC=$?
rm -f "$RG_HOOKS/reference-transaction"
_ST_EQ "a reader gone once the branch moves lets the run finish" "$RC" "0"
_ST_CHECK "moving the branch" test "$(git rev-parse HEAD)" != "$RG_TIP"
_ST_EQ "with the index re-synced to the new tip" "$(git diff --cached --name-only)" ""
_ST_EQ "and no worktree" "$(git worktree list | wc -l | tr -d ' ')" "$RG_WORKTREES"
_ST_RUN --status
_ST_OUT_HAS "and its journal entry written for --undo" "Last completed: exec (${RG_TIP:0:7} → "
git checkout -q -- rg_one.txt
