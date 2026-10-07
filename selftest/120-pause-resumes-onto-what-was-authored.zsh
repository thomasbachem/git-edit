_ST_SCENARIO "\e[1;96m[120] a pause resumes onto what was authored, and an abort leaves what it found\e[0m"
local PZ_WT PZ_A PZ_B PZ_X PZ_RES PZ_I PZ_ORIG
# Commits made by hand at an edit stop stand in for the paused commit, what followed replaying
_ST_PZ_NEW p1
for PZ_I in a b c d; do _ST_PZ_C "$PZ_I.txt" "$PZ_I" "PZ ${(U)PZ_I}"; done
_ST_RUN HEAD~2
PZ_WT=$(_ST_PZ_WT)
echo bb >> "$PZ_WT/b.txt" && git -C "$PZ_WT" commit -q --amend -am "PZ B by hand"
_ST_RUN --continue
_ST_EQ "a hand-made amend at an edit stop replays what followed" "$RC:$(git log --format=%s | tr '\n' ' ')" "0:PZ D PZ C PZ B by hand PZ A "
_ST_RUN HEAD~2
PZ_WT=$(_ST_PZ_WT)
echo n > "$PZ_WT/n.txt" && git -C "$PZ_WT" add n.txt && git -C "$PZ_WT" commit -qm "PZ N inserted"
_ST_RUN --continue
_ST_EQ "as does a commit added on top of it" "$RC:$(git log --format=%s | tr '\n' ' ')" "0:PZ D PZ C PZ N inserted PZ B by hand PZ A "
_ST_RUN HEAD~1
PZ_WT=$(_ST_PZ_WT)
git -C "$PZ_WT" reset -q --hard HEAD~3
_ST_RUN --continue
_ST_OUT_HAS "while a worktree reset elsewhere refuses" 'no longer builds on'
_ST_RUN --abort
# An edit whose branch was rewritten below it refuses, as a replay would carry the old commits back
_ST_PZ_NEW p10
for PZ_I in base a b c; do _ST_PZ_C "$PZ_I.txt" "$PZ_I" "PZ $PZ_I"; done
_ST_RUN HEAD~1
PZ_WT=$(_ST_PZ_WT)
echo "a fixed" > a.txt && git commit -qam "fixup! PZ a" && GIT_SEQUENCE_EDITOR=true git rebase -q -i --autosquash HEAD~4 >/dev/null 2>&1
echo "b edited" > "$PZ_WT/b.txt"
_ST_RUN --continue
_ST_OUT_HAS "an edit whose branch was rewritten below it refuses" 'was rewritten under this edit'
_ST_RUN --abort
# A squash of a commit with its revert keeps the tip's content – skipping the emptied step
# brought the reverted file back
_ST_PZ_NEW p2
_ST_PZ_C base.txt base "PZ base" && _ST_PZ_C a.txt a "PZ add a" && PZ_A=$(git rev-parse HEAD)
_ST_PZ_C x.txt x "PZ x" && git rm -q a.txt && git commit -qm "PZ remove a" && PZ_B=$(git rev-parse HEAD) && _ST_PZ_C y.txt y "PZ y"
_ST_RUN -s="$PZ_A" "$PZ_B"
_ST_EQ "a squash of a commit with its revert keeps the tip's content" "$RC:$(git ls-tree --name-only HEAD | tr '\n' ' ')" "0:base.txt x.txt y.txt "
# A scoped fold of a file left unmerged refuses – its missing stage 0 read as a deletion
_ST_PZ_NEW p3
_ST_PZ_C f.txt base "PZ base" && git checkout -q -b pz-side && _ST_PZ_C f.txt side "PZ side" && git checkout -q main && _ST_PZ_C f.txt main "PZ main"
git cherry-pick pz-side >/dev/null 2>&1
_ST_RUN --amend-into="$(git rev-parse HEAD)" -- f.txt
_ST_EQ "a scoped fold of an unmerged file refuses" "$RC:$(git cat-file -e HEAD:f.txt && echo kept)" "1:kept"
git cherry-pick --abort >/dev/null 2>&1
# A content split resumed while the checkout sits on another branch keeps what followed
_ST_PZ_NEW p4
_ST_PZ_C base.txt base "PZ base" && git branch pz-other
printf 'one\ntwo\n' > f.txt && git add f.txt && git commit -qm "PZ X" && PZ_X=$(git rev-parse HEAD)
_ST_PZ_C g.txt g "PZ Y" && _ST_PZ_C h.txt h "PZ Z"
_ST_RUN --split="$PZ_X" --text "PZ X1"
PZ_WT=$(_ST_PZ_WT)
print -r -- one > "$PZ_WT/f.txt"
git switch -q pz-other
_ST_RUN --continue
git switch -q main
_ST_EQ "a split resumed from another branch keeps what followed" "$RC:$(git log --format=%s main | tr '\n' ' ')" "0:PZ Z PZ Y PZ X PZ X1 PZ base "
# A -C worktree the caller named stays theirs – an abort leaves it, and one with a branch refuses
_ST_PZ_NEW p5
printf 'l1\nl2\nl3\n' > f.txt && git add f.txt && git commit -qm "PZ A"
printf 'l1\nB2\nl3\n' > f.txt && git commit -qam "PZ B" && printf 'l1\nC2\nl3\n' > f.txt && git commit -qam "PZ C"
git worktree add -q --detach "$TMP/pz-p5-mine" HEAD && echo keep > "$TMP/pz-p5-mine/notes.txt"
_ST_RUN -C="$TMP/pz-p5-mine" -d HEAD~1
_ST_RUN --abort
_ST_CHECK "an abort leaves the caller's own -C worktree in place" test -e "$TMP/pz-p5-mine/notes.txt"
git worktree add -q -b pz-taken "$TMP/pz-p5-branch" HEAD
_ST_RUN -C="$TMP/pz-p5-branch" -d HEAD~1
_ST_OUT_HAS "a -C worktree with a branch checked out refuses" 'has pz-taken checked out'
# A marker line the file holds of its own passes, while one at a configured size is caught
_ST_PZ_NEW p7
printf 'l1\nl2\nl3\n' > f.txt && git add f.txt && git commit -qm "PZ A" && PZ_A=$(git rev-parse HEAD)
printf 'Changes\n=======\n\n- first\n' > NEWS.md && printf 'l1\nX2\nl3\n' > f.txt && git add f.txt NEWS.md && git commit -qm "PZ B"
_ST_PZ_C g.txt g "PZ C"
printf 'l1\nY2\nl3\n' > f.txt && git add f.txt
_ST_RUN --amend-into="$PZ_A"
PZ_WT=$(_ST_PZ_WT)
printf 'l1\nY2\nl3\n' > "$PZ_WT/f.txt" && git -C "$PZ_WT" add f.txt
_ST_RUN --continue
PZ_WT=$(_ST_PZ_WT)
[ -n "$PZ_WT" ] && printf 'l1\nX2\nl3\n' > "$PZ_WT/f.txt" && git -C "$PZ_WT" add f.txt && _ST_RUN --continue
_ST_OUT_LACKS "a file's own ======= underline is no conflict marker" 'still contains conflict markers'
_ST_RUN --abort
_ST_PZ_NEW p8
print -r -- '*.adoc conflict-marker-size=32' > .gitattributes && git add .gitattributes
printf 'l1\nl2\nl3\n' > f.adoc && git add f.adoc && git commit -qm "PZ A" && PZ_A=$(git rev-parse HEAD)
printf 'l1\nX2\nl3\n' > f.adoc && git commit -qam "PZ B" && _ST_PZ_C g.txt g "PZ C"
printf 'l1\nY2\nl3\n' > f.adoc && git add f.adoc
_ST_RUN --amend-into="$PZ_A"
git -C "$(_ST_PZ_WT)" add -A
_ST_RUN --continue
_ST_OUT_HAS "markers at a configured size are caught" 'still contains conflict markers'
_ST_RUN --abort
# A rebase aborted by hand in a fold's worktree applies nothing on the continue
_ST_PZ_NEW p9
printf 'l1\nl2\nl3\n' > f.txt && git add f.txt && git commit -qm "PZ A" && PZ_A=$(git rev-parse HEAD)
printf 'l1\nX2\nl3\n' > f.txt && git commit -qam "PZ B" && _ST_PZ_C g.txt g "PZ C"
printf 'l1\nY2\nl3\n' > f.txt && git add f.txt
_ST_RUN --amend-into="$PZ_A"
git -C "$(_ST_PZ_WT)" rebase --abort >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a rebase aborted by hand in a fold's worktree applies nothing" "$RC:$(git log --format=%s | tr '\n' ' '):$(git diff --cached --name-only)" "1:PZ C PZ B PZ A :f.txt"
_ST_RUN --abort
# A fold leaves another commit's own fixup! where it is
_ST_PZ_NEW p11
_ST_PZ_C a.txt a "PZ A" && PZ_A=$(git rev-parse HEAD) && _ST_PZ_C b.txt b "PZ B" && _ST_PZ_C b2.txt b2 "fixup! PZ B" && _ST_PZ_C c.txt c "PZ C"
echo "a fixed" > a.txt && git add a.txt
_ST_RUN --amend-into="$PZ_A"
_ST_EQ "a fold leaves another commit's fixup! where it is" "$RC:$(git log --format=%s | tr '\n' ' ')" "0:PZ C fixup! PZ B PZ B PZ A "
# A continue cut off after its landing completes rather than call the branch moved
_ST_PZ_NEW p20
printf 'l1\nl2\nl3\n' > f.txt && git add f.txt && git commit -qm "PZ A" && PZ_A=$(git rev-parse HEAD)
printf 'l1\nX2\nl3\n' > f.txt && git commit -qam "PZ B" && _ST_PZ_C g.txt g "PZ C"
printf 'l1\nY2\nl3\n' > f.txt && git add f.txt
PZ_ORIG=$(git rev-parse HEAD)
_ST_RUN --amend-into="$PZ_A"
PZ_WT=$(_ST_PZ_WT)
for PZ_I in 1 2 3; do
	[ -d "$(git -C "$PZ_WT" rev-parse --git-path rebase-merge)" ] || break
	printf 'l1\nY2\nl3\n' > "$PZ_WT/f.txt" && git -C "$PZ_WT" add f.txt
	GIT_EDITOR=true git -C "$PZ_WT" rebase --continue >/dev/null 2>&1
