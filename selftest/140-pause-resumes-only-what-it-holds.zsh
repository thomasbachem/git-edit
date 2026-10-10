# A pause resumes only as what it holds – its owner's, its messages whole, a hand quit at its last
# stop refused – and a refused resume leaves it as it was
_ST_SCENARIO "\e[1;96m[140] a pause resumes only what it holds, a refused resume changing nothing\e[0m"
local PR_T PR_WT PR_SF
_ST_PZ_NEW pr1
_ST_PZ_C a.txt 1 "PR one" && _ST_PZ_C a.txt 2 "PR two" && _ST_PZ_C b.txt 1 "PR three"
PR_SF="$(git rev-parse --git-common-dir)/git-edit-state"
# Another label's refused resume notes nothing into the pause, its --verify included
GIT_EDIT_ACTOR=pr-a _ST_RUN HEAD~1
GIT_EDIT_ACTOR=pr-b _ST_RUN --continue --verify="touch $TMP/pr-b-ran" --no-verify-span
_ST_EQ "another label's resume refuses" "$RC" "1"
_ST_EQ "noting none of its flags into the pause" "$(grep -cE '^verify_(cmd|span)=' "$PR_SF")" "0"
GIT_EDIT_ACTOR=pr-b _ST_RUN --status
_ST_OUT_HAS "--status names whose pause it is, and that it is not the caller's" "Paused by pr-a's run – not yours to resume"
print -r -- edited > "$(_ST_PZ_WT)/a.txt"
GIT_EDIT_ACTOR=pr-a _ST_RUN --continue
_ST_EQ "the owner's resume runs no gate the other label asked for" "${RC}:$([ -e "$TMP/pr-b-ran" ] && echo ran)" "0:"
# A pause from before labels were kept – no actor key – is anyone's to resume
_ST_RUN HEAD~1
sed -i.bak '/^actor=/d' "$PR_SF" && rm -f "$PR_SF.bak"
print -r -- again > "$(_ST_PZ_WT)/a.txt"
GIT_EDIT_ACTOR=pr-c _ST_RUN --continue
_ST_EQ "a pause with no actor key resumes for a labeled caller" "${RC}:$(git show HEAD~1:a.txt)" "0:again"
# --allow-other-actor only where a pause or a run is taken back
_ST_RUN -d -y --allow-other-actor HEAD
_ST_OUT_HAS "--allow-other-actor elsewhere refuses" 'only applies to --continue, --skip, --abort and --undo'
# `#` lines kept whatever cleanup the caller configured – an edit's resume and a replayed pick alike
git config commit.cleanup strip
_ST_PZ_C e.txt e "PR drop me"
print -r -- 3 > a.txt && git add a.txt && git commit -q --cleanup=verbatim -m $'PR hash\n\n#42 kept'
_ST_PZ_C b.txt 2 "PR four"
_ST_RUN HEAD~1
print -r -- 4 > "$(_ST_PZ_WT)/a.txt"
_ST_RUN --continue
_ST_EQ "an edit's resume keeps a # line under commit.cleanup=strip" "${RC}:$(git log -1 --format=%B HEAD~1 | grep -c '^#42 kept')" "0:1"
_ST_PZ_C c.txt 1 "PR five"
_ST_RUN -d -y "$(git log --format=%H --grep='^PR drop me$' -1)"
_ST_EQ "as does a pick a drop replays" "${RC}:$(git log --format=%B --grep='^PR hash$' -1 | grep -c '^#42 kept')" "0:1"
print -r -- d > "$TMP/pr-d"
_ST_RUN --amend-into="$(git log --format=%H --grep='^PR two$' -1)" --put d.txt="$TMP/pr-d"
_ST_EQ "and one a fold replays" "${RC}:$(git log --format=%B --grep='^PR hash$' -1 | grep -c '^#42 kept')" "0:1"
_ST_RUN --move="$(git log --format=%H --grep='^PR four$' -1)" --before="$(git log --format=%H --grep='^PR hash$' -1)"
_ST_EQ "and one a move replays" "${RC}:$(git log --format=%B --grep='^PR hash$' -1 | grep -c '^#42 kept')" "0:1"
_ST_RUN HEAD~1
_ST_RUN --continue --text $'PR hash again\n\n#43 kept'
_ST_EQ "and a resume's --text" "${RC}:$(git log -1 --format=%B HEAD~1 | grep -c '^#43 kept')" "0:1"
git config --unset commit.cleanup
# A hand quit at a drop's last stop, its resolution staged, lands nothing
_ST_PZ_NEW pr2
_ST_PZ_C f.txt $'1\n2\n3' "PR2 c1" && _ST_PZ_C f.txt $'1\n2x\n3' "PR2 c2" && _ST_PZ_C f.txt $'1\n2xy\n3' "PR2 c3"
PR_T=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~1
PR_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$PR_WT" f.txt $'1\n2y\n3'
git -C "${PR_WT:-$ST_NO_WT}" rebase --quit >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a hand quit at the last stop refuses, the pause kept" "${RC}:$(git rev-parse HEAD):$([ -f "$(git rev-parse --git-common-dir)/git-edit-state" ] && echo kept)" "1:$PR_T:kept"
_ST_OUT_HAS "naming the commit it stopped short of" 'stopped short of its last 1 commit'
_ST_RUN --abort
# A branch deleted during the pause is named as gone, not as moved
git branch pr2-feat && git checkout -q pr2-feat
_ST_RUN -d -y HEAD~1
git checkout -q main && git branch -D pr2-feat >/dev/null 2>&1
_ST_RUN --continue
_ST_OUT_HAS "a branch deleted during the pause is named as gone" 'Branch pr2-feat is gone'
_ST_RUN --abort
# A pause worktree deleted by hand leaves no registration behind once the pause is cleared
_ST_RUN -d -y HEAD~1
PR_WT=$(_ST_PZ_WT)
rm -rf "${PR_WT:-$ST_NO_WT}"
_ST_RUN --abort
_ST_EQ "a hand-deleted pause worktree is unregistered by the abort" "${RC}:$(git worktree list --porcelain | grep -c '^prunable')" "0:0"
# An edit's replay quit by hand at its stop refuses rather than replay anew
_ST_PZ_NEW pr3
_ST_PZ_C f.txt $'1\n2\n3' "PR3 c1" && _ST_PZ_C f.txt $'1\n2x\n3' "PR3 c2"
PR_T=$(git rev-parse HEAD)
_ST_RUN HEAD~1
print -r -- $'1\nE\n3' > "$(_ST_PZ_WT)/f.txt"
_ST_RUN --continue
PR_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$PR_WT" f.txt $'1\nEx\n3'
git -C "${PR_WT:-$ST_NO_WT}" rebase --quit >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "an edit's replay quit by hand refuses" "${RC}:$(git rev-parse HEAD)" "1:$PR_T"
_ST_OUT_HAS "naming it as quit" 'quit by hand at a stop'
# Reset to the amend, as the hint for a replay aborted by hand says, it replays anew
git -C "${PR_WT:-$ST_NO_WT}" reset -q --hard "$(sed -n 's/^amended=//p' "$(git rev-parse --git-common-dir)/git-edit-state")"
_ST_RUN --continue
_ST_EQ "a worktree reset to the amend replays again rather than refuse" "$RC" "2"
_ST_RUN --abort
# A replant's last stop skipped by hand is a finish, not a quit – one that lost the commit it
# stepped over, refused as such, while git edit's own skip lands without it
_ST_PZ_NEW pr4
_ST_PZ_C f.txt $'1\n2\n3' "PR4 A" && git branch pr4-up && _ST_PZ_C g.txt g "PR4 F1" && _ST_PZ_C f.txt $'1\nF\n3' "PR4 F2"
git checkout -q pr4-up && _ST_PZ_C f.txt $'1\nU\n3' "PR4 U" && git checkout -q main
_ST_RUN --onto=pr4-up
git -C "$(_ST_PZ_WT)" rebase --skip >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a replant whose last stop was skipped by hand refuses" "$RC" "1"
_ST_OUT_HAS "as a commit left out by hand" 'PR4 F2 – left out by hand'
_ST_OUT_LACKS "not as a quit" 'stopped short'
_ST_RUN --abort
_ST_RUN --onto=pr4-up
_ST_RUN --skip
_ST_EQ "while one skipped by git edit lands" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:PR4 F1|PR4 U|PR4 A|"
cd "$TMP/repo"
