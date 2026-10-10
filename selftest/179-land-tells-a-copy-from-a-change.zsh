# A land tells a copy from a change:
# • A branch commit sharing author and date with one the target held, and its subject or patch,
#   looks like a copy, and one bringing a change the tip lacks – an amend or fold on the branch
#   since it landed, or a pick main resolved by hand – refuses whatever the dates, naming both,
#   with a step that brings its change, or lands past it, as printed
# • One whose change and message the tip holds ends landed
# • A land resumed past a conflict names the catch-up copy it left out
# • A catch-up of a branch checked out nowhere into a worktree's never offers to move or delete it
_ST_SCENARIO "\e[1;96m[179] --land tells a copy from a change made since it landed\e[0m"
local LC_L LC_B LC_T LC_C LC_WT
mkdir -p "$TMP/lc-bin" && ln -sf "$SELF" "$TMP/lc-bin/git-edit"
# Runs a printed `git edit …` step as a caller would – past the suite's `git`, whose clock a
# subshell would wind back to the parent's tick, dating its commits before the parent's later ones
_LC_AS_PRINTED () {
	[[ "$1" == "git edit "* ]] || return 1
	( export PATH="$TMP/lc-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1; eval "command $1" </dev/null ) >/dev/null 2>&1
}
# A fix folded on the branch into a commit main took by a fast-forward – the land refuses, naming
# both, and the fold it prints, run as printed, brings the fix, the land again ending landed
_ST_PZ_NEW lc1
_ST_PZ_C f.txt $'a\nb\nc' "LC1 base"
git worktree add -q -b feat "$TMP/lc1-wt" main 2>/dev/null
( cd "$TMP/lc1-wt" && _ST_PZ_C f.txt $'a\nB\nc' "LC1 F1" && _ST_PZ_C g.txt g "LC1 F2" )
_ST_RUN --land=feat
LC_L=$(git rev-parse HEAD~1)
cd "$TMP/lc1-wt"
print -r -- $'a\nB\nc\nFIX' > f.txt && git add f.txt
_ST_RUN --amend-into="$LC_L"
LC_B=$(git rev-parse HEAD~1)
cd "$TMP/pz-lc1"
LC_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "a fix folded on the branch into a commit main took – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$LC_T"
_ST_OUT_HAS "naming the branch's commit and main's" "^  ${LC_B:0:7} LC1 F1 – like ${LC_L:0:7} main took, another patch$"
_ST_OUT_LACKS "never as landed" 'already landed'
LC_C=$(print -r -- "$OUT" | sed -n 's/^.*fold it into [0-9a-f]*: //p' | head -1)
LC_C=${LC_C%%$'\e'*}
_ST_EQ "a fold into main's commit offered" "${LC_C%% --tree=*}" "git edit --amend-into=${LC_L:0:12}"
_LC_AS_PRINTED "$LC_C"
_ST_EQ "which, run as printed, brings the fix to main" "$(git show HEAD~1:f.txt | tr '\n' ' '):$(git log --format=%s | tr '\n' '|')" "a B c FIX :LC1 F2|LC1 F1|LC1 base|"
_ST_RUN --land=feat
_ST_EQ "the land run again ends landed" "$RC:$(git rev-parse HEAD)" "0:$(git rev-parse main)"
_ST_OUT_HAS "as already landed" '^git-edit: ok – refs/heads/main unchanged, already landed$'
git worktree remove --force "$TMP/lc1-wt"
# The same after a replay land, the two commits on other parents – the fold composed on main's tip
# still carries the fix alone, the fold dated later, as a replay and a fold a second apart would tie
_ST_PZ_NEW lc2
_ST_PZ_C f.txt $'a\nb\nc' "LC2 base"
git worktree add -q -b feat "$TMP/lc2-wt" main 2>/dev/null
( cd "$TMP/lc2-wt" && _ST_PZ_C f.txt $'a\nB\nc' "LC2 F1" && _ST_PZ_C g.txt g "LC2 F2" )
_ST_PZ_C m.txt m "LC2 M"
_ST_RUN --land=feat
LC_L=$(git rev-parse HEAD~1)
cd "$TMP/lc2-wt"
print -r -- $'a\nB\nc\nFIX' > f.txt && git add f.txt
export GIT_COMMITTER_DATE="@4102444800 +0000"
_ST_RUN --amend-into="$(git rev-parse HEAD~1)"
unset GIT_COMMITTER_DATE
LC_B=$(git rev-parse HEAD~1)
cd "$TMP/pz-lc2"
_ST_EQ "the fold dated past the replay" "$(( $(git log -1 --format=%ct "$LC_B") > $(git log -1 --format=%ct "$LC_L") ))" "1"
LC_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "a fix folded into a commit a replay landed – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$LC_T"
_ST_OUT_HAS "naming both" "^  ${LC_B:0:7} LC2 F1 – like ${LC_L:0:7} main took, another patch$"
LC_C=$(print -r -- "$OUT" | sed -n 's/^.*fold it into [0-9a-f]*: //p' | head -1)
LC_C=${LC_C%%$'\e'*}
_LC_AS_PRINTED "$LC_C"
_ST_EQ "the fold run as printed brings the fix alone" "$(git show HEAD~1:f.txt | tr '\n' ' '):$(git show HEAD~1 --format= --name-only)" "a B c FIX :f.txt"
_ST_RUN --land=feat
_ST_OUT_HAS "and the land again ends landed" '^git-edit: ok – refs/heads/main unchanged, already landed$'
git worktree remove --force "$TMP/lc2-wt"
# Changed since main took it, and main dropped it since – the pick it offers lands it, its change
# included, and the land again ends landed
_ST_PZ_NEW lc3
_ST_PZ_C f.txt $'a\nb\nc' "LC3 base"
git worktree add -q -b feat "$TMP/lc3-wt" main 2>/dev/null
( cd "$TMP/lc3-wt" && _ST_PZ_C f.txt $'a\nB\nc' "LC3 F1" && _ST_PZ_C g.txt g "LC3 F2" )
_ST_RUN --land=feat
LC_L=$(git rev-parse HEAD~1)
_ST_RUN -d "$LC_L"
cd "$TMP/lc3-wt"
print -r -- $'a\nB\nc\nFIX' > f.txt && git add f.txt
_ST_RUN --amend-into="$LC_L"
LC_B=$(git rev-parse HEAD~1)
cd "$TMP/pz-lc3"
LC_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "a commit changed since main took it and dropped it – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$LC_T"
_ST_OUT_HAS "naming both and the drop" "^  ${LC_B:0:7} LC3 F1 – like ${LC_L:0:7} main took, which main dropped since$"
LC_C=$(print -r -- "$OUT" | sed -n 's/^.*as a commit of its own: //p' | head -1)
LC_C=${LC_C%%$'\e'*}
_ST_EQ "a pick of it offered" "$LC_C" "git edit --exec -- git cherry-pick ${LC_B:0:12}"
_LC_AS_PRINTED "$LC_C"
_ST_EQ "which, run as printed, lands it with its change" "$(git show HEAD:f.txt | tr '\n' ' '):$(git log --format=%s | tr '\n' '|')" "a B c FIX :LC3 F1|LC3 F2|LC3 base|"
_ST_RUN --land=feat
_ST_OUT_HAS "the land again ending landed" '^git-edit: ok – refs/heads/main unchanged, already landed$'
git worktree remove --force "$TMP/lc3-wt"
# Fixes folded into two landed commits – the first fold run as printed rewrites main's copy of the
# second, which still refuses, weighed against the commit main first took, its own fold then
# landing it, the land again ending landed with both fixes on main
_ST_PZ_NEW lc7
_ST_PZ_C f.txt $'a\nb\nc' "LC7 base"
git worktree add -q -b feat "$TMP/lc7-wt" main 2>/dev/null
( cd "$TMP/lc7-wt" && _ST_PZ_C f.txt $'a\nB\nc' "LC7 F1" && _ST_PZ_C g.txt $'x\ny' "LC7 F2" )
_ST_RUN --land=feat
cd "$TMP/lc7-wt"
print -r -- $'a\nB\nc\nFIX1' > f.txt && git add f.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~1)"
print -r -- $'x\ny\nFIX2' > g.txt && git add g.txt
_ST_RUN --amend-into="$(git rev-parse HEAD)"
cd "$TMP/pz-lc7"
_ST_RUN --land=feat
_ST_EQ "two commits changed since main took them – nothing lands" "$RC" "1"
_ST_OUT_HAS "both named" 'feat holds 2 commit(s) that look like copies of commits main holds or held'
LC_C=$(print -r -- "$OUT" | sed -n 's/^.*fold it into [0-9a-f]*: //p' | head -1)
LC_C=${LC_C%%$'\e'*}
_LC_AS_PRINTED "$LC_C"
_ST_EQ "the first fold brings the first fix" "$(git show HEAD~1:f.txt | tr '\n' ' ')" "a B c FIX1 "
_ST_RUN --land=feat
_ST_EQ "the second, its copy on main rewritten since, still refuses" "$RC" "1"
_ST_OUT_HAS "named with main's copy as it holds it now" "LC7 F2 – like [0-9a-f]* main took, which it holds as ${$(git rev-parse HEAD):0:7}, another patch$"
LC_C=$(print -r -- "$OUT" | sed -n 's/^.*fold it into [0-9a-f]*: //p' | head -1)
LC_C=${LC_C%%$'\e'*}
_LC_AS_PRINTED "$LC_C"
_ST_RUN --land=feat
_ST_EQ "its fold run as printed, the land again ends landed with both fixes" \
	"$RC:$(git show HEAD~1:f.txt | tr '\n' ' '):$(git show HEAD:g.txt | tr '\n' ' ')" "0:a B c FIX1 :x y FIX2 "
