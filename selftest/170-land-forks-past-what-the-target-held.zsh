# `--land`'s own commits are those the target never held, by its reflog, a land of the
# branch an `--undo` took back set aside – so a branch redone or moved onto its copies
# after that undo, a land kept and partly dropped since, or a catch-up to a commit the
# target dropped all land exactly their own
# Without a reflog to read, a span past the merge base holding what looks like the
# target's rewritten history refuses
# What landed comes from the replay, never a patch id, and every hint runs
_ST_SCENARIO "\e[1;96m[170] --land lands what the target never held, and says what landed\e[0m"
local LH_T LH_B LH_C LH_WT
# The branch's moves after an undo dated past it, as they come in real time – the undo's entry takes
# the wall clock, the suite's commits a pinned one long before
local LH_LATE="@$(( $(date +%s) + 3600 )) +0000"
# A land taken back, the branch's last commit then redone – both its commits land,
# where the redone one alone did
# A land kept and one of its commits dropped since – only what the branch gained lands
_ST_PZ_NEW lh1
_ST_PZ_C a.txt m1 "LH1 m1"
_ST_PZ_C a.txt m2 "LH1 m2"
git checkout -q -b feat && _ST_PZ_C b.txt c1 "LH1 c1" && _ST_PZ_C c.txt c2 "LH1 c2" && git checkout -q main
_ST_RUN --land=feat
_ST_RUN --undo
git checkout -q feat && GIT_COMMITTER_DATE=$LH_LATE git reset -q --soft HEAD~1 && \
	GIT_COMMITTER_DATE=$LH_LATE git commit -qm "LH1 c2 redone" && git checkout -q main
_ST_RUN --land=feat
_ST_EQ "a land taken back, the branch's last commit redone – both its commits land" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LH1 c2 redone|LH1 c1|LH1 m2|LH1 m1|"
_ST_OUT_HAS "the land taken back said as set aside" "from main's reflog (a land of feat that --undo took back set aside) – still on main"
_ST_PZ_NEW lh1b
_ST_PZ_C a.txt m1 "LH1B m1"
_ST_PZ_C a.txt m2 "LH1B m2"
git checkout -q -b feat && _ST_PZ_C b.txt c1 "LH1B c1" && _ST_PZ_C c.txt c2 "LH1B c2" && git checkout -q main
_ST_RUN --land=feat
_ST_RUN -d "$(git rev-parse HEAD~1)"
git checkout -q feat && _ST_PZ_C d.txt c3 "LH1B c3" && git checkout -q main
_ST_RUN --land=feat
_ST_EQ "a land kept, main dropping one of its commits since – only the new one lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LH1B c3|LH1B c2|LH1B m2|LH1B m1|"
_ST_OUT_HAS "forking at the newest commit of it main held" "Fork point [0-9a-f]* LH1B c2, from main's reflog – main rewrote or dropped it since"
# The branch moved onto the copies a replay landed, as the land's hint offers, then the land taken
# back – the copies land again, where nothing did
_ST_PZ_NEW lh2
_ST_PZ_C a.txt m1 "LH2 m1"
git worktree add -q -b feat "$TMP/lh2-wt" main 2>/dev/null
( cd "$TMP/lh2-wt" && _ST_PZ_C b.txt c1 "LH2 c1" && _ST_PZ_C c.txt c2 "LH2 c2" )
_ST_PZ_C m.txt m2 "LH2 m2"
_ST_RUN --land=feat
_ST_OUT_HAS "a replay offers the branch's checkout the move onto the copies" "lh2-wt reset --keep $(git rev-parse --short=12 HEAD)"
GIT_COMMITTER_DATE=$LH_LATE git -C "$TMP/lh2-wt" reset -q --keep "$(git rev-parse HEAD)"
_ST_RUN --undo
_ST_RUN --land=feat
_ST_EQ "the land taken back after that move lands the copies again" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LH2 c2|LH2 c1|LH2 m2|LH2 m1|"
git worktree remove --force "$TMP/lh2-wt"
# A branch caught up to main – by a fast-forward merge, a bare `update-ref`, a land of main – then
# main dropping what it caught up to: that commit stays out, while kept it fast-forwards
_ST_PZ_NEW lh3
_ST_PZ_C a.txt m1 "LH3 m1"
_ST_PZ_C a.txt m2 "LH3 m2"
git branch fm && git branch fu && git branch fl
_ST_PZ_C x.txt bad "LH3 m3 bad"
git checkout -q fm && git merge -q --ff-only main && _ST_PZ_C b.txt c1 "LH3 fm c1"
git update-ref refs/heads/fu main && git checkout -q fu && _ST_PZ_C b.txt c1 "LH3 fu c1"
git checkout -q fl
_ST_RUN --land=main
_ST_PZ_C b.txt c1 "LH3 fl c1"
git checkout -q main
_ST_RUN --land=fu --dry-run
_ST_OUT_HAS "a catch-up main keeps fast-forwards" 'Landing fu on main – a fast-forward of 1 commit(s)'
_ST_RUN -d HEAD
LH_T=$(git rev-parse HEAD)
for LH_B in fm fu fl; do
	git reset -q --hard "$LH_T"
	_ST_RUN --land=$LH_B
	_ST_EQ "a catch-up ($LH_B) to a commit main dropped since keeps that commit out" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LH3 $LH_B c1|LH3 m2|LH3 m1|"
