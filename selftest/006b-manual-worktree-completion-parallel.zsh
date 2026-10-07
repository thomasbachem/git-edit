# Conflict resolved manually in the worktree, staged WIP survives
_ST_SCENARIO "\e[1;96m[6b] manual worktree completion + parallel staged WIP\e[0m"
PRE_HEAD=$(git rev-parse HEAD)
local SHA_C3=$(git rev-parse HEAD~2)
echo "line1-again" > c.txt
git add c.txt
_ST_RUN --amend-into="$SHA_C3"
_ST_EQ "pauses with exit 2" "$RC" "2"
# A parallel session stages an unrelated file mid-pause
echo "parallel" > w.txt
git add w.txt
# The agent resolves and drives the rebase manually inside the worktree
local MANUAL_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
_ST_RESOLVE "$MANUAL_WT" c.txt "line1-again"
local MROUNDS=0
while [ $MROUNDS -lt 4 ]; do
	MROUNDS=$((MROUNDS+1))
	GIT_EDIT_NO_AUTO_OPEN=1 git -C "$MANUAL_WT" -c core.editor=true rebase --continue >/dev/null 2>&1 && break
	_ST_RESOLVE "$MANUAL_WT" c.txt "line2"
done
_ST_RUN --continue
_ST_EQ "continue applies the manual result" "$RC" "0"
_ST_OUT_HAS "notes manual completion" 'already completed'
_ST_CHECK "HEAD moved" test "$(git rev-parse HEAD)" != "$PRE_HEAD"
_ST_CHECK "parallel staged WIP survived" sh -c "git diff --cached --name-only | grep -q w.txt"
_ST_CHECK "folded path reports clean" sh -c "! git diff --cached --name-only | grep -q c.txt"
git reset -q -- w.txt && rm -f w.txt
