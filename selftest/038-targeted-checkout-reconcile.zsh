# A tree-changing rewrite brings the checkout along per path, never by stashing or a blanket reset
_ST_SCENARIO "\e[1;96m[38] targeted checkout reconcile\e[0m"
git reset -q --hard
echo "tc-keep" > tc-keep.txt && git add tc-keep.txt && git commit -qm "TC base"
echo "tc-drop" > tc-drop.txt && git add tc-drop.txt && git commit -qm "TC to drop"
local TC_DROP=$(git rev-parse HEAD)
echo "tc-later" > tc-later.txt && git add tc-later.txt && git commit -qm "TC later"
echo "local wip" > tc-keep.txt   # unrelated WIP the sync must not disturb
_ST_RUN -d -y "$TC_DROP"
_ST_EQ "drop exits 0" "$RC" "0"
# The dropped content leaves the checkout as it left the history, named with the way back
_ST_CHECK "the dropped file leaves the checkout" sh -c "! test -f tc-drop.txt"
_ST_OUT_HAS "named with the way back" "Taken out of your checkout with the rewrite: tc-drop\.txt – back with git edit --undo while that is the last run, else git show [0-9a-f]\{12\}:<path>$"
_ST_OUT_LACKS "never prescribes stashing a shared checkout" 'git stash push'
_ST_OUT_LACKS "never prescribes a blanket reset" 'reset --hard'
_ST_OUT_LACKS "nor a discard" 'git clean\|git restore \(--source\|--worktree\|-- \)'
_ST_CHECK "nothing of it is staged" git diff --cached --quiet
_ST_EQ "unrelated WIP untouched" "$(cat tc-keep.txt)" "local wip"
git reset -q --hard
# A path with a space is named as itself
echo "tc-b2" > tc-b2.txt && git add tc-b2.txt && git commit -qm "TC base2"
mkdir -p "tc dir" && echo "spaced" > "tc dir/tc file.txt"
git add "tc dir/tc file.txt" && git commit -qm "TC spaced drop"
local TC_SP=$(git rev-parse HEAD)
echo "tc-after" > tc-after.txt && git add tc-after.txt && git commit -qm "TC after"
_ST_RUN -d -y "$TC_SP"
_ST_EQ "drop with a spaced path exits 0" "$RC" "0"
_ST_EQ "the spaced file leaves the checkout, its directory with it" "$([ -e "tc dir" ] || echo gone)" "gone"
_ST_OUT_HAS "named as itself" "Taken out of your checkout with the rewrite: tc dir/tc file\.txt – "
git reset -q --hard
