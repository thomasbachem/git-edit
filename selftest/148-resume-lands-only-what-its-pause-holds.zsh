# A resume lands only what its own pause holds – no peer's landing read as its own, no replay a
# hand finished with markers committed or redid elsewhere, no commit a gate pause never built – and
# a prompt or a label answers only for the pause and the stop it was given
_ST_SCENARIO "\e[1;96m[148] a resume lands only what its pause holds, a prompt or a label only its own\e[0m"
local HF_T HF_WT HF_SF HF_R HF_I
local -i HF_W
# Finishes a rebase in <worktree> by hand as a careless resolver would, staging all as it stands
_HF_HAND_FINISH () {
	for HF_I in 1 2 3 4 5; do
		git -C "$1" add -A && GIT_EDITOR=true git -C "$1" rebase --continue >/dev/null 2>&1 && return 0
	done
	return 1
}
# A peer's drop of everything above a paused edit lands on the paused commit itself – passing the
# in-flight check before the pause, the state file held aside standing in for that race
_ST_PZ_NEW hf1
_ST_PZ_C a.txt a "HF a" && _ST_PZ_C b.txt b "HF b" && _ST_PZ_C c.txt c "HF c" && _ST_PZ_C d.txt d "HF d"
HF_T=$(git rev-parse HEAD~2)
HF_SF="$(git rev-parse --git-common-dir)/git-edit-state"
GIT_EDIT_ACTOR=hf-a _ST_RUN "$HF_T"
HF_WT=$(_ST_PZ_WT)
print -r -- edited > "${HF_WT:-$ST_NO_WT}/b.txt"
mv "$HF_SF" "$TMP/hf-held" && GIT_EDIT_ACTOR=hf-b _ST_RUN -d -y HEAD~1 HEAD
mv "$TMP/hf-held" "$HF_SF"
_ST_EQ "a peer's drop lands the branch on the paused commit" "$RC:$(git rev-parse HEAD)" "0:$HF_T"
GIT_EDIT_ACTOR=hf-a _ST_RUN --continue
_ST_EQ "the edit's resume lands the edit there, never read as landed already" "$RC:$(git show HEAD:b.txt):$(git log -1 --format=%s)" "0:edited:HF b"
_ST_OUT_LACKS "nor said to have landed" 'had landed already'
# A drop's stop finished by hand with its markers staged lands nothing
_ST_PZ_NEW hf2
_ST_PZ_C f.txt $'1\n2\n3' "HF2 c1" && _ST_PZ_C f.txt $'1\n2x\n3' "HF2 c2" && _ST_PZ_C f.txt $'1\n2xy\n3' "HF2 c3"
HF_T=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~1
HF_WT=$(_ST_PZ_WT)
_HF_HAND_FINISH "${HF_WT:-$ST_NO_WT}"
_ST_RUN --continue
_ST_EQ "a drop finished by hand with markers committed lands nothing" "$RC:$(git rev-parse HEAD)" "1:$HF_T"
_ST_OUT_HAS "naming what carries them" 'committed conflict markers'
# While one the resolver amended clean lands
print -r -- $'1\n2y\n3' > "${HF_WT:-$ST_NO_WT}/f.txt"
git -C "${HF_WT:-$ST_NO_WT}" commit -qa --amend --no-edit
_ST_RUN --continue
_ST_EQ "and one finished by hand clean lands" "$RC:$(git show HEAD:f.txt | tr '\n' ' ')" "0:1 2y 3 "
# So does a replant's, and a replant redone by hand onto another base, finished or in progress
_ST_PZ_NEW hf3
_ST_PZ_C f.txt $'1\n2\n3' "HF3 A" && git branch up && git branch other
_ST_PZ_C f.txt $'1\nF\n3' "HF3 F1" && _ST_PZ_C g.txt g "HF3 F2"
git checkout -q up && _ST_PZ_C f.txt $'1\nU\n3' "HF3 U"
git checkout -q other && _ST_PZ_C o.txt o "HF3 O" && git checkout -q main
HF_T=$(git rev-parse HEAD)
_ST_RUN --onto=up
HF_WT=$(_ST_PZ_WT)
_HF_HAND_FINISH "${HF_WT:-$ST_NO_WT}"
_ST_RUN --continue
_ST_EQ "a replant finished by hand with markers committed lands nothing" "$RC:$(git rev-parse HEAD)" "1:$HF_T"
_ST_OUT_HAS "naming what carries them" 'committed conflict markers'
_ST_RUN --abort
_ST_RUN --onto=up
HF_WT=$(_ST_PZ_WT)
git -C "${HF_WT:-$ST_NO_WT}" rebase --abort && git -C "${HF_WT:-$ST_NO_WT}" rebase -q --onto other HEAD~2 >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a replant redone by hand onto another base lands nothing" "$RC:$(git rev-parse HEAD)" "1:$HF_T"
_ST_OUT_HAS "naming the upstream it was to build on" 'is not built on up'
_ST_RUN --abort
_ST_RUN --onto=up
HF_WT=$(_ST_PZ_WT)
git -C "${HF_WT:-$ST_NO_WT}" rebase --abort && git -C "${HF_WT:-$ST_NO_WT}" rebase -q -x "test -e $TMP/hf-go" --onto other HEAD~2 >/dev/null 2>&1
: > "$TMP/hf-go"
_ST_RUN --continue
_ST_EQ "and one still in progress there lands nothing" "$RC:$(git rev-parse HEAD)" "1:$HF_T"
_ST_OUT_HAS "named as not the replant's" "is not this replant's"
# Another label's --skip is named as a skip
GIT_EDIT_ACTOR=hf-b _ST_RUN --skip
_ST_OUT_HAS "a refused --skip says skip" 'refusing to skip it as hf-b'
_ST_RUN --abort
# An edit's replay finished by hand with markers committed lands nothing
_ST_PZ_NEW hf4
_ST_PZ_C g.txt $'1\n2\n3' "HF4 G1" && _ST_PZ_C g.txt $'1\n2x\n3' "HF4 G2"
HF_T=$(git rev-parse HEAD)
_ST_RUN HEAD~1
HF_WT=$(_ST_PZ_WT)
print -r -- $'1\nE\n3' > "${HF_WT:-$ST_NO_WT}/g.txt"
_ST_RUN --continue
_HF_HAND_FINISH "${HF_WT:-$ST_NO_WT}"
_ST_RUN --continue
_ST_EQ "an edit's replay finished by hand with markers committed lands nothing" "$RC:$(git rev-parse HEAD)" "1:$HF_T"
_ST_OUT_HAS "naming what carries them" 'committed conflict markers'
_ST_RUN --abort
# As does a fold's, and a fold or a reorder whose worktree runs a rebase begun there by hand
_ST_PZ_NEW hf5
_ST_PZ_C h.txt $'1\n2\n3' "HF5 H1" && _ST_PZ_C h.txt $'1\n2x\n3' "HF5 H2" && _ST_PZ_C h.txt $'1\n2xy\n3' "HF5 H3"
HF_T=$(git rev-parse HEAD)
print -r -- $'1\nZ\n3' > h.txt && git add h.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" -- h.txt
HF_WT=$(_ST_PZ_WT)
_HF_HAND_FINISH "${HF_WT:-$ST_NO_WT}"
_ST_RUN --continue
_ST_EQ "a fold finished by hand with markers committed lands nothing" "$RC:$(git rev-parse HEAD)" "1:$HF_T"
_ST_OUT_HAS "naming what carries them" 'committed conflict markers'
_ST_RUN --abort
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" -- h.txt
HF_WT=$(_ST_PZ_WT)
git -C "${HF_WT:-$ST_NO_WT}" rebase --abort && git -C "${HF_WT:-$ST_NO_WT}" checkout -q --detach HEAD~1 && \
	git -C "${HF_WT:-$ST_NO_WT}" rebase -q -x false HEAD~1 >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a fold's worktree running a rebase begun by hand lands nothing" "$RC:$(git rev-parse HEAD)" "1:$HF_T"
