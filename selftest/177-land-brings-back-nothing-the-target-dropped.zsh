# What `--land` lands is the branch's own commits alone:
# • A commit the target held and dropped since, carried by a catch-up merge,
#   refuses by name, never a merge offered
# • One held by a peer inside an undone land's window, or copied by a catch-up land,
#   stays out by name, the drop standing
# • A branch commit like an earlier replay's copy refuses, the `--base` it names landing as printed
# • The raw undo a land prints reads as an undo
# • A catch-up of the main worktree's branch never offers to move that checkout
# • Main rewritten below the fork lands as ever
_ST_SCENARIO "\e[1;96m[177] --land brings back nothing the target dropped, and lands copies once\e[0m"
# Each given a value, as 157 declares some of these names in the same scope, where a bare one prints
local LD_T= LD_C= LD_M= LD_WT=
# A catch-up merge main keeps fast-forwards – main dropping what it merged since, the land
# refuses, naming it and the fork that lands it back all the same, never a merge
_ST_PZ_NEW ld1
_ST_PZ_C a.txt a "LD1 A"
git worktree add -q -b feat "$TMP/ld1-wt" main 2>/dev/null
( cd "$TMP/ld1-wt" && _ST_PZ_C f1.txt f1 "LD1 F1" )
_ST_PZ_C x.txt x "LD1 X"
( cd "$TMP/ld1-wt" && git merge -q --no-edit main )
_ST_RUN --land=feat --dry-run
_ST_OUT_HAS "a catch-up merge main keeps fast-forwards" 'Landing feat on main – a fast-forward of 2 commit(s)'
_ST_RUN -d HEAD
LD_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "a catch-up merge carrying a commit main dropped since lands nothing" "$RC:$(git rev-parse HEAD)" "1:$LD_T"
_ST_OUT_HAS "naming that commit" '^  [0-9a-f]* LD1 X$'
_ST_OUT_HAS "and the branch's own commits the dropped one sits above" '^  [0-9a-f]* LD1 F1$'
_ST_OUT_HAS "and the fork landing it back all the same" "To land them back all the same: git edit --land=feat --base=$(git rev-parse --short=12 HEAD)$"
_ST_OUT_LACKS "never a merge" 'merge --no-ff'
_ST_RUN --land=feat --base="$LD_T"
_ST_EQ "which lands it back, as asked" "$RC:$(git log --format=%s main | grep -c 'LD1 X')" "0:1"
git worktree remove --force "$TMP/ld1-wt"
# Main moved on as well – the refusal comes before the merge's own, names the fork past the merge
# for what follows it, and that fork lands it alone
_ST_PZ_NEW ld2
_ST_PZ_C a.txt a "LD2 A"
git worktree add -q -b feat "$TMP/ld2-wt" main 2>/dev/null
( cd "$TMP/ld2-wt" && _ST_PZ_C f1.txt f1 "LD2 F1" )
_ST_PZ_C x.txt x "LD2 X"
( cd "$TMP/ld2-wt" && git merge -q --no-edit main && _ST_PZ_C f2.txt f2 "LD2 F2" )
_ST_RUN -d HEAD
_ST_PZ_C b.txt b "LD2 B"
LD_T=$(git rev-parse HEAD)
LD_M=$(git rev-parse feat~1)
_ST_RUN --land=feat
_ST_EQ "main moved on too – still nothing lands" "$RC:$(git rev-parse HEAD)" "1:$LD_T"
_ST_OUT_HAS "the dropped commit named" '^  [0-9a-f]* LD2 X$'
_ST_OUT_LACKS "no merge offered, which would bring it back" 'merge --no-ff'
_ST_OUT_HAS "the fork past the merge offered for what follows" "Land what follows the last of them: git edit --land=feat --base=${LD_M:0:12}$"
_ST_RUN --land=feat --base="$LD_M"
_ST_EQ "that lands the commit past the merge alone" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LD2 F2|LD2 B|LD2 A|"
git worktree remove --force "$TMP/ld2-wt"
# A merge of the branch's own past a fork main still holds is offered as a merge – past one
# main rewrote, a merge would bring the old commits along, so none is
_ST_PZ_NEW ld3
_ST_PZ_C a.txt a "LD3 A0"
_ST_PZ_C b.txt b "LD3 A"
git checkout -q -b side && _ST_PZ_C s.txt s "LD3 S1"
git checkout -q -b feat main && _ST_PZ_C f1.txt f1 "LD3 F1" && git merge -q --no-edit side && git checkout -q main
_ST_PZ_C m.txt m "LD3 M"
_ST_RUN --land=feat
_ST_EQ "a merge of the branch's own refuses" "$RC" "1"
_ST_OUT_HAS "offered as a merge where main holds the fork" 'Land it as a merge instead: git edit --exec -- git merge --no-ff'
_ST_RUN -M --text "LD3 A reworded" HEAD~1
_ST_RUN --land=feat
_ST_OUT_HAS "past a fork main rewrote it still refuses" 'holds a merge commit past its fork'
_ST_OUT_LACKS "with no merge offered" 'merge --no-ff'
_ST_OUT_HAS "saying why" 'A merge would bring along what main rewrote or dropped below the fork'
# A catch-up land from a worktree branch leaves the main worktree's branch where it is, naming
# the land the other way, which lands the branch's own commit alone – the copies of main's
# commits named as main's by the catch-up's record
_ST_PZ_NEW ld4
_ST_PZ_C a.txt a "LD4 A"
git worktree add -q -b feat "$TMP/ld4-wt" main 2>/dev/null
( cd "$TMP/ld4-wt" && _ST_PZ_C f1.txt f1 "LD4 F1" )
_ST_PZ_C b.txt b "LD4 B"
_ST_PZ_C c.txt c "LD4 C"
cd "$TMP/ld4-wt"
_ST_RUN --land=main
_ST_EQ "a catch-up land replays main's commits onto the branch" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LD4 C|LD4 B|LD4 F1|LD4 A|"
_ST_OUT_LACKS "never a reset of the main worktree onto the branch" 'reset --keep'
_ST_OUT_HAS "main's checkout said to stay" "Branch main, checked out in the main worktree, .*pz-ld4, stays as it is"
LD_C=$(print -r -- "$OUT" | sed -n 's/^Once feat.s work is done, land it there: //p' | head -1)
LD_C=${LD_C%%$'\e'*}
_ST_EQ "naming the land the other way" "${LD_C/#*pz-ld4 /}" "edit --land=feat"
mkdir -p "$TMP/ld-bin" && ln -sf "$SELF" "$TMP/ld-bin/git-edit"
( export PATH="$TMP/ld-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1; eval "${LD_C:-false}" </dev/null ) > "$TMP/ld4-out" 2>&1
cd "$TMP/pz-ld4"
_ST_EQ "which lands the branch's own commit alone" "$(git log --format=%s | tr '\n' '|')" "LD4 F1|LD4 C|LD4 B|LD4 A|"
OUT=$(<"$TMP/ld4-out")
_ST_OUT_HAS "the catch-up copies named as main's by the land's record" "^2 commit(s) left out as main's own by a land's record – it holds or held them in another form:$"
# Main then dropping what the branch caught up to, the copy stays out by name
_ST_RUN -d "$(git rev-parse HEAD~1)"
LD_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_EQ "main dropping a commit the branch holds a copy of – the drop stands, nothing lands" "$RC:$(git rev-parse HEAD)" "0:$LD_T"
_ST_OUT_HAS "the copy named as staying out" '^feat has nothing of its own to land past that fork – 1 commit(s) main held and dropped since, or copies of such, stay out:$'
_ST_OUT_HAS "by name" '^  [0-9a-f]* LD4 C$'
_ST_OUT_LACKS "never the copy of a commit main still holds" '^  [0-9a-f]* LD4 B$'
_ST_OUT_HAS "ending as nothing to land" '^git-edit: ok – refs/heads/main unchanged, nothing to land$'
git worktree remove --force "$TMP/ld4-wt"
# The branch's commit like a replay land's copy main dropped since refuses, never left out as the
# drop standing – the fork named landing it back all the same
_ST_PZ_NEW ld5
_ST_PZ_C a.txt a "LD5 A"
git checkout -q -b rp && _ST_PZ_C r.txt r "LD5 R1" && git checkout -q main
_ST_PZ_C b.txt b "LD5 B"
_ST_RUN --land=rp
_ST_RUN -d HEAD
LD_T=$(git rev-parse HEAD)
_ST_RUN --land=rp
_ST_EQ "a replayed commit main dropped since lands nothing" "$RC:$(git rev-parse HEAD)" "1:$LD_T"
_ST_OUT_HAS "naming the branch's commit and the copy main dropped" '^  [0-9a-f]* LD5 R1 – like [0-9a-f]* main took, which main dropped since$'
_ST_OUT_HAS "and the fork landing it back" "land them back all the same: git edit --land=rp --base=$(git rev-parse --short=12 HEAD~1)$"
_ST_RUN --land=rp --base="$(git rev-parse HEAD~1)"
_ST_EQ "which lands it back, as asked" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LD5 R1|LD5 B|LD5 A|"
# A second land after a first replayed with a resolution, the branch never moved onto the copies,
# refuses, naming each copy – the one the resolution changed as that land took it – and the --base
# past them, which lands only what the branch gained
_ST_PZ_NEW ld6
_ST_PZ_C f.txt $'1\n2\n3' "LD6 base"
git checkout -q -b feat && _ST_PZ_C f.txt $'1\n2f\n3' "LD6 F1" && _ST_PZ_C g.txt g "LD6 F2" && git checkout -q main
_ST_PZ_C f.txt $'1\n2m\n3' "LD6 M"
_ST_RUN --land=feat
LD_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${LD_WT:-$ST_NO_WT}" f.txt $'1\n2m 2f\n3'
_ST_RUN --continue
_ST_EQ "a first land with a resolution lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LD6 F2|LD6 F1|LD6 M|LD6 base|"
git reset -q --hard
git checkout -q feat && _ST_PZ_C h.txt h "LD6 F3" && git checkout -q main
_ST_RUN --land=feat --dry-run
_ST_EQ "the second refuses" "$RC" "1"
_ST_OUT_HAS "naming the copy the resolution changed as that land took it" '^  [0-9a-f]* LD6 F1 – on main as [0-9a-f]*, as a land of feat took it – the difference that land.s resolution$'
_ST_OUT_HAS "and the one main holds as it is" '^  [0-9a-f]* LD6 F2 – on main as [0-9a-f]*, change and message alike$'
LD_C=$(print -r -- "$OUT" | sed -n 's/^.*leaving them out: //p' | head -1)
_ST_EQ "the --base past them offered" "${LD_C%%$'\e'*}" "git edit --land=feat --base=$(git rev-parse --short=12 feat~1)"
_ST_RUN --land=feat --base="$(git rev-parse feat~1)"
_ST_EQ "which lands only what the branch gained" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LD6 F3|LD6 F2|LD6 F1|LD6 M|LD6 base|"
# A peer's commit made and taken back inside an undone land's window stays held – the branch
# having caught up to it, between its own commits, the replay leaves it out by name, while a
# branch that never caught up lands all its own
_ST_PZ_NEW ld7
_ST_PZ_C a.txt a "LD7 A"
git worktree add -q -b feat "$TMP/ld7-wt" main 2>/dev/null
( cd "$TMP/ld7-wt" && _ST_PZ_C f1.txt f1 "LD7 F1" )
_ST_RUN --land=feat
print -r -- p > p.txt
_ST_RUN --commit --text "LD7 P" -- p.txt
( cd "$TMP/ld7-wt" && git merge -q --ff-only main )
_ST_RUN --undo
_ST_RUN --undo
( cd "$TMP/ld7-wt" && _ST_PZ_C f2.txt f2 "LD7 F2" )
_ST_RUN --land=feat --dry-run
_ST_OUT_HAS "a peer's commit inside an undone land's window, caught up to – named as staying out" '^1 commit(s) main held and dropped since stay out – the drop stands:$'
_ST_OUT_HAS "the replay of the branch's own two said" 'replaying 2 from'
_ST_RUN --land=feat
_ST_EQ "the branch's own land around it" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LD7 F2|LD7 F1|LD7 A|"
_ST_OUT_HAS "naming it as left out" '^  [0-9a-f]* LD7 P$'
_ST_OUT_LACKS "never refused" 'nothing landed'
git worktree remove --force "$TMP/ld7-wt"
_ST_PZ_NEW ld7b
_ST_PZ_C a.txt a "LD7B A"
git worktree add -q -b feat "$TMP/ld7b-wt" main 2>/dev/null
( cd "$TMP/ld7b-wt" && _ST_PZ_C f1.txt f1 "LD7B F1" )
_ST_RUN --land=feat
print -r -- p > p.txt
_ST_RUN --commit --text "LD7B P" -- p.txt
_ST_RUN --undo
_ST_RUN --undo
( cd "$TMP/ld7b-wt" && _ST_PZ_C f2.txt f2 "LD7B F2" )
_ST_RUN --land=feat
_ST_EQ "a branch that never caught up to it lands all its own" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LD7B F2|LD7B F1|LD7B A|"
_ST_OUT_HAS "the land taken back said as set aside" 'a land of feat that --undo took back set aside'
git worktree remove --force "$TMP/ld7b-wt"
# The raw undo a land prints writes the undo's reflog message – run as printed, a later land reads
# the land as undone and lands it again, a bare update-ref still ending with nothing to land
_ST_PZ_NEW ld8
_ST_PZ_C a.txt a "LD8 A"
git checkout -q -b feat && _ST_PZ_C f1.txt f1 "LD8 F1" && _ST_PZ_C f2.txt f2 "LD8 F2" && git checkout -q main
LD_T=$(git rev-parse HEAD)
_ST_RUN --land=feat
_ST_OUT_HAS "the raw undo names the undo's reflog message" "(or, the ref alone: git update-ref -m 'git edit: undo land feat' refs/heads/main $LD_T $(git rev-parse HEAD))"
LD_C=$(print -r -- "$OUT" | sed -n 's/^Undo: git edit --undo  (or, the ref alone: \(.*\))$/\1/p' | head -1)
LD_C=${LD_C%%$'\e'*}
eval "${LD_C:-false}"
_ST_RUN --undo
_ST_RUN --land=feat
_ST_EQ "a land taken back by the printed update-ref lands again" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LD8 F2|LD8 F1|LD8 A|"
git update-ref refs/heads/main "$LD_T" "$(git rev-parse HEAD)"
git reset -q --hard
_ST_RUN --land=feat
_ST_EQ "one taken back by a bare update-ref lands nothing" "$RC:$(git rev-parse HEAD)" "0:$LD_T"
_ST_OUT_HAS "ending as nothing to land" '^git-edit: ok – refs/heads/main unchanged, nothing to land$'
_ST_OUT_HAS "naming the --base that lands it all the same" 'name an older fork: git edit --land=feat --base=<sha>'
# Main rewritten below the fork by a fold, a reword and a drop – the branch's own commits land, no
# refusal, and a linked worktree's branch replayed is still offered the move onto the copies
_ST_PZ_NEW ld9
_ST_PZ_C a.txt a1 "LD9 m1"
_ST_PZ_C b.txt b1 "LD9 m2"
_ST_PZ_C c.txt c1 "LD9 m3"
_ST_PZ_C d.txt d1 "LD9 m4"
git worktree add -q -b feat "$TMP/ld9-wt" main 2>/dev/null
( cd "$TMP/ld9-wt" && _ST_PZ_C f1.txt f1 "LD9 F1" && _ST_PZ_C f2.txt f2 "LD9 F2" )
print -r -- b2 > b.txt && git add b.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~2)"
_ST_RUN -M --text "LD9 m3 reworded" HEAD~1
_ST_RUN -d HEAD
_ST_RUN --land=feat
_ST_EQ "main folded, reworded and dropped below the fork – the branch's own land" "$RC:$(git log --format=%s | tr '\n' '|')" "0:LD9 F2|LD9 F1|LD9 m3 reworded|LD9 m2|LD9 m1|"
_ST_OUT_LACKS "no refusal on the way" 'nothing landed'
_ST_OUT_HAS "the worktree's branch offered the move onto the copies" "ld9-wt reset --keep $(git rev-parse --short=12 HEAD)"
git worktree remove --force "$TMP/ld9-wt"
cd "$TMP/repo"
