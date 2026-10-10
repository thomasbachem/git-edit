# What a land of the branch took is the branch's value when that land started – read from the
# copies it made, never guessed where the branch's reflog cannot tell:
# • A version made in that land's pause, after a recreate or an expiry of the reflog, is unsure –
#   named so with the land past it that ends the retry – never already landed, the fix lost
# • A reword before the land, or a rename since, still reads as landed
# • A branch value in the second the land started is unsure, one before it landed, one after it a
#   change since, offered its fold – and a copy the target changed reads alike whatever the clock
# • A catch-up land's copies pair one to one, so a pause-made commit of a target commit's message
#   stays the branch's, while a resolution committed by hand there stays the target's
# • A commit made at a stop then skipped counts as made in the pause, the skipped pick as skipped
# • A --base names as the branch's alone no catch-up copy and no copy a land took
_ST_SCENARIO "\e[1;96m[190] --land reads what a land took from when it started\e[0m"
local LW_WT LW_C LW_S LW_N LW_A
local -i LW_T=4000000000
mkdir -p "$TMP/lw-bin" && ln -sf "$SELF" "$TMP/lw-bin/git-edit"
# Runs a printed `git edit …` or `git -C <path> edit …` step as a caller would, its output in `OUT`
# – at the clock second <at> where one is given, past the land it follows
_LW_AS_PRINTED () {
	[[ "$1" == "git edit "* || "$1" == "git -C "*" edit "* ]] || { OUT=""; return 1; }
	OUT=$( export PATH="$TMP/lw-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1; [ -n "$2" ] && export GIT_COMMITTER_DATE="@$2 +0000"
		eval "command $1" </dev/null 2>&1 )
}
# Prints the step in `OUT` past <lead> up to <end>, its color codes cut
_LW_STEP () {
	local S=$(print -r -- "$OUT" | sed -n "s/^.*$1//p" | head -1)
	S=${S%%$'\e'*}
	print -r -- "${S%%${2:-$'\n'}*}"
}
# Runs git edit at the clock second <at>, so the copies a land makes and its entries carry it
_LW_AT () {
	local AT=$1
	shift
	export GIT_COMMITTER_DATE="@$AT +0000"
	_ST_RUN "$@"
	unset GIT_COMMITTER_DATE
}
# Makes `pz-<name>`: feat's A and B, main's M – <which> of them, `a` or `b`, conflicting with M
_LW_REPO () {
	_ST_PZ_NEW "$1"
	_ST_PZ_C f.txt $'1\n2\n3' "LW base"
	git checkout -q -b feat
	if [ "$2" = a ]; then
		_ST_PZ_C f.txt $'1\n2f\n3' "LW A" && _ST_PZ_C b.txt b "LW B"
	else
		_ST_PZ_C a.txt a "LW A" && _ST_PZ_C f.txt $'1\n2f\n3' "LW B"
	fi
	git checkout -q main
	_ST_PZ_C f.txt $'1\n2m\n3' "LW M"
}
# Rebuilds feat at the clock second <at> as <how> – `fix` adding fix.txt to <A or B>, `reword`
# giving A a new subject – each commit keeping its author, by `branch -f`, `recreate` or `expire`
_LW_AMEND () {
	# Args: <at> <fix|reword> <A|B> <move|recreate|expire>
	local IDX="$TMP/lw-idx" BL A B T M
	export GIT_COMMITTER_DATE="@$1 +0000"
	A=$(git rev-parse feat~1) B=$(git rev-parse feat)
	rm -f "$IDX"
	BL=$(print -r -- fix | git hash-object -w --stdin)
	T=$(git rev-parse "$A^{tree}")
	if [ "$2$3" = fixA ]; then
		GIT_INDEX_FILE=$IDX git read-tree "$A" && GIT_INDEX_FILE=$IDX git update-index --add --cacheinfo "100644,$BL,fix.txt"
		T=$(GIT_INDEX_FILE=$IDX git write-tree)
	fi
	M=$(git log -1 --format=%B "$A")
	[ "$2" = reword ] && M="LW A reworded"
	A=$(GIT_AUTHOR_DATE="$(git log -1 --format='@%at +0000' "$A")" git commit-tree "$T" -p "$A^" -m "$M")
	GIT_INDEX_FILE=$IDX git read-tree "$B"
	[ "$2" = fix ] && GIT_INDEX_FILE=$IDX git update-index --add --cacheinfo "100644,$BL,fix.txt"
	B=$(GIT_AUTHOR_DATE="$(git log -1 --format='@%at +0000' "$B")" git commit-tree "$(GIT_INDEX_FILE=$IDX git write-tree)" -p "$A" -m "$(git log -1 --format=%B "$B")")
	case $4 in
		(recreate) git branch -D feat >/dev/null && git branch feat "$B" ;;
		(*) git branch -f feat "$B" ;;
	esac
	[ "$4" = expire ] && git reflog expire --expire="$(( $1 - 1 ))" refs/heads/feat
	unset GIT_COMMITTER_DATE
}
# Resolves the paused land's conflict and resumes it at the clock second <at>
_LW_RESUME () {
	_ST_RESOLVE "${LW_WT:-$ST_NO_WT}" f.txt $'1\n2m 2f\n3'
	_LW_AT "$1" --continue
	git reset -q --hard
}

