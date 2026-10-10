# `--land` forks past all the target ever held, by its reflog – a land taken back set aside – so a
# peer's rewrite or drop below the fork, a rebase or replant of the branch onto the target, or a
# cherry-pick never shrinks or widens the span – `--base` overriding the fork
# A branch landed already or holding nothing ends `ok`, and a skip leaves the branch
# as the only holder of what it skipped
_ST_SCENARIO "\e[1;96m[162] --land forks past what the target held, ends ok where nothing lands\e[0m"
local LF_T LF_F LF_B LF_WT LF_N LF_C
# A land taken back, then the target reworded below the fork and the branch grown – every commit
# of the branch lands, not just the newest
_ST_PZ_NEW lf1
_ST_PZ_C a.txt a "LF1 base"
_ST_PZ_C m.txt m "LF1 main two"
git checkout -q -b feat && _ST_PZ_C f1.txt f1 "LF1 feat one" && _ST_PZ_C f2.txt f2 "LF1 feat two" && git checkout -q main
_ST_RUN --land=feat
_ST_RUN --undo
_ST_RUN -M --text "LF1 main two, reworded" HEAD
git checkout -q feat && _ST_PZ_C f3.txt f3 "LF1 feat three" && git checkout -q main
_ST_RUN --land=feat --dry-run
_ST_OUT_HAS "a dry run names the fork and where it came from" "Fork point [0-9a-f]* LF1 main two, from main's reflog (a land of feat that --undo took back set aside) – main rewrote or dropped it since"
_ST_OUT_HAS "and replays all three" 'would replay 3 commit(s)'
_ST_RUN --land=feat
_ST_EQ "a land taken back and a rewrite below lose no commit" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LF1 feat three|LF1 feat two|LF1 feat one|LF1 main two, reworded|LF1 base|"
# A land taken back, then one of its commits cherry-picked – the copy refuses the land, never left
# out as landed, and the --base past it it names lands the rest
_ST_PZ_NEW lf2
_ST_PZ_C a.txt a "LF2 base"
git checkout -q -b feat && _ST_PZ_C f1.txt f1 "LF2 feat one" && _ST_PZ_C f2.txt f2 "LF2 feat two" && git checkout -q main
_ST_RUN --land=feat
_ST_RUN --undo
git cherry-pick "$(git rev-parse feat~1)" >/dev/null
_ST_RUN --land=feat
_ST_EQ "after a cherry-pick of one, nothing lands" "$RC:$(git log --format=%s | tr '\n' '|')" "1:LF2 feat one|LF2 base|"
_ST_OUT_HAS "the picked one named with its copy" "^  $(git rev-parse --short=7 feat~1) LF2 feat one – on main as $(git rev-parse --short=7 HEAD), change and message alike$"
_ST_OUT_LACKS "never left out as landed" 'left out'
LF_C=$(print -r -- "$OUT" | sed -n 's/^.*leaving them out: //p' | head -1)
_ST_EQ "the --base past it offered" "${LF_C%%$'\e'*}" "git edit --land=feat --base=$(git rev-parse --short=12 feat~1)"
_ST_RUN --land=feat --base="$(git rev-parse feat~1)"
_ST_EQ "which lands the rest" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LF2 feat two|LF2 feat one|LF2 base|"
# Landed already, by ancestry or by patch id, or holding nothing of its own – ok, nothing moved
_ST_RUN --land=feat
_ST_EQ "a branch landed by patch id ends ok" "$RC:$(git log -1 --format=%s)" "0:LF2 feat two"
_ST_OUT_HAS "as already landed, its trailer saying so" '^git-edit: ok – refs/heads/main unchanged, already landed$'
_ST_OUT_HAS "its commits proven there, so its deletion offered" 'git branch -D feat'
git branch -q fresh
_ST_PZ_C m.txt m "LF2 main moved"
_ST_RUN --land=fresh
_ST_EQ "a branch with no commits of its own ends ok" "$RC:$(git log -1 --format=%s)" "0:LF2 main moved"
_ST_OUT_HAS "saying it has none" "fresh has no commits of its own past that fork – nothing to land"
_ST_OUT_HAS "its trailer saying so" '^git-edit: ok – refs/heads/main unchanged, nothing to land$'
_ST_OUT_LACKS "nothing landed is no deletion offered" 'git branch -[dD]'
# The target dropped the commit the branch forked from – it stays out, on a replay and where the tip
# sits below the branch alike, while --base names an older fork that takes it back
_ST_PZ_NEW lf3
_ST_PZ_C a.txt a "LF3 base"
_ST_PZ_C b.txt b "LF3 dropped by main"
git checkout -q -b feat && _ST_PZ_C f.txt f "LF3 feat" && git checkout -q main
_ST_RUN -d HEAD
LF_T=$(git rev-parse HEAD)
_ST_RUN --land=feat --dry-run
_ST_OUT_HAS "a tip below the branch that dropped its fork replays, no fast-forward" 'would replay 1 commit(s) onto main'
_ST_OUT_HAS "naming what stays out" '^  [0-9a-f]* LF3 dropped by main'
_ST_RUN --land=feat
_ST_EQ "the dropped commit stays out of a land onto that tip" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LF3 feat|LF3 base|"
# Taken back by --undo – a raw reset would leave the copies held, so a land again refuses them
_ST_RUN --undo && git reset -q --hard
_ST_PZ_C m.txt m "LF3 main moved"
_ST_RUN --land=feat
_ST_EQ "and out of a replay onto a moved tip" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LF3 feat|LF3 main moved|LF3 base|"
git reset -q --hard HEAD~1
_ST_RUN --land=feat --base="$(git rev-parse feat~2)"
_ST_EQ "--base names an older fork, taking it back on purpose" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LF3 feat|LF3 dropped by main|LF3 main moved|LF3 base|"
_ST_OUT_HAS "said as --base's" 'Fork point [0-9a-f]* LF3 base, as --base names it – still on main'
_ST_RUN --land=feat --base=main
_ST_EQ "--base takes a SHA alone" "$RC" "1"
_ST_OUT_HAS "naming what it takes" '--base takes the SHA of the commit the landed branch forked from'
_ST_RUN --land=feat --base="$(git rev-parse HEAD)"
_ST_EQ "--base outside the branch's history refuses" "$RC" "1"
_ST_OUT_HAS "as such" "is not in feat's history – nothing landed"
# A branch rebased onto a newer target, or replanted by --onto, forks there – the target dropping
# that newer commit afterwards keeps it out
_ST_PZ_NEW lf4
_ST_PZ_C a.txt a "LF4 base"
git checkout -q -b feat && _ST_PZ_C f.txt f "LF4 feat" && git checkout -q -b feat2 && git checkout -q main
_ST_PZ_C n.txt n "LF4 main newer"
git checkout -q feat && git rebase -q main 2>/dev/null
git checkout -q feat2 && _ST_RUN --onto=main
git checkout -q main
_ST_RUN -d HEAD
_ST_PZ_C m.txt m "LF4 main moved"
LF_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "a rebase onto a newer target forks there" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LF4 feat|LF4 main moved|LF4 base|"
_ST_OUT_HAS "said as the newest commit of it main held" "Fork point [0-9a-f]* LF4 main newer, from main's reflog – main rewrote or dropped it since"
_ST_RUN --undo && git reset -q --hard
_ST_RUN --land=feat2
_ST_EQ "and a replant by --onto" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LF4 feat|LF4 main moved|LF4 base|"
_ST_OUT_HAS "said so for the replant too" "Fork point [0-9a-f]* LF4 main newer, from main's reflog – main rewrote or dropped it since"
# A branch made by `git worktree add -b`, the target folding the commit it forked from – its own
# commit alone lands, and its checkout is named with a step that runs from here
_ST_PZ_NEW lf5
_ST_PZ_C a.txt a "LF5 base"
_ST_PZ_C b.txt b1 "LF5 main one"
_ST_PZ_C b.txt b2 "LF5 main two"
git worktree add -q -b wtb "$TMP/lf5-wt" main 2>/dev/null
( cd "$TMP/lf5-wt" && _ST_PZ_C w.txt w "LF5 worktree branch" )
# From the branch's own worktree, the hints run from where the caller stands
cd "$TMP/lf5-wt"
_ST_RUN --land=wtb
_ST_EQ "landing the branch checked out here refuses" "$RC" "1"
_ST_OUT_HAS "naming the run from the target's checkout" "onto main: git -C .*/pz-lf5 edit --land=wtb"
_ST_RUN --land=main
_ST_EQ "landing the main worktree's branch it holds ends ok" "$RC" "0"
_ST_OUT_LACKS "that branch never offered for deletion" 'git branch -[dD] main'
_ST_OUT_HAS "the land the other way named instead" "To land wtb on it instead, from there: git -C .*/pz-lf5 edit --land=wtb"
cd "$TMP/pz-lf5"
_ST_RUN -s HEAD~1 HEAD
LF_T=$(git rev-parse HEAD)
_ST_RUN --land=wtb
_ST_EQ "a worktree branch over a fold below its fork lands its own commit alone" "$RC:$(git log -1 --format=%s):$(git rev-parse HEAD~1)" "0:LF5 worktree branch:$LF_T"
_ST_OUT_HAS "its checkout's step runnable from here" "git -C .*/lf5-wt reset --keep $(git rev-parse --short=12 HEAD)"
git worktree remove --force "$TMP/lf5-wt"
# Without a reflog of its own, the branch forks where the target's puts it all the same
_ST_PZ_NEW lf6
_ST_PZ_C a.txt a "LF6 base"
LF_F=$(git commit-tree "HEAD^{tree}" -p HEAD -m "LF6 no reflog")
git -c core.logAllRefUpdates=false update-ref refs/heads/nolog "$LF_F"
_ST_PZ_C m.txt m "LF6 main moved"
_ST_RUN --land=nolog
_ST_EQ "a branch without a reflog lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LF6 no reflog|LF6 main moved|LF6 base|"
_ST_OUT_HAS "saying where its fork came from" "Fork point [0-9a-f]* LF6 base, from main's reflog – still on main"
# A branch shares its name with a tag – the branch lands
# A tag alone lands said as one, unmoved
_ST_PZ_NEW lf7
_ST_PZ_C a.txt a "LF7 base"
git checkout -q -b feat && _ST_PZ_C f.txt f "LF7 feat one" && _ST_PZ_C g.txt g "LF7 feat two" && git checkout -q main
git tag feat refs/heads/feat~1
git tag v1 refs/heads/feat
_ST_PZ_C m.txt m "LF7 main moved"
LF_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "the branch wins over the tag of its name" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LF7 feat two|LF7 feat one|LF7 main moved|LF7 base|"
_ST_RUN --undo && git reset -q --hard
git tag -d feat >/dev/null
_ST_RUN --land=v1
_ST_EQ "a tag alone lands, unmoved" "$RC:$(git log -1 --format=%s):$(git rev-parse v1)" "0:LF7 feat two:$(git rev-parse feat)"
_ST_OUT_HAS "said as the tag it is" 'v1 names no branch – landing refs/tags/v1 at'
_ST_RUN --undo && git reset -q --hard
# A branch named with a leading dash resolves, its hints keeping it an operand
git update-ref refs/heads/-x feat
_ST_RUN --land=-x
_ST_EQ "a dash-led branch lands" "$RC:$(git log -1 --format=%s)" "0:LF7 feat two"
_ST_OUT_HAS "its deletion by its full ref" "git update-ref -d refs/heads/-x"
_ST_OUT_HAS "and its pointing too" "git update-ref refs/heads/-x [0-9a-f]*"
_ST_RUN --undo && git reset -q --hard
# A relative name lands the branch it names now, the pause keeping that name
git checkout -q feat && _ST_PZ_C m.txt mf "LF7 feat on m" && git checkout -q main
_ST_RUN --land=@{-1}
_ST_EQ "@{-1} pauses on its conflict" "$RC" "2"
_ST_EQ "the pause holding the branch's name" "$(sed -n 's/^upstream=//p' .git/git-edit-state)" "feat"
_ST_RUN --abort
# Beside --undo, --carry or --status, --land and --onto refuse, nothing done
_ST_RUN -M --text "LF7 main moved, reworded" HEAD
LF_T=$(git rev-parse HEAD)
_ST_RUN --land=feat --undo
_ST_EQ "--land beside --undo refuses, nothing undone" "$RC:$(git rev-parse HEAD)" "1:$LF_T"
_ST_OUT_HAS "naming the two" '--land and --undo cannot be combined'
_ST_RUN --land=feat --carry="$LF_T"
_ST_EQ "beside --carry too" "$RC:$(git rev-parse HEAD)" "1:$LF_T"
_ST_RUN --land=feat --status
_ST_EQ "and beside --status" "$RC" "1"
_ST_RUN --onto=main --undo
_ST_EQ "--onto beside --undo refuses" "$RC:$(git rev-parse HEAD)" "1:$LF_T"
_ST_RUN --undo
_ST_EQ "while --undo alone takes the reword back" "$RC:$(git log -1 --format=%s)" "0:LF7 main moved"
# A skipped commit is named as landed nowhere, the branch as its only holder – nothing moving or
# deleting it offered – and a run skipping all moves and journals nothing
_ST_PZ_NEW lf8
_ST_PZ_C c.txt $'1\n2\n3' "LF8 base"
git checkout -q -b feat && _ST_PZ_C c.txt $'1\n2f\n3' "LF8 feat conflicting" && _ST_PZ_C g.txt g "LF8 feat two" && git checkout -q main
_ST_PZ_C c.txt $'1\n2m\n3' "LF8 main"
LF_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_RUN --skip
_ST_EQ "a skip lands the rest" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LF8 feat two|LF8 main|LF8 base|"
_ST_OUT_HAS "the skipped one named as on the branch alone" "Branch feat keeps 1 commit(s) main holds in no form"
_ST_OUT_HAS "by its subject" '^  [0-9a-f]* LF8 feat conflicting$'
_ST_OUT_LACKS "no move of the branch offered" 'git branch -f feat'
_ST_OUT_LACKS "nor its deletion" 'git branch -D feat'
git reset -q --hard "$LF_T"
git branch -q -f feat feat~1
LF_N=$(wc -l < .git/git-edit-journal)
_ST_RUN --land=feat
_ST_RUN --skip
_ST_EQ "a skip of every commit moves nothing" "$RC:$(git rev-parse HEAD)" "0:$LF_T"
_ST_OUT_HAS "its trailer saying nothing landed" '^git-edit: ok – refs/heads/main unchanged, nothing landed$'
_ST_EQ "and journals nothing" "$(wc -l < .git/git-edit-journal)" "$LF_N"
_ST_OUT_LACKS "no undo offered for it" 'Undo: git edit --undo'
# While a clean replay still offers the branch's move onto the copies
git checkout -q -b clean "$LF_T~1" && _ST_PZ_C h.txt h "LF8 clean" && git checkout -q main
_ST_RUN --land=clean
_ST_OUT_HAS "a clean replay offers the move onto the copies" "point it at those (git branch -f clean $(git rev-parse --short=12 HEAD))"
# A merge in the span refuses a replay, the merge it names recording the target's name
git checkout -q -b mrg "$LF_T~1" && _ST_PZ_C k.txt k "LF8 mrg one"
git merge -q --no-ff -m "LF8 merge clean" clean && git checkout -q main
_ST_RUN --land=mrg
_ST_EQ "a merge past the fork refuses" "$RC" "1"
_ST_OUT_LACKS "no replant offered, which refuses a merge too" 'replant'
_ST_OUT_HAS "the merge named with a message" "git merge --no-ff -m \"Merge branch 'mrg' into main\" mrg"
_ST_RUN --exec -- git merge -q --no-ff -m "Merge branch 'mrg' into main" mrg
_ST_EQ "which records the target's name" "$RC:$(git log -1 --format=%s)" "0:Merge branch 'mrg' into main"
# --onto refuses uncommitted work only on the paths the upstream changed since the fork – the
# branch's own files land as they are – naming a step per file and never a stash
_ST_PZ_NEW lf9
_ST_PZ_C a.txt a "LF9 base"
_ST_PZ_C m.txt m1 "LF9 main one"
git checkout -q -b feat && _ST_PZ_C f.txt f "LF9 feat" && git checkout -q main
_ST_RUN -M --text "LF9 main one, reworded" HEAD
git checkout -q feat
print -r -- fwip >> f.txt
_ST_RUN --onto=main
_ST_EQ "WIP on the branch's own file replants" "$RC:$(git log --format=%s | tr '\n' '|'):$(tr '\n' ' ' < f.txt)" "0:LF9 feat|LF9 main one, reworded|LF9 base|:f fwip "
# The target moves on by plumbing, the checkout's WIP keeping it on the branch
LF_B=$(print -r -- m2 | git hash-object -w --stdin)
GIT_INDEX_FILE="$TMP/lf9-index" git read-tree main
GIT_INDEX_FILE="$TMP/lf9-index" git update-index --cacheinfo "100644,$LF_B,m.txt"
git update-ref refs/heads/main "$(git commit-tree "$(GIT_INDEX_FILE="$TMP/lf9-index" git write-tree)" -p main -m "LF9 main two")"
print -r -- mwip > m.txt
LF_T=$(git rev-parse HEAD)
_ST_RUN --onto=main
_ST_EQ "WIP on a path the upstream changed refuses" "$RC:$(git rev-parse HEAD)" "1:$LF_T"
_ST_OUT_HAS "naming the file and its step" "m.txt (modified) – yours: git edit --commit --text '<subject>' -- m.txt"
_ST_OUT_LACKS "never a stash" 'stash'
cd "$TMP/repo"
