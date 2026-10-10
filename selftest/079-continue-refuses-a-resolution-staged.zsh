# A stop's resolution keeps the replayed commit's mode – a file written anew loses it
_ST_SCENARIO "\e[1;96m[79] --continue refuses a resolution staged at a mode the replay does not carry\e[0m"
git reset -q --hard
printf '#!/bin/sh\necho sm1\n' > sm.sh && chmod +x sm.sh && git add sm.sh && git commit -qm "SM base"
local SM_BASE=$(git rev-parse HEAD)
printf '#!/bin/sh\necho sm2\n' > sm.sh && git add sm.sh && git commit -qm "SM later"
echo "sm-top" > sm2.txt && git add sm2.txt && git commit -qm "SM top"
local SM_TIP=$(git rev-parse HEAD)
# A fold on the line the later commit edits too – it stops at its fixup, then at that commit
# (a commit on top keeps that stop from being the final step, which resolves itself)
printf '#!/bin/sh\necho sm1-folded\n' > sm.sh && git add sm.sh
_ST_RUN --amend-into="$SM_BASE" -- sm.sh
_ST_EQ "the fold stops" "$RC" "2"
local SM_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
# The resolver writes the file anew through `_ST_REWRITE` – a temp file moved into place, at 644
_ST_REWRITE "$SM_WT" sm.sh $'#!/bin/sh\necho sm1-folded'
_ST_EQ "and staged it without the bit" "$(git -C "$SM_WT" ls-files -s -- sm.sh | cut -d' ' -f1)" "100644"
_ST_RUN --continue
_ST_EQ "the continue refuses" "$RC" "2"
_ST_OUT_HAS "naming the path and both modes" 'sm\.sh: staged 100644, the replay carries 100755'
_ST_OUT_HAS "and the restore, worktree and index both" 'chmod -- +x .*sm\.sh && git -C .* add --chmod=+x -- sm\.sh'
_ST_OUT_HAS "as a conflict pause on the path" '^git-edit: conflict – resolve in .*(sm\.sh)'
_ST_EQ "the branch never moved" "$(git rev-parse HEAD)" "$SM_TIP"
# Restored as told, the replay goes on – to the later commit's own stop, resolved in place
chmod +x "$SM_WT/sm.sh" && git -C "$SM_WT" add -- sm.sh
_ST_RUN --continue
_ST_EQ "restored, the replay reaches the later commit" "$RC" "2"
_ST_OUT_HAS "which stops in turn" 'SM later'
_ST_RESOLVE "$SM_WT" sm.sh $'#!/bin/sh\necho sm2-resolved'
_ST_RUN --continue
_ST_EQ "resolved at the mode it carries, it lands" "$RC" "0"
_ST_OUT_LACKS "with no mode note" 'Mode changes landed'
_ST_EQ "the bit survived the replay" "$(git ls-tree HEAD -- sm.sh | cut -d' ' -f1)" "100755"
_ST_EQ "and so did the resolution" "$(git show HEAD:sm.sh | tail -1)" "echo sm2-resolved"
# The same slip kept on purpose: the flag on the continue lets it through, holds for the stop
# after, and the landing names it
git reset -q --hard
printf '#!/bin/sh\necho sm1-again\n' > sm.sh && git add sm.sh
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" -- sm.sh
_ST_EQ "a second fold stops too" "$RC" "2"
SM_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
_ST_REWRITE "$SM_WT" sm.sh $'#!/bin/sh\necho sm1-again'
_ST_RUN --allow-mode-change --continue
_ST_EQ "--allow-mode-change on the continue keeps it" "$RC" "2"
_ST_OUT_HAS "and the later commit stops as before" 'SM later'
_ST_RESOLVE "$SM_WT" sm.sh $'#!/bin/sh\necho sm2-kept'
_ST_RUN --continue
_ST_EQ "a bare continue lands it" "$RC" "0"
_ST_OUT_HAS "and the landing names the mode change" 'mode change 100755 => 100644 sm\.sh'
_ST_EQ "the tip carries it" "$(git ls-tree HEAD -- sm.sh | cut -d' ' -f1)" "100644"
# What the replay carries is git's own merge of modes: a fold flipping the bit on purpose sets
# the fixup's mode at its stop and the new parent's at the later commit's, so a resolution at
# the commit's original mode is the stray at either
git reset -q --hard
printf '#!/bin/sh\necho fm1\n' > fm.sh && git add fm.sh && git commit -qm "FM base"
local FM_BASE=$(git rev-parse HEAD)
printf '#!/bin/sh\necho fm2\n' > fm.sh && git add fm.sh && git commit -qm "FM later"
echo "fm-top" > fm2.txt && git add fm2.txt && git commit -qm "FM top"
printf '#!/bin/sh\necho fm1-x\n' > fm.sh && chmod +x fm.sh && git add fm.sh
_ST_RUN --amend-into="$FM_BASE" --allow-mode-change -- fm.sh
_ST_EQ "the flipping fold stops" "$RC" "2"
local FM_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
_ST_REWRITE "$FM_WT" fm.sh $'#!/bin/sh\necho fm1-x'
_ST_RUN --continue
_ST_EQ "a resolution at the target's old mode is refused at the fixup" "$RC" "2"
_ST_OUT_HAS "wanting the fold's" 'fm\.sh: staged 100644, the replay carries 100755'
chmod +x "$FM_WT/fm.sh" && git -C "$FM_WT" add -- fm.sh
_ST_RUN --continue
_ST_EQ "restored, the later commit stops" "$RC" "2"
_ST_REWRITE "$FM_WT" fm.sh $'#!/bin/sh\necho fm2-resolved'
_ST_RUN --continue
_ST_EQ "and a resolution at that commit's own old mode is refused there" "$RC" "2"
_ST_OUT_HAS "wanting the new parent's" 'fm\.sh: staged 100644, the replay carries 100755'
chmod +x "$FM_WT/fm.sh" && git -C "$FM_WT" add -- fm.sh
_ST_RUN --continue
_ST_EQ "restored, it lands" "$RC" "0"
_ST_OUT_HAS "the fold's own flip named as landed" 'mode change 100644 => 100755 fm\.sh'
_ST_EQ "the tip carries it" "$(git ls-tree HEAD -- fm.sh | cut -d' ' -f1)" "100755"
# A commit that flipped the mode itself keeps its flip through a resolution
git reset -q --hard
printf '#!/bin/sh\necho cm1\n' > cm.sh && chmod +x cm.sh && git add cm.sh && git commit -qm "CM base"
local CM_BASE=$(git rev-parse HEAD)
printf '#!/bin/sh\necho cm2\n' > cm.sh && chmod -x cm.sh && git add cm.sh && git commit -qm "CM later, unflagged"
echo "cm-top" > cm2.txt && git add cm2.txt && git commit -qm "CM top"
printf '#!/bin/sh\necho cm1-folded\n' > cm.sh && git add cm.sh
_ST_RUN --amend-into="$CM_BASE" -- cm.sh
_ST_EQ "the fold stops" "$RC" "2"
local CM_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
_ST_RESOLVE "$CM_WT" cm.sh $'#!/bin/sh\necho cm1-folded'
_ST_RUN --continue
_ST_EQ "past the fixup, the flipping commit stops" "$RC" "2"
_ST_REWRITE "$CM_WT" cm.sh $'#!/bin/sh\necho cm2-resolved'
_ST_RUN --continue
_ST_EQ "a resolution at that commit's own mode passes" "$RC" "0"
_ST_OUT_LACKS "with no mode note" 'Mode changes landed'
_ST_EQ "the tip keeps the commit's flip" "$(git ls-tree HEAD -- cm.sh | cut -d' ' -f1)" "100644"
# A path with a space rides the NUL-separated reads intact
git reset -q --hard
printf '#!/bin/sh\necho sp1\n' > 'sp ace.sh' && chmod +x 'sp ace.sh' && git add 'sp ace.sh' && git commit -qm "SP base"
local SP_BASE=$(git rev-parse HEAD)
printf '#!/bin/sh\necho sp2\n' > 'sp ace.sh' && git add 'sp ace.sh' && git commit -qm "SP later"
echo "sp-top" > sp2.txt && git add sp2.txt && git commit -qm "SP top"
printf '#!/bin/sh\necho sp1-folded\n' > 'sp ace.sh' && git add 'sp ace.sh'
_ST_RUN --amend-into="$SP_BASE" -- 'sp ace.sh'
_ST_EQ "a fold on a spaced path stops" "$RC" "2"
local SP_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
_ST_REWRITE "$SP_WT" 'sp ace.sh' $'#!/bin/sh\necho sp1-folded'
_ST_RUN --continue
_ST_EQ "the stop guard reads the spaced path" "$RC" "2"
_ST_OUT_HAS "and names it" 'sp ace\.sh: staged 100644, the replay carries 100755'
_ST_RUN --abort
_ST_EQ "and aborts" "$RC" "0"
git reset -q --hard
