# The landing refuses a mode change nothing asked for, wherever it slipped in
_ST_SCENARIO "\e[1;96m[80] the landing refuses a stray mode change, names its commit, and --allow-mode-change --continue applies it\e[0m"
git reset -q --hard
printf '#!/bin/sh\necho lm1\n' > lm.sh && chmod +x lm.sh && git add lm.sh && git commit -qm "LM base"
local LM_BASE=$(git rev-parse HEAD)
printf '#!/bin/sh\necho lm2\n' > lm.sh && git add lm.sh && git commit -qm "LM later"
echo "lm-top" > lm2.txt && git add lm2.txt && git commit -qm "LM top"
local LM_TIP=$(git rev-parse HEAD)
printf '#!/bin/sh\necho lm1-folded\n' > lm.sh && git add lm.sh
_ST_RUN --amend-into="$LM_BASE" -- lm.sh
_ST_EQ "the fold stops" "$RC" "2"
local LM_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
# Resolved and driven past every stop by hand, inside the worktree – no stop guard ran
_ST_REWRITE "$LM_WT" lm.sh $'#!/bin/sh\necho lm1-folded'
local LROUNDS=0
while [ $LROUNDS -lt 4 ]; do
	LROUNDS=$((LROUNDS+1))
	GIT_EDIT_NO_AUTO_OPEN=1 git -C "$LM_WT" -c core.editor=true rebase --continue >/dev/null 2>&1 && break
	_ST_RESOLVE "$LM_WT" lm.sh $'#!/bin/sh\necho lm2-resolved'
done
_ST_RUN --continue
_ST_EQ "the landing refuses" "$RC" "2"
_ST_OUT_HAS "naming the stray" 'mode change 100755 => 100644 lm\.sh'
_ST_OUT_HAS "and the commit that brought it in" 'brought in by [0-9a-f]* LM base'
_ST_OUT_HAS "as a mode pause" '^git-edit: paused – mode change at [0-9a-f]* in .*--allow-mode-change --continue'
_ST_EQ "the branch never moved" "$(git rev-parse HEAD)" "$LM_TIP"
_ST_RUN --status
_ST_OUT_HAS "--status reprints the pause" '^git-edit: paused – mode change at'
_ST_RUN --continue
_ST_EQ "a bare continue re-checks and refuses again" "$RC" "2"
_ST_OUT_HAS "as the same pause" '^git-edit: paused – mode change at'
_ST_RUN --allow-mode-change --continue
_ST_EQ "--allow-mode-change --continue applies it" "$RC" "0"
_ST_OUT_HAS "and the landing names the mode change" 'mode change 100755 => 100644 lm\.sh'
_ST_EQ "the fold landed" "$(git show "$(git rev-parse HEAD~2):lm.sh" | tail -1)" "echo lm1-folded"
_ST_CHECK "state cleared" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"
# Flips an operation asks for pass the landing: a drop's undoing of its commit's own, and one
# authored at an edit pause
git reset -q --hard
printf '#!/bin/sh\necho dm\n' > dm.sh && git add dm.sh && git commit -qm "DM base"
chmod +x dm.sh && git add dm.sh && git commit -qm "DM flip"
local DM_FLIP=$(git rev-parse HEAD)
echo "dm-top" > dm2.txt && git add dm2.txt && git commit -qm "DM top"
_ST_RUN -y -d "$DM_FLIP"
_ST_EQ "dropping the flipping commit lands" "$RC" "0"
_ST_EQ "the tip undoes its flip" "$(git ls-tree HEAD -- dm.sh | cut -d' ' -f1)" "100644"
_ST_RUN "$(git rev-parse HEAD~1)"
_ST_EQ "an edit pauses" "$RC" "2"
local EM_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – edit [0-9a-f]* in \([^;]*\);.*/\1/p' | head -1)
chmod +x "$EM_WT/dm.sh" && git -C "$EM_WT" add dm.sh
_ST_RUN --continue
_ST_EQ "a flip authored at the pause lands unflagged" "$RC" "0"
_ST_OUT_HAS "named by the landing" 'mode change 100644 => 100755 dm\.sh'
_ST_EQ "the tip carries it" "$(git ls-tree HEAD -- dm.sh | cut -d' ' -f1)" "100755"
git reset -q --hard