done
PZ_RES=$(git -C "$PZ_WT" rev-parse HEAD)
git update-ref refs/heads/main "$PZ_RES" "$PZ_ORIG"
_ST_RUN --continue
_ST_EQ "a continue after a landing cut short completes" "$RC:$(git rev-parse HEAD)" "0:$PZ_RES"
_ST_OUT_HAS "saying so" 'holds this result already'
# An abort run from inside the pause worktree clears the pause all the same
_ST_PZ_NEW p13
_ST_PZ_C a.txt a "PZ A" && _ST_PZ_C b.txt b "PZ B"
_ST_RUN HEAD~1
PZ_WT=$(_ST_PZ_WT)
cd "$PZ_WT" && _ST_RUN --abort
cd "$TMP/pz-p13"
_ST_CHECK "an abort from inside the pause worktree clears the pause" test ! -e "$(git rev-parse --git-common-dir)/git-edit-state"
# An unreadable pause aborts all the same
: > "$(git rev-parse --git-common-dir)/git-edit-state"
_ST_RUN --abort
_ST_EQ "an unreadable pause aborts" "$RC:$([ -e "$(git rev-parse --git-common-dir)/git-edit-state" ] && echo left)" "0:"
# A drop's or squash's continue refuses a --text it has nowhere to put
_ST_PZ_NEW p19
printf 'l1\nl2\nl3\n' > f.txt && git add f.txt && git commit -qm "PZ A"
printf 'l1\nB2\nl3\n' > f.txt && git commit -qam "PZ B" && printf 'l1\nC2\nl3\n' > f.txt && git commit -qam "PZ C"
_ST_RUN -d HEAD~1
_ST_RUN --continue --text "x"
_ST_OUT_HAS "a drop's continue refuses a --text" 'no message to set'
_ST_RUN --abort
# An isolated drop from a detached `HEAD` refuses, as there is no branch to land on
git checkout -q --detach
_ST_RUN -d HEAD~1
_ST_OUT_HAS "an isolated drop on a detached HEAD refuses" 'requires being on a branch'
git checkout -q main
# A temp path that can't be made stops the run, never falling back to a shared worktree
TMPDIR="$TMP/pz-nowhere" _ST_RUN -d HEAD~1
_ST_EQ "a temp path that can't be made stops the run" "$([ "$RC" -ne 0 ] && echo stopped):$([ -e "$TMP/pz-p19.git-edit" ] && echo shared)" "stopped:"
# A relative -C path still gets the gate
_ST_PZ_NEW pv2
for PZ_I in a b c; do _ST_PZ_C "$PZ_I.txt" "$PZ_I" "PZ $PZ_I"; done
git config edit.verifyCmd false
PZ_ORIG=$(git rev-parse HEAD)
# Nested, so the same relative path read from inside the worktree names nothing
_ST_RUN -C=../pz-wts/pv2 -d HEAD~1
git config --unset edit.verifyCmd
_ST_EQ "a relative -C path still gets the gate" "$([ "$RC" -ne 0 ] && echo gated):$(git rev-parse HEAD)" "gated:$PZ_ORIG"
_ST_RUN --abort
# A pathspec split carries a name holding a quote as itself
_ST_PZ_NEW p17
_ST_PZ_C base.txt base "PZ base"
echo hi > 'say "hi".txt' && echo o > other.txt && git add -A && git commit -qm "PZ both"
_ST_RUN --split=HEAD --text "PZ first" -- ':(literal)say "hi".txt'
_ST_EQ "a pathspec split carries a quoted name as itself" "$RC:$(git ls-tree -z --name-only HEAD~1 | tr '\0' '|')" '0:base.txt|say "hi".txt|'
# A snapshot fold refuses staging beyond its stopped paths, which it would drop
if _ST_MERGE_BASE_OK; then
	_ST_PZ_NEW p12
	printf 'a\nb\nc\n' > f.txt && git add f.txt && git commit -qm "PZ A"
	_ST_PZ_C h.txt h1 "PZ H"
	printf 'a\nB1\nc\n' > f.txt && git commit -qam "PZ T" && PZ_A=$(git rev-parse HEAD)
	printf 'a\nB2\nc\n' > f.txt && git commit -qam "PZ L" && _ST_PZ_C g.txt g "PZ M"
	printf 'a\nB3\nc\n' > f.txt && git add f.txt
	_ST_RUN --amend-into="$PZ_A" --snapshot
	PZ_WT=$(_ST_PZ_WT)
	printf 'a\nB3\nc\n' > "$PZ_WT/f.txt" && echo h2 > "$PZ_WT/h.txt" && git -C "$PZ_WT" add f.txt h.txt
	_ST_RUN --continue
	_ST_OUT_HAS "a snapshot fold refuses staging beyond its stopped paths" 'Staged beyond the stopped paths'
	_ST_RUN --abort