done
# Round 4's shapes keep landing:
# • A commit main dropped below the fork stays out
# • A land taken back, main reworded below the fork and one commit cherry-picked, refuses on the
#   pick's original, the `--base` past it landing the rest
_ST_PZ_NEW lh4
_ST_PZ_C a.txt a "LH4 base"
_ST_PZ_C b.txt b "LH4 dropped"
git checkout -q -b feat && _ST_PZ_C f.txt f "LH4 feat" && git checkout -q main
_ST_RUN -d HEAD
_ST_RUN --land=feat
_ST_EQ "a commit main dropped below the fork stays out" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LH4 feat|LH4 base|"
_ST_PZ_NEW lh5
_ST_PZ_C a.txt a "LH5 base"
_ST_PZ_C m.txt m "LH5 m"
git checkout -q -b feat && _ST_PZ_C f1.txt f1 "LH5 f1" && _ST_PZ_C f2.txt f2 "LH5 f2" && git checkout -q main
_ST_RUN --land=feat
_ST_RUN --undo
_ST_RUN -M --text "LH5 m reworded" HEAD
git cherry-pick "$(git rev-parse feat~1)" >/dev/null
git checkout -q feat && _ST_PZ_C f3.txt f3 "LH5 f3" && git checkout -q main
_ST_RUN --land=feat
_ST_EQ "a land taken back, a reword below and a pick – the pick's original refuses" "$RC" "1"
_ST_OUT_HAS "named with its copy" "^  $(git rev-parse --short=7 feat~2) LH5 f1 – on main as $(git rev-parse --short=7 HEAD), change and message alike$"
_ST_RUN --land=feat --base="$(git rev-parse feat~2)"
_ST_EQ "the --base past it lands the rest" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LH5 f3|LH5 f2|LH5 f1|LH5 m reworded|LH5 base|"
# With no reflog to read, a span past the merge base holding a copy of a main commit refuses,
# naming it and the `--base` for each reading
# With nothing alike it lands from there, with the branch's reflog alone forking where that puts it
_ST_PZ_NEW lh6
_ST_PZ_C a.txt m1 "LH6 m1"
_ST_PZ_C m2.txt m2 "LH6 m2"
_ST_PZ_C m3.txt m3 "LH6 m3"
git checkout -q -b feat && _ST_PZ_C b.txt c1 "LH6 c1" && git checkout -q main
_ST_PZ_C m4.txt m4 "LH6 m4"
_ST_RUN -d "$(git rev-parse HEAD~2)"
LH_T=$(git rev-parse HEAD)
git reflog expire --expire=now --all
_ST_RUN --land=feat
_ST_EQ "no reflog to read and a rewritten copy past the merge base – nothing lands" "$RC:$(git rev-parse HEAD)" "1:$LH_T"
_ST_OUT_HAS "naming the copy" '^  [0-9a-f]* LH6 m3$'
_ST_OUT_HAS "the --base landing what follows it" "git edit --land=feat --base=$(git rev-parse --short=12 feat~1)"
_ST_OUT_HAS "and the one landing from the merge base" "git edit --land=feat --base=$(git rev-parse --short=12 feat~3)"
_ST_RUN --land=feat --base="$(git rev-parse feat~1)"
_ST_EQ "the first lands the branch's own commit alone" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LH6 c1|LH6 m4|LH6 m3|LH6 m1|"
_ST_PZ_NEW lh7
_ST_PZ_C a.txt m1 "LH7 m1"
git checkout -q -b feat && _ST_PZ_C b.txt c1 "LH7 c1" && git checkout -q main
_ST_PZ_C m.txt m2 "LH7 m2"
git reflog expire --expire=now refs/heads/main
_ST_RUN --land=feat --dry-run
_ST_OUT_HAS "main keeping no reflog, the branch's own names the fork" "from feat's reflog (branch: Created from HEAD), main keeping none – still on main"
git reflog expire --expire=now --all
_ST_RUN --land=feat
_ST_EQ "neither keeping one, nothing alike – it lands from the merge base" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LH7 c1|LH7 m2|LH7 m1|"
_ST_OUT_HAS "saying so" 'the merge base, as neither main nor feat keeps a reflog to read'
# A commit whose context changed lands as landed, the branch offered its move – and landed again it
# ends ok as already landed, never as skipped
_ST_PZ_NEW lh8
_ST_PZ_C f.txt $'l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8' "LH8 base"
git checkout -q -b feat && _ST_PZ_C f.txt $'l1\nl2\nl3\nl4\nL5\nl6\nl7\nl8' "LH8 feat l5" && git checkout -q main
_ST_PZ_C f.txt $'l1\nl2\nL3\nl4\nl5\nl6\nl7\nl8' "LH8 main l3"
_ST_RUN --land=feat
_ST_EQ "a commit whose context changed lands" "$RC:$(git log -1 --format=%s)" "0:LH8 feat l5"
_ST_OUT_HAS "the branch offered the move onto its copy" "point it at those (git branch -f feat $(git rev-parse --short=12 HEAD))"
_ST_OUT_LACKS "never said held in no form" 'in no form'
_ST_RUN --land=feat
_ST_EQ "landed again it ends ok, unchanged" "$RC:$(git log -1 --format=%s)" "0:LH8 feat l5"
_ST_OUT_HAS "as already landed" '^git-edit: ok – refs/heads/main unchanged, already landed$'
_ST_OUT_HAS "its deletion offered" 'git branch -D feat'
_ST_OUT_LACKS "never as skipped" 'skipped'
# A skipped commit beside one resolved by hand – the skipped one alone is the branch's to keep
_ST_PZ_NEW lh9
_ST_PZ_C c.txt $'1\n2\n3' "LH9 base"
_ST_PZ_C d.txt $'a\nb\nc' "LH9 base two"
git checkout -q -b feat && _ST_PZ_C c.txt $'1\n2f\n3' "LH9 c1" && _ST_PZ_C d.txt $'a\nbf\nc' "LH9 c2" && git checkout -q main
_ST_PZ_C c.txt $'1\n2m\n3' "LH9 main c"
_ST_PZ_C d.txt $'a\nbm\nc' "LH9 main d"
_ST_RUN --land=feat
_ST_RUN --skip
LH_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${LH_WT:-$ST_NO_WT}" d.txt $'a\nbm bf\nc'
_ST_RUN --continue
_ST_EQ "a skip and a hand resolution land the resolved one" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LH9 c2|LH9 main d|LH9 main c|LH9 base two|LH9 base|"
_ST_OUT_HAS "the skipped one alone kept by the branch" 'Branch feat keeps 1 commit(s) main holds in no form'
_ST_OUT_HAS "and counted as skipped" '^1 commit(s) were skipped'
# A revision lands the commit it names, said so, with no branch command for it
# `--base` on the branch's own commit is said as `--base`'s choice
# The hint from the branch's checkout runs as printed
_ST_PZ_NEW lh10
_ST_PZ_C a.txt m1 "LH10 m1"
git checkout -q -b feat && _ST_PZ_C b.txt c1 "LH10 c1" && _ST_PZ_C c.txt c2 "LH10 c2" && git checkout -q main
_ST_PZ_C m.txt m2 "LH10 m2"
LH_T=$(git rev-parse HEAD)
_ST_RUN --land='feat~1'
_ST_EQ "a revision lands the commit it names" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LH10 c1|LH10 m2|LH10 m1|"
_ST_OUT_HAS "said as no branch" 'feat~1 names no branch – landing commit [0-9a-f]* LH10 c1'
_ST_OUT_LACKS "no branch command offered for it" 'git branch'
_ST_RUN --undo && git reset -q --hard
_ST_RUN --land='feat@{0}' --dry-run
_ST_OUT_HAS "a reflog selector too" 'feat@{0} names no branch – landing commit [0-9a-f]* LH10 c2'
_ST_RUN --land=feat --base="$(git rev-parse feat~1)" --dry-run
_ST_OUT_HAS "--base on the branch's own commit said as its choice" 'LH10 c1, as --base names it – not on main, so the commits up to it stay out, as --base asks'
_ST_OUT_LACKS "never as main's rewrite" 'rewrote or dropped'
_ST_RUN --land=feat
_ST_OUT_HAS "a branch itself offered its move" 'git branch -f feat'
git worktree add -q -b wtb "$TMP/lh10-wt" main 2>/dev/null
( cd "$TMP/lh10-wt" && _ST_PZ_C w.txt w "LH10 wtb" )
cd "$TMP/lh10-wt"
_ST_RUN --land=wtb
LH_C=$(print -r -- "$OUT" | sed -n 's/^.*onto main: //p' | head -1)
LH_C=${LH_C%%$'\e'*}
mkdir -p "$TMP/lh-bin" && ln -sf "$SELF" "$TMP/lh-bin/git-edit"
( export PATH="$TMP/lh-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1; eval "$LH_C" </dev/null ) >/dev/null 2>&1
cd "$TMP/pz-lh10"
_ST_EQ "the hint from the branch's checkout runs as printed" "$(git log -1 --format=%s)" "LH10 wtb"
git worktree remove --force "$TMP/lh10-wt"
cd "$TMP/repo"
