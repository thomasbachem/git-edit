# A branch commit whose copy on the target has its change and another message refuses, naming both,
# with the reword of the target's commit that lands as printed, `--subject` where the subject alone
# differs – one the target reworded itself too, then with the move onto its copies, and one like a
# copy the target dropped, named against that.
# A land of the repository's default branch into another – `init.defaultBranch`, else a remote's
# HEAD, else `main` – never offers to move or delete it, wherever it is checked out, while another
# branch still is
_ST_SCENARIO "\e[1;96m[181] --land takes a reword for a change and leaves the default branch be\e[0m"
local RW_L RW_B RW_T RW_C
mkdir -p "$TMP/rw-bin" && ln -sf "$SELF" "$TMP/rw-bin/git-edit"
# Runs a printed `git edit …` step as a caller would – past the suite's `git`, whose clock a subshell
# would wind back to the parent's tick
_RW_AS_PRINTED () {
	[[ "$1" == "git edit "* ]] || return 1
	( export PATH="$TMP/rw-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1; eval "command $1" </dev/null ) >/dev/null 2>&1
}
# Its body reworded on the branch after a fast-forward land – the land refuses, naming both, and the
# reword it prints, run as printed, gives main's commit the branch's message; the land again ends landed
_ST_PZ_NEW rw1
_ST_PZ_C f.txt f "RW1 base"
git worktree add -q -b feat "$TMP/rw1-wt" main 2>/dev/null
( cd "$TMP/rw1-wt" && _ST_PZ_C g.txt g "RW1 F1" && _ST_PZ_C h.txt h "RW1 F2" )
_ST_RUN --land=feat
RW_L=$(git rev-parse HEAD~1)
cd "$TMP/rw1-wt"
_ST_RUN -M --text=$'RW1 F1\n\nWhy it lands' "$RW_L"
RW_B=$(git rev-parse HEAD~1)
cd "$TMP/pz-rw1"
RW_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "a commit reworded on the branch since main took it – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$RW_T"
_ST_OUT_HAS "naming the branch's commit and main's" "^  ${RW_B:0:7} RW1 F1 – on main as ${RW_L:0:7}, its change alike, another message$"
_ST_OUT_LACKS "never as landed" 'already landed'
RW_C=$(print -r -- "$OUT" | sed -n 's/^.*its new message: //p' | head -1)
RW_C=${RW_C%%$'\e'*}
_ST_EQ "the reword of main's commit offered" "$RW_C" "git edit -M --text=\"\$(git log -1 --format=%B ${RW_B:0:12})\" ${RW_L:0:12}"
_RW_AS_PRINTED "$RW_C"
_ST_EQ "which, run as printed, gives main's commit the branch's message" "$(git log -1 --format=%B HEAD~1)" "$(git log -1 --format=%B "$RW_B")"
_ST_RUN --land=feat
_ST_EQ "the land run again ends landed" "$RC:$(git log --format=%s | tr '\n' '|')" "0:RW1 F2|RW1 F1|RW1 base|"
_ST_OUT_HAS "as already landed" '^git-edit: ok – refs/heads/main unchanged, already landed$'
git worktree remove --force "$TMP/rw1-wt"
# Its subject alone reworded after a replay land, dated past the replay – the subject alone offered,
# which keeps main's body
_ST_PZ_NEW rw2
_ST_PZ_C f.txt f "RW2 base"
git worktree add -q -b feat "$TMP/rw2-wt" main 2>/dev/null
( cd "$TMP/rw2-wt" && print -r -- g > g.txt && git add g.txt && git commit -qm "RW2 F1" -m "Its body" && _ST_PZ_C h.txt h "RW2 F2" )
_ST_PZ_C m.txt m "RW2 M"
_ST_RUN --land=feat
RW_L=$(git rev-parse HEAD~1)
cd "$TMP/rw2-wt"
export GIT_COMMITTER_DATE="@4102444800 +0000"
_ST_RUN -M --subject="RW2 F1 renamed" "$(git rev-parse HEAD~1)"
unset GIT_COMMITTER_DATE
RW_B=$(git rev-parse HEAD~1)
cd "$TMP/pz-rw2"
RW_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "a subject reworded after a replay land – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$RW_T"
_ST_OUT_HAS "naming both" "^  ${RW_B:0:7} RW2 F1 renamed – on main as ${RW_L:0:7}, its change alike, another message$"
RW_C=$(print -r -- "$OUT" | sed -n 's/^.*its new subject: //p' | head -1)
RW_C=${RW_C%%$'\e'*}
_ST_EQ "the subject alone offered" "$RW_C" "git edit -M --subject='RW2 F1 renamed' ${RW_L:0:12}"
_RW_AS_PRINTED "$RW_C"
_ST_EQ "which, run as printed, renames main's commit and keeps its body" "$(git log -1 --format=%B HEAD~1)" $'RW2 F1 renamed\n\nIts body'
_ST_RUN --land=feat
_ST_OUT_HAS "and the land again ends landed" '^git-edit: ok – refs/heads/main unchanged, already landed$'
git worktree remove --force "$TMP/rw2-wt"
# A copy main reworded itself refuses as well, whichever side changed – the move of a branch checked
# out nowhere onto main's copies offered, main's messages standing, and run as printed, nothing is
# left to land, main's message kept
_ST_PZ_NEW rw3
_ST_PZ_C f.txt f "RW3 base"
git checkout -q -b feat && _ST_PZ_C g.txt g "RW3 F1" && _ST_PZ_C h.txt h "RW3 F2" && git checkout -q main
_ST_PZ_C m.txt m "RW3 M"
_ST_RUN --land=feat
_ST_RUN -M --subject="RW3 F1 as main words it" HEAD~1
_ST_RUN --land=feat
_ST_EQ "a copy main reworded itself – nothing lands" "$RC:$(git log -1 --format=%s HEAD~1)" "1:RW3 F1 as main words it"
_ST_OUT_HAS "named under its other message" "^  $(git rev-parse --short=7 feat~1) RW3 F1 – on main as $(git rev-parse --short=7 HEAD~1), its change alike, another message$"
RW_C=$(print -r -- "$OUT" | sed -n "s/^.*main's messages standing, then run it again: //p" | head -1)
RW_C=${RW_C%%$'\e'*}
_ST_EQ "the move onto main's copies offered" "$RW_C" "git branch -f feat $(git rev-parse --short=12 HEAD)"
eval "${RW_C:-false}"
_ST_RUN --land=feat
_ST_EQ "run as printed, nothing is left to land, main's message kept" "$RC:$(git log -1 --format=%s HEAD~1)" "0:RW3 F1 as main words it"
_ST_OUT_HAS "ending ok" '^git-edit: ok – refs/heads/main unchanged, nothing to land$'
# A commit main dropped, reworded on the branch since – nothing lands, the commit named against the
# copy main dropped
_ST_PZ_NEW rw4
_ST_PZ_C f.txt f "RW4 base"
git worktree add -q -b feat "$TMP/rw4-wt" main 2>/dev/null
( cd "$TMP/rw4-wt" && _ST_PZ_C g.txt g "RW4 F1" && _ST_PZ_C h.txt h "RW4 F2" )
_ST_RUN --land=feat
_ST_RUN -d HEAD~1
cd "$TMP/rw4-wt"
_ST_RUN -M --subject="RW4 F1 renamed" HEAD~1
cd "$TMP/pz-rw4"
RW_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "a dropped commit reworded on the branch – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$RW_T"
_ST_OUT_HAS "named against the copy main dropped" '^  [0-9a-f]* RW4 F1 renamed – like [0-9a-f]* main took, which main dropped since$'
_ST_OUT_LACKS "never as reworded" 'reworded since'
git worktree remove --force "$TMP/rw4-wt"
# Reworded on the branch after main folded a fix into its copy – named against the copy main holds,
# whose reword run as printed keeps main's fix; the land again ends landed
_ST_PZ_NEW rw5
_ST_PZ_C f.txt f "RW5 base"
git worktree add -q -b feat "$TMP/rw5-wt" main 2>/dev/null
( cd "$TMP/rw5-wt" && _ST_PZ_C g.txt g "RW5 F1" && _ST_PZ_C h.txt h "RW5 F2" )
_ST_RUN --land=feat
RW_L=$(git rev-parse HEAD~1)
print -r -- $'g\nFIX' > g.txt && git add g.txt
_ST_RUN --amend-into="$RW_L"
RW_C=$(git rev-parse HEAD~1)
cd "$TMP/rw5-wt"
_ST_RUN -M --text=$'RW5 F1\n\nWhy it lands' "$RW_L"
RW_B=$(git rev-parse HEAD~1)
cd "$TMP/pz-rw5"
RW_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "reworded after main folded into its copy – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$RW_T"
_ST_OUT_HAS "named against the copy main holds" "^  ${RW_B:0:7} RW5 F1 – on main as ${RW_C:0:7}, its change alike, another message$"
RW_C=$(print -r -- "$OUT" | sed -n 's/^.*its new message: //p' | head -1)
RW_C=${RW_C%%$'\e'*}
_RW_AS_PRINTED "$RW_C"
_ST_EQ "whose reword run as printed keeps main's fix" "$(git log -1 --format=%B HEAD~1):$(git show HEAD~1:g.txt | tr '\n' ' ')" "$(git log -1 --format=%B "$RW_B"):g FIX "
_ST_RUN --land=feat
_ST_OUT_HAS "and the land again ends landed" '^git-edit: ok – refs/heads/main unchanged, already landed$'
git worktree remove --force "$TMP/rw5-wt"
# A fix and a new body amended into one landed commit – the fold it prints first, then the reword,
# each run as printed, and the land ends landed with both
_ST_PZ_NEW rw6
_ST_PZ_C f.txt f "RW6 base"
git worktree add -q -b feat "$TMP/rw6-wt" main 2>/dev/null
( cd "$TMP/rw6-wt" && _ST_PZ_C g.txt g "RW6 F1" && _ST_PZ_C h.txt h "RW6 F2" )
_ST_RUN --land=feat
RW_L=$(git rev-parse HEAD~1)
cd "$TMP/rw6-wt"
print -r -- $'g\nFIX' > g.txt && git add g.txt
_ST_RUN --amend-into="$RW_L" --text=$'RW6 F1\n\nWith its fix'
RW_B=$(git rev-parse HEAD~1)
cd "$TMP/pz-rw6"
_ST_RUN --land=feat
_ST_OUT_HAS "the change named first" "^  ${RW_B:0:7} RW6 F1 – like ${RW_L:0:7} main took, another patch$"
RW_C=$(print -r -- "$OUT" | sed -n 's/^.*fold it into [0-9a-f]*: //p' | head -1)
_RW_AS_PRINTED "${RW_C%%$'\e'*}"
_ST_RUN --land=feat
_ST_OUT_HAS "then the reword" "^  ${RW_B:0:7} RW6 F1 – on main as [0-9a-f]*, its change alike, another message$"
RW_C=$(print -r -- "$OUT" | sed -n 's/^.*its new message: //p' | head -1)
_RW_AS_PRINTED "${RW_C%%$'\e'*}"
_ST_RUN --land=feat
_ST_EQ "each run as printed, the land ends landed with fix and body" \
	"$RC:$(git show HEAD~1:g.txt | tr '\n' ' '):$(git log -1 --format=%b HEAD~1)" "0:g FIX :With its fix"
_ST_OUT_HAS "as already landed" '^git-edit: ok – refs/heads/main unchanged, already landed$'
git worktree remove --force "$TMP/rw6-wt"
# A catch-up of main, checked out nowhere, into the main worktree's dev leaves main as it is – no
# move onto dev's copies, no deletion – landed or already landed; another branch checked out nowhere
# is still offered both
_ST_PZ_NEW dm1
_ST_PZ_C a.txt a "DM1 A"
git checkout -q -b dev && _ST_PZ_C d.txt d "DM1 D" && git checkout -q main
_ST_PZ_C b.txt b "DM1 B"
git checkout -q -b side && _ST_PZ_C s.txt s "DM1 S" && git checkout -q dev
_ST_RUN --land=main
_ST_EQ "a catch-up of main into the main worktree's dev lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:DM1 B|DM1 D|DM1 A|"
_ST_OUT_HAS "main said to stay, the default branch" "^Branch main, the repository's default branch, stays as it is – dev now holds copies of its commits\.$"
_ST_OUT_LACKS "never moved onto dev's copies" 'git branch -f main'
_ST_OUT_LACKS "nor deleted" 'git branch -D main'
_ST_RUN --land=main
_ST_OUT_HAS "landed already, main said to stay" "^Nothing to do – main, the repository's default branch, stays as it is\.$"
_ST_OUT_LACKS "never deleted" 'git branch -[dD] main'
_ST_RUN --land=side
_ST_OUT_HAS "another branch checked out nowhere still offered both" "point it at those (git branch -f side $(git rev-parse --short=12 HEAD)) or delete it (git branch -D side)"
# Main checked out in a linked worktree, landed into the main worktree's dev – never a move of that
# checkout onto dev's copies, nor a deletion
_ST_PZ_NEW dm2
_ST_PZ_C a.txt a "DM2 A"
git checkout -q -b dev && _ST_PZ_C d.txt d "DM2 D"
git worktree add -q "$TMP/dm2-wt" main 2>/dev/null
( cd "$TMP/dm2-wt" && _ST_PZ_C b.txt b "DM2 B" )
_ST_RUN --land=main
_ST_EQ "a catch-up of main from its linked worktree lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:DM2 B|DM2 D|DM2 A|"
_ST_OUT_HAS "main said to stay where it is checked out" "^Branch main, the repository's default branch, checked out in .*dm2-wt, stays as it is – dev now holds copies of its commits\.$"
_ST_OUT_LACKS "never moved onto dev's copies there" 'reset --keep'
_ST_RUN --land=main
_ST_OUT_HAS "landed already, main said to stay" "^Nothing to do – main, the repository's default branch, checked out in .*dm2-wt, stays as it is\.$"
_ST_OUT_LACKS "never deleted" 'git branch -[dD] main'
git worktree remove --force "$TMP/dm2-wt"
# The default branch by `init.defaultBranch` first, `main` then offered both; by a remote's HEAD where
# that is unset, past `main`
_ST_PZ_NEW dm3
_ST_PZ_C a.txt a "DM3 A"
git branch trunk
git checkout -q -b dev && _ST_PZ_C d.txt d "DM3 D"
git checkout -q trunk && _ST_PZ_C t.txt t "DM3 T"
git checkout -q main && _ST_PZ_C b.txt b "DM3 B"
git checkout -q dev
git config init.defaultBranch trunk
_ST_RUN --land=trunk
_ST_OUT_HAS "init.defaultBranch's branch said to stay" "^Branch trunk, the repository's default branch, stays as it is – dev now holds copies of its commits\.$"
_ST_RUN --land=main
_ST_OUT_HAS "main, not the default there, offered both" "or delete it (git branch -D main)"
git config --unset init.defaultBranch
git remote add origin "$TMP/dm3-nowhere.git"
git update-ref refs/remotes/origin/trunk trunk
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
_ST_RUN --land=trunk
_ST_OUT_HAS "the remote's HEAD names trunk, said to stay" "^Nothing to do – trunk, the repository's default branch, stays as it is\.$"
_ST_RUN --land=main
_ST_OUT_HAS "main, not the remote's HEAD, offered a delete" '^Nothing to do – delete it once its work is done: git branch -D main$'
cd "$TMP/repo"