fi
# A pause whose run landed it and was then killed before clearing it is told apart from one
# rewritten underneath – its state file and worktree put back stand in for the kill
_ST_PZ_NEW cut
for PZ_N in a b c; do _ST_PZ_C "$PZ_N.txt" "$PZ_N" "PZ $PZ_N"; done
PZ_SF="$(git rev-parse --git-common-dir)/git-edit-state"
_ST_RUN HEAD~1
PZ_WT=$(_ST_PZ_WT)
print -r -- b2 > "${PZ_WT:-$ST_NO_WT}/b.txt"
cp "$PZ_SF" "$TMP/pz-cut-state"
_ST_RUN --continue
PZ_TIP=$(git rev-parse HEAD)
for PZ_N in --continue --abort; do
	cp "$TMP/pz-cut-state" "$PZ_SF" && git worktree add -q --detach "${PZ_WT:-$ST_NO_WT}" HEAD
	_ST_RUN $PZ_N
	_ST_EQ "an edit cut off after landing takes $PZ_N as done" "$RC:$(git rev-parse HEAD)" "0:$PZ_TIP"
	_ST_OUT_HAS "saying it had landed" 'The edit had landed already'
	_ST_CHECK "leaving neither the pause nor its worktree" sh -c "! test -e '$PZ_SF' && ! test -d '${PZ_WT:-$ST_NO_WT}'"
