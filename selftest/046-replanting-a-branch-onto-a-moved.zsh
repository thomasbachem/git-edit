_ST_SCENARIO "\e[1;96m[46] replanting a branch onto a moved upstream\e[0m"
git reset -q --hard
git checkout -q -B onto-main
printf 'om base\n' > om.txt && git add om.txt && git commit -qm "OM base"
git checkout -q -b onto-feature
printf 'of one\n' > of1.txt && git add of1.txt && git commit -qm "OF one"
printf 'of two\n' > of2.txt && git add of2.txt && git commit -qm "OF two"
git checkout -q onto-main
printf 'om next\n' > om2.txt && git add om2.txt && git commit -qm "OM next"
git checkout -q onto-feature
_ST_RUN --onto=onto-main
_ST_EQ "the replant succeeds" "$RC" "0"
_ST_CHECK "the branch now sits on the upstream tip" \
	sh -c "git merge-base --is-ancestor onto-main onto-feature"
_ST_CHECK "and still carries its own commits" \
	sh -c "test \$(git rev-list --count onto-main..onto-feature) -eq 2"
_ST_OUT_HAS "reports what landed" 'Replanted 2 of 2'
# The branch moved under this checkout and a replant changes its content –
# left stale, every commit the upstream gained reads as a local deletion
_ST_CHECK "the checkout came along" sh -c "test -f om2.txt"
_ST_CHECK "and reports nothing pending" sh -c "git diff --quiet && git diff --cached --quiet"
_ST_OUT_HAS "which is stated, not left to be discovered" 'Your checkout came along – now as they landed: om2.txt'
_ST_RUN --onto=onto-main
_ST_OUT_HAS "a second run is a no-op" 'Already on top of'

# The case the manual flow exists for: a rewrite orphans the fork point,
# so plain merge-base answers with a far older ancestor and would replay
# commits the upstream already carries
git checkout -q onto-main
_ST_RUN -M --text='OM base, reworded' onto-main~1
git checkout -q -B onto-orphan onto-feature
_ST_CHECK "the fork point really is orphaned" \
	sh -c "! git merge-base --is-ancestor \$(git rev-parse onto-orphan~2) onto-main"
_ST_RUN --onto=onto-main
_ST_EQ "the orphaned replant succeeds" "$RC" "0"
_ST_OUT_HAS "and says the fork was recovered" 'orphaned by a rewrite'
_ST_OUT_LACKS "without claiming it guessed" 'could not answer'
_ST_CHECK "no upstream commit was replayed onto the branch" \
	sh -c "test \$(git log --format=%s onto-main..onto-orphan | grep -c '^OM ') -eq 0"

# A commit the upstream already carries by patch id is dropped, not lost –
# and the summary has to say so, or the shorter branch reads as lost work
git checkout -q -B onto-dup onto-main
printf 'dup work\n' > dup.txt && git add dup.txt && git commit -qm "Dup on branch"
printf 'own\n' > own.txt && git add own.txt && git commit -qm "Own work"
git checkout -q onto-main
printf 'dup work\n' > dup.txt && git add dup.txt && git commit -qm "Dup landed upstream"
git checkout -q onto-dup
_ST_RUN --onto=onto-main
_ST_OUT_HAS "duplicates are named before the replay" 'already on onto-main'
_ST_OUT_HAS "and counted afterwards" 'dropped as already upstream'
_ST_CHECK "the branch keeps only its own commit" \
	sh -c "test \$(git rev-list --count onto-main..onto-dup) -eq 1"

# A replant rewrites its whole span, so it owes the same guards every other
# rewriting mode applies – it reached the branch without them at first
git checkout -q -B onto-pushed onto-main
printf 'op work\n' > op.txt && git add op.txt && git commit -qm "OP pushed"
git push -q origin onto-pushed 2>/dev/null
git checkout -q onto-main
printf 'om third\n' > om3.txt && git add om3.txt && git commit -qm "OM third"
git checkout -q onto-pushed
_ST_RUN --onto=onto-main
_ST_EQ "a pushed span is refused" "$RC" "1"
_ST_OUT_HAS "naming the reason" 'already pushed'
_ST_RUN --onto=onto-main --allow-pushed
_ST_EQ "--allow-pushed overrides it" "$RC" "0"

