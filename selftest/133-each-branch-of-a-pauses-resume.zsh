_ST_SCENARIO "\e[1;96m[133] each branch of a pause's resume and the checkout's sync does what it says\e[0m"
local SG_WT SG_T SG_N
# A resume from inside the pause's worktree is no person at the checkout – it gets the hints
_ST_PZ_NEW sg1
_ST_PZ_C a.txt a "SG a" && _ST_PZ_C b.txt b "SG b"
_ST_RUN HEAD~1
SG_WT=$(_ST_PZ_WT)
print -r -- a2 > "${SG_WT:-$ST_NO_WT}/a.txt"
cd "${SG_WT:-$ST_NO_WT}"
_ST_TTY -- --continue
cd "$TMP/pz-sg1"
_ST_EQ "a terminal resume from the pause's worktree lands" "$RC:$(git show HEAD~1:a.txt)" "0:a2"
_ST_EQ "leaving the checkout, which is no caller's own there" "$(<a.txt)" "a"
_ST_OUT_HAS "with its hints" 'checkout still holds the'
git checkout -q -- .
# Nor is a checkout halfway through a rebase brought along
_ST_RUN HEAD~1
SG_WT=$(_ST_PZ_WT)
print -r -- a3 > "${SG_WT:-$ST_NO_WT}/a.txt"
GIT_SEQUENCE_EDITOR="sed -i.bak '1i\\
break
'" git rebase -q -i HEAD~1 >/dev/null 2>&1
_ST_TTY -- --continue
_ST_OUT_HAS "a checkout mid-rebase stays as it was" 'halfway through a rebase'
git rebase --abort >/dev/null 2>&1
git checkout -q -- .
# A merged file keeps the executable bit the checkout gave it, set or cleared
_ST_PZ_NEW sg2
print -l 1 2 3 4 5 6 > x.sh && print -l 1 2 3 4 5 6 > n.sh && chmod +x n.sh && git add x.sh n.sh && git commit -qm "SG2 base"
print -l 1 2x 3 4 5 6 > x.sh && print -l 1 2x 3 4 5 6 > n.sh && git commit -qam "SG2 change"
_ST_PZ_C g.txt g "SG2 g"
print -l 1 2x 3 4 5 6m > x.sh && chmod +x x.sh
print -l 1 2x 3 4 5 6m > n.sh && chmod -x n.sh
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a merge keeps a +x the checkout set" "$RC:$(test -x x.sh && echo x):$(tr '\n' ' ' < x.sh)" "0:x:1 2 3 4 5 6m "
_ST_CHECK "and a -x it cleared" test ! -x n.sh
git checkout -q -- . 2>/dev/null; chmod -x x.sh; chmod +x n.sh
# A file deleted in the checkout stays deleted, its entry taking what landed
_ST_PZ_NEW sg3
_ST_PZ_C f.txt $'1\n2\n3' "SG3 c1" && _ST_PZ_C f.txt $'1\n2x\n3' "SG3 c2" && _ST_PZ_C g.txt g "SG3 g"
rm f.txt
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a deletion in the checkout stays, unstaged, against what landed" "$RC:$(git status --porcelain -- f.txt):$(git diff --cached --name-only)" "0: D f.txt:"
git checkout -q -- f.txt
# A path the rewrite adds that the caller staged a version of their own for stays theirs
_ST_PZ_NEW sg4
_ST_PZ_C base.txt b "SG4 base"
_ST_PZ_C n.txt n "SG4 adds n"
git rm -q n.txt && git commit -qm "SG4 removes n"
_ST_PZ_C g.txt g "SG4 g"
print -r -- mine > n.txt && git add n.txt
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a staged version of a path the rewrite adds stays staged" "$RC:$(git show :n.txt)" "0:mine"
_ST_OUT_HAS "named" 'you staged your own version'
git rm -q --cached n.txt; rm -f n.txt; git checkout -q -- . 2>/dev/null
# A path that lands below one the checkout keeps waits with it – the kept file stays whole
_ST_PZ_NEW sg5
_ST_PZ_C base.txt b "SG5 base"
_ST_PZ_C x x "SG5 file x"
git rm -q x && mkdir x && print -r -- y > x/y.txt && git add x/y.txt && git commit -qm "SG5 dir x"
_ST_PZ_C g.txt g "SG5 g"
git rm -rq x && print -r -- mine > x && git add x && git commit -qm "SG5 file x again"
print -r -- edited > x
_ST_TTY -- -d -y HEAD
_ST_EQ "a file the checkout edits stays whole where a directory lands" "$RC:$(<x)" "0:edited"
_ST_OUT_HAS "named as standing there" 'x/y.txt – your file x stands where its directory goes'
rm -f x; git checkout -q -- . 2>/dev/null
# Ctrl-D at the prompt leaves the pause, as q does
_ST_PZ_NEW sg6
_ST_PZ_C a.txt a "SG6 a" && _ST_PZ_C b.txt b "SG6 b"
_ST_TTY_START -- HEAD~1
_ST_TTY_AT 'Make your changes in' && zpty -wn ST_TTY $'\004'
_ST_TTY_END
_ST_EQ "Ctrl-D leaves the pause" "$RC" "2"
_ST_OUT_HAS "saying so" 'Left paused – resume with'
_ST_RUN --abort
# Enter takes a deletion and a link's new target as the resolution they are
_ST_PZ_NEW sg7
_ST_PZ_C f.txt $'1\n2\n3' "SG7 c1" && _ST_PZ_C f.txt $'1\n2x\n3' "SG7 c2"
git rm -q f.txt && git commit -qm "SG7 removes f"
_ST_PZ_C g.txt g "SG7 g"
_ST_TTY_START -- -d -y HEAD~2
if _ST_TTY_AT 'Resolve the conflicts in'; then
	rm -f "$(_ST_PZ_WT)/f.txt"
	zpty -wn ST_TTY $'\r'
