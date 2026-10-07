# Read from the branch's old tip, the rebuilt range took in every commit the upstream gained,
# so the first of those ran as the replant's own and the count carried them all
_ST_SCENARIO "\e[1;96m[102] a replant checks the commits it replanted, not its upstream's\e[0m"
local RP RP_BRANCH=$(git symbolic-ref --short HEAD)
git checkout -q -b rp-upstream
for RP in u1 u2 u3; do
	echo "$RP" > "rp_$RP.txt" && git add "rp_$RP.txt" && git commit -qm "RP $RP"
done
git checkout -q "$RP_BRANCH"
for RP in t1 t2; do
	echo "$RP" > "rp_$RP.txt" && git add "rp_$RP.txt" && git commit -qm "RP $RP"
done
git config edit.verifyCmd "sh -c 'git log -1 --format=%s \"\$GIT_EDIT_VERIFY_COMMIT\" >> \"$TMP/rp-verified\"'"
rm -f "$TMP/rp-verified"
_ST_RUN --onto=rp-upstream
_ST_EQ "the replant lands" "$RC" "0"
_ST_EQ "checking the first commit it replanted and the tip" "$(tr '\n' ' ' < "$TMP/rp-verified")" "RP t1 RP t2 "
_ST_OUT_HAS "counting only what it built" 'Verified 2 commit(s)'
git config --unset edit.verifyCmd