_ST_OUT_HAS "named as not the fold's" "is not this fold's"
_ST_RUN --abort
git reset -q --hard
_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
HF_WT=$(_ST_PZ_WT)
git -C "${HF_WT:-$ST_NO_WT}" rebase --abort && git -C "${HF_WT:-$ST_NO_WT}" checkout -q --detach HEAD~1 && \
	git -C "${HF_WT:-$ST_NO_WT}" rebase -q -x false HEAD~1 >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "as does a reorder's" "$RC:$(git rev-parse HEAD)" "1:$HF_T"
_ST_OUT_HAS "named as not the reorder's" "is not this reorder's"
_ST_RUN --abort
# A gate pause whose result was amended refuses rather than restore it away, while an inspect
# checkout of a commit the result holds is restored
_ST_PZ_NEW hf6
_ST_PZ_C a.txt a "HF6 a" && _ST_PZ_C b.txt b "HF6 b" && _ST_PZ_C c.txt c "HF6 c"
HF_T=$(git rev-parse HEAD)
HF_SF="$(git rev-parse --git-common-dir)/git-edit-state"
_ST_RUN -d -y --verify='test -f fix.txt' HEAD~1
HF_WT=$(_ST_PZ_WT)
HF_R=$(sed -n 's/^verify_result=//p' "$HF_SF" | tail -1)
print -r -- fix > "${HF_WT:-$ST_NO_WT}/fix.txt"
git -C "${HF_WT:-$ST_NO_WT}" add fix.txt && git -C "${HF_WT:-$ST_NO_WT}" commit -q --amend --no-edit
_ST_RUN --no-verify --continue
_ST_EQ "an amend at a gate pause refuses, the branch untouched" "$RC:$(git rev-parse HEAD)" "1:$HF_T"
_ST_OUT_HAS "naming a commit the result does not hold" "does not hold"
git -C "${HF_WT:-$ST_NO_WT}" reset -q --hard "${HF_R:-HEAD}" && git -C "${HF_WT:-$ST_NO_WT}" checkout -q --detach HEAD~1
_ST_RUN --no-verify --continue
_ST_EQ "an inspect checkout inside the result is restored and lands" "$RC:$(git rev-parse HEAD)" "0:$HF_R"
_ST_OUT_HAS "saying so" 'restoring'
# A state file cut short keeps its owner, or with nothing readable left refuses a labeled caller
_ST_PZ_NEW hf7
_ST_PZ_C f.txt $'1\n2\n3' "HF7 c1" && _ST_PZ_C f.txt $'1\n2x\n3' "HF7 c2" && _ST_PZ_C f.txt $'1\n2xy\n3' "HF7 c3"
HF_SF="$(git rev-parse --git-common-dir)/git-edit-state"
GIT_EDIT_ACTOR=hf-a _ST_RUN -d -y HEAD~1
head -n 3 "$HF_SF" > "$TMP/hf-cut" && cat "$TMP/hf-cut" > "$HF_SF"
GIT_EDIT_ACTOR=hf-b _ST_RUN --abort
_ST_EQ "another label's abort of a pause cut short refuses" "$RC:$([ -f "$HF_SF" ] && echo kept)" "1:kept"
_ST_OUT_HAS "naming whose it is" "is hf-a's"
printf 'act' > "$HF_SF"
GIT_EDIT_ACTOR=hf-b _ST_RUN --abort
_ST_EQ "as does one cut to nothing readable" "$RC:$([ -f "$HF_SF" ] && echo kept)" "1:kept"
_ST_OUT_HAS "saying its owner is unknown" 'names neither its caller nor its operation'
GIT_EDIT_ACTOR=hf-b _ST_RUN --abort --allow-other-actor
_ST_EQ "which --allow-other-actor clears" "$RC:$([ -f "$HF_SF" ] && echo kept)" "0:"
# Enter at a prompt whose pause another run took on to a later stop stages and resumes nothing
_ST_PZ_NEW hf8
printf '1\n2\n3\n' > f.txt && print g > g.txt && git add -A && git commit -qm "HF8 c1"
printf '1\n2x\n3\n' > f.txt && print g2 > g.txt && git add -A && git commit -qm "HF8 c2"
_ST_PZ_C f.txt $'1\n2xy\n3' "HF8 c3" && git rm -q g.txt && git commit -qm "HF8 c4"
HF_T=$(git rev-parse HEAD)
_ST_TTY_START -- -d -y HEAD~2
if _ST_TTY_AT 'Resolve the conflicts in'; then
	HF_WT=$(_ST_PZ_WT)
	_ST_RESOLVE "${HF_WT:-$ST_NO_WT}" f.txt $'1\n2y\n3'
	_ST_RUN --continue
	zpty -wn ST_TTY $'\r'
