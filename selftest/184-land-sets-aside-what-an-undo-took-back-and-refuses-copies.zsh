# `--land` sets aside exactly what an undone land brought – by its commits and its window, whatever
# it was named – and never guesses a copy landed: a branch commit that looks like one of the
# target's refuses the land, naming each, with steps that land as printed – the branch moved onto
# the copies, the --base past them, the fold into the target's own rewrite of it – while a commit
# the target took by another branch's land stays out by that land's record, a refusal names no
# --base ending in the merge refusal, and a dry run's "Land it:" keeps the --base it was given
_ST_SCENARIO "\e[1;96m[184] --land sets aside what an undo took back and refuses a copy it would guess at\e[0m"
local Q1_T Q1_C Q1_F
local -i Q1_I Q1_PID
mkdir -p "$TMP/q1-bin" && ln -sf "$SELF" "$TMP/q1-bin/git-edit"
# Runs a printed `git edit …` or `git -C <path> edit …` step as a caller would – past the suite's
# `git`, whose clock a subshell would wind back to the parent's tick
_Q1_AS_PRINTED () {
	[[ "$1" == "git edit "* || "$1" == "git -C "*" edit "* ]] || return 1
	( export PATH="$TMP/q1-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1; eval "command $1" </dev/null ) > "$TMP/q1-step.out" 2>&1
}
# Prints the step after <lead> in `OUT`, its color codes cut
_Q1_STEP () {
	local S=$(print -r -- "$OUT" | sed -n "s/^.*$1//p" | head -1)
	print -r -- "${S%%$'\e'*}"
}

# A land of a revision taken back counts for the branch, as its commits do – both land, the fork
# said as set aside by that land, and a dry run with --base keeps it in the command it prints
_ST_PZ_NEW q1a
_ST_PZ_C a.txt a "Q1A base"
git checkout -q -b feat && _ST_PZ_C b.txt b "Q1A F1" && _ST_PZ_C c.txt c "Q1A F2" && git checkout -q main
_ST_RUN --land=feat --base="$(git rev-parse main)" --dry-run
_ST_OUT_HAS "a fast-forward's dry run keeps its --base" "Land it: git edit --land=feat --base=$(git rev-parse --short=12 main)$"
_ST_RUN --land=feat~1
_ST_RUN --undo
_ST_RUN --land=feat
_ST_EQ "a land of feat~1 taken back – feat lands both its commits" "$RC:$(git log --format=%s | tr '\n' '|')" "0:Q1A F2|Q1A F1|Q1A base|"
_ST_OUT_HAS "the fork said as set aside by that land" 'a land of feat~1 that --undo took back set aside'
# Held again by a value outside the window and dropped since, the commit stays out
_ST_PZ_NEW q1b
_ST_PZ_C a.txt a "Q1B base"
git checkout -q -b feat && _ST_PZ_C b.txt b "Q1B F1" && _ST_PZ_C c.txt c "Q1B F2" && git checkout -q main
_ST_RUN --land=feat~1
_ST_RUN --undo
git merge -q --ff-only feat~1
_ST_RUN -d HEAD
_ST_RUN --land=feat
_ST_EQ "one held again outside the window, then dropped, stays out" "$RC:$(git log --format=%s | tr '\n' '|')" "0:Q1B F2|Q1B base|"

# A land taken back after a fold or a reword below it inside its window – its commits land again,
# never held by the rewrite's copies of them
for Q1_F in fold reword; do
	_ST_PZ_NEW q1c-$Q1_F
	_ST_PZ_C a.txt a "Q1C base"
	git worktree add -q -b feat "$TMP/q1c-$Q1_F-wt" main 2>/dev/null
	( cd "$TMP/q1c-$Q1_F-wt" && _ST_PZ_C b.txt b "Q1C F1" && _ST_PZ_C c.txt c "Q1C F2" )
	_ST_PZ_C m.txt m "Q1C M1"
	_ST_RUN --land=feat
	git reset -q --hard
	if [ "$Q1_F" = fold ]; then
		print -r -- m2 > m.txt && git add m.txt
		_ST_RUN --amend-into="$(git rev-parse HEAD~2)"
	else
		_ST_RUN -M --subject="Q1C M1 reworded" HEAD~2
	fi
	_ST_RUN --undo
	_ST_RUN --undo
	git reset -q --hard
	_ST_RUN --land=feat
	_ST_EQ "a land taken back past a $Q1_F below it – both its commits land again" "$RC:$(git log --format=%s | tr '\n' '|')" "0:Q1C F2|Q1C F1|Q1C M1|Q1C base|"
	git worktree remove --force "$TMP/q1c-$Q1_F-wt"
done

# A commit main dropped and one it rewrote, inside a catch-up merge – the rewrite named as such, and
# no --base back from the fork, which would end in the merge refusal, while the one past the merge
# lands as printed, and its dry run keeps that --base
_ST_PZ_NEW q1d
_ST_PZ_C a.txt a "Q1D base"
git worktree add -q -b feat "$TMP/q1d-wt" main 2>/dev/null
( cd "$TMP/q1d-wt" && _ST_PZ_C b.txt b "Q1D F1" )
_ST_PZ_C p.txt p "Q1D P"
_ST_PZ_C q.txt q "Q1D Q"
( cd "$TMP/q1d-wt" && git merge -q --no-edit main && _ST_PZ_C c.txt c "Q1D F2" )
_ST_RUN -d HEAD~1
git reset -q --hard
Q1_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "a merge carrying a dropped and a rewritten commit – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$Q1_T"
_ST_OUT_HAS "the dropped one named" '^  [0-9a-f]* Q1D P$'
_ST_OUT_HAS "the rewritten one named with its copy" "^  [0-9a-f]* Q1D Q – rewritten since, held as $(git rev-parse --short=7 HEAD)$"
_ST_OUT_LACKS "no --base back from the fork" 'land them back all the same'
Q1_C=$(_Q1_STEP 'Land what follows the last of them: ')
_ST_EQ "the --base past the merge offered" "$Q1_C" "git edit --land=feat --base=$(git -C "$TMP/q1d-wt" rev-parse --short=12 HEAD~1)"
_ST_RUN --land=feat --base="$(git -C "$TMP/q1d-wt" rev-parse HEAD~1)" --dry-run
_ST_OUT_HAS "a replay's dry run keeps its --base" "Land it: git edit --land=feat --base=$(git -C "$TMP/q1d-wt" rev-parse --short=12 HEAD~1)$"
_Q1_AS_PRINTED "$Q1_C"
_ST_EQ "which lands what follows it" "$(git log --format=%s | tr '\n' '|')" "Q1D F2|Q1D Q|Q1D base|"
git worktree remove --force "$TMP/q1d-wt"

# A second land after a replay, the branch never moved onto the copies, refuses – the move from its
# checkout offered, which lands only the new commit after it, while first lands go through
_ST_PZ_NEW q1e
_ST_PZ_C a.txt a "Q1E base"
git worktree add -q -b feat "$TMP/q1e-wt" main 2>/dev/null
( cd "$TMP/q1e-wt" && _ST_PZ_C b.txt b "Q1E F1" && _ST_PZ_C c.txt c "Q1E F2" )
_ST_PZ_C m.txt m "Q1E M1"
_ST_RUN --land=feat
_ST_EQ "a first land replays, no refusal" "$RC:$(git log --format=%s | tr '\n' '|')" "0:Q1E F2|Q1E F1|Q1E M1|Q1E base|"
git reset -q --hard
( cd "$TMP/q1e-wt" && _ST_PZ_C d.txt d "Q1E F3" )
Q1_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "the second land, the branch not moved – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$Q1_T"
_ST_OUT_HAS "each copy named" "^  [0-9a-f]* Q1E F1 – on main as $(git rev-parse --short=7 HEAD~1), change and message alike$"
_ST_OUT_LACKS "never left out as landed" 'left out'
Q1_C=$(_Q1_STEP "Move feat onto main's copies, then run it again: ")
_ST_EQ "the move from the branch's checkout offered" "${${Q1_C#git -C }%% *}:${Q1_C##* }" "${TMP:A}/q1e-wt:--onto=main"
_Q1_AS_PRINTED "$Q1_C"
_ST_RUN --land=feat
_ST_EQ "run as printed, the land lands the new commit alone" "$RC:$(git log --format=%s | tr '\n' '|')" "0:Q1E F3|Q1E F2|Q1E F1|Q1E M1|Q1E base|"
_ST_OUT_HAS "as a fast-forward" 'a fast-forward of 1 commit(s)'
git worktree remove --force "$TMP/q1e-wt"

# A fold on the branch while a land of it replays – the land run again refuses on the folded commit
# with the fold of its change, never as landed already
_ST_PZ_NEW q1f
_ST_PZ_C a.txt a "Q1F base"
git worktree add -q -b feat "$TMP/q1f-wt" main 2>/dev/null
( cd "$TMP/q1f-wt" && _ST_PZ_C b.txt b "Q1F F1" && _ST_PZ_C c.txt c "Q1F F2" )
_ST_PZ_C m.txt m "Q1F M1"
mkdir -p "$TMP/q1f-git"
{
	print -r -- '#!/bin/sh'
	print -r -- "case \" \$* \" in *\" rebase \"*\"--onto \"*) if [ -e ${(q)TMP}/q1f-git/arm ]; then mv ${(q)TMP}/q1f-git/arm ${(q)TMP}/q1f-git/in; ${(q)TMP}/st-hold ${(q)TMP}/q1f-git/go; fi ;; esac"
	print -r -- "exec ${(q)commands[git]} \"\$@\""
} > "$TMP/q1f-git/git"
chmod +x "$TMP/q1f-git/git"
: > "$TMP/q1f-git/arm"
( PATH="$TMP/q1f-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --land=feat </dev/null > "$TMP/q1f.land" 2>&1 ) &
Q1_PID=$!
Q1_I=0; until [ -e "$TMP/q1f-git/in" ] || ! kill -0 "$Q1_PID" 2>/dev/null || (( ++Q1_I > 1200 )); do sleep 0.1; done
cd "$TMP/q1f-wt"
print -r -- fix >> b.txt && git add b.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~1)"
cd "$TMP/pz-q1f"
: > "$TMP/q1f-git/go"
wait "$Q1_PID"
_ST_EQ "the fold landed on the branch while the land replayed" "$([ -e "$TMP/q1f-git/in" ] && print held):$(git show feat~1:b.txt | tr '\n' ' '):$(git log -1 --format=%s HEAD~1)" "held:b fix :Q1F F1"
git reset -q --hard
_ST_RUN --land=feat
_ST_EQ "the land run again refuses" "$RC" "1"
_ST_OUT_HAS "naming the folded commit against main's copy" '^  [0-9a-f]* Q1F F1 – like [0-9a-f]* main took, another patch$'
_ST_OUT_LACKS "never as landed already" 'already landed'
Q1_C=$(_Q1_STEP 'fold it into [0-9a-f]*: ')
_Q1_AS_PRINTED "$Q1_C"
_ST_EQ "whose fold, run as printed, brings the fix to main" "$(git show HEAD~1:b.txt | tr '\n' ' ')" "b fix "
git worktree remove --force "$TMP/q1f-wt"

# A catch-up merge of main into the branch after a replay – its copies refuse, no merge offered,
# whether main moved since or not, while the --base past the merge lands the new commit alone
_ST_PZ_NEW q1g
_ST_PZ_C a.txt a "Q1G base"
git worktree add -q -b feat "$TMP/q1g-wt" main 2>/dev/null
( cd "$TMP/q1g-wt" && _ST_PZ_C b.txt b "Q1G F1" && _ST_PZ_C c.txt c "Q1G F2" )
_ST_PZ_C m.txt m "Q1G M1"
_ST_RUN --land=feat
git reset -q --hard
( cd "$TMP/q1g-wt" && git merge -q --no-edit main && _ST_PZ_C d.txt d "Q1G F3" )
Q1_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "a catch-up merge carrying main's copies – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$Q1_T"
_ST_OUT_HAS "each copy named" "^  [0-9a-f]* Q1G F2 – on main as $(git rev-parse --short=7 HEAD), change and message alike$"
_ST_OUT_LACKS "no merge offered, which would land them twice" 'merge --no-ff'
_ST_PZ_C n.txt n "Q1G M2"
_ST_RUN --land=feat
_ST_EQ "main moved since – still nothing lands" "$RC" "1"
_ST_OUT_LACKS "still no merge offered" 'merge --no-ff'
Q1_C=$(_Q1_STEP 'leaving them out: ')
_ST_EQ "the --base past the merge offered" "$Q1_C" "git edit --land=feat --base=$(git -C "$TMP/q1g-wt" rev-parse --short=12 HEAD~1)"
_Q1_AS_PRINTED "$Q1_C"
_ST_EQ "which lands the new commit alone, each commit once" "$(git log --format=%s | tr '\n' '|')" "Q1G F3|Q1G M2|Q1G F2|Q1G F1|Q1G M1|Q1G base|"
git worktree remove --force "$TMP/q1g-wt"

# Main reworded its copy, the branch folded a fix into the commit – named against that reworded
# copy, never as dropped, whose fold run as printed brings the fix – the messages left to tell apart
_ST_PZ_NEW q1h
_ST_PZ_C a.txt a "Q1H base"
git worktree add -q -b feat "$TMP/q1h-wt" main 2>/dev/null
( cd "$TMP/q1h-wt" && _ST_PZ_C b.txt b "Q1H F1" && _ST_PZ_C c.txt c "Q1H F2" )
_ST_PZ_C m.txt m "Q1H M1"
_ST_RUN --land=feat
git reset -q --hard
_ST_RUN -M --subject="Q1H F1 reworded" HEAD~1
git reset -q --hard
cd "$TMP/q1h-wt"
print -r -- fix >> b.txt && git add b.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~1)"
cd "$TMP/pz-q1h"
_ST_RUN --land=feat
_ST_EQ "a fix on a commit main reworded – nothing lands" "$RC" "1"
_ST_OUT_HAS "named against main's reworded copy" "^  [0-9a-f]* Q1H F1 – like [0-9a-f]* main took, which it holds as $(git rev-parse --short=7 HEAD~1), another patch$"
_ST_OUT_LACKS "never as dropped" 'dropped since'
Q1_C=$(_Q1_STEP 'fold it into [0-9a-f]*: ')
_Q1_AS_PRINTED "$Q1_C"
_ST_EQ "whose fold run as printed brings the fix to it" "$(git show HEAD~1:b.txt | tr '\n' ' '):$(git log -1 --format=%s HEAD~1)" "b fix :Q1H F1 reworded"
_ST_RUN --land=feat
_ST_OUT_HAS "the message then named alone" '^  [0-9a-f]* Q1H F1 – on main as [0-9a-f]*, its change alike, another message$'
git worktree remove --force "$TMP/q1h-wt"

# A branch forked from another that a replay landed – the first land of it leaves that branch's
# commit out by the replay's record and lands its own, no refusal
_ST_PZ_NEW q1i
_ST_PZ_C a.txt a "Q1I base"
git checkout -q -b side && _ST_PZ_C s.txt s "Q1I S1"
git checkout -q -b feat && _ST_PZ_C f.txt f "Q1I F1" && git checkout -q main
_ST_PZ_C m.txt m "Q1I M"
_ST_RUN --land=side
_ST_RUN --land=feat
_ST_EQ "a branch over one a replay landed lands its own" "$RC:$(git log --format=%s | tr '\n' '|')" "0:Q1I F1|Q1I S1|Q1I M|Q1I base|"
_ST_OUT_HAS "the other's commit left out by the land's record" "^1 commit(s) left out as main's own by a land's record"
cd "$TMP/repo"