_ST_OUT_HAS "as already landed" '^git-edit: ok – refs/heads/main unchanged, already landed$'
git worktree remove --force "$TMP/lc7-wt"
# A fix folded on the branch that main already holds, made apart, brings nothing –
# left out as landed, no refusal
_ST_PZ_NEW lc8
_ST_PZ_C f.txt $'a\nb\nc\nd\ne' "LC8 base"
git worktree add -q -b feat "$TMP/lc8-wt" main 2>/dev/null
( cd "$TMP/lc8-wt" && _ST_PZ_C f.txt $'a\nB\nc\nd\ne' "LC8 F1" && _ST_PZ_C g.txt g "LC8 F2" )
_ST_RUN --land=feat
_ST_PZ_C f.txt $'a\nB\nc\nD\ne' "LC8 fix made apart"
cd "$TMP/lc8-wt"
print -r -- $'a\nB\nc\nD\ne' > f.txt && git add f.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~1)"
cd "$TMP/pz-lc8"
_ST_RUN --land=feat
_ST_EQ "a change main holds already – nothing to land, no refusal" "$RC:$(git log -1 --format=%s)" "0:LC8 fix made apart"
_ST_OUT_HAS "ending as landed" '^git-edit: ok – refs/heads/main unchanged, already landed$'
git worktree remove --force "$TMP/lc8-wt"
# Main's copy of another patch – a pick resolved by hand – refuses whatever the dates, never left
# out as landed, the --base past it landing the rest
_ST_PZ_NEW lc4
_ST_PZ_C f.txt $'a\nb\nc' "LC4 base"
git checkout -q -b feat && _ST_PZ_C f.txt $'a\nB\nc' "LC4 F1" && _ST_PZ_C g.txt g "LC4 F2" && git checkout -q main
_ST_PZ_C f.txt $'a\nb\nC' "LC4 M"
git cherry-pick -n feat~1 >/dev/null 2>&1
print -r -- $'a\nB\nC2' > f.txt && git add f.txt && git commit -q -C feat~1
LC_C=$(git diff-tree -p HEAD | git patch-id --stable | cut -d' ' -f1)
_ST_EQ "main's copy shares author, date and subject, of another patch" \
	"$(git log -1 --format='%an %at %s'):$([ "$LC_C" != "$(git diff-tree -p feat~1 | git patch-id --stable | cut -d' ' -f1)" ] && print other)" \
	"$(git log -1 --format='%an %at %s' feat~1):other"
