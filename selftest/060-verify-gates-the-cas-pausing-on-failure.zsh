# --verify gates the CAS on the caller's own check

# A rewrite can land semantically wrong yet green – a bad resolution, a fold that breaks a
# later commit – so `--verify=<cmd>` or `edit.verifyCmd` runs the caller's check over the
# built result before the CAS, primary plus tip by default, all of it under `--verify-span`
_ST_SCENARIO "\e[1;96m[60] --verify gates the CAS, pausing on failure\e[0m"
git reset -q --hard
printf '#!/bin/sh\nif grep -q FORBIDDEN vf.txt; then echo VERIFY_SAW_FORBIDDEN; exit 1; fi\nexit 0\n' > "$TMP/verify.sh" && chmod +x "$TMP/verify.sh"
git config edit.verifyCmd "$TMP/verify.sh"
printf 'vf one\n' > vf.txt && git add vf.txt && git commit -qm "VF base"
local VF_BASE=$(git rev-parse HEAD)
printf 'vo\n' > vo.txt && git add vo.txt && git commit -qm "VF top"
local VF_TOP=$(git rev-parse HEAD)
# A clean fold passes at the amended commit and the tip
printf 'vf one\nvf two\n' > vf.txt && git add vf.txt
_ST_RUN --amend-into="$VF_BASE" -- vf.txt
_ST_EQ "a clean fold passes verification" "$RC" "0"
_ST_OUT_HAS "both tiers ran" 'Verified 2 commit(s)'
# A fold that lands failing content pauses before the CAS
local VF_TIP=$(git rev-parse HEAD)
printf 'vf one\nvf two\nFORBIDDEN\n' > vf.txt && git add vf.txt
_ST_RUN --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
_ST_EQ "a failing fold pauses" "$RC" "2"
_ST_OUT_HAS "the pause is a verify pause" 'git-edit: paused – verify failed'
_ST_OUT_HAS "the failing commit is named" 'Verification failed at'
_ST_OUT_HAS "the run's exit status and duration are printed" 'exit 1,'
_ST_OUT_HAS "the trailer names the saved output" '; output in '
local VF_LOG=$(print -r -- "$OUT" | sed -n 's/.*paused – verify failed at [0-9a-f]* in [^;]*; output in \([^;]*\);.*/\1/p' | head -1)
_ST_CHECK "the named file is there" test -f "$VF_LOG"
_ST_CHECK "it holds the failing run's own output" sh -c "grep -q VERIFY_SAW_FORBIDDEN '$VF_LOG'"
_ST_CHECK "headed by the exit status" sh -c "grep -q '^exit: 1' '$VF_LOG'"
_ST_CHECK "and by the command that produced it" sh -c "grep -q '^command: ' '$VF_LOG'"
_ST_EQ "the branch has not moved" "$(git rev-parse HEAD)" "$VF_TIP"
_ST_CHECK "the staged change is untouched" sh -c "! git diff --cached --quiet -- vf.txt"
# --status reports the verify pause as what it is, not as a bare conflict
_ST_RUN --status
_ST_OUT_HAS "status names the verify pause" 'paused – verify failed at'
_ST_OUT_LACKS "and reports no empty conflict" 'git-edit: conflict'
_ST_OUT_HAS "and still names the saved output" '; output in '
# Plain --continue re-verifies and pauses again
_ST_RUN --continue
_ST_EQ "a plain continue re-verifies and pauses" "$RC" "2"
# --abort cancels the paused verdict with nothing consumed
_ST_RUN --abort
_ST_EQ "the verify pause aborts clean" "$RC" "0"
_ST_CHECK "the saved output goes with the state" sh -c "[ ! -f '$VF_LOG' ]"
_ST_EQ "the abort left the branch alone" "$(git rev-parse HEAD)" "$VF_TIP"
_ST_CHECK "and the staged change is still staged" sh -c "! git diff --cached --quiet -- vf.txt"
# The same failing fold pauses again, and `--no-verify --continue` applies it – after
# following the inspect hint, whose checkout moves the worktree off the built result, so
# the resume must restore it or the failing commit lands as the tip
_ST_RUN --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
_ST_EQ "the retried fold pauses again" "$RC" "2"
local VP_WT=$(print -r -- "$OUT" | sed -n 's/.*paused – verify failed at [0-9a-f]* in \([^;]*\);.*/\1/p' | head -1)
local VP_BAD=$(print -r -- "$OUT" | sed -n 's/.*paused – verify failed at \([0-9a-f]*\) in .*/\1/p' | head -1)
if [ -n "$VP_WT" ] && [ -n "$VP_BAD" ]; then
	git -C "$VP_WT" checkout -q "$VP_BAD" 2>/dev/null