# A fix made in the pause, feat recreated or its reflog expired – unsure, never already landed, its
# land past them ending the retry with nothing to land, the fix kept on feat
for LW_S in recreate expire; do
	_LW_REPO "lw1-$LW_S" a
	LW_T+=100
	_LW_AT $LW_T --land=feat
	LW_WT=$(_ST_PZ_WT)
	_LW_AMEND $(( LW_T + 10 )) fix A "$LW_S"
	_LW_RESUME $(( LW_T + 20 ))
	_ST_RUN --land=feat
	_ST_EQ "a fix made in the pause, feat ${LW_S}d – nothing lands ($LW_S)" "$RC" "1"
	_ST_OUT_LACKS "never already landed ($LW_S)" 'already landed\|git branch -D'
	_ST_OUT_HAS "named as maybe that land's resolution ($LW_S)" "^  [0-9a-f]* LW A – like [0-9a-f]* a land of feat brought, another patch – that land.s resolution, maybe$"
	_ST_OUT_HAS "a change of its own there left to a fold by hand ($LW_S)" "where it holds a change of its own, make that on main by hand, stage it and fold it into [0-9a-f]*: git edit --amend-into=[0-9a-f]* -- <paths>"
	LW_C=$(_LW_STEP 'so this ends it, with nothing to land: ')
	_ST_EQ "the land past them named ($LW_S)" "$LW_C" "git edit --land=feat --base=$(git rev-parse --short=12 feat)"
	_LW_AS_PRINTED "$LW_C"
	_ST_OUT_HAS "which, run as printed, ends with nothing to land ($LW_S)" '^git-edit: ok – refs/heads/main unchanged, nothing to land$'
	_ST_OUT_LACKS "naming nothing main dropped ($LW_S)" 'dropped since\|holds in no form'
	_ST_EQ "the fix on feat alone ($LW_S)" "$(git cat-file -e main:fix.txt 2>/dev/null && print main):$(git cat-file -e feat:fix.txt 2>/dev/null && print feat)" ":feat"
done

# A reword after main's last move, before the land – landed as that land took it, as is the
# branch renamed since
_LW_REPO lw2 a
_LW_AMEND $(( ++LW_T )) reword A move
LW_T+=100
_LW_AT $LW_T --land=feat
LW_WT=$(_ST_PZ_WT)
_LW_RESUME $(( LW_T + 20 ))
_ST_RUN --land=feat
_ST_OUT_HAS "a reword before a land with a resolution reads as landed" '^git-edit: ok – refs/heads/main unchanged, already landed$'
git branch -m feat feat2
_ST_RUN --land=feat2
_ST_OUT_HAS "and renamed since, still" '^git-edit: ok – refs/heads/main unchanged, already landed$'
_ST_OUT_LACKS "no fold offered under the new name" 'amend-into'

