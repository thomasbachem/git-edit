# The drop/squash dispatch path records the result too – a spanned drop
# whose worktree was inspected away still applies whole on the override
_ST_SCENARIO "\e[1;96m[60b] a verify pause on a drop, and what its resume keeps\e[0m"
git reset -q --hard
printf '#!/bin/sh\n! grep -q BAD vd.txt\n' > "$TMP/vdcheck.sh" && chmod +x "$TMP/vdcheck.sh"
git config edit.verifyCmd "$TMP/vdcheck.sh"
printf 'vd\n' > vd.txt && git add vd.txt && git commit -qm "VD one"
printf 'x\n' > vdx.txt && git add vdx.txt && git commit -qm "VD two"
printf 'vd\nBAD\n' > vd.txt && git add vd.txt && git commit -qm "VD three"
printf 'vd\n' > vd.txt && git add vd.txt && git commit -qm "VD four"
local VD_COUNT=$(git rev-list --count HEAD)
_ST_RUN -d -y --verify-span "$(git rev-parse ':/VD two')"
_ST_EQ "the spanned drop pauses on the mid-span failure" "$RC" "2"
local VD_WT=$(print -r -- "$OUT" | sed -n 's/.*paused – verify failed at [0-9a-f]* in \([^;]*\);.*/\1/p' | head -1)
local VD_BAD=$(print -r -- "$OUT" | sed -n 's/.*paused – verify failed at \([0-9a-f]*\) in .*/\1/p' | head -1)
if [ -n "$VD_WT" ] && [ -n "$VD_BAD" ]; then
	git -C "$VD_WT" checkout -q "$VD_BAD" 2>/dev/null
fi
_ST_RUN --no-verify --continue
_ST_EQ "the override applies the drop" "$RC" "0"
_ST_OUT_HAS "after restoring this worktree too" 'restoring'
_ST_EQ "nothing above the drop was truncated" "$(git rev-list --count HEAD)" "$((VD_COUNT - 1))"
_ST_EQ "the tip is the last commit, not the failing one" "$(git log -1 --format=%s)" "VD four"
# A dropped tip rebuilds nothing, so its span is empty – the tier still checks the tip it
# lands, as the default one does, where it once tried to check out a blank commit
printf 'y\n' > vdy.txt && git add vdy.txt && git commit -qm "VD five"
_ST_RUN -d -y --verify-span "$(git rev-parse HEAD)"
_ST_EQ "a spanned tip drop applies" "$RC" "0"
_ST_OUT_HAS "verifying the tip it lands" 'Verified 1 commit(s)'
_ST_EQ "which is the dropped commit's parent" "$(git log -1 --format=%s)" "VD four"
git restore --source=HEAD --staged --worktree -- vdy.txt
# What the drops handed back, untracked – a later scenario reads the checkout as clean
git clean -fq -- vdx.txt vdy.txt
printf 'vd\nBAD\n' > vd.txt && git commit -qam "VD six"
printf 'vd\n' > vd.txt && git commit -qam "VD seven"
local VD_SIX=$(git rev-parse --short=7 HEAD^)
_ST_RUN -d -y --verify-span "$(git rev-parse HEAD)"
_ST_EQ "a spanned tip drop onto a failing commit pauses" "$RC" "2"
_ST_OUT_HAS "naming that commit" "paused – verify failed at $VD_SIX"
_ST_RUN --abort
_ST_EQ "and the abort keeps the tip" "$(git log -1 --format=%s)" "VD seven"
# A recorded result that no longer resolves refuses the resume, since falling back to
# worktree `HEAD` would reopen the truncation trap – a tip fold has no replays, so the
# pause is guaranteed to be verify's rather than a conflict
git config edit.verifyCmd false
printf 'vd\nstale\n' > vd.txt && git add vd.txt
_ST_RUN --amend-into="$(git rev-parse HEAD)" -- vd.txt
_ST_EQ "the doomed tip fold pauses" "$RC" "2"
_ST_OUT_HAS "as a verify pause" 'git-edit: paused – verify failed'
local VD_SF=$(git rev-parse --git-dir)/git-edit-state
sed 's/^verify_result=.*/verify_result=ffffffffffffffffffffffffffffffffffffffff/' "$VD_SF" > "$VD_SF.tmp" && mv "$VD_SF.tmp" "$VD_SF"
_ST_RUN --continue
_ST_EQ "a vanished recorded result refuses the resume" "$RC" "1"
_ST_OUT_HAS "and names what happened" 'no longer resolves'
_ST_RUN --abort
_ST_EQ "while abort still cancels clean" "$RC" "0"
git reset -q -- vd.txt && git checkout -q -- vd.txt
# A verify pause discards worktree edits, so a continue refuses while any are present rather
# than swallowing them – the content-edit pause invites exactly the opposite instinct,
# and a tip fold has no replays, so the pause is verify's for certain
printf 'vd\ndirty\n' > vd.txt && git add vd.txt
_ST_RUN --amend-into="$(git rev-parse HEAD)" -- vd.txt
_ST_EQ "the tip fold pauses on verification" "$RC" "2"
_ST_OUT_HAS "and warns that editing there is not the repair" 'not the repair'
local VE_WT=$(print -r -- "$OUT" | sed -n 's/.*paused – verify failed at [0-9a-f]* in \([^;]*\);.*/\1/p' | head -1)
_ST_CHECK "the pause named a worktree" sh -c "[ -d '$VE_WT' ]"
# Untracked files feed the re-verify yet never land, so they block the resume – an ignored
# one does not, the linked deps being ignored paths
printf 'log\n' > "${VE_WT:-$ST_NO_WT}/verify-run.log"
_ST_RUN --continue
_ST_EQ "an untracked file blocks the gated resume" "$RC" "1"
_ST_OUT_HAS "naming it" 'never land: verify-run.log'
rm -f "$VE_WT/verify-run.log"
local VE_EXCLUDE="$(git rev-parse --git-common-dir)/info/exclude"
cp "$VE_EXCLUDE" "$TMP/ve-exclude" 2>/dev/null
print -r -- 'ignored-run.log' >> "$VE_EXCLUDE"
printf 'log\n' > "${VE_WT:-$ST_NO_WT}/ignored-run.log"
_ST_RUN --continue
_ST_EQ "an ignored one does not" "$RC" "2"
_ST_OUT_HAS "which re-verifies as usual" 'git-edit: paused – verify failed'
rm -f "$VE_WT/ignored-run.log"
cp "$TMP/ve-exclude" "$VE_EXCLUDE" 2>/dev/null || rm -f "$VE_EXCLUDE"
printf 'hand-edited\n' >> "${VE_WT:-$ST_NO_WT}/vd.txt"
_ST_RUN --continue
_ST_EQ "a continue over worktree edits refuses" "$RC" "1"
_ST_OUT_HAS "naming what would have been lost" 'carries edits'
_ST_OUT_HAS "and the repair path" 'no-verify --continue'
_ST_RUN --no-verify --continue
_ST_EQ "the override refuses too, while they are still there" "$RC" "1"
git -C "$VE_WT" checkout -- . 2>/dev/null
_ST_RUN --no-verify --continue
_ST_EQ "and applies once they are gone" "$RC" "0"
git reset -q -- vd.txt && git checkout -q -- vd.txt

