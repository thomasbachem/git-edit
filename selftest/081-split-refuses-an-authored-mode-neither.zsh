# A content split's authored tree keeps the commit's modes, or says so
# The descendants are re-parented, never replayed, so the authoring worktree is the one
# place a split can lose a bit – the remainder would then flip it straight back
_ST_SCENARIO "\e[1;96m[81] a split refuses an authored mode neither the commit nor its parent carries\e[0m"
git reset -q --hard
printf '#!/bin/sh\necho a\n' > xs.sh && chmod +x xs.sh && git add xs.sh && git commit -qm "XS base"
printf '#!/bin/sh\necho A\necho b\n' > xs.sh && git add xs.sh && git commit -qm "XS mixed"
local XS_TARGET=$(git rev-parse HEAD)
echo "xs-later" > xs2.txt && git add xs2.txt && git commit -qm "XS later"
local XS_TIP=$(git rev-parse HEAD)
_ST_RUN --split="$XS_TARGET"
_ST_EQ "the split pauses" "$RC" "2"
local XS_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – split [0-9a-f]* in \(.*\); then.*/\1/p')
# The first half authored through a temp file moved into place – the bit goes with it
printf '#!/bin/sh\necho A\n' > "${XS_WT:-$ST_NO_WT}/xs.sh.tmp" && mv "$XS_WT/xs.sh.tmp" "$XS_WT/xs.sh"
_ST_RUN --continue --text "XS extracted"
_ST_EQ "the authored mode is refused" "$RC" "1"
_ST_OUT_HAS "naming the path and the modes around it" 'xs\.sh: authored 100644, [0-9a-f]* carries 100755, its parent 100755'
_ST_OUT_HAS "and the fix" 'chmod it in'
_ST_EQ "the branch never moved" "$(git rev-parse HEAD)" "$XS_TIP"
chmod +x "$XS_WT/xs.sh"
_ST_RUN --continue --text "XS extracted"
_ST_EQ "restored, the split lands" "$RC" "0"
_ST_EQ "both halves carry the bit" "$(git ls-tree HEAD~2 -- xs.sh | cut -d' ' -f1)|$(git ls-tree HEAD~1 -- xs.sh | cut -d' ' -f1)" "100755|100755"
_ST_EQ "the tip tree is the old one" "$(git rev-parse 'HEAD^{tree}')" "$(git rev-parse "$XS_TIP^{tree}")"
# A flip the commit made itself may go to either half – here the remainder's
git reset -q --hard
printf '#!/bin/sh\necho c\n' > xf.sh && git add xf.sh && git commit -qm "XF base"
printf '#!/bin/sh\necho C\necho d\n' > xf.sh && chmod +x xf.sh && git add xf.sh && git commit -qm "XF mixed, flipping"
local XF_TARGET=$(git rev-parse HEAD)
echo "xf-later" > xf2.txt && git add xf2.txt && git commit -qm "XF later"
_ST_RUN --split="$XF_TARGET"
_ST_EQ "the flipping split pauses" "$RC" "2"
local XF_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – split [0-9a-f]* in \(.*\); then.*/\1/p')
printf '#!/bin/sh\necho C\n' > "${XF_WT:-$ST_NO_WT}/xf.sh" && chmod -x "$XF_WT/xf.sh"
_ST_RUN --continue --text "XF extracted"
_ST_EQ "the first half at the parent's mode passes" "$RC" "0"
_ST_EQ "the flip sits in the remainder" "$(git ls-tree HEAD~2 -- xf.sh | cut -d' ' -f1)|$(git ls-tree HEAD~1 -- xf.sh | cut -d' ' -f1)" "100644|100755"
git reset -q --hard