# B, picked at a stop past A's clean pick, the land started in A's copy's second – B fixed the
# second before reads as landed, in that second as unsure, the second after as a change since,
# its fold, run as printed, bringing the fix
for LW_N in -1 0 1; do
	_LW_REPO "lw3$LW_N" b
	LW_T+=100
	(( LW_N < 0 )) && _LW_AMEND $(( LW_T + LW_N )) fix B move
	_LW_AT $LW_T --land=feat
	LW_WT=$(_ST_PZ_WT)
	(( LW_N >= 0 )) && _LW_AMEND $(( LW_T + LW_N )) fix B move
	_LW_RESUME $(( LW_T + 20 ))
	_ST_RUN --land=feat
	case $LW_N in
		(-1) _ST_OUT_HAS "fixed the second before the land, it is what the land took" '^git-edit: ok – refs/heads/main unchanged, already landed$' ;;
		(0)  _ST_OUT_HAS "fixed in the second the land started, unsure" "^  [0-9a-f]* LW B – like [0-9a-f]* a land of feat brought, another patch – that land.s resolution, maybe$"
		     _ST_OUT_LACKS "and offered no fold" 'composed on the tip' ;;
		(1)  LW_C=$(_LW_STEP 'fold it into [0-9a-f]*: ')
		     _ST_EQ "fixed the second after, its fold offered" "${LW_C%% --tree=*}" "git edit --amend-into=$(git rev-parse --short=12 HEAD)"
		     _LW_AS_PRINTED "$LW_C" $(( LW_T + 30 ))
		     _ST_RUN --land=feat
		     _ST_EQ "which, run as printed, brings the fix alone, the land again ending landed" \
		     	"$RC:$(git show HEAD:f.txt | tr '\n' ' '):$(git show HEAD:fix.txt)" "0:1 2m 2f 3 :fix" ;;
	esac
done

# A fix main folded into its copy, in the land's second or seconds after – the branch's commit
# named as main first took it either way
for LW_N in 0 5; do
	_ST_PZ_NEW "lw4-$LW_N"
	_ST_PZ_C f.txt f "LW base"
	git checkout -q -b feat && _ST_PZ_C a.txt a "LW A" && _ST_PZ_C b.txt b "LW B" && git checkout -q main
	_ST_PZ_C m.txt m "LW M"
	LW_T+=100
	_LW_AT $LW_T --land=feat
	_LW_AT $(( LW_T + LW_N )) --amend-into="$(git rev-parse HEAD~1)" --edits '{"a.txt": [["a\n", "a\nfix\n"]]}'
	git checkout -q feat && _ST_PZ_C c.txt c "LW C" && git checkout -q main
	_ST_RUN --land=feat
	_ST_OUT_HAS "a copy main changed since, named as main first took it ($LW_N s apart)" \
		'^  [0-9a-f]* LW A – on main as [0-9a-f]*, its change as main first took it, changed there since$'
done

# A commit made in a catch-up's pause sharing the message of main's commit lands back as feat's,
# while a resolution committed by hand there, its `# Conflicts:` lines kept, stays main's
_ST_PZ_NEW lw5
_ST_PZ_C f.txt $'1\n2\n3' "LW base"
git worktree add -q -b feat "$TMP/lw5-wt" main 2>/dev/null
( cd "$TMP/lw5-wt" && _ST_PZ_C f.txt $'1\n2f\n3' "LW A" )
_ST_PZ_C f.txt $'1\n2m\n3' "LW M"
_ST_PZ_C l.txt lint "LW fix lint"
cd "$TMP/lw5-wt"
_ST_RUN --land=main
LW_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${LW_WT:-$ST_NO_WT}" f.txt $'1\n2f 2m\n3'
git -C "${LW_WT:-$ST_NO_WT}" commit -q --no-edit >/dev/null 2>&1
_ST_EQ "a resolution committed by hand keeps its conflict lines" "$(git -C "${LW_WT:-$ST_NO_WT}" log -1 --format=%B | grep -c '^# Conflicts:')" "1"
print -r -- own > "${LW_WT:-$ST_NO_WT}/x.txt" && git -C "${LW_WT:-$ST_NO_WT}" add x.txt && git -C "${LW_WT:-$ST_NO_WT}" commit -qm "LW fix lint"
_ST_RUN --continue
_ST_OUT_HAS "the catch-up counts the pause-made commit apart" 'and 1 commit(s) made in its pause:$'
cd "$TMP/pz-lw5"
_ST_RUN --land=feat --dry-run
_ST_OUT_HAS "the land back replays feat's own and the pause-made commit" "replaying 2 from 'feat' on top:"
_ST_OUT_HAS "the hand resolution and the copy stay main's" "^2 commit(s) are main's own by a land's record"
LW_C=$(print -r -- "$OUT" | sed -n "/^main gained/,/are main.s own/p")
_ST_EQ "the hand resolution, its conflict lines aside, is no replayed commit" "$(print -r -- "$LW_C" | grep -c ' LW M$')" "0"
_ST_RUN --land=feat
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'1\n2m 2f\n3'
_ST_RUN --continue
_ST_EQ "and lands the pause-made commit" "$RC:$(git show HEAD:x.txt 2>/dev/null)" "0:own"
_ST_RUN --land=feat
_ST_OUT_HAS "the land again ends landed, main still holding what the hand resolution copies" '^git-edit: ok – refs/heads/main unchanged, already landed$'
_ST_OUT_LACKS "naming nothing as dropped" 'dropped since'
git worktree remove --force "$TMP/lw5-wt"

