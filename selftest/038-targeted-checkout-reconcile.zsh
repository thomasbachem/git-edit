# A tree-changing rewrite reconciles per path, never by stashing
_ST_SCENARIO "\e[1;96m[38] targeted checkout reconcile\e[0m"
git reset -q --hard
echo "tc-keep" > tc-keep.txt && git add tc-keep.txt && git commit -qm "TC base"
echo "tc-drop" > tc-drop.txt && git add tc-drop.txt && git commit -qm "TC to drop"
local TC_DROP=$(git rev-parse HEAD)
echo "tc-later" > tc-later.txt && git add tc-later.txt && git commit -qm "TC later"
echo "local wip" > tc-keep.txt   # unrelated WIP the advice must not disturb
_ST_RUN -d -y "$TC_DROP"
_ST_EQ "drop exits 0" "$RC" "0"
_ST_OUT_HAS "names the dropped path" 'tc-drop\.txt'
_ST_OUT_HAS "prescribes a targeted discard" 'Keep it, or discard it with: git clean -f -- tc-drop\.txt'
_ST_OUT_LACKS "never prescribes stashing a shared checkout" 'git stash push'
_ST_OUT_LACKS "never prescribes a blanket reset" 'run git reset --hard'
# A drop's leftover paths are exactly the dropped work, so the restore has to read as
# an opt-in discard – calling it a reconcile invites destroying what was kept
_ST_OUT_HAS "frames the leftovers as uncommitted work" 'dropped content stays in your checkout, unstaged'
_ST_OUT_LACKS "never calls a drop a reconcile" 'Reconcile those paths'
# Staged, a peer's fold of everything staged would land it again
_ST_CHECK "nothing of it is staged" git diff --cached --quiet
git clean -fq -- tc-drop.txt
_ST_CHECK "and that discard does remove the file" sh -c "! test -f tc-drop.txt"
_ST_EQ "unrelated WIP untouched" "$(cat tc-keep.txt)" "local wip"
git reset -q --hard
# A path with a space must come out shell-quoted, or the printed command
# parses as several pathspecs and matches none of them
echo "tc-b2" > tc-b2.txt && git add tc-b2.txt && git commit -qm "TC base2"
mkdir -p "tc dir" && echo "spaced" > "tc dir/tc file.txt"
git add "tc dir/tc file.txt" && git commit -qm "TC spaced drop"
local TC_SP=$(git rev-parse HEAD)
echo "tc-after" > tc-after.txt && git add tc-after.txt && git commit -qm "TC after"
_ST_RUN -d -y "$TC_SP"
_ST_EQ "drop with a spaced path exits 0" "$RC" "0"
_ST_OUT_HAS "shell-quotes the spaced path" "clean -f -- 'tc dir/tc file.txt'"
git reset -q --hard