done
echo d > d.txt && git add d.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --verify=false -- d.txt
PZ_WT=$(_ST_PZ_WT)
cp "$PZ_SF" "$TMP/pz-cut-state"
_ST_RUN --no-verify --continue
PZ_TIP=$(git rev-parse HEAD)
cp "$TMP/pz-cut-state" "$PZ_SF" && git worktree add -q --detach "${PZ_WT:-$ST_NO_WT}" HEAD
_ST_RUN --abort
_ST_EQ "and so does a fold's abort" "$RC:$(git rev-parse HEAD)" "0:$PZ_TIP"
_ST_OUT_HAS "saying it had landed" 'The fold had landed already'
# An undo of a landing on a paused branch would strand that pause's landing, so it waits
_ST_PZ_NEW und
_ST_PZ_C f.txt 1 "PZ one"
print -r -- 2 > f.txt && _ST_RUN --commit --text "PZ two" -- f.txt
print -r -- 3 > f.txt && git add f.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" -- f.txt
_ST_RUN --undo
_ST_EQ "an undo on a paused branch refuses" "$RC:$(git log -1 --format=%s)" "1:PZ two"
_ST_OUT_HAS "naming the pause" 'in flight on main – finish it'
_ST_RUN --abort
# A squash whose commits cancel out keeps the combined commit, under the message it was given
_ST_PZ_NEW sq
_ST_PZ_C base.txt base "PZ base"
_ST_PZ_C a.txt a "PZ add a"
PZ_A=$(git rev-parse HEAD)
_ST_PZ_C x.txt x "PZ x"
git rm -q a.txt && git commit -qm "PZ remove a"
PZ_B=$(git rev-parse HEAD)
_ST_PZ_C y.txt y "PZ y"
PZ_TIP=$(git rev-parse HEAD)
_ST_RUN -s="$PZ_A" "$PZ_B" --text "PZ combined"
_ST_EQ "a squash whose commits cancel out takes its --text" "$RC:$(git log --format=%s | tr '\n' ' ')" "0:PZ y PZ x PZ combined PZ base "
_ST_CHECK "leaving out the file both left out" sh -c '! git cat-file -e HEAD:a.txt'
git reset -q --hard "$PZ_TIP"
_ST_TTY "GIT_EDITOR=printf 'PZ via editor\n' >" -- -s="$PZ_A" "$PZ_B" -m -y
_ST_EQ "and -m opens the editor on it" "$RC:$(git log -1 --format=%s HEAD~2)" "0:PZ via editor"
cd "$TMP/repo"