# A commit made at a stop, then the stop skipped – made in the pause, the pick skipped and kept on
# feat alone, no move of feat offered
_ST_PZ_NEW lw6
_ST_PZ_C f.txt $'1\n2\n3' "LW base"
git worktree add -q -b feat "$TMP/lw6-wt" main 2>/dev/null
( cd "$TMP/lw6-wt" && _ST_PZ_C f.txt $'1\n2f\n3' "LW A" && _ST_PZ_C b.txt b "LW B" )
_ST_PZ_C f.txt $'1\n2m\n3' "LW M"
_ST_RUN --land=feat
LW_WT=$(_ST_PZ_WT)
git -C "${LW_WT:-$ST_NO_WT}" reset -q && git -C "${LW_WT:-$ST_NO_WT}" checkout -q -- f.txt
print -r -- own > "${LW_WT:-$ST_NO_WT}/x.txt" && git -C "${LW_WT:-$ST_NO_WT}" add x.txt && git -C "${LW_WT:-$ST_NO_WT}" commit -qm "LW X made at the stop"
_ST_RUN --skip
_ST_OUT_HAS "a commit made at a skipped stop counts as made in the pause" '^Landed 1 of 2 commit(s) from feat onto main, and 1 commit(s) made in its pause:$'
_ST_OUT_HAS "the skipped pick named as kept on feat alone" "^Branch feat keeps 1 commit(s) main holds in no form – skipped, or emptied by a resolution"
_ST_OUT_LACKS "no move of feat offered" 'reset --keep\|git branch -f\|git branch -D'
git worktree remove --force "$TMP/lw6-wt"
# A stop's resolution committed by hand under a message of its own, then resumed – git's own pair
# kept, the pick landed, nothing named as skipped or made in the pause
_ST_PZ_NEW lw6b
_ST_PZ_C f.txt $'1\n2\n3' "LW base"
git worktree add -q -b feat "$TMP/lw6b-wt" main 2>/dev/null
( cd "$TMP/lw6b-wt" && _ST_PZ_C f.txt $'1\n2f\n3' "LW A" && _ST_PZ_C b.txt b "LW B" )
_ST_PZ_C f.txt $'1\n2m\n3' "LW M"
_ST_RUN --land=feat
LW_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${LW_WT:-$ST_NO_WT}" f.txt $'1\n2m 2f\n3'
git -C "${LW_WT:-$ST_NO_WT}" commit -qm "LW A, resolved against M" >/dev/null 2>&1
_ST_RUN --continue
_ST_OUT_HAS "a resolution committed by hand under a new message lands as the pick's" '^Landed 2 of 2 commit(s) from feat onto main:$'
_ST_OUT_LACKS "never as skipped, nor kept on feat alone" 'were skipped\|holds in no form'
git worktree remove --force "$TMP/lw6b-wt"

# A commit made in a catch-up's pause repeating the message of main's copy of feat's own earlier
# commit – which the catch-up left out as there already – stays feat's, the --base past the
# catch-up landing it
_ST_PZ_NEW lw6c
_ST_PZ_C f.txt $'1\n2\n3' "LW base"
git worktree add -q -b feat "$TMP/lw6c-wt" main 2>/dev/null
( cd "$TMP/lw6c-wt" && _ST_PZ_C l1.txt l1 "LW fix lint" && _ST_PZ_C f.txt $'1f\n2\n3' "LW Z" )
_ST_PZ_C n.txt n "LW N"
_ST_RUN --land=feat
_ST_PZ_C f.txt $'1f\n2\n3m' "LW M"
( cd "$TMP/lw6c-wt" && _ST_PZ_C f.txt $'1f\n2\n3y' "LW Y own" )
cd "$TMP/lw6c-wt"
_ST_RUN --land=main
LW_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${LW_WT:-$ST_NO_WT}" f.txt $'1f\n2\n3y 3m'
GIT_EDITOR=true git -C "${LW_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
print -r -- l2 > "${LW_WT:-$ST_NO_WT}/l2.txt" && git -C "${LW_WT:-$ST_NO_WT}" add l2.txt && git -C "${LW_WT:-$ST_NO_WT}" commit -qm "LW fix lint"
_ST_RUN --continue
git restore --source=HEAD --worktree -- .
cd "$TMP/pz-lw6c"
_ST_RUN --land=feat
LW_C=$(_LW_STEP 'leaving them out with [0-9]* commit(s) of its own at or below [0-9a-f]*: ')
_ST_EQ "the --base past the catch-up offered" "${LW_C% --base=*}" "git edit --land=feat"
_LW_AS_PRINTED "$LW_C"
_ST_EQ "which, run as printed, lands the pause-made commit" "$(git show HEAD:l2.txt 2>/dev/null):$(git log -1 --format=%s)" "l2:LW fix lint"
git worktree remove --force "$TMP/lw6c-wt"

