# A land refusing the branch's copies of the target's commits prints only steps that work as
# printed, run here one by one:
# • The --base leaving them out lands the branch's own commits alone, never a catch-up copy of
#   a commit the target dropped
# • Its own commits no step lands are named, with the drop of its copies of dropped commits
# • A copy a land of the branch brought, the branch's commit as it was then, is landed – the
#   difference that land's resolution – while a commit amended since gets its fold, and one the
#   branch's reflog cannot tell is offered no fold
# • A copy the target changed since it took it is named so, and no move onto it is offered
_ST_SCENARIO "\e[1;96m[186] --land refusals print only steps that work as printed\e[0m"
local LR_M1 LR_C LR_T LR_WT
mkdir -p "$TMP/lr-bin" && ln -sf "$SELF" "$TMP/lr-bin/git-edit"
# Runs a printed `git edit …` or `git -C <path> edit …` step as a caller would – past the suite's
# `git`, whose clock a subshell would wind back to the parent's tick
_LR_AS_PRINTED () {
	[[ "$1" == "git edit "* || "$1" == "git -C "*" edit "* ]] || return 1
	( export PATH="$TMP/lr-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1; eval "command $1" </dev/null ) > "$TMP/lr-step.out" 2>&1
}
# Prints the step in `OUT` between <lead> and <end>, its color codes cut
_LR_STEP () {
	local S=$(print -r -- "$OUT" | sed -n "s/^.*$1//p" | head -1)
	S=${S%%$'\e'*}
	print -r -- "${S%%${2:-$'\n'}*}"
}
# Makes `pz-<name>`: feat landed by a replay, caught up to main by a land of main, a commit of its
# own past that, and main's commit the catch-up copied dropped since
_LR_CAUGHT () {
	_ST_PZ_NEW "$1"
	_ST_PZ_C f.txt f "LR base"
	git worktree add -q -b feat "$TMP/$1-wt" main 2>/dev/null
	( cd "$TMP/$1-wt" && _ST_PZ_C a.txt a "LR A" )
	_ST_PZ_C m0.txt m0 "LR M0"
	"$SELF" --land=feat </dev/null >/dev/null 2>&1
	_ST_PZ_C m1.txt m1 "LR M1 dropped later"
	LR_M1=$(git rev-parse HEAD)
	( cd "$TMP/$1-wt" && "$SELF" --land=main </dev/null >/dev/null 2>&1 && git restore --source=HEAD --worktree -- . && \
		_ST_PZ_C c.txt c "LR C" )
	"$SELF" -d "$LR_M1" </dev/null >/dev/null 2>&1
}
# The --base leaving the copies out sits past the catch-up copy of the dropped commit, and run as
# printed lands the branch's own commit alone
_LR_CAUGHT lr1
LR_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "a catch-up copy of a commit main dropped since – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$LR_T"
LR_C=$(_LR_STEP 'leaving them out: ')
_ST_EQ "the --base leaving them out sits past the catch-up copies" "$LR_C" \
	"git edit --land=feat --base=$(git -C "$TMP/lr1-wt" rev-parse --short=12 HEAD~1)"
_LR_AS_PRINTED "$LR_C"
_ST_EQ "which, run as printed, lands the branch's own commit alone, the drop standing" \
	"$(git log --format=%s | tr '\n' '|')" "LR C|LR A|LR M0|LR base|"
git worktree remove --force "$TMP/lr1-wt"
# The move onto main's copies, run as printed, never brings the dropped commit back either – the
# land again refuses it as a copy of a dropped one, its --base landing the rest
_LR_CAUGHT lr2
_ST_RUN --land=feat
LR_C=$(_LR_STEP 'onto main.s copies, then run it again: ')
_ST_EQ "the move onto main's copies offered" "${LR_C##* }" "--onto=main"
_LR_AS_PRINTED "$LR_C"
_ST_RUN --land=feat
_ST_EQ "after the move, the copy of the dropped commit still refuses" "$RC:$(git log --format=%s | tr '\n' '|')" "1:LR A|LR M0|LR base|"
_ST_OUT_HAS "named as a copy of what main dropped" '^  [0-9a-f]* LR M1 dropped later – like [0-9a-f]* main took, which main dropped since$'
LR_C=$(_LR_STEP 'leaving them out: ')
_LR_AS_PRINTED "$LR_C"
_ST_EQ "whose --base, run as printed, lands the branch's own alone" "$(git log --format=%s | tr '\n' '|')" "LR C|LR A|LR M0|LR base|"
git worktree remove --force "$TMP/lr2-wt"

# Makes `pz-<name>`: feat holding a commit of its own, then picks of two commits main dropped since
_LR_PICKED () {
	_ST_PZ_NEW "$1"
	_ST_PZ_C f.txt f "LR base"
	git worktree add -q -b feat "$TMP/$1-wt" main 2>/dev/null
	_ST_PZ_C p.txt p "LR P" && _ST_PZ_C q.txt q "LR Q"
	( cd "$TMP/$1-wt" && _ST_PZ_C a.txt a "LR A" && git cherry-pick main~1 main >/dev/null 2>&1 )
	"$SELF" -d "$(git rev-parse main~1)" "$(git rev-parse main)" </dev/null >/dev/null 2>&1
}
# Its own commit below the picks is named, with the drop of the picks from its checkout, which run
# as printed lets the land again land it alone
_LR_PICKED lr3
_ST_EQ "main dropped both" "$(git log --format=%s | tr '\n' '|')" "LR base|"
_ST_RUN --land=feat
_ST_EQ "picks of what main dropped – nothing lands" "$RC" "1"
_ST_OUT_HAS "a pick landing both back, as one step" \
	"To land the 2 copies of what main dropped back, their changes included, as commits of their own: git edit --exec -- git cherry-pick $(git -C "$TMP/lr3-wt" rev-parse --short=12 HEAD~1) $(git -C "$TMP/lr3-wt" rev-parse --short=12 HEAD)"
_ST_OUT_HAS "the branch's own commit named" '^  [0-9a-f]* LR A$'
LR_C=$(_LR_STEP 'dropped off feat first: ' ', then run it again')
_ST_EQ "with the drop of both picks from its checkout" "${LR_C#git -C * edit }" \
	"-d $(git -C "$TMP/lr3-wt" rev-parse --short=12 HEAD~1) $(git -C "$TMP/lr3-wt" rev-parse --short=12 HEAD)"
_LR_AS_PRINTED "$LR_C"
_ST_RUN --land=feat
_ST_EQ "which, run as printed, lets the land again land it alone" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LR A|LR base|"
git worktree remove --force "$TMP/lr3-wt"
# The pick landing them back, run as printed, then the move the land again offers, lands all three
_LR_PICKED lr4
_ST_RUN --land=feat
_LR_AS_PRINTED "$(_LR_STEP 'as commits of their own: ')"
_ST_RUN --land=feat
LR_C=$(_LR_STEP 'onto main.s copies, then run it again: ')
_LR_AS_PRINTED "$LR_C"
_ST_RUN --land=feat
_ST_EQ "the picks landed back, the move and the land again land the rest" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LR A|LR Q|LR P|LR base|"
git worktree remove --force "$TMP/lr4-wt"
# The fork landing them back all the same does so, as it says
_LR_PICKED lr5
_ST_RUN --land=feat
_LR_AS_PRINTED "$(_LR_STEP 'land them back all the same: ')"
_ST_EQ "landing them back all the same lands all three" "$(git log --format=%s | tr '\n' '|')" "LR Q|LR P|LR A|LR base|"
git worktree remove --force "$TMP/lr5-wt"

# Makes `pz-<name>`: feat's two commits landed by a replay whose conflict on the first was resolved,
# `<amend>` given – feat's second amended with a fix while the land waited
_LR_RESOLVED () {
	_ST_PZ_NEW "$1"
	_ST_PZ_C f.txt $'1\n2\n3\n4\n5\n6' "LR base"
	git worktree add -q -b feat "$TMP/$1-wt" main 2>/dev/null
	( cd "$TMP/$1-wt" && _ST_PZ_C f.txt $'1\n2f\n3\n4\n5\n6' "LR A" && _ST_PZ_C b.txt b "LR B" )
	_ST_PZ_C f.txt $'1\n2m\n3\n4\n5\n6' "LR M"
	"$SELF" --land=feat </dev/null >/dev/null 2>&1
	LR_WT=$(_ST_PZ_WT)
	[ -n "$2" ] && ( cd "$TMP/$1-wt" && print -r -- $'b\nfix' > b.txt && git add b.txt && git commit -q --amend --no-edit )
	_ST_RESOLVE "${LR_WT:-$ST_NO_WT}" f.txt $'1\n2m 2f\n3\n4\n5\n6'
	"$SELF" --continue </dev/null >/dev/null 2>&1
	git reset -q --hard
}
# Landed with a resolution, the branch never moved since – the land again ends landed
_LR_RESOLVED lr6
_ST_EQ "a land with a resolution lands" "$(git log --format=%s | tr '\n' '|')" "LR B|LR A|LR M|LR base|"
_ST_RUN --land=feat
_ST_EQ "the land again ends landed, the resolution's copy counted" "$RC" "0"
_ST_OUT_HAS "as already landed" '^git-edit: ok – refs/heads/main unchanged, already landed$'
git worktree remove --force "$TMP/lr6-wt"
# A fix amended into the second while the land waited – the first counted as landed, never a
# fold of its pre-resolution change, the second's fold run as printed bringing the fix
_LR_RESOLVED lr7 amend
_ST_RUN --land=feat
_ST_EQ "a fix amended in while the land waited – nothing lands" "$RC" "1"
_ST_OUT_HAS "the resolved one named as landed by that land" \
	'^  [0-9a-f]* LR A – on main as [0-9a-f]*, as a land of feat took it – the difference that land.s resolution$'
_ST_OUT_LACKS "never a fold of its pre-resolution change" 'make it there, stage it'
LR_C=$(_LR_STEP 'fold it into [0-9a-f]*: ')
_ST_EQ "the amended one offered its fold" "${LR_C%% --tree=*}" "git edit --amend-into=$(git rev-parse --short=12 HEAD)"
_LR_AS_PRINTED "$LR_C"
_ST_RUN --land=feat
_ST_EQ "which, run as printed, brings the fix, the land again ending landed" "$RC:$(git show HEAD:b.txt | tr '\n' ' ')" "0:b fix "
git worktree remove --force "$TMP/lr7-wt"
# Amended past main's last move, before the land – the reflog cannot tell which the resolution took,
# so no fold is offered, only the comparison
_ST_PZ_NEW lr8
_ST_PZ_C f.txt $'1\n2\n3' "LR base"
git worktree add -q -b feat "$TMP/lr8-wt" main 2>/dev/null
( cd "$TMP/lr8-wt" && _ST_PZ_C f.txt $'1\n2f\n3' "LR A" )
_ST_PZ_C f.txt $'1\n2m\n3' "LR M"
( cd "$TMP/lr8-wt" && print -r -- $'1\n2F\n3' > f.txt && git add f.txt && git commit -q --amend --no-edit && _ST_PZ_C b.txt b "LR B" )
"$SELF" --land=feat </dev/null >/dev/null 2>&1
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'1\n2m 2F\n3'
"$SELF" --continue </dev/null >/dev/null 2>&1
git reset -q --hard
( cd "$TMP/lr8-wt" && _ST_PZ_C c.txt c "LR C" )
_ST_RUN --land=feat
_ST_EQ "a copy the reflog cannot tell – nothing lands" "$RC" "1"
_ST_OUT_HAS "its difference named as maybe the resolution" 'may be the resolution of the land of feat that brought it, so no fold is offered'
_ST_OUT_LACKS "no fold of it offered" 'make it there, stage it'
LR_C=$(_LR_STEP 'leaving them out: ')
_LR_AS_PRINTED "$LR_C"
_ST_EQ "the --base past it, run as printed, lands the rest" "$(git log --format=%s | tr '\n' '|')" "LR C|LR B|LR A|LR M|LR base|"
git worktree remove --force "$TMP/lr8-wt"
# A fix folded on the branch, dated past the land, into a commit that land took with a resolution –
# the fold it offers composes the fix alone, keeping the resolution, the land again ending landed
_LR_RESOLVED lr10
cd "$TMP/lr10-wt"
print -r -- $'1\n2f\n3\n4\n5\n6\nFIX' > f.txt && git add f.txt
export GIT_COMMITTER_DATE="@4102444800 +0000"
_ST_RUN --amend-into="$(git rev-parse HEAD~1)"
unset GIT_COMMITTER_DATE
cd "$TMP/pz-lr10"
_ST_RUN --land=feat
_ST_EQ "a fix on a commit landed with a resolution – nothing lands" "$RC" "1"
_ST_OUT_LACKS "never a fold of its pre-resolution change" 'make it there, stage it'
LR_C=$(_LR_STEP 'fold it into [0-9a-f]*: ')
_ST_EQ "a fold of its change since offered" "${LR_C%% --tree=*}" "git edit --amend-into=$(git rev-parse --short=12 HEAD~1)"
_LR_AS_PRINTED "$LR_C"
_ST_RUN --land=feat
_ST_EQ "which, run as printed, brings the fix alone, the resolution kept, the land again ending landed" \
	"$RC:$(git show HEAD~1:f.txt | tr '\n' ' ')" "0:1 2m 2f 3 4 5 6 FIX "
git worktree remove --force "$TMP/lr10-wt"

# A fix main folded into its copy – the branch's commit named as main first took it, no move onto
# the copies offered, the --base past them landing the rest as printed
_ST_PZ_NEW lr9
_ST_PZ_C f.txt f "LR base"
git worktree add -q -b feat "$TMP/lr9-wt" main 2>/dev/null
( cd "$TMP/lr9-wt" && _ST_PZ_C a.txt a "LR A" && _ST_PZ_C b.txt b "LR B" )
_ST_PZ_C m.txt m "LR M"
_ST_RUN --land=feat
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --edits '{"a.txt": [["a\n", "a\nfix\n"]]}'
( cd "$TMP/lr9-wt" && _ST_PZ_C c.txt c "LR C" )
_ST_RUN --land=feat
_ST_EQ "a copy main changed since, then a commit of the branch's own – nothing lands" "$RC" "1"
_ST_OUT_HAS "named as main first took it" '^  [0-9a-f]* LR A – on main as [0-9a-f]*, its change as main first took it, changed there since$'
_ST_OUT_LACKS "no move onto the copies, which would conflict" 'edit --onto=main'
LR_C=$(_LR_STEP 'leaving them out: ')
_ST_EQ "the --base past them offered" "$LR_C" "git edit --land=feat --base=$(git -C "$TMP/lr9-wt" rev-parse --short=12 HEAD~1)"
_LR_AS_PRINTED "$LR_C"
_ST_EQ "which, run as printed, lands the rest, main's fix kept" \
	"$(git log --format=%s | tr '\n' '|'):$(git show HEAD~2:a.txt | tr '\n' ' ')" "LR C|LR B|LR A|LR M|LR base|:a fix "
git worktree remove --force "$TMP/lr9-wt"
cd "$TMP/repo"
