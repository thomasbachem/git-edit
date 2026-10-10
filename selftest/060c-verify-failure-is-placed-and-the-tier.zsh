# A failure raises two questions the report has to answer – whether the rewrite caused it,
# and where the span heals, so the fold below needs a line a later commit adds, failing at
# the amended commit and passing again at the commit carrying that line
_ST_SCENARIO "\e[1;96m[60c] a verify failure is placed, and the tier says what it checked\e[0m"
git reset -q --hard
printf '#!/bin/sh\ngrep -q USE nv_app.txt 2>/dev/null || exit 0\ngrep -q NEEDED nv_boot.txt\n' > "$TMP/need.sh"
chmod +x "$TMP/need.sh"
git config edit.verifyCmd "$TMP/need.sh"
printf 'base\n' > nv_app.txt && printf 'boot\n' > nv_boot.txt
git add nv_app.txt nv_boot.txt && git commit -qm "NV base"
local NV_BASE=$(git rev-parse HEAD)
printf 'boot\nNEEDED\n' > nv_boot.txt && git commit -qam "NV bootstrap line"
printf 'nv\n' > nv_late.txt && git add nv_late.txt && git commit -qm "NV later work"
printf 'USE\n' > nv_app.txt && git add nv_app.txt
_ST_RUN --amend-into="$NV_BASE" -- nv_app.txt
_ST_EQ "the fold pauses at the amended commit" "$RC" "2"
_ST_OUT_HAS "the walk names the commit that heals it" 'first green: [0-9a-f]* NV bootstrap line'
_ST_OUT_LACKS "and does not disown the failure" 'not this operation'
_ST_RUN --abort
# The commit under test reaches the command by name too, exported, as a prefix assignment on
# the `eval` builtin never reaches the child
# A command insisting on it pins all three sites: the gate, the counterpart run and the climb
printf '#!/bin/sh\n[ "$GIT_EDIT_VERIFY_COMMIT" = "$(git rev-parse HEAD)" ] || exit 1\ngrep -q USE nv_app.txt 2>/dev/null || exit 0\ngrep -q NEEDED nv_boot.txt\n' > "$TMP/need_env.sh"
chmod +x "$TMP/need_env.sh"
git config edit.verifyCmd "$TMP/need_env.sh"
_ST_RUN --amend-into="$NV_BASE" -- nv_app.txt
_ST_EQ "the fold pauses on the same failure with the commit named" "$RC" "2"
_ST_OUT_HAS "the climb finds the healing commit with the name in hand" 'first green: [0-9a-f]* NV bootstrap line'
_ST_OUT_LACKS "and the counterpart, named too, is not blamed" 'not this operation'
_ST_RUN --abort
# A check already failing at the commit being replaced is not this
# rewrite's doing – saying so is what keeps the gate worth reading
git config edit.verifyCmd "false"
_ST_RUN --amend-into="$NV_BASE" -- nv_app.txt
_ST_EQ "the always-failing check pauses too" "$RC" "2"
_ST_OUT_HAS "disowning it without overclaiming" 'pre-existing, or the check cannot run'
_ST_OUT_HAS "naming the counterpart" 'counterpart: [0-9a-f]* NV base'
# The remedy, not just the cause – and only because nothing is linked in this repo
_ST_OUT_HAS "and the config that would let a check run there" 'edit.worktreeLink node_modules'
_ST_OUT_LACKS "and skipping the walk it would mislead with" 'first green'
_ST_RUN --abort
# A repo that configured it hears the cause and not a remedy it already has – the positive
# beside it is what proves this run reached the branch that would have printed the hint
git config --add edit.worktreeLink node_modules
_ST_RUN --amend-into="$NV_BASE" -- nv_app.txt
_ST_OUT_HAS "the disowning still stands there" 'pre-existing, or the check cannot run'
_ST_OUT_LACKS "without the hint it has no use for" 'Nothing is linked'
git config --unset-all edit.worktreeLink
_ST_RUN --abort
# The default tier states what it left out, and the standing config raises
# it – a bare "Verified 2 commit(s)" over a span of four reads as verified
git config edit.verifyCmd "true"
_ST_RUN --amend-into="$NV_BASE" -- nv_app.txt
_ST_EQ "the passing fold applies" "$RC" "0"
# On the claim's own line, so one `grep '^Verified'` cannot read a sampled run as complete
_ST_OUT_HAS "naming the unverified middle" '^Verified .* of .* commit(s) with .* unchecked in between'
_ST_OUT_HAS "and the tier that covers it" 'verify-span'
git config edit.verifySpan true
printf 'USE\nagain\n' > nv_app.txt && git add nv_app.txt
_ST_RUN --amend-into="$(git rev-parse ':/NV base')" -- nv_app.txt
_ST_EQ "the config-raised span applies" "$RC" "0"
_ST_OUT_HAS "verifying the whole span" 'Verified 3 commit(s)'
_ST_OUT_LACKS "so the line reports nothing short" 'unchecked in between'
# The span tier states in turn what it ran beyond the default one, with the lever that steps
# back down and what the whole check took – a caller picks its flags before running, so the
# price that can reach it in time is the previous run's
_ST_OUT_HAS "stating what the whole check took" 'Verified 3 commit(s) with `true` in [0-9][0-9]*s'
_ST_OUT_HAS "and what it ran beyond the default tier" '1 beyond the default tier'
_ST_OUT_HAS "with the lever that steps back down" 'no-verify-span` runs only its 2 (set by edit.verifySpan)'
printf 'USE\nnarrowed\n' > nv_app.txt && git add nv_app.txt
_ST_RUN --no-verify-span --amend-into="$(git rev-parse ':/NV base')" -- nv_app.txt
_ST_EQ "the flag steps one run down to the default tier" "$RC" "0"
_ST_OUT_HAS "verifying the primary commit and the tip alone" 'Verified 2 of 3 commit(s)'
_ST_OUT_HAS "naming the shortfall as the default tier does" 'unchecked in between'
_ST_OUT_LACKS "and not the step it just took" 'beyond the default tier'
# The lever is not named where nothing lies beyond the default tier – a fold at the tip
# rebuilds one commit under either, on the tip's own file, so the later folds below still
# replay over descendants that leave theirs alone
printf 'nv\nat the tip\n' > nv_late.txt && git add nv_late.txt
_ST_RUN --amend-into="$(git rev-parse HEAD)" -- nv_late.txt
_ST_EQ "a fold at the tip applies under the tier" "$RC" "0"
_ST_OUT_HAS "verifying the one commit it built" 'Verified 1 commit(s) with `true` in'
_ST_OUT_LACKS "with nothing beyond the default tier to name" 'no-verify-span'
# The two tier flags contradict each other
_ST_RUN --verify-span --no-verify-span --amend-into="$(git rev-parse ':/NV base')" -- nv_app.txt
_ST_EQ "both tier flags together refuse" "$RC" "1"
_ST_OUT_HAS "naming the contradiction" 'verify-span and --no-verify-span cannot be combined'
# And the declined tier survives a pause – a resume that fell back to the config would
# climb to the whole span the run stepped down from
printf 'USE\nstepped\n' > nv_app.txt && git add nv_app.txt
_ST_RUN --verify=false --no-verify-span --amend-into="$(git rev-parse ':/NV base')" -- nv_app.txt
_ST_EQ "the stepped-down fold pauses on its failing check" "$RC" "2"
_ST_OUT_HAS "at the default tier" '# verify 2 commit(s)'
_ST_CHECK "and the pause records the declined tier" sh -c "grep -qx verify_span=0 '$(git rev-parse --git-dir)/git-edit-state'"
_ST_RUN --continue
_ST_EQ "the resume re-pauses" "$RC" "2"
_ST_OUT_HAS "still at the default tier" '# verify 2 commit(s)'
_ST_RUN --abort
# The config names a tier, not a check – with no command it has to stay
# inert, or setting it would refuse every operation in the repo
git config --unset edit.verifyCmd
printf 'USE\nonce more\n' > nv_app.txt && git add nv_app.txt
_ST_RUN --amend-into="$(git rev-parse ':/NV base')" -- nv_app.txt
_ST_EQ "the tier config alone verifies nothing" "$RC" "0"
_ST_OUT_LACKS "and refuses nothing" 'needs a command'
# Nor may it turn a pause into a dead end – a recorded tier no command can
# serve would refuse every resume of an operation already underway, leaving
# an abort as the only way out of a fold that was going fine
printf 'boot\nrewritten\n' > nv_boot.txt && git add nv_boot.txt
_ST_RUN --amend-into="$(git rev-parse ':/NV base')" -- nv_boot.txt
_ST_EQ "the fold conflicts under the tier config" "$RC" "2"
local NV_SF=$(git rev-parse --git-dir)/git-edit-state
_ST_CHECK "and the pause records no tier it cannot serve" sh -c "! grep -q verify_span '$NV_SF'"
local NV_ROUNDS=0
while [ "$RC" = "2" ] && [ $NV_ROUNDS -lt 4 ]; do
	NV_ROUNDS=$((NV_ROUNDS+1))
	local NV_WT=$(print -r -- "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ (;]*\).*/\1/p' | head -1)
	[ -z "$NV_WT" ] && break
	# Each stop resolved to what the commit it builds holds – the fold's line at the target, the
	# bootstrap line added beside it – as one taking that commit's line in early is refused
	if [ "$(git -C "$NV_WT" log -1 --format=%s REBASE_HEAD 2>/dev/null)" = "NV bootstrap line" ]; then
		printf 'boot\nNEEDED\nrewritten\n' > "${NV_WT:-$ST_NO_WT}/nv_boot.txt"
	else
		printf 'boot\nrewritten\n' > "${NV_WT:-$ST_NO_WT}/nv_boot.txt"
	fi
	git -C "$NV_WT" add nv_boot.txt
	_ST_RUN --continue
done
_ST_EQ "the resume completes instead of refusing" "$RC" "0"
_ST_OUT_LACKS "with no demand for a command" 'needs a command'
git config --unset edit.verifySpan
# An explicit zero budget turns the climb off – the wait is the caller's,
# and the same fold climbs again once the budget is back to its default
printf 'nb\n' > nb_app.txt && printf 'nb\n' > nb_boot.txt
git add nb_app.txt nb_boot.txt && git commit -qm "NB base"
local NB_BASE=$(git rev-parse HEAD)
printf 'nb\nREADY\n' > nb_boot.txt && git commit -qam "NB bootstrap line"
printf '#!/bin/sh\ngrep -q USE nb_app.txt 2>/dev/null || exit 0\ngrep -q READY nb_boot.txt\n' > "$TMP/need2.sh"
chmod +x "$TMP/need2.sh"
git config edit.verifyCmd "$TMP/need2.sh"
git config edit.verifyBudget 0
printf 'USE\n' > nb_app.txt && git add nb_app.txt
_ST_RUN --amend-into="$NB_BASE" -- nb_app.txt
_ST_EQ "the failing fold still pauses" "$RC" "2"
_ST_OUT_LACKS "with no climb to report" 'first green'
_ST_RUN --abort
git config --unset edit.verifyBudget
_ST_RUN --amend-into="$NB_BASE" -- nb_app.txt
_ST_EQ "the same fold pauses on the default budget" "$RC" "2"
_ST_OUT_HAS "and climbs to the commit that heals it" 'first green: [0-9a-f]* NB bootstrap line'
_ST_RUN --abort
git config --unset edit.verifyCmd
git reset -q --hard