fi
_ST_TTY_END
_ST_EQ "Enter at a prompt resumed on by another run does nothing" "$RC:$(git rev-parse HEAD)" "1:$HF_T"
_ST_OUT_HAS "saying the pause it showed is no longer pending" 'no longer pending'
_ST_EQ "leaving the later stop's file unmerged" "$(git -C "${HF_WT:-$ST_NO_WT}" ls-files -u -- g.txt | wc -l | tr -d ' ')" "2"
_ST_RUN --abort
# A q at a prompt a refusal brought back ends as the pause, not as that refusal
_ST_PZ_NEW hf9
_ST_PZ_C a.txt a "HF9 a" && _ST_PZ_C b.txt b "HF9 b"
_ST_TTY_START -- HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	zpty -wn ST_TTY $'\r'
	if _ST_TTY_AT 'to leave it paused' 2; then
		print -r -- a2 > "${$(_ST_PZ_WT):-$ST_NO_WT}/a.txt"
		zpty -wn ST_TTY q
	fi
fi
_ST_TTY_END
_ST_EQ "q after a refusal's re-prompt leaves the pause, ending on its paused trailer" "$RC:$([[ "${OUT##*$'\n'}" == "git-edit: paused"* ]] && echo paused)" "2:paused"
_ST_OUT_HAS "the refusal told before it" 'Nothing to amend'
_ST_RUN --abort
# A fold whose stop at its target is resolved to the file as the tip holds it absorbs what later
# commits change there – refused, naming them – while one resolved to the target's own content lands
_ST_PZ_NEW hf10
print -l -- 1 2 3 4 5 6 7 8 9 10 11 12 > f.txt && git add f.txt && git commit -qm "HF10 base"
print -l -- 1 2 3 4 5 6 7 8 9 10 11 T12 > f.txt && git commit -qam "HF10 target"
HF_R=$(git rev-parse HEAD)
print -l -- 1 a2 a3 a4 5 6 7 8 9 10 11 T12 > f.txt && print g1 > g1.txt && git add -A && git commit -qm "HF10 later one"
print -l -- 1 a2 a3 a4 5 b6 b7 b8 9 10 11 T12 > f.txt && print g2 > g2.txt && git add -A && git commit -qm "HF10 later two"
HF_T=$(git rev-parse HEAD)
print -l -- 1 a2 a3 a4 5 b6 b7 b8 E9 10 11 T12 > f.txt
_ST_RUN --amend-into="$HF_R" --whole -- f.txt
_ST_OUT_HAS "the fold's stop says it builds the target itself" 'This stop folds into .* HF10 target itself'
HF_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${HF_WT:-$ST_NO_WT}" f.txt "$(print -l -- 1 a2 a3 a4 5 b6 b7 b8 E9 10 11 T12)"
_ST_RUN --continue
_ST_EQ "a fold resolved to the tip's content refuses" "$RC:$(git rev-parse HEAD)" "1:$HF_T"
_ST_OUT_HAS "naming the later commit it absorbed" 'HF10 later one – f.txt'
_ST_RUN --abort
git checkout -q -- f.txt && print -l -- 1 a2 a3 a4 5 b6 b7 b8 E9 10 11 T12 > f.txt
_ST_RUN --amend-into="$HF_R" --whole -- f.txt
HF_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${HF_WT:-$ST_NO_WT}" f.txt "$(print -l -- 1 2 3 4 5 6 7 8 E9 10 11 T12)"
_ST_RUN --continue
_ST_EQ "one resolved to the target's own content lands, each later commit keeping its change" \
	"$RC:$(git diff --stat HEAD~2 HEAD~1 -- f.txt | grep -c f.txt):$(git show HEAD:f.txt | tr '\n' ' ')" "0:1:1 a2 a3 a4 5 b6 b7 b8 E9 10 11 T12 "
# A resume held in its gate while its pause is aborted and another run pauses lands over, notes
# into and clears nothing of that run's pause – its worktree lock taken away first, as nothing else
# lets an abort in while it lives
_ST_PZ_NEW hf11
_ST_PZ_C a.txt a "HF11 a" && _ST_PZ_C b.txt b "HF11 b"
_ST_PZ_C f.txt $'1\n2\n3' "HF11 f1" && _ST_PZ_C f.txt $'1\n2x\n3' "HF11 f2" && _ST_PZ_C f.txt $'1\n2xy\n3' "HF11 f3"
HF_T=$(git rev-parse HEAD)
HF_SF="$(git rev-parse --git-common-dir)/git-edit-state"
_ST_RUN HEAD~3
print -r -- b2 > "${$(_ST_PZ_WT):-$ST_NO_WT}/b.txt"
rm -f "$TMP/hf-check" "$TMP/hf-release"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue --verify="sh -c ': > \"$TMP/hf-check\"; \"$TMP/st-hold\" \"$TMP/hf-release\"'" </dev/null >"$TMP/hf-out" 2>&1 &
HF_I=$!
HF_W=0
until [ -e "$TMP/hf-check" ] || ! kill -0 $HF_I 2>/dev/null || (( ++HF_W > 1200 )); do sleep 0.1; done
rm -f "$(git -C "$(_ST_PZ_WT)" rev-parse --absolute-git-dir 2>/dev/null)/git-edit-run.lock"
_ST_RUN --abort
_ST_RUN -d -y HEAD~1
HF_WT=$(_ST_PZ_WT)
: > "$TMP/hf-release"
wait $HF_I
RC=$? OUT=$(<"$TMP/hf-out")
_ST_EQ "a resume whose pause another run ended meanwhile lands nothing" "$RC:$(git rev-parse HEAD)" "1:$HF_T"
_ST_OUT_HAS "saying so" 'ended by another run meanwhile'
_ST_EQ "the new run's pause is left as it paused" "$(_ST_PZ_WT):$(grep -c '^verify_' "$HF_SF")" "$HF_WT:0"
_ST_RESOLVE "${HF_WT:-$ST_NO_WT}" f.txt $'1\n2y\n3'
_ST_RUN --continue
_ST_EQ "and resumes as its own" "$RC:$(git log -1 --format=%s HEAD~1)" "0:HF11 f1"
unfunction _HF_HAND_FINISH
cd "$TMP/repo"