fi
_ST_RUN --no-verify --continue
_ST_EQ "the override applies the fold" "$RC" "0"
_ST_OUT_HAS "after restoring the inspected-away worktree" 'restoring'
# The run that lands a result a gate rejected is the one a reader most needs told, and the
# command comes from what the pause recorded rather than from config
_ST_OUT_HAS "and the landing says the gate was overridden" 'Verify skipped'
_ST_OUT_HAS "naming the check the pause had recorded" "$TMP/verify.sh"
_ST_EQ "the whole chain survived" "$(git rev-list --count HEAD)" "$(git rev-list --count $VF_TIP)"
_ST_CHECK "the overridden content landed at the base" \
	sh -c "git show \"\$(git rev-parse ':/VF base'):vf.txt\" | grep -q FORBIDDEN"
# --no-verify up front skips the gate entirely
printf 'vf one\nvf two\nFORBIDDEN\nmore FORBIDDEN\n' > vf.txt && git add vf.txt
_ST_RUN --no-verify --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
_ST_EQ "--no-verify skips the gate up front" "$RC" "0"
_ST_OUT_LACKS "and the check never ran" 'Verified'
# Silence here would read exactly like a repo that configured no gate at all, so the bypass
# says so and names what it bypassed – the one gate state nothing else in the output records
_ST_OUT_HAS "while saying the gate was bypassed" 'Verify skipped'
_ST_OUT_HAS "naming the flag that bypassed it" '--no-verify was passed'
_ST_OUT_HAS "and the command that never ran" "$TMP/verify.sh"
# With nothing configured there was no gate to skip, and a note would invent one – that
# remaining silence is what makes the note above tell the two states apart
git config --unset edit.verifyCmd
printf 'vf ungated\n' >> vf.txt && git add vf.txt
_ST_RUN --no-verify --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
_ST_EQ "an ungated repo folds under --no-verify too" "$RC" "0"
_ST_OUT_LACKS "claiming no gate was skipped" 'Verify skipped'
git config edit.verifyCmd "$TMP/verify.sh"
# The flag outranks the config
git config edit.verifyCmd "false"
printf 'vf flag\n' >> vf.txt && git add vf.txt
_ST_RUN --verify=true --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
_ST_EQ "--verify=<cmd> overrides edit.verifyCmd" "$RC" "0"
git config edit.verifyCmd "$TMP/verify.sh"
# The span tier runs the command once per rebuilt commit
printf '#!/bin/sh\necho x >> %s/vcount\n' "$TMP" > "$TMP/count.sh" && chmod +x "$TMP/count.sh"
rm -f "$TMP/vcount"
printf 'vf span\n' >> vf.txt && git add vf.txt
_ST_RUN --verify="$TMP/count.sh" --verify-span --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
_ST_EQ "the span fold applies" "$RC" "0"
_ST_EQ "every rebuilt commit was verified" "$(wc -l < "$TMP/vcount" | tr -d ' ')" "$(git rev-list --count "$(git rev-parse ':/VF base')^..HEAD")"
# --verify-span without any command is refused loudly
printf 'vf refuse\n' >> vf.txt && git add vf.txt
git config --unset edit.verifyCmd
_ST_RUN --verify-span --amend-into="$(git rev-parse HEAD)" -- vf.txt
_ST_EQ "--verify-span without a command refuses" "$RC" "1"
git reset -q -- vf.txt && git checkout -q -- vf.txt
# The other rebase modes run the same gate – a reorder verifies its tip
# (a pass-through command: vf.txt legitimately carries "FORBIDDEN" by now)
git config edit.verifyCmd "true"
printf 'ra\n' > ra.txt && git add ra.txt && git commit -qm "VR one"
printf 'rb\n' > rb.txt && git add rb.txt && git commit -qm "VR two"
_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
_ST_EQ "a reorder passes through verification" "$RC" "0"
# Both commits are rebuilt, and the default tier checks the first one rebuilt and the tip
_ST_OUT_HAS "and verified its result" 'Verified 2 commit(s)'
_ST_OUT_LACKS "leaving none unchecked" 'unchecked in between'
_ST_OUT_LACKS "with no skip note from a repo-pathless command" 'Verify skipped'
# Plumbing modes have nothing to verify – a reword must not run the check
_ST_RUN -M --text="VR two reworded" "$(git rev-parse HEAD)"
_ST_EQ "a reword still completes" "$RC" "0"
_ST_OUT_LACKS "without running verification" 'Verified'
# A split authors an intermediate tree no commit carried, so the gate covers
# it – here the tip passes by construction while the extracted half does not
printf 'sa\n' > sa.txt && printf 'sb\n' > sb.txt && git add sa.txt sb.txt
git commit -qm "SP both files"
local SP_TIP=$(git rev-parse HEAD)
local SP_COUNT=$(git rev-list --count HEAD)
# The check lives outside the repo, so it names no path the skip heuristic
# could exempt – the absence of sb.txt is the failure, not a missing target
printf '#!/bin/sh\ntest -f sb.txt\n' > "$TMP/spcheck.sh" && chmod +x "$TMP/spcheck.sh"
git config edit.verifyCmd "$TMP/spcheck.sh"
_ST_RUN --split="$SP_TIP" --text "SP extracted sa" -- sa.txt
_ST_EQ "the split is refused on its broken intermediate" "$RC" "1"
_ST_OUT_HAS "saying nothing was applied" 'the split was not applied'
_ST_EQ "and the branch never moved" "$(git rev-parse HEAD)" "$SP_TIP"
# The gate's own pause hints name a worktree removed the line after it fails, and a
# resume that re-derives the halves rather than applying this result
_ST_OUT_LACKS "not pointing into the worktree it removed" 'Inspect the failing state'
_ST_OUT_LACKS "nor at a resume that would re-derive instead" '--no-verify --continue'
git config edit.verifyCmd "true"
_ST_RUN --split="$SP_TIP" --text "SP extracted sa" -- sa.txt
_ST_EQ "a passing check lets the same split through" "$RC" "0"
_ST_EQ "and it really split" "$(git rev-list --count HEAD)" "$((SP_COUNT + 1))"
# `--exec` authors its content instead of replaying a commit somebody already made, so the
# gate covers it too – the mode where an unchecked tree would otherwise reach the branch
printf '#!/bin/sh\nif grep -q EXBAD ex.txt; then exit 1; fi\nexit 0\n' > "$TMP/excheck.sh" && chmod +x "$TMP/excheck.sh"
git config edit.verifyCmd "$TMP/excheck.sh"
printf 'ex\n' > ex.txt && git add ex.txt && git commit -qm "EX base"
local EX_BASE=$(git rev-parse HEAD)
_ST_RUN --exec -- sh -c 'printf "ex good\n" > ex.txt && git commit -qam "EX good"'
_ST_EQ "an --exec commit passes through verification" "$RC" "0"
_ST_OUT_HAS "and its result is verified" 'Verified 1 commit(s)'
_ST_EQ "and the branch moved" "$(git rev-parse HEAD~1)" "$EX_BASE"
local EX_GOOD=$(git rev-parse HEAD)
_ST_RUN --exec -- sh -c 'printf "EXBAD\n" > ex.txt && git commit -qam "EX bad"'
_ST_EQ "an --exec commit the gate rejects is refused" "$RC" "1"
_ST_OUT_HAS "naming the failure" 'Verification failed at'
_ST_OUT_HAS "and where the built history sits" 'Built history is at'
_ST_EQ "with the branch left where it was" "$(git rev-parse HEAD)" "$EX_GOOD"
# No pause here either, so neither hint the pausing modes print may appear
_ST_OUT_LACKS "offering no resume it hasn't got" '--no-verify --continue'
_ST_OUT_LACKS "nor a worktree its exit removes" 'Inspect the failing state'
_ST_RUN --no-verify --exec -- sh -c 'printf "EXBAD\n" > ex.txt && git commit -qam "EX bad, ungated"'
_ST_EQ "--no-verify lets the same --exec through" "$RC" "0"
_ST_EQ "and it landed" "$(git rev-parse HEAD~1)" "$EX_GOOD"
# The gate sits behind the `HEAD`-unchanged return, so a commit-less command pays for no check
_ST_RUN --exec -- true
_ST_EQ "an --exec that moves nothing completes" "$RC" "0"
_ST_OUT_LACKS "without running the check" 'Verified'
# The span tier reaches --exec too, where a command commonly builds a whole run of commits
# and only the tip would otherwise be checked
printf '#!/bin/sh\necho x >> %s/excount\n' "$TMP" > "$TMP/excount.sh" && chmod +x "$TMP/excount.sh"
rm -f "$TMP/excount"
local EX_SPAN_BASE=$(git rev-parse HEAD)
_ST_RUN --verify="$TMP/excount.sh" --verify-span --exec -- sh -c 'printf "one\n" > exs.txt && git add exs.txt && git commit -qm "EXS one" && printf "two\n" > exs.txt && git commit -qam "EXS two"'
_ST_EQ "an --exec span applies" "$RC" "0"
_ST_EQ "and every commit it built was verified" "$(wc -l < "$TMP/excount" | tr -d ' ')" "$(git rev-list --count "$EX_SPAN_BASE..HEAD")"
_ST_OUT_HAS "as the tier says" 'verify 2 commit(s)'
# And an explicit --verify gates --exec rather than being refused as ungatable
local EX_TIP=$(git rev-parse HEAD)
_ST_RUN --verify=false --exec -- sh -c 'printf "ex again\n" > ex.txt && git commit -qam "EX verify flag"'
_ST_EQ "--verify=<cmd> gates --exec instead of refusing" "$RC" "1"
_ST_OUT_HAS "as a verification failure" 'Verification failed at'
_ST_EQ "leaving the branch alone" "$(git rev-parse HEAD)" "$EX_TIP"
# A command that cannot survive the state file is refused, not truncated
printf 'nl\n' > nl.txt && git add nl.txt && git commit -qm "NL base"
local NL_TIP=$(git rev-parse HEAD)
printf 'nl2\n' > nl.txt && git add nl.txt
_ST_RUN --verify=$'echo one\necho two' --amend-into="$NL_TIP" -- nl.txt
_ST_EQ "a multi-line verify command is refused" "$RC" "1"
_ST_OUT_HAS "naming the reason" 'spans multiple lines'
_ST_EQ "with the branch untouched" "$(git rev-parse HEAD)" "$NL_TIP"
_ST_CHECK "and the staged change still staged" sh -c "! git diff --cached --quiet -- nl.txt"
git reset -q -- nl.txt && git checkout -q -- nl.txt
# Completed runs still take their worktrees with them – the interrupt-safety
# rule keeps one only while resumable state is on disk
_ST_EQ "no worktree outlives a finished run" "$(git worktree list | wc -l | tr -d ' ')" "1"
# A target predating the verify command's own files skips, not fails – each
# command token naming a file at the result tip is required at a verified
# commit, so the note replaces a false MODULE_NOT_FOUND-style failure
printf '#!/bin/sh\nexit 0\n' > runner.sh && git add runner.sh && git commit -qm "VS runner"
git config edit.verifyCmd "sh runner.sh"
printf 'vf skip\n' >> vf.txt && git add vf.txt
_ST_RUN --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
_ST_EQ "a fold into a pre-runner commit applies" "$RC" "0"
_ST_OUT_HAS "the absent target is skipped, not failed" 'Verify skipped at'
_ST_OUT_HAS "the note names what is missing" "doesn't exist at this commit"
# The summary counts against what the rewrite built, not against the set the tier picked,
# and names every commit short of it – so one grep of this line cannot read as complete
_ST_OUT_HAS "and the tip still verified" 'Verified 1 of '
_ST_OUT_HAS "the skip named as a shortfall, not just in passing" '1 skipped where a path the command names is absent'
# The span tier verifies what exists and skips the rest
printf 'vf skip span\n' >> vf.txt && git add vf.txt
_ST_RUN --verify-span --amend-into="$(git rev-parse ':/VF base')" -- vf.txt
_ST_EQ "the span fold applies across the gap" "$RC" "0"
local VS_TOTAL=$(git rev-list --count "$(git rev-parse ':/VF base')^..HEAD")
local VS_WITH=$(git rev-list --count "$(git rev-parse ':/VS runner')^..HEAD")
_ST_OUT_HAS "the span verified only where the runner exists" "Verified $VS_WITH of $VS_TOTAL commit(s)"
git config --unset edit.verifyCmd
git reset -q --hard
