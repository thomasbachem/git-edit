# Edit mode must report the stale checkout it leaves behind
_ST_SCENARIO "\e[1;96m[37] edit-mode checkout staleness\e[0m"
git reset -q --hard
printf 'ed1\nSTALE-ME\ned3\n' > stale.js && git add stale.js && git commit -qm "STALE target"
local STALE_T=$(git rev-parse HEAD)
echo "stale-later" > stale-later.txt && git add stale-later.txt && git commit -qm "STALE later" >/dev/null 2>&1
_ST_EQ "target has a descendant to replay" "$(git rev-list --count ${STALE_T}..HEAD)" "1"
_ST_RUN "$STALE_T"
local STALE_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – edit [0-9a-f]* in \(.*\); then.*/\1/p')
printf 'ed1\nEDITED\ned3\n' > "${STALE_WT:-$ST_NO_WT}/stale.js"
_ST_RUN --continue
_ST_EQ "edit applies" "$RC" "0"
# The trap: content was authored in the isolated worktree, so the main
# checkout still has the old file – its index entry, which read as a staged revert of
# the edit, is re-synced in place, the worktree named and left to an opt-in restore
_ST_CHECK "checkout really is stale" sh -c "test \"\$(sed -n 2p stale.js)\" = STALE-ME"
_ST_OUT_HAS "re-syncs the stranded index entry" 'Index entries re-synced to the new tip: stale\.js'
_ST_CHECK "index already matches the new tip" sh -c "git diff --cached --quiet -- stale.js"
_ST_OUT_HAS "warns the checkout is stale" 'still holds the pre-edit content'
_ST_OUT_HAS "names the stale path" 'stale\.js'
_ST_OUT_HAS "prescribes a worktree-only restore" 'restore --source=HEAD --worktree -- stale\.js'
# The blob it discards is content the rewrite may have handed back on purpose, so the hint has
# to read as an offer – a bare "Reconcile those paths" invites destroying an extraction
_ST_OUT_HAS "and says what reconciling discards" 'Reconcile those paths (discards what the rewrite left there)'
_ST_OUT_LACKS "the restore never names the index" 'restore --source=HEAD --staged'
git restore --source=HEAD --worktree -- stale.js
_ST_CHECK "the printed reconcile fixes it" sh -c "test \"\$(sed -n 2p stale.js)\" = EDITED"
_ST_CHECK "and the index stays clean" sh -c "git diff --cached --quiet -- stale.js"
# A message-only edit changes no content, so it must not cry wolf
_ST_RUN "$(git rev-parse HEAD)"
_ST_RUN --continue --text "STALE later, reworded"
_ST_OUT_LACKS "no stale hint when content is unchanged" 'still holds the pre-edit content'
git reset -q --hard
