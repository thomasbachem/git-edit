# `--land=<branch>` lands a branch's commits on the checked-out one – a fast-forward by CAS into a
# dirty checkout, else a replay onto the tip in an isolated worktree, pausing as a replant does –
# <branch> itself never moving, the checkout handled as after any landing
_ST_SCENARIO "\e[1;96m[157] --land lands a branch on the checked-out one\e[0m"
local LD_T LD_F LD_N LD_WT LD_P LD_C
# A fast-forward into a dirty checkout – a peer's staging kept, uncommitted work untouched, the
# hints naming what the landing left
_ST_PZ_NEW ld1
_ST_PZ_C a.txt $'1\n2\n3' "LD base"
LD_T=$(git rev-parse HEAD)
git checkout -q -b feat
_ST_PZ_C f.txt f "LD feat one"
_ST_PZ_C a.txt $'1\n2f\n3' "LD feat two"
LD_F=$(git rev-parse HEAD)
git checkout -q main
print -r -- peer > p.txt && git add p.txt
print -r -- $'1\n2\n3\n4' > a.txt
print -r -- wip > w.txt
_ST_RUN --land=feat --dry-run
_ST_EQ "a dry run lands nothing" "$RC:$(git rev-parse HEAD)" "0:$LD_T"
_ST_OUT_HAS "saying it would fast-forward" 'would fast-forward main to'
_ST_OUT_HAS "listing the commits" 'LD feat two'
_ST_OUT_HAS "its trailer naming the dry run" '^git-edit: ok – refs/heads/main unchanged, dry run$'
_ST_RUN --land=feat
_ST_EQ "a fast-forward lands the branch's tip" "$RC:$(git rev-parse HEAD)" "0:$LD_F"
_ST_OUT_HAS "said to be one" 'a fast-forward of 2 commit(s)'
_ST_EQ "a peer's staging stays staged" "$(git diff --cached --name-only)" "p.txt"
_ST_EQ "uncommitted work stays as it was" "$(tr '\n' ' ' < a.txt):$(<w.txt)" "1 2 3 4 :wip"
_ST_OUT_HAS "the edits on what it changed named, with the carry" "git edit --carry=${LD_T:0:12}"
_ST_OUT_HAS "and the file it added offered" 'git restore --source=HEAD --worktree -- f.txt'
_ST_EQ "the branch landed stays where it was" "$(git rev-parse feat)" "$LD_F"
_ST_EQ "journaled as a land of that branch" "$(git reflog -1 --format=%gs main):$(tail -1 .git/git-edit-journal | cut -d' ' -f5-)" "git edit: land feat:land feat"
_ST_OUT_LACKS "nothing pushed, nothing said of it" 'already pushed'
_ST_RUN --undo
_ST_EQ "an undo takes the land back" "$RC:$(git rev-parse HEAD):$(git diff --cached --name-only)" "0:$LD_T:p.txt"
_ST_RUN --land=feat
_ST_RUN --land=feat
_ST_EQ "a branch the target holds lands nothing, ok" "$RC:$(git rev-parse HEAD)" "0:$LD_F"
_ST_OUT_HAS "as already landed" 'feat is already landed'
_ST_OUT_HAS "its trailer saying so" '^git-edit: ok – refs/heads/main unchanged, already landed$'
_ST_OUT_HAS "naming what is left to do" 'delete it once its work is done: git branch -d feat'
git reset -q && git checkout -q -- a.txt f.txt && git clean -fq
git checkout -q --detach
_ST_RUN --land=feat
_ST_EQ "a detached HEAD refuses" "$RC" "1"
_ST_OUT_HAS "naming the checkout to make first" 'HEAD is detached'
git checkout -q main
_ST_RUN --land=nope
_ST_EQ "an unknown branch refuses" "$RC" "1"
_ST_OUT_HAS "naming it" 'Unknown branch: nope'
_ST_RUN --land=main
_ST_EQ "the target itself refuses" "$RC" "1"
_ST_OUT_HAS "as itself" 'main is the checked-out branch itself'
_ST_RUN --land=feat -d HEAD
_ST_EQ "another mode beside it refuses" "$RC" "1"
_ST_OUT_HAS "as such" 'Option --land cannot be combined'
_ST_RUN --land=feat HEAD
_ST_EQ "a positional refuses" "$RC" "1"
_ST_OUT_HAS "naming it" '--land takes no <commit> arguments'
# A replay without a conflict, onto a target that moved past the fork – the branch keeps its
# commits and is named as keeping them, a checkout of it elsewhere too, and a pushed one copied
_ST_PZ_NEW ld2
_ST_PZ_C a.txt a "LR base"
git checkout -q -b feat2
_ST_PZ_C f.txt f "LR feat"
LD_F=$(git rev-parse HEAD)
git checkout -q main
_ST_PZ_C m.txt m "LR main moved"
LD_T=$(git rev-parse HEAD)
git init -q --bare "$TMP/ld2-origin.git" && git remote add origin "$TMP/ld2-origin.git" && git push -q origin feat2 2>/dev/null
git worktree add -q "$TMP/ld2-wt" feat2 2>/dev/null
_ST_RUN --land=feat2 --dry-run
_ST_EQ "a replay's dry run lands nothing" "$RC:$(git rev-parse HEAD)" "0:$LD_T"
_ST_OUT_HAS "saying it would replay" 'would replay 1 commit(s) onto main'
_ST_RUN --land=feat2 -C="$TMP/ld2-c"
_ST_EQ "a replay lands on the tip" "$RC:$(git log --format=%s | tr '\n' '|'):$(git rev-parse HEAD^)" "0:LR feat|LR main moved|LR base|:$LD_T"
_ST_EQ "the branch keeps the original commits" "$(git rev-parse feat2)" "$LD_F"
_ST_OUT_HAS "named as keeping them, checked out elsewhere" 'Branch feat2, checked out in .*/ld2-wt, still holds the original commits'
_ST_OUT_HAS "with what that checkout does, run from here" "git -C .*/ld2-wt reset --keep $(git rev-parse --short=12 HEAD)"
_ST_OUT_HAS "the pushed commits it copied named, not refused" 'already pushed (on: origin/feat2)'
_ST_EQ "in the -C path named, which stays" "$(git -C "$TMP/ld2-c" rev-parse HEAD 2>/dev/null)" "$(git rev-parse HEAD)"
_ST_EQ "journaled as a land" "$(tail -1 .git/git-edit-journal | cut -d' ' -f5-)" "land feat2"
_ST_RUN --land=feat2
_ST_EQ "a branch landed by replay lands nothing a second time, ok" "$RC" "0"
_ST_OUT_HAS "as landed in another form" 'in another form (by patch id)'
git worktree remove --force "$TMP/ld2-wt" && git worktree remove --force "$TMP/ld2-c"
# A merge past the fork refuses a replay, which would flatten it – while a fast-forward lands it
_ST_PZ_NEW ld3
_ST_PZ_C a.txt a "LM base"
git checkout -q -b side && _ST_PZ_C s.txt s "LM side"
git checkout -q -b feat3 main && _ST_PZ_C f.txt f "LM feat"
git merge -q --no-ff -m "LM merge" side
LD_F=$(git rev-parse HEAD)
git checkout -q main
_ST_PZ_C m.txt m "LM main moved"
_ST_RUN --land=feat3
_ST_EQ "a merge in a replay's span refuses" "$RC:$(git log -1 --format=%s)" "1:LM main moved"
_ST_OUT_HAS "naming the merge" 'feat3 holds a merge commit past its fork, [0-9a-f]* LM merge'
git reset -q --hard HEAD~1
_ST_RUN --land=feat3
_ST_EQ "a fast-forward lands one" "$RC:$(git rev-parse HEAD)" "0:$LD_F"
# A replay pausing on a conflict – resumed, cancelled, skipped past, taken up by its own label alone
_ST_PZ_NEW ld4
_ST_PZ_C c.txt $'1\n2\n3' "LC base"
git checkout -q -b feat4
_ST_PZ_C c.txt $'1\n2f\n3' "LC feat c"
_ST_PZ_C g.txt g "LC feat g"
LD_F=$(git rev-parse HEAD)
git checkout -q main
_ST_PZ_C c.txt $'1\n2m\n3' "LC main c"
LD_T=$(git rev-parse HEAD)
_ST_RUN --land=feat4
LD_WT=$(_ST_PZ_WT)
_ST_EQ "a conflict pauses, nothing landed" "$RC:$(git rev-parse HEAD)" "2:$LD_T"
_ST_OUT_HAS "the trailer naming the worktree" "^git-edit: conflict – resolve in ${LD_WT:-$ST_NO_WT} (c.txt)"
_ST_RUN --status
_ST_OUT_HAS "--status names it as a land" 'In-flight operation: land'
_ST_RESOLVE "${LD_WT:-$ST_NO_WT}" c.txt $'1\n2fm\n3'
_ST_RUN --continue
_ST_EQ "--continue lands it" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:c.txt | tr '\n' ' ')" "0:LC feat g|LC feat c|LC main c|LC base|:1 2fm 3 "
_ST_CHECK "its worktree gone" test ! -e "${LD_WT:-$ST_NO_WT}"
_ST_EQ "the branch untouched" "$(git rev-parse feat4)" "$LD_F"
# Taken back by --undo – a raw reset would leave the copies held, so the land again refuses them
_ST_RUN --undo
git reset -q --hard
_ST_RUN --land=feat4
LD_WT=$(_ST_PZ_WT)
_ST_RUN --abort
_ST_EQ "--abort cancels it" "$RC:$(git rev-parse HEAD):$(git rev-parse feat4)" "0:$LD_T:$LD_F"
_ST_OUT_HAS "said as a land" 'Land aborted, state cleared.'
_ST_CHECK "its worktree gone too" test ! -e "${LD_WT:-$ST_NO_WT}"
_ST_RUN --land=feat4
_ST_RUN --skip
_ST_EQ "--skip lands past the conflicted commit" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LC feat g|LC main c|LC base|"
_ST_OUT_HAS "counting it" '1 commit(s) were skipped'
_ST_RUN --undo
git reset -q --hard
export GIT_EDIT_ACTOR=ld-a
_ST_RUN --land=feat4
export GIT_EDIT_ACTOR=ld-b
_ST_RUN --continue
_ST_EQ "another label's continue refuses" "$RC:$(git rev-parse HEAD)" "1:$LD_T"
_ST_OUT_HAS "naming whose the land is" "The paused land is ld-a's – refusing to continue it as ld-b"
_ST_RUN --status
_ST_OUT_HAS "--status leaves it to that caller" "^git-edit: paused – land ${LD_F:0:7} is ld-a's, not yours"
export GIT_EDIT_ACTOR=ld-a
_ST_RUN --abort
_ST_EQ "while its own label cancels it" "$RC" "0"
export GIT_EDIT_ACTOR=
# A peer landing on the target meanwhile – a paused replay refuses, its resolution kept, and a
# fresh land rebuilds on the new tip
_ST_RUN --land=feat4
LD_WT=$(_ST_PZ_WT)
_ST_PZ_C p.txt p "LC peer"
LD_P=$(git rev-parse HEAD)
_ST_RESOLVE "${LD_WT:-$ST_NO_WT}" c.txt $'1\n2fm\n3'
_ST_RUN --continue
_ST_EQ "a resume over a peer's landing refuses" "$RC:$(git rev-parse HEAD)" "1:$LD_P"
_ST_OUT_HAS "keeping the resolution" 'Your resolution is intact in'
_ST_RUN --abort
_ST_RUN --land=feat4
_ST_RESOLVE "$(_ST_PZ_WT)" c.txt $'1\n2fm\n3'
_ST_RUN --continue
_ST_EQ "and a land again rebuilds on the new tip" "$RC:$(git rev-parse HEAD~2)" "0:$LD_P"
# A fast-forward whose target a peer moves while its gate runs refuses, never overwriting it
_ST_PZ_NEW ld5
_ST_PZ_C a.txt a "LP base"
git checkout -q -b feat5 && _ST_PZ_C f.txt f "LP feat" && git checkout -q main
LD_P=$(git commit-tree "HEAD^{tree}" -p HEAD -m "LP peer")
_ST_RUN --land=feat5 --verify="git update-ref refs/heads/main $LD_P"
_ST_EQ "a fast-forward over a peer's landing refuses" "$RC:$(git rev-parse HEAD)" "1:$LD_P"
_ST_OUT_HAS "naming the move" 'moved from .* during the land – refusing to overwrite'
_ST_OUT_HAS "and the run again" 'land it onto the new tip: git edit --land=feat5'
_ST_RUN --land=feat5
_ST_EQ "which lands on the new tip" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LP feat|LP peer|LP base|"
# A target that once held the branch's commits – a fast-forward taken back – then moved on still
# lacks them, its reflog's word notwithstanding
_ST_PZ_NEW ld7
_ST_PZ_C a.txt a "LU base"
git checkout -q -b feat7 && _ST_PZ_C f.txt f "LU feat one" && _ST_PZ_C g.txt g "LU feat two" && git checkout -q main
LD_T=$(git rev-parse HEAD)
# The gate checks a fast-forward too, refusing it outright, as `--exec`'s does
git config edit.verifyCmd false
_ST_RUN --land=feat7
_ST_EQ "a failing gate refuses a fast-forward" "$RC:$(git rev-parse HEAD)" "1:$LD_T"
_ST_OUT_HAS "naming the run that lands it unchecked" 'land it unchecked: git edit --land=feat7 --no-verify'
_ST_RUN --land=feat7 --no-verify
_ST_EQ "which lands it" "$RC:$(git rev-parse HEAD)" "0:$(git rev-parse feat7)"
_ST_OUT_HAS "saying the gate was skipped" '^Verify skipped – --no-verify was passed'
git config --unset edit.verifyCmd
_ST_RUN --undo
_ST_PZ_C p.txt p "LU peer"
_ST_RUN --land=feat7
_ST_EQ "a land taken back lands again, every commit replayed" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LU feat two|LU feat one|LU peer|LU base|"
# While a rewrite of the target below the fork leaves the fork where the target's reflog puts it
_ST_PZ_NEW ld8
_ST_PZ_C a.txt a "LW base"
_ST_PZ_C b.txt b "LW main two"
git checkout -q -b feat8 && _ST_PZ_C f.txt f "LW feat" && git checkout -q main
_ST_RUN -M --text "LW main two, reworded" HEAD
LD_T=$(git rev-parse HEAD)
# A replay's failing gate pauses, as a replant's does
_ST_RUN --land=feat8 --verify=false
_ST_EQ "a failing gate pauses a replay, nothing landed" "$RC:$(git rev-parse HEAD)" "2:$LD_T"
_ST_OUT_HAS "on a verify pause" '^git-edit: paused – verify failed at'
_ST_OUT_HAS "a rewrite of its target below the fork named, the fork from the target's reflog" "LW main two, from main's reflog – main rewrote or dropped it since"
_ST_RUN --no-verify --continue
_ST_EQ "which lands the branch's own commits alone" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LW feat|LW main two, reworded|LW base|"
# At a terminal the checkout comes along, edits merged onto what landed
_ST_PZ_NEW ld6
_ST_PZ_C a.txt $'1\n2\n3\n4\n5' "LT base"
git checkout -q -b feat6 && _ST_PZ_C a.txt $'1\n2f\n3\n4\n5' "LT feat" && git checkout -q main
print -r -- $'1\n2\n3\n4\n5y' > a.txt
_ST_TTY -- --land=feat6
_ST_EQ "a terminal land brings the checkout along" "$RC:$(tr '\n' ' ' < a.txt):$(git diff --cached --name-only)" "0:1 2f 3 4 5y :"
_ST_OUT_HAS "naming the edits merged" 'edits merged onto what landed: a.txt'
cd "$TMP/repo"