fi
_ST_TTY_END
_ST_EQ "a deletion resolved at Enter lands as one" "$RC:$(git cat-file -e HEAD:f.txt 2>/dev/null && echo kept || echo gone)" "0:gone"
_ST_PZ_NEW sg8
_ST_PZ_C a.txt a "SG8 base"
ln -s t1 l && git add l && git commit -qm "SG8 link t1"
ln -sfn t2 l && git commit -qam "SG8 link t2"
ln -sfn t3 l && git commit -qam "SG8 link t3"
_ST_TTY_START -- -d -y HEAD~1
if _ST_TTY_AT 'Resolve the conflicts in'; then
	ln -sfn t9 "$(_ST_PZ_WT)/l"
	zpty -wn ST_TTY $'\r'
fi
_ST_TTY_END
_ST_EQ "a link re-pointed at a conflict lands at Enter" "$RC:$(git cat-file -p HEAD:l)" "0:t9"
# A copy run as `zsh git-edit`, never executable itself, resumes the same way
_ST_PZ_NEW sg9
_ST_PZ_C a.txt a "SG9 a" && _ST_PZ_C b.txt b "SG9 b"
cp "$SELF" "$TMP/sg-copy" && chmod -x "$TMP/sg-copy"
cp -R "${SELF:h}/selftest" "$TMP/selftest" 2>/dev/null
rm -f "$TMP/tty-out" "$TMP/tty-rc"; : > "$TMP/tty-out"
zpty ST_TTY "unset CLAUDECODE CI GIT_EDIT_ACTOR GIT_CONFIG_PARAMETERS; env HOME=${(q)TMP} GIT_EDIT_NO_AUTO_OPEN=1 NO_COLOR=1 PAGER=cat zsh ${(q)TMP}/sg-copy HEAD~1 2>&1; print -r -- \$? >${(q)TMP}/tty-rc"
if _ST_TTY_AT 'Make your changes in'; then
	print -r -- a2 > "$(_ST_PZ_WT)/a.txt"
	zpty -wn ST_TTY $'\r'
	_ST_TTY_AT 'to leave it paused' 2 && zpty -wn ST_TTY q
fi
_ST_TTY_END
_ST_EQ "a non-executable copy resumes through zsh" "$RC:$(git show HEAD~1:a.txt)" "0:a2"
# The resume carries the caller's own settings on, leaving no temp file of the run it replaced
git config edit.verifyCmd 'test "$GIT_DIFF_OPTS" = --unified=5'
SG_N=$(command find "$TMP/tmp" -maxdepth 1 -type f -name 'git-edit-*' 2>/dev/null | wc -l | tr -d ' ')
_ST_TTY_START "GIT_DIFF_OPTS=--unified=5" "TMPDIR=$TMP/tmp" -- HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	print -r -- a3 > "$(_ST_PZ_WT)/a.txt"
	zpty -wn ST_TTY $'\r'
	_ST_TTY_AT 'to leave it paused' 2 && zpty -wn ST_TTY q