LC_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "a copy of another patch on main – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$LC_T"
_ST_OUT_HAS "named with main's copy" '^  [0-9a-f]* LC4 F1 – like [0-9a-f]* main took, another patch$'
_ST_OUT_LACKS "never left out as landed" 'left out as'
LC_C=$(print -r -- "$OUT" | sed -n 's/^.*leaving them out: //p' | head -1)
_ST_EQ "the --base past it offered" "${LC_C%%$'\e'*}" "git edit --land=feat --base=$(git rev-parse --short=12 feat~1)"
_LC_AS_PRINTED "${LC_C%%$'\e'*}"
_ST_EQ "which, run as printed, lands the rest" "$(git log --format=%s | tr '\n' '|')" "LC4 F2|LC4 F1|LC4 M|LC4 base|"
# A land resumed past a conflict names what it left out – a copy of main's commit a catch-up land
# of main into the branch made, kept out of the replay by that land's record
_ST_PZ_NEW lc5
_ST_PZ_C f.txt $'1\n2\n3' "LC5 base"
git worktree add -q -b rp "$TMP/lc5-wt" main 2>/dev/null
( cd "$TMP/lc5-wt" && _ST_PZ_C r.txt r "LC5 R1" )
_ST_PZ_C b.txt b "LC5 B"
cd "$TMP/lc5-wt"
_ST_RUN --land=main
_ST_PZ_C f.txt $'1\n2r\n3' "LC5 R3"
cd "$TMP/pz-lc5"
_ST_PZ_C f.txt $'1\n2m\n3' "LC5 M"
_ST_RUN --land=rp
_ST_EQ "the replay of the new commit pauses on its conflict" "$RC" "2"
_ST_OUT_HAS "the catch-up copy named as staying out" "^1 commit(s) are main's own by a land's record – it holds or held them in another form – and stay out:$"
LC_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${LC_WT:-$ST_NO_WT}" f.txt $'1\n2m 2r\n3'
_ST_RUN --continue
_ST_EQ "resumed, it lands the branch's own alone" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LC5 R3|LC5 R1|LC5 M|LC5 B|LC5 base|"
_ST_OUT_HAS "naming the copy left out" "^1 commit(s) left out as main's own by a land's record"
_ST_OUT_HAS "by name" '^  [0-9a-f]* LC5 B$'
git worktree remove --force "$TMP/lc5-wt"
# A catch-up of main, checked out nowhere, into a worktree's branch leaves main as it is – no move
# onto the worktree's commits, no deletion – landed or already landed, while landed into the main
# worktree's branch, a branch checked out nowhere is still offered both
_ST_PZ_NEW lc6
_ST_PZ_C a.txt a "LC6 A"
git worktree add -q -b feat "$TMP/lc6-wt" main 2>/dev/null
( cd "$TMP/lc6-wt" && _ST_PZ_C f1.txt f1 "LC6 F1" )
_ST_PZ_C b.txt b "LC6 B"
git checkout -q -b other
cd "$TMP/lc6-wt"
_ST_RUN --land=main
_ST_EQ "a catch-up of main into the worktree's branch lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LC6 B|LC6 F1|LC6 A|"
_ST_OUT_HAS "main said to stay" '^Branch main, checked out nowhere, stays as it is – feat, checked out in .*lc6-wt, now holds copies of its commits\.$'
_ST_OUT_LACKS "never moved onto the worktree's branch" 'git branch -f main'
_ST_OUT_LACKS "nor deleted" 'git branch -D main'
_ST_RUN --land=main
_ST_OUT_HAS "landed already, main said to stay" '^Nothing to do – main, checked out nowhere, stays as it is\.$'
_ST_OUT_LACKS "never deleted" 'git branch -[dD] main'
cd "$TMP/pz-lc6"
git checkout -q main && git checkout -q -b side && _ST_PZ_C s.txt s "LC6 S" && git checkout -q other
_ST_PZ_C o.txt o "LC6 O"
_ST_RUN --land=side
_ST_OUT_HAS "a branch checked out nowhere, landed into the main worktree's, offered both" "point it at those (git branch -f side $(git rev-parse --short=12 HEAD)) or delete it (git branch -D side)"
git worktree remove --force "$TMP/lc6-wt"
cd "$TMP/repo"
