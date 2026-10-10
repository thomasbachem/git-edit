# Edit mode brings the checkout along once it lands, as every run does – an agent's too
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
# The content was authored in the isolated worktree, and the checkout comes along – its file and
# index entry both, so nothing reads as a staged revert of the edit and nothing is left to run
_ST_CHECK "the checkout came along" sh -c "test \"\$(sed -n 2p stale.js)\" = EDITED"
_ST_OUT_HAS "naming it" 'Your checkout came along – now as they landed: stale\.js'
_ST_CHECK "index already matches the new tip" sh -c "git diff --cached --quiet -- stale.js"
_ST_EQ "nothing left differing" "$(git status --short -- stale.js)" ""
_ST_OUT_LACKS "no stale hint" 'still holds the pre-edit content'
_ST_OUT_LACKS "no restore to run" 'git restore \(--source\|--worktree\|-- \)'
# A message-only edit changes no content, so it must not cry wolf
_ST_RUN "$(git rev-parse HEAD)"
_ST_RUN --continue --text "STALE later, reworded"
_ST_OUT_LACKS "no stale hint when content is unchanged" 'still holds the pre-edit content'
_ST_OUT_LACKS "nor a sync" 'came along'
git reset -q --hard