fi
_ST_TTY_END
git config --unset edit.verifyCmd
_ST_EQ "a resume at Enter keeps the caller's GIT_DIFF_OPTS for its gate" "$RC:$(git show HEAD~1:a.txt)" "0:a3"
_ST_EQ "and leaves no temp file of the run it replaced" "$(command find "$TMP/tmp" -maxdepth 1 -type f -name 'git-edit-*' 2>/dev/null | wc -l | tr -d ' ')" "$SG_N"
# A resumed drop refuses where the branch moved during the resolution
_ST_PZ_NEW sg10
_ST_PZ_C f.txt $'1\n2\n3' "SG10 c1" && _ST_PZ_C f.txt $'1\n2x\n3' "SG10 c2" && _ST_PZ_C f.txt $'1\n2xy\n3' "SG10 c3"
_ST_RUN -d -y HEAD~1
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'1\n2y\n3'
_ST_PZ_C p.txt p "SG10 peer"
SG_T=$(git rev-parse HEAD)
_ST_RUN --continue
_ST_EQ "a resumed drop refuses a branch moved meanwhile" "$RC:$(git rev-parse HEAD)" "1:$SG_T"
_ST_OUT_HAS "keeping the resolution" 'Your resolution is intact in'
_ST_RUN --abort
# A commit the drop leaves empty is named
_ST_PZ_NEW sg11
_ST_PZ_C base.txt b "SG11 base"
_ST_PZ_C x.txt x "SG11 adds x"
git rm -q x.txt && git commit -qm "SG11 removes x"
_ST_PZ_C g.txt g "SG11 g"
_ST_RUN -d -y HEAD~2
_ST_OUT_HAS "a commit the drop empties is named" 'left empty by the drop were dropped'
# An edit's --text after its amend refuses, as do commits at the stop with edits beside them
_ST_PZ_NEW sg12
_ST_PZ_C a.txt a "SG12 a" && _ST_PZ_C b.txt b "SG12 b"
_ST_RUN HEAD~1
print -r -- a2 > "$(_ST_PZ_WT)/a.txt"
_ST_RUN --continue --verify=false
_ST_RUN --continue --text "SG12 late"
_ST_EQ "--text past the amend refuses" "$RC" "1"
_ST_OUT_HAS "saying where it belonged" 'takes effect at the amend, which is past'
_ST_RUN --abort
_ST_RUN HEAD~1
SG_WT=$(_ST_PZ_WT)
print -r -- a3 > "${SG_WT:-$ST_NO_WT}/a.txt" && git -C "${SG_WT:-$ST_NO_WT}" commit -qam "SG12 at the stop"
print -r -- a4 > "${SG_WT:-$ST_NO_WT}/a.txt"
_ST_RUN --continue
_ST_EQ "commits at the stop with edits beside them refuse" "$RC" "1"
_ST_OUT_HAS "naming both" 'Commits were made at the stop, with changes beside them still uncommitted'
_ST_RUN --abort
# A pause reads as landed only where its own run's move put the branch at its worktree's `HEAD`
_ST_PZ_NEW sg13
_ST_PZ_C a.txt a "SG13 a" && _ST_PZ_C b.txt b "SG13 b"
_ST_RUN HEAD~1
SG_WT=$(_ST_PZ_WT)
print -r -- a2 > "${SG_WT:-$ST_NO_WT}/a.txt"
# A peer's landing, journaled, from the tip the pause read – a pause blocks a --commit itself
SG_T=$(git rev-parse HEAD)
_ST_PZ_C p.txt p "SG13 peer"
printf '%s refs/heads/main %s %s commit\tsg-peer\n' "$(date +%s)" "$SG_T" "$(git rev-parse HEAD)" >> .git/git-edit-journal
_ST_RUN --continue
_ST_OUT_LACKS "a peer's landing from the same tip is no landing of the pause" 'had landed already'
_ST_EQ "which lands onto it" "$RC:$(git log --format=%s | tr '\n' ' ')" "0:SG13 peer SG13 b SG13 a "
_ST_RUN HEAD~2
SG_WT=$(_ST_PZ_WT)
git update-ref refs/heads/main "$(git -C "${SG_WT:-$ST_NO_WT}" rev-parse HEAD)"
git reset -q --hard
_ST_RUN --continue
_ST_OUT_LACKS "nor is a branch reset to the paused commit" 'had landed already'
_ST_RUN --abort
# A file another caller added empty holds no lines a caller's own could keep
_ST_PZ_NEW sg14
_ST_PZ_C base.txt b "SG14 base"
: > e.txt
GIT_EDIT_ACTOR=sg-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "SG14 peer adds empty" -- e.txt </dev/null >/dev/null 2>&1
print -r -- filled > e.txt
GIT_EDIT_ACTOR=sg-self _ST_RUN --commit --text "SG14 fills" -- e.txt
_ST_EQ "a file another caller added empty takes edits on it" "$RC:$(git log -1 --format=%s)" "0:SG14 fills"
cd "$TMP/repo"
