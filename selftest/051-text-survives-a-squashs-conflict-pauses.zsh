# A squash's --text has to outlive the conflicts it pauses on

# The override applying it lasts one rebase invocation, so every `--continue`
# spawned its own process without it and the fold silently kept git's default
# combined message – a wrong result the run still reported as ok
_ST_SCENARIO "\e[1;96m[51] --text survives a squash's conflict pauses\e[0m"
git reset -q --hard
local N
# Each commit adds a line, so the reordered replay conflicts yet resolves back to the tip
for N in 1 2 3 4; do
	printf 'tx%s\n' {1..$N} > tx.txt && git add tx.txt && git commit -qm "TX $N"
done
local TX_TARGET=$(git log --format=%H --grep='^TX 2$' -1)
local TX_VICTIM=$(git log --format=%H --grep='^TX 4$' -1)
_ST_RUN -s="$TX_TARGET" -y --text="$(printf 'TX folded subject\n\n• TX folded body')" "$TX_VICTIM"
_ST_EQ "the squash pauses on a conflict" "$RC" "2"
local TX_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
_ST_RESOLVE "$TX_WT" tx.txt $'tx1\ntx2\ntx4'
_ST_RUN --continue
_ST_OUT_HAS "pauses on a conflict, not a wedge" 'Conflicted files:'
_ST_RESOLVE "$TX_WT" tx.txt $'tx1\ntx2\ntx3\ntx4'
_ST_RUN --continue
_ST_EQ "the resumed squash settles" "$RC" "0"
_ST_EQ "the fold carries --text, not the combined default" \
	"$(git log --format=%s --skip=1 -1)" "TX folded subject"
_ST_CHECK "including its body" \
	sh -c "git log --format=%B --skip=1 -1 | grep -q '• TX folded body'"
_ST_CHECK "and no commit kept git's squash boilerplate" \
	sh -c "! git log --format=%B | grep -q 'This is a combination of'"
_ST_EQ "the replayed commit keeps its own message" "$(git log --format=%s -1)" "TX 3"

# Folding an older commit forward replays the commits it skipped first, and
# a resume commits those too – each opening an editor the fold's message
# must not answer, or an untouched commit silently takes the fold's subject
git reset -q --hard
for N in 1 2 3 4; do
	printf 'tf%s\n' {1..$N} > tf.txt && git add tf.txt && git commit -qm "TF $N"
done
local TF_VICTIM=$(git log --format=%H --grep='^TF 2$' -1)
local TF_TARGET=$(git log --format=%H --grep='^TF 4$' -1)
_ST_RUN -s="$TF_TARGET" -y --text="TF folded subject" "$TF_VICTIM"
_ST_EQ "folding forward pauses before reaching the fold" "$RC" "2"
local TF_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
_ST_RESOLVE "$TF_WT" tf.txt $'tf1\ntf3'
_ST_RUN --continue
_ST_OUT_HAS "pauses on a conflict, not a wedge" 'Conflicted files:'
_ST_RESOLVE "$TF_WT" tf.txt $'tf1\ntf2\ntf3\ntf4'
_ST_RUN --continue
_ST_EQ "the forward fold settles" "$RC" "0"
_ST_EQ "the fold still takes --text" "$(git log --format=%s -1)" "TF folded subject"
_ST_EQ "the commit replayed ahead of it is untouched" "$(git log --format=%s --skip=1 -1)" "TF 3"
git reset -q --hard

# A fold must not edit the messages of the commits it replays past, and the message here
# carries a `#` line, which is what makes that a real assertion – git's own rebase drops
# those from any commit it stops on, and the fold's cleanup leaves `# Conflicts:` instead
git reset -q --hard
printf 'tr1\n' > tr.txt && git add tr.txt && git commit -qm "TR 1"
printf 'tr1\ntr2\n' > tr.txt && git add tr.txt && git commit -qm "TR 2 target"
printf 'tr1\ntr2\ntr3\n' > tr.txt && git add tr.txt
git commit -q -F - <<-'TRMSG'
	TR 3 replayed

	refs:
	#77 belongs to this commit
TRMSG
printf 'tr1\ntr2\ntr3\ntr4\n' > tr.txt && git add tr.txt && git commit -qm "TR 4 victim"
local TR_BEFORE=$(git log --format=%B --grep='^TR 3 replayed$' -1)
_ST_RUN -s="$(git log --format=%H --grep='^TR 2 target$' -1)" -y --text="TR folded subject" \
	"$(git log --format=%H --grep='^TR 4 victim$' -1)"
local TR_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
_ST_RESOLVE "$TR_WT" tr.txt $'tr1\ntr2\ntr4'
_ST_RUN --continue
_ST_OUT_HAS "pauses on a conflict, not a wedge" 'Conflicted files:'
_ST_RESOLVE "$TR_WT" tr.txt $'tr1\ntr2\ntr3\ntr4'
_ST_RUN --continue
_ST_EQ "the replay settles" "$RC" "0"
_ST_EQ "a replayed commit's message survives byte for byte" \
	"$(git log --format=%B --grep='^TR 3 replayed$' -1)" "$TR_BEFORE"
_ST_EQ "its own '#' line included" \
	"$(git log --format=%B | grep -c '^#77 belongs to this commit$')" "1"
_ST_CHECK "with none of git's conflict template in it" \
	sh -c "! git log --format=%B | grep -q 'Conflicts:'"
git reset -q --hard

# A conflict exits straight from the handler, past the `rm` that follows the
# call – so the message file it wrote survived the run, once per pause
local TX_TMP_BEFORE=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'git-edit-squash-msg.*' 2>/dev/null | grep -c .)
local TX_ED_BEFORE=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'git-edit-fold-editor.*' 2>/dev/null | grep -c .)
for N in 1 2 3 4; do
	echo "tl$N" > tl.txt && git add tl.txt && git commit -qm "TL $N"
done
_ST_RUN -s="$(git log --format=%H --grep='^TL 2$' -1)" -y --text="TL folded subject" \
	"$(git log --format=%H --grep='^TL 4$' -1)"
_ST_EQ "the leak probe's fold pauses" "$RC" "2"
_ST_RUN --abort
local TX_TMP_AFTER=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'git-edit-squash-msg.*' 2>/dev/null | grep -c .)
_ST_EQ "a paused fold leaves no temp message behind" "$TX_TMP_AFTER" "$TX_TMP_BEFORE"
# The stand-in is built inside a command substitution, so registering it for
# cleanup there would only ever reach a subshell's copy of the list
local TX_ED_AFTER=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'git-edit-fold-editor.*' 2>/dev/null | grep -c .)
_ST_EQ "nor the editor stand-in it built" "$TX_ED_AFTER" "$TX_ED_BEFORE"
git reset -q --hard
