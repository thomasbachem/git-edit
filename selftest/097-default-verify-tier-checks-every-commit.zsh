# A later commit can heal a wrong resolution before the tip shows it – so a run stepped down
# from the span still checks what was resolved at a stop, both stops here, and says so
_ST_SCENARIO "\e[1;96m[97] the default verify tier checks every commit a resolution wrote\e[0m"
echo a > rv.txt && git add rv.txt && git commit -qm "RV base"
echo x > rv.txt && git commit -qam "RV x"
echo y > rv.txt && git commit -qam "RV y"
echo v > rv_v.txt && git add rv_v.txt && git commit -qm "RV v"
echo w > rv_w.txt && git add rv_w.txt && git commit -qm "RV w"
local RV_Y=$(git rev-parse ':/RV y') RV_BASE=$(git rev-parse ':/RV base') RV_TIP=$(git rev-parse HEAD) RV_TREE=$(git rev-parse 'HEAD^{tree}')
git config edit.verifyCmd "sh -c '! grep -q BAD rv.txt'"
_ST_RUN --move="$RV_Y" --after="$RV_BASE" --no-verify-span
_ST_EQ "moving y below x stops on its conflict" "$RC" "2"
local RV_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
echo BAD > "${RV_WT:-$ST_NO_WT}/rv.txt" && git -C "$RV_WT" add rv.txt
_ST_RUN --continue
_ST_EQ "and again on x replaying above it" "$RC" "2"
echo y > "${RV_WT:-$ST_NO_WT}/rv.txt" && git -C "$RV_WT" add rv.txt
_ST_RUN --continue
_ST_EQ "a resolution the tip heals still fails the gate" "$RC" "2"
_ST_OUT_HAS "at the commit it wrote" 'failing: [0-9a-f]* RV y'
_ST_EQ "and nothing landed" "$(git rev-parse HEAD)" "$RV_TIP"
_ST_RUN --abort
_ST_RUN --move="$RV_Y" --after="$RV_BASE" --no-verify-span
RV_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
echo ya > "${RV_WT:-$ST_NO_WT}/rv.txt" && git -C "$RV_WT" add rv.txt
_ST_RUN --continue
echo y > "${RV_WT:-$ST_NO_WT}/rv.txt" && git -C "$RV_WT" add rv.txt
_ST_RUN --continue
_ST_EQ "a sound one lands" "$RC" "0"
_ST_OUT_HAS "checking both resolved commits and the tip" '# verify 3 commit(s)'
_ST_OUT_HAS "and naming them on its line" 'Verified 3 of 4 commit(s) .* 2 of them resolved at a stop, 1 unchecked in between'
_ST_EQ "the move kept the tree" "$(git rev-parse 'HEAD^{tree}')" "$RV_TREE"
# The span tier runs them anyway, but its note prices the default tier, which counts them
git config edit.verifySpan true
_ST_RUN --undo
_ST_RUN --move="$RV_Y" --after="$RV_BASE"
RV_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
echo ya > "${RV_WT:-$ST_NO_WT}/rv.txt" && git -C "$RV_WT" add rv.txt
_ST_RUN --continue
echo y > "${RV_WT:-$ST_NO_WT}/rv.txt" && git -C "$RV_WT" add rv.txt
_ST_RUN --continue
_ST_OUT_HAS "a span run prices the default tier with them" 'Verified 4 commit(s) .* 1 beyond the default tier, `--no-verify-span` runs only its 3'
# A fold resumes through a path of its own, stopping at its fixup and then at each descendant
# editing the same line – the middle one resolved wrong and healed above it
echo a > fd.txt && git add fd.txt && git commit -qm "FD base"
echo t > fd.txt && git commit -qam "FD t"
echo d > fd.txt && git commit -qam "FD d"
echo h > fd.txt && git commit -qam "FD h"
echo e > fd_e.txt && git add fd_e.txt && git commit -qm "FD e"
local FD_T=$(git rev-parse ':/FD t') FD_TIP=$(git rev-parse HEAD) FD_R
git config edit.verifyCmd "sh -c '! grep -q BAD fd.txt'"
echo n > fd.txt && git add fd.txt
_ST_RUN --amend-into="$FD_T" --no-verify-span -- fd.txt
local FD_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
for FD_R in n BAD n; do
	echo "$FD_R" > "${FD_WT:-$ST_NO_WT}/fd.txt" && git -C "$FD_WT" add fd.txt
	_ST_RUN --continue
done
_ST_EQ "a fold's resolution the tip heals fails the gate too" "$RC" "2"
_ST_OUT_HAS "at the descendant it wrote" 'failing: [0-9a-f]* FD d'
_ST_EQ "and nothing landed" "$(git rev-parse HEAD)" "$FD_TIP"
_ST_RUN --abort
git reset -q --hard
git config --unset edit.verifySpan
git config --unset edit.verifyCmd
