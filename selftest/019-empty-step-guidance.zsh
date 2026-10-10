# Empty-step pause: guidance + git edit's continue dropping the step, plus graceful no-op continue
_ST_SCENARIO "\e[1;96m[19] empty-step guidance\e[0m"
echo "f1" > f1.txt && echo "v1" > f2.txt && git add f1.txt f2.txt && git commit -qm "R0 base"
echo "f1x" > f1.txt && echo "v2" > f2.txt && git add f1.txt f2.txt && git commit -qm "R1 commit"
echo "v1" > f2.txt && git add f2.txt && git commit -qm "R2 revert"
PRE_HEAD=$(git rev-parse HEAD)
# Moving the revert before the commit it reverts makes it empty
_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
_ST_EQ "pauses with exit 2" "$RC" "2"
_ST_OUT_HAS "explains the empty step" 'became empty'
_ST_OUT_HAS "names git edit's continue as the way past it" 'Continuing drops that commit'
_ST_OUT_LACKS "never a hand skip, which loses the change" 'rebase --skip'
_ST_OUT_HAS "and that dropping one changing a reorder's tree refuses" 'A reorder only moves commits'
# Dropping it here drops the revert's change, which a reorder may not – the result refuses
_ST_RUN --continue
_ST_EQ "a drop that changes the tree refuses, the branch untouched" "${RC}:$(git rev-parse HEAD)" "1:$PRE_HEAD"
_ST_OUT_HAS "naming the file it changed" 'no longer ends on the tree it began with – a resolution changed f2.txt'
_ST_RUN --abort
_ST_CHECK "state cleared by the abort" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"
# A reorder aborted by hand in its worktree is no reorder – refused, the pause kept for an abort
echo "v2b" > f2.txt && git add f2.txt && git commit -qm "R3 commit"
echo "v1" > f2.txt && git add f2.txt && git commit -qm "R4 revert"
PRE_HEAD=$(git rev-parse HEAD)
_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
_ST_EQ "pauses with exit 2" "$RC" "2"
EMPTY_WT=$(_ST_PZ_WT)
git -C "$EMPTY_WT" rebase --abort >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a continue after a hand abort refuses" "$RC" "1"
_ST_OUT_HAS "saying nothing was applied" 'aborted by hand – nothing was applied'
_ST_EQ "branch untouched" "$(git rev-parse HEAD)" "$PRE_HEAD"
_ST_RUN --abort
_ST_CHECK "which an abort clears" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"
