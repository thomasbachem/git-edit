# Explicit-target squash: same-second span, short SHAs

# The rebuilt-commit case: descendants of one rewrite all share a committer
# second, so timestamp sorts tie – the span must sort from `HEAD`'s history,
# and short SHAs must normalize for that sort's exact match to hit
_ST_SCENARIO "\e[1;96m[26] explicit-target squash ordering\e[0m"
local QN
for QN in q1 q2 q3 q4; do
	echo "$QN" > q.txt && git add q.txt
	GIT_COMMITTER_DATE="2026-01-02T03:04:05+00:00" git commit -qm "Q $QN"
done
local QT=$(git rev-parse --short HEAD~3)
_ST_RUN -s="$QT" -y --text="Q combined" "$(git rev-parse --short HEAD)" "$(git rev-parse --short HEAD~1)" "$(git rev-parse --short HEAD~2)"
_ST_EQ "same-second short-SHA squash exits 0" "$RC" "0"
_ST_OUT_HAS "routed to plumbing" 'commit-tree'
_ST_EQ "one combined commit" "$(git log -1 --format=%s)" "Q combined"
_ST_EQ "content is the newest version" "$(git show HEAD:q.txt)" "q4"
# A tree-identical rewrite (non-adjacent squash of separate-file commits,
# forced onto the rebase path) needs no checkout reconcile – the hint must
# say so instead of prescribing the stash/reset dance
echo "r1" > r1.txt && git add r1.txt && git commit -qm "R gap1"
echo "r2" > r2.txt && git add r2.txt && git commit -qm "R gap2"
echo "r3" > r3.txt && git add r3.txt && git commit -qm "R gap3"
_ST_RUN -s="$(git rev-parse HEAD~2)" -y --text="R gap1+3" "$(git rev-parse HEAD)"
_ST_EQ "non-adjacent pure squash exits 0" "$RC" "0"
_ST_OUT_HAS "reconcile hint suppressed" 'checkout is already current'
_ST_OUT_LACKS "no stash dance prescribed" "stash push -u -m 'wip before git-edit'"