# A merge in the span would be flattened by the replay, silently
git checkout -q -B onto-merge onto-main
printf 'oms\n' > oms.txt && git add oms.txt && git commit -qm "OMS side"
git checkout -q -B onto-mergebase onto-main~1
printf 'omb\n' > omb.txt && git add omb.txt && git commit -qm "OMB base"
git merge -q --no-ff -m "OMB merge" onto-merge 2>/dev/null
git checkout -q onto-main
printf 'om fourth\n' > om4.txt && git add om4.txt && git commit -qm "OM fourth"
git checkout -q onto-mergebase
_ST_RUN --onto=onto-main
_ST_EQ "a merge in the span is refused" "$RC" "1"
_ST_OUT_HAS "rather than flattened silently" 'contains a merge commit'

# A replant that would strand the checkout must refuse before the CAS, not
# move the branch and then decline to follow
git checkout -q -B onto-dirty onto-main
printf 'od branch\n' > od.txt && git add od.txt && git commit -qm "OD on branch"
git checkout -q onto-main
printf 'od upstream\n' > od.txt && git add od.txt && git commit -qm "OD upstream"
git checkout -q onto-dirty
local OD_BEFORE=$(git rev-parse onto-dirty)
printf 'od uncommitted\n' > od.txt
_ST_RUN --onto=onto-main
_ST_EQ "a replant onto dirty paths is refused" "$RC" "1"
_ST_OUT_HAS "naming the blocked path" 'od.txt'
_ST_EQ "and the branch never moved" "$(git rev-parse onto-dirty)" "$OD_BEFORE"
_ST_CHECK "with the uncommitted work intact" sh -c "grep -qx 'od uncommitted' od.txt"
git checkout -q -- od.txt 2>/dev/null
git reset -q --hard

# Dirt on a path the replant does not touch is no reason to refuse – a fresh branch, since
# `od.txt` differs on both sides and would conflict on its own merits, proving nothing
git checkout -q -B onto-clean onto-main
printf 'oc branch\n' > oc.txt && git add oc.txt && git commit -qm "OC on branch"
git checkout -q onto-main
printf 'om fifth\n' > om5.txt && git add om5.txt && git commit -qm "OM fifth"
git checkout -q onto-clean
printf 'oc unrelated\n' > oc-unrelated.txt
_ST_RUN --onto=onto-main
_ST_EQ "unrelated dirt does not block it" "$RC" "0"
_ST_CHECK "and that file survives" sh -c "grep -qx 'oc unrelated' oc-unrelated.txt"
rm -f oc-unrelated.txt
git reset -q --hard

# Without the upstream's reflog the fork point is only a merge base, which after a
# content-changing rewrite sits below the real fork, taking in commits the upstream has
# It must also have moved past the fork – `--fork-point` answers from the graph alone
git checkout -q -B onto-noreflog onto-main
printf 'onr branch\n' > onr.txt && git add onr.txt && git commit -qm "ONR on branch"
git checkout -q onto-main
printf 'onr up\n' > onr-up.txt && git add onr-up.txt && git commit -qm "ONR upstream"
git checkout -q onto-noreflog
git reflog expire --expire=now --all 2>/dev/null
_ST_CHECK "the reflog can no longer answer" \
	sh -c "test -z \"\$(git merge-base --fork-point onto-main onto-noreflog 2>/dev/null)\""
_ST_RUN --onto=onto-main
_ST_OUT_HAS "a guessed fork point is flagged" 'could not answer'
_ST_OUT_HAS "and warns the span may be too wide" 'may be too wide'

# `--skip` belongs to this mode alone – elsewhere the paused commit is the point
git checkout -q -B onto-skip onto-main
_ST_RUN --skip
_ST_EQ "a skip with nothing in flight is refused" "$RC" "1"
git checkout -q onto-main
git push -q origin --delete onto-pushed 2>/dev/null
git branch -q -D onto-feature onto-orphan onto-dup onto-skip onto-pushed onto-merge onto-mergebase onto-dirty onto-clean onto-noreflog 2>/dev/null
git checkout -q main
git reset -q --hard