# A --base past a catch-up copy of a commit main dropped names no commit as feat's alone
_ST_PZ_NEW lw7
_ST_PZ_C f.txt base "LW base"
git worktree add -q -b feat "$TMP/lw7-wt" main 2>/dev/null
( cd "$TMP/lw7-wt" && _ST_PZ_C a.txt a "LW A" )
_ST_PZ_C m0.txt m0 "LW M0"
_ST_RUN --land=feat
_ST_PZ_C m1.txt m1 "LW M1 dropped later"
LW_A=$(git rev-parse HEAD)
( cd "$TMP/lw7-wt" && "$SELF" --land=main </dev/null >/dev/null 2>&1 && git restore --source=HEAD --worktree -- . && _ST_PZ_C c.txt c "LW C" )
_ST_RUN -d "$LW_A"
_ST_RUN --land=feat
LW_C=$(_LW_STEP 'leaving them out: ')
_LW_AS_PRINTED "$LW_C"
_ST_OUT_HAS "the --base past a catch-up copy lands the rest" '^Landed 1 of 1 commit(s) from feat onto main:$'
_ST_OUT_LACKS "naming the catch-up copy as feat's alone" 'is the only branch holding them'
_ST_OUT_HAS "while naming the copy of the dropped commit as held by main in no form" '^1 commit(s) below it main holds in no form now – they stay out, as --base asks:$'
_ST_OUT_HAS "that copy itself" '^  [0-9a-f]* LW M1 dropped later$'
git worktree remove --force "$TMP/lw7-wt"
# Nor a copy a land with a resolution took, when a --base lands what followed it
_ST_PZ_NEW lw8
_ST_PZ_C f.txt $'1\n2\n3\n4\n5' "LW base"
git worktree add -q -b feat "$TMP/lw8-wt" main 2>/dev/null
( cd "$TMP/lw8-wt" && _ST_PZ_C f.txt $'1f\n2\n3\n4\n5' "LW A" && _ST_PZ_C b.txt b "LW B" )
_ST_PZ_C f.txt $'1m\n2\n3\n4\n5' "LW M"
_ST_RUN --land=feat
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'1m 1f\n2\n3\n4\n5'
_ST_RUN --continue
( cd "$TMP/lw8-wt" && _ST_PZ_C f.txt $'1f\n2\n3\n4\n5c' "LW C" )
_ST_PZ_C f.txt $'1m 1f\n2\n3\n4\n5n' "LW N"
_ST_RUN --land=feat --base="$(git -C "$TMP/lw8-wt" rev-parse HEAD~1)"
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'1m 1f\n2\n3\n4\n5n 5c'
_ST_RUN --continue
_ST_EQ "a --base past a copy landed with a resolution lands the rest" "$RC:$(git log -1 --format=%s)" "0:LW C"
_ST_OUT_LACKS "naming no copy main took as feat's alone" 'is the only branch holding them'
git worktree remove --force "$TMP/lw8-wt"

# The commits a dropped commit's merge leaves feat's own below it name no merge
_ST_PZ_NEW lw9
_ST_PZ_C f.txt base "LW base"
git worktree add -q -b feat "$TMP/lw9-wt" main 2>/dev/null
_ST_PZ_C p.txt p "LW P peer"
LW_A=$(git rev-parse HEAD)
( cd "$TMP/lw9-wt" && _ST_PZ_C a.txt a "LW A own" && git merge -q --no-edit main && _ST_PZ_C c.txt c "LW C own" )
_ST_PZ_C q.txt q "LW Q peer"
_ST_RUN -d "$LW_A"
_ST_RUN --land=feat
_ST_OUT_HAS "a merge carrying a dropped commit refuses, naming feat's own below it" "^  1 commit(s) of feat's own sit at or below"
_ST_OUT_LACKS "never the merge itself" '^  [0-9a-f]* Merge '
git worktree remove --force "$TMP/lw9-wt"
cd "$TMP/repo"