# A flag-only --verify survives the pause – with no standing config, a
# resume that forgot it would apply the result with no verification at all
git config --unset edit.verifyCmd
printf 'vd\nflagkeep\n' > vd.txt && git add vd.txt
_ST_RUN --verify=false --amend-into="$(git rev-parse HEAD)" -- vd.txt
_ST_EQ "the flag-only verify pauses" "$RC" "2"
_ST_RUN --continue
_ST_EQ "the resume still verifies – the flag survived the pause" "$RC" "2"
_ST_OUT_HAS "as a verify pause again" 'git-edit: paused – verify failed'
_ST_RUN --abort
git reset -q -- vd.txt && git checkout -q -- vd.txt
# The span tier survives too – a plain continue must re-verify the whole
# span, not silently downgrade to primary+tip
printf 'vs1\n' > vs.txt && git add vs.txt && git commit -qm "VS span one"
printf 'vs1\nmid\n' > vs.txt && git add vs.txt && git commit -qm "VS span two"
printf 'vs1\nmid\nend\n' > vs.txt && git add vs.txt && git commit -qm "VS span three"
printf 'vd\nspankeep\n' > vd.txt && git add vd.txt
_ST_RUN --verify=false --verify-span --amend-into="$(git rev-parse ':/VS span one')" -- vd.txt
_ST_EQ "the spanned fold pauses" "$RC" "2"
_ST_RUN --continue
_ST_EQ "and the resume re-pauses" "$RC" "2"
_ST_OUT_HAS "verifying the span, not just primary+tip" '# verify 3 commit(s)'
# The flag on a resume steps the recorded span down, and the pause then keeps that –
# a flag given on any invocation of an operation sticks to the operation, as --verify-span does
_ST_RUN --no-verify-span --continue
_ST_EQ "a resume may decline the recorded span" "$RC" "2"
_ST_OUT_HAS "verifying primary+tip alone" '# verify 2 commit(s)'
_ST_RUN --continue
_ST_EQ "and a plain resume keeps the declined tier" "$RC" "2"
_ST_OUT_HAS "still at primary+tip" '# verify 2 commit(s)'
# The other direction and the command stick the same way – a resume raises the tier back
# and a plain resume keeps that, and a --verify on a resume replaces the pause's command
_ST_RUN --verify-span --continue
_ST_EQ "a resume may raise the recorded tier back" "$RC" "2"
_ST_OUT_HAS "verifying the span again" '# verify 3 commit(s)'
_ST_RUN --continue
_ST_EQ "and a plain resume keeps that" "$RC" "2"
_ST_OUT_HAS "still the span" '# verify 3 commit(s)'
_ST_RUN --verify='false resumed' --continue
_ST_EQ "a resume may replace the command" "$RC" "2"
_ST_OUT_HAS "running the resume's command" 'false resumed # verify'
_ST_RUN --continue
_ST_EQ "and a plain resume keeps it" "$RC" "2"
_ST_OUT_HAS "still the resume's command" 'false resumed # verify'
# A multi-line command is refused before it can be persisted truncated – on a resume as on
# a fresh run, whose conflict pause comes before any gate
_ST_RUN --verify="$(printf 'false\nfalse')" --continue
_ST_EQ "a multi-line --verify on a resume refuses" "$RC" "1"
_ST_OUT_HAS "naming the reason" 'spans multiple lines'
_ST_CHECK "without touching the recorded command" sh -c "[ \"\$(grep '^verify_cmd=' '$(git rev-parse --git-dir)/git-edit-state' | tail -1)\" = 'verify_cmd=false resumed' ]"
_ST_RUN --abort
git reset -q -- vd.txt && git checkout -q -- vd.txt
git config --unset edit.verifyCmd
git reset -q --hard
# A span tier asked for on a resume with no command in hand refuses before anything is
# rebuilt and records nothing – recorded, every plain resume would refuse for want of one
_ST_RUN "$(git rev-parse HEAD)"
_ST_EQ "an edit pauses" "$RC" "2"
local VR_WT=$(print -r -- "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
printf 'vs1\nmid\nend\nedited\n' > "${VR_WT:-$ST_NO_WT}/vs.txt"
_ST_RUN --verify-span --continue
_ST_EQ "a span tier with no command refuses the resume" "$RC" "1"
_ST_OUT_HAS "naming the missing command" 'needs a command'
_ST_CHECK "and records no tier" sh -c "! grep -q '^verify_span=' '$(git rev-parse --git-dir)/git-edit-state'"
_ST_RUN --continue
_ST_EQ "so a plain resume still completes" "$RC" "0"
_ST_CHECK "with the edit landed" sh -c "git show HEAD:vs.txt | grep -qx edited"

# An explicit `--verify` on a mode with no gate refuses up front, since ignoring it would
# promise a gate the run never keeps – the standing config stays exempt there, so a reword
# under `edit.verifyCmd` must land untouched, and `--exec`, authoring a tree, takes the flag
local XM_TIP=$(git rev-parse HEAD)
_ST_RUN --verify=false -M "$XM_TIP" --text="XM reworded"
_ST_EQ "an explicit --verify on -M refuses" "$RC" "1"
_ST_OUT_HAS "naming the reason" 'cannot gate this mode'
_ST_EQ "with the branch untouched" "$(git rev-parse HEAD)" "$XM_TIP"
_ST_RUN --verify-span --exec -- true
_ST_EQ "--verify-span on --exec is no longer refused up front" "$RC" "0"
_ST_OUT_LACKS "so nothing calls the mode ungatable" 'cannot gate this mode'
git config edit.verifyCmd "false"
_ST_RUN -M "$XM_TIP" --text="XM reworded quietly"
_ST_EQ "a standing config leaves the reword alone" "$RC" "0"
git config --unset edit.verifyCmd

# A split whose verify worktree cannot open fails closed – applying it
# unverified under an `ok` trailer would read as gated when nothing ran
printf 'vw1\n' > vw1.txt && printf 'vw2\n' > vw2.txt && git add vw1.txt vw2.txt && git commit -qm "VW both"
git config edit.verifyCmd "true"
local VW_TIP=$(git rev-parse HEAD)
mkdir -p "$TMP/shim"
# `whence -p` resolves the real binary – the tick wrapper shadows `git`, so
# `command -v` names the function and the shim would exec itself forever
printf '#!/bin/zsh\nif [[ "$1" == "worktree" && "$2" == "add" && "$*" == *git-edit-verify* ]]; then exit 1; fi\nexec %s "$@"\n' "$(whence -p git)" > "$TMP/shim/git"
chmod +x "$TMP/shim/git"
PATH="$TMP/shim:$PATH" _ST_RUN --split="$VW_TIP" --text="VW extracted" -- vw1.txt
_ST_EQ "a split with no verify worktree refuses" "$RC" "1"
_ST_OUT_HAS "naming the failure" 'Could not open a worktree to verify the split'
_ST_EQ "with the branch untouched" "$(git rev-parse HEAD)" "$VW_TIP"
PATH="$TMP/shim:$PATH" _ST_RUN --no-verify --split="$VW_TIP" --text="VW extracted" -- vw1.txt
_ST_EQ "and --no-verify is the stated escape" "$RC" "0"
git config --unset edit.verifyCmd
