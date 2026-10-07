# A rewrite names the notes git's policy left behind
# Copying is git's own call, so the tool reports rather than overrides – the
# same posture as an orphaned tag, which it names but never re-points
_ST_SCENARIO "\e[1;96m[65] a rewrite names the notes left behind\e[0m"
git reset -q --hard
# Scenario 50 turned the config on and left it there, so the unconfigured
# half has to clear it rather than assume a fresh repo
git config --unset notes.rewriteRef 2>/dev/null
printf 'nn\n' > nn.txt && git add nn.txt && git commit -qm "NN target"
local NN_TARGET=$(git rev-parse HEAD)
printf 'nn2\n' > nn2.txt && git add nn2.txt && git commit -qm "NN annotated descendant"
# A non-default ref on purpose: `notes.rewriteRef` is a glob, so the check
# has to look past `refs/notes/commits`
git notes --ref=ge-left add -m "a note worth not losing quietly" HEAD >/dev/null 2>&1
_ST_RUN -M --text="NN target reworded" "$NN_TARGET"
_ST_EQ "the reword over an annotated descendant applies" "$RC" "0"
_ST_OUT_HAS "names the notes left on the replaced commits" 'Notes stayed on [0-9]* replaced commit'
_ST_OUT_HAS "and points at the config that would carry them" 'notes\.rewriteRef'
# Configured, git carries them itself and the notice stays quiet
git config notes.rewriteRef 'refs/notes/*'
printf 'nc\n' > nc.txt && git add nc.txt && git commit -qm "NC target"
local NC_TARGET=$(git rev-parse HEAD)
printf 'nc2\n' > nc2.txt && git add nc2.txt && git commit -qm "NC annotated descendant"
git notes --ref=ge-left add -m "carried by config" HEAD >/dev/null 2>&1
_ST_RUN -M --text="NC target reworded" "$NC_TARGET"
_ST_OUT_LACKS "a carried note draws no notice" 'Notes stayed on [0-9]* replaced commit'
_ST_CHECK "and the note reached the rebuilt commit" \
	sh -c "git notes --ref=ge-left show HEAD >/dev/null 2>&1"
# Negative: a rewrite touching no annotated commit says nothing
git config --unset notes.rewriteRef 2>/dev/null
printf 'nq\n' > nq.txt && git add nq.txt && git commit -qm "NQ target"
local NQ_TARGET=$(git rev-parse HEAD)
printf 'nq2\n' > nq2.txt && git add nq2.txt && git commit -qm "NQ plain descendant"
_ST_RUN -M --text="NQ target reworded" "$NQ_TARGET"
_ST_OUT_LACKS "an unannotated span draws no notice" 'Notes stayed on [0-9]* replaced commit'
git reset -q --hard
