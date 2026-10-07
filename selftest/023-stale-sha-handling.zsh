# Stale (rewritten) SHAs are refused, never silently no-op'd
_ST_SCENARIO "\e[1;96m[23] stale SHA handling\e[0m"
echo "stale" > stale.txt && git add stale.txt && git commit -qm "Stale target"
local STALE_SHA=$(git rev-parse HEAD)
# Fold into it: the SHA changes, the subject survives for the counterpart hint
echo "stale2" > stale.txt && git add stale.txt
_ST_RUN --amend-into="$STALE_SHA"
local STALE_HEAD=$(git rev-parse HEAD)
local STALE_COUNT=$(git rev-list --count HEAD)
_ST_RUN -d -y "$STALE_SHA"
_ST_EQ "drop refuses a stale SHA" "$RC" "1"
_ST_OUT_HAS "explains it was rewritten" 'likely rewritten'
_ST_OUT_HAS "names the counterpart" 'counterpart on HEAD'
_ST_EQ "HEAD untouched" "$(git rev-parse HEAD)" "$STALE_HEAD"
_ST_EQ "nothing dropped" "$(git rev-list --count HEAD)" "$STALE_COUNT"
_ST_RUN -d -y "${$(git rev-parse HEAD)//?/d}"
_ST_EQ "nonexistent SHA refused" "$RC" "1"
_ST_OUT_HAS "reports it does not exist" 'does not exist'
# A commit only rebuilt as a descendant keeps its diff, so it resolves outright
echo "tip" > tip.txt && git add tip.txt && git commit -qm "Tip commit"
local SHIFTED=$(git rev-parse HEAD)
echo "stale3" > stale.txt && git add stale.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~1)"
_ST_RUN -M --text="Tip reworded" "$SHIFTED"
_ST_EQ "stale descendant auto-resolves" "$RC" "0"
_ST_OUT_HAS "reports the substitution" 'current identity'
_ST_EQ "reword hit the right commit" "$(git log -1 --format=%s)" "Tip reworded"
export GIT_EDIT_NO_RESOLVE=1
_ST_RUN -M --text="Opted out" "$SHIFTED"
unset GIT_EDIT_NO_RESOLVE
_ST_EQ "GIT_EDIT_NO_RESOLVE opts out" "$RC" "1"
# --amend-into and --split take their target as an option value, not a
# positional, so they need the guard wired in separately
echo "anchor" > anchor.txt && git add anchor.txt && git commit -qm "Anchor commit"
local ANCHOR=$(git rev-parse HEAD)
echo "opt" > opt.txt && git add opt.txt && git commit -qm "Option-value target"
local OPTVAL=$(git rev-parse HEAD)
echo "shift" > shift.txt && git add shift.txt && git commit -qm "Shifter"
# Fold below the target so it is only rebuilt – its own diff, and so its
# patch id, must survive for the resolution to be provable
echo "anchor2" > anchor.txt && git add anchor.txt
_ST_RUN --amend-into="$ANCHOR"
echo "folded" > folded.txt && git add folded.txt
_ST_RUN --amend-into="$OPTVAL"
_ST_EQ "--amend-into resolves a stale target" "$RC" "0"
_ST_OUT_HAS "--amend-into reports the substitution" 'current identity'
_ST_EQ "fold landed on the resolved commit" "$(git show 'HEAD~1:folded.txt' 2>/dev/null)" "folded"
# A resolved match on pushed history is named, never acted on – not even
# under --allow-pushed, which consents to the named commit and not this one
# A cherry-pick keeps both author date and diff, so it is the twin to beat
git rm -q b.txt && git commit -qm "Remove beta"
git cherry-pick "$(git rev-parse origin/main)" >/dev/null 2>&1
local TWIN=$(git rev-parse HEAD)
# Dropping the twin leaves the pushed original as the sole commit with that
# diff, so the stale SHA resolves uniquely onto shared history
_ST_RUN -d -y "$TWIN"
local TWIN_HEAD=$(git rev-parse HEAD)
_ST_RUN -M --text="Should not land" --allow-pushed "$TWIN"
_ST_EQ "pushed match refused under --allow-pushed" "$RC" "1"
_ST_OUT_HAS "names the pushed match" 'already pushed'
_ST_EQ "branch untouched" "$(git rev-parse HEAD)" "$TWIN_HEAD"
