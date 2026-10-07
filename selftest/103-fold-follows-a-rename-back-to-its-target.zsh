_ST_SCENARIO "\e[1;96m[103] a fold follows a rename back to its target where git's rename detection pairs the paths\e[0m"
local RNM RNM_TARGET RNW_TARGET
for RNM in {1..12}; do echo "rn line $RNM"; done > rn_old.txt
git add rn_old.txt && git commit -qm "RN add" -- rn_old.txt
RNM_TARGET=$(git rev-parse HEAD)
git mv rn_old.txt rn_new.txt && git commit -qm "RN rename" -- rn_old.txt rn_new.txt
echo "rn tail" >> rn_new.txt && git commit -qm "RN after" -- rn_new.txt
sed 's/^rn line 3$/rn line 3 fixed/' rn_new.txt > rn_new.tmp && mv rn_new.tmp rn_new.txt && git add rn_new.txt
_ST_RUN --amend-into="$RNM_TARGET" -- rn_new.txt
_ST_EQ "the fold lands without --allow-new-path" "$RC" "0"
_ST_OUT_HAS "naming the old path it folds into" 'rn_new.txt is rn_old.txt at'
_ST_EQ "into the target, at the old path" "$(git show HEAD~2:rn_old.txt | sed -n 3p)" "rn line 3 fixed"
_ST_EQ "and the rename replays over it" "$(git show HEAD:rn_new.txt | sed -n '3p;13p' | tr '\n' ' ')" "rn line 3 fixed rn tail "
# The `--tree` form `build-commit` composes pairs the same way
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" --tree="$(_ST_COMPOSE rn_new.txt "$(git show HEAD:rn_new.txt | sed 's/^rn line 5$/rn line 5 fixed/')")"
_ST_EQ "a composed tree folds there too" "$(git show HEAD~2:rn_old.txt | sed -n 5p)" "rn line 5 fixed"
git checkout -q HEAD -- rn_new.txt
# A deletion, which the merge meets as a rename/delete conflict
git rm -q rn_new.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" -- rn_new.txt
_ST_EQ "a fold deleting the renamed path is refused" "$RC" "1"
_ST_OUT_HAS "as one that arrives later" 'rn_new.txt – arrives in'
git checkout -q HEAD -- rn_new.txt
# The merge reads `merge.renames`, falling back to `diff.renames` – with either off nothing pairs
sed 's/^rn line 7$/rn line 7 fixed/' rn_new.txt > rn_new.tmp && mv rn_new.tmp rn_new.txt && git add rn_new.txt
git config merge.renames false
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" -- rn_new.txt
_ST_EQ "with merge.renames off the fold is refused" "$RC" "1"
_ST_OUT_HAS "as a path that arrives later" 'rn_new.txt – arrives in'
git config --unset merge.renames
git config diff.renames ''
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" -- rn_new.txt
_ST_EQ "and with an empty diff.renames, which git reads as off" "$RC" "1"
_ST_OUT_HAS "the same way" 'rn_new.txt – arrives in'
git config --unset diff.renames
git checkout -q HEAD -- rn_new.txt
# A rename rewritten past git's similarity threshold pairs nothing
for RNM in {1..12}; do echo "rw line $RNM"; done > rw_old.txt
git add rw_old.txt && git commit -qm "RW add" -- rw_old.txt
RNW_TARGET=$(git rev-parse HEAD)
git mv rw_old.txt rw_new.txt
for RNM in {1..12}; do if [ "$RNM" = 3 ]; then echo "rw line 3"; else echo "rewritten $RNM"; fi; done > rw_new.txt
git add rw_new.txt && git commit -qm "RW rename and rewrite" -- rw_old.txt rw_new.txt
sed 's/^rw line 3$/rw line 3 fixed/' rw_new.txt > rw_new.tmp && mv rw_new.tmp rw_new.txt && git add rw_new.txt
_ST_RUN --amend-into="$RNW_TARGET" -- rw_new.txt
_ST_EQ "a rename git can't pair is still refused" "$RC" "1"
_ST_OUT_HAS "naming the commit the path arrives in" 'rw_new.txt – arrives in'
git checkout -q HEAD -- rw_new.txt
