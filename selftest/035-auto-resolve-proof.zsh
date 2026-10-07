# The final-step auto-resolve must refuse when it can't prove itself
_ST_SCENARIO "\e[1;96m[35] auto-resolve proof\e[0m"
git reset -q --hard
printf 'p1\n' > pa.txt && printf 'q1\n' > pb.txt && git add pa.txt pb.txt && git commit -qm "PR base"
printf 'p1\npA\n' > pa.txt && git add pa.txt && git commit -qm "PR A"
local PR_A=$(git rev-parse HEAD)
printf 'p1\npB\npA\n' > pa.txt && git add pa.txt && git commit -qm "PR B"
local PR_B=$(git rev-parse HEAD)
_ST_RUN --move="$PR_A" --after="$PR_B"
_ST_EQ "abutting swap conflicts" "$RC" "2"
local PR_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
# Resolve step 1, but also touch a file neither commit changes – the final
# step's pre-op blobs then cannot reproduce the pre-op tree, so the proof
# fails and it must hand back rather than apply a resolution it can't verify
printf 'p1\npB\n' > "${PR_WT:-$ST_NO_WT}/pa.txt"
printf 'STRAY\n' > "${PR_WT:-$ST_NO_WT}/pb.txt"
git -C "$PR_WT" add pa.txt pb.txt
_ST_RUN --continue
_ST_EQ "unprovable final step still pauses" "$RC" "2"
_ST_OUT_LACKS "never claims an unproven auto-resolve" 'auto-resolved'
_ST_RUN --abort
_ST_CHECK "abort leaves no state" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
git reset -q --hard
