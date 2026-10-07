_ST_SCENARIO "\e[1;96m[126] a resume lands what its own run built, and nothing else\e[0m"
local RE_WT RE_TIP RE_PID RE_AMENDED RE_N
# A resume cut off in its gate left the worktree on the commit it was checking – the next one
# lands the whole result all the same, as the pause records it
_ST_PZ_NEW re1
_ST_PZ_C f.txt $'1\n2\n3' "RE base"
_ST_PZ_C f.txt $'1\n2x\n3' "RE x"
_ST_PZ_C f.txt $'1\n2xy\n3' "RE y"
_ST_PZ_C g.txt g "RE g"
_ST_PZ_C h.txt h "RE h"
_ST_RUN -d -y HEAD~3
_ST_EQ "a drop conflicting with what follows pauses" "$RC" "2"
RE_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RE_WT:-$ST_NO_WT}" f.txt $'1\n2y\n3'
git config edit.verifyCmd "if [ -e '$TMP/re1-arm' ]; then rm -f '$TMP/re1-arm'; until [ -s '$TMP/re1-pid' ]; do sleep 0.1; done; kill -TERM \$(cat '$TMP/re1-pid'); sleep 1; fi; true"
: > "$TMP/re1-arm"
rm -f "$TMP/re1-pid"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null >"$TMP/re1-out" 2>&1 &
RE_PID=$!
print -r -- $RE_PID > "$TMP/re1-pid"
wait $RE_PID
RC=$?
_ST_EQ "a resume stopped in its gate stops" "$RC:$(git log -1 --format=%s)" "143:RE h"
_ST_RUN --continue
_ST_EQ "the next resume lands the whole result, not the commit the gate had out" \
	"$RC:$(git log --format=%s | tr '\n' ' ')" "0:RE h RE g RE y RE base "
git config --unset edit.verifyCmd
# A rebase begun by hand in an edit's worktree is not its replay – refused, never landed
_ST_PZ_NEW re2
for RE_N in a b c; do _ST_PZ_C "$RE_N.txt" "$RE_N" "RE2 $RE_N"; done
RE_TIP=$(git rev-parse HEAD)
_ST_RUN HEAD~1
RE_WT=$(_ST_PZ_WT)
GIT_SEQUENCE_EDITOR=true git -C "${RE_WT:-$ST_NO_WT}" rebase -q --exec false HEAD~1 >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a rebase begun by hand at an edit's stop is refused" "$RC:$(git rev-parse HEAD)" "1:$RE_TIP"
_ST_OUT_HAS "named as not the edit's replay" "is not this edit's replay"
_ST_RUN --abort
# A merge that reached the branch during an edit would be flattened by the replay – refused
_ST_RUN HEAD~1
RE_WT=$(_ST_PZ_WT)
print -r -- b2 > "${RE_WT:-$ST_NO_WT}/b.txt"
git checkout -q -b re2-side HEAD~2 && _ST_PZ_C s.txt s "RE2 side" && git checkout -q main
git merge -q --no-ff -m "RE2 merge" re2-side
RE_TIP=$(git rev-parse HEAD)
_ST_RUN --continue
_ST_EQ "a merge landed during an edit refuses its replay" "$RC:$(git rev-parse HEAD)" "1:$RE_TIP"
_ST_OUT_HAS "naming the merge" 'A merge reached main during the edit'
_ST_RUN --abort
# A branch reset to the paused commit is no landing of the pause – its authored files stay
_ST_PZ_NEW re3
for RE_N in a b c; do _ST_PZ_C "$RE_N.txt" "$RE_N" "RE3 $RE_N"; done
_ST_RUN HEAD~1
RE_WT=$(_ST_PZ_WT)
print -r -- b-authored > "${RE_WT:-$ST_NO_WT}/b.txt"
git reset -q --hard HEAD~1
_ST_RUN --continue
_ST_EQ "a branch reset to the paused commit still lands the edit" "$RC:$(git show HEAD:b.txt)" "0:b-authored"
_ST_OUT_LACKS "never read as landed already" 'had landed already'
# A squash resumed past a resolution that changes what the commits add up to lands nothing
_ST_PZ_NEW re4
for RE_N in 1 2 3 4; do _ST_PZ_C t.txt "t$RE_N" "RE4 $RE_N"; done
RE_TIP=$(git rev-parse HEAD)
_ST_RUN -s="$(git rev-parse HEAD~2)" -y HEAD
RE_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RE_WT:-$ST_NO_WT}" t.txt t4
_ST_RUN --continue
_ST_RESOLVE "${RE_WT:-$ST_NO_WT}" t.txt t3
_ST_RUN --continue
_ST_EQ "a resumed squash changing the tip lands nothing" "$RC:$(git rev-parse HEAD)" "1:$RE_TIP"
_ST_OUT_HAS "saying so" "The squash would change the tip's content"
_ST_RUN --abort
# A root's edit takes an amend made by hand at its stop
_ST_PZ_NEW re5
for RE_N in a b; do _ST_PZ_C "$RE_N.txt" "$RE_N" "RE5 $RE_N"; done
_ST_RUN HEAD~1
RE_WT=$(_ST_PZ_WT)
print -r -- a2 > "${RE_WT:-$ST_NO_WT}/a.txt"
git -C "${RE_WT:-$ST_NO_WT}" commit -q --amend -am "RE5 root amended"
_ST_RUN --continue
_ST_EQ "a hand-made amend of the root lands" "$RC:$(git log --format=%s | tr '\n' ' '):$(git show HEAD~1:a.txt)" "0:RE5 b RE5 root amended :a2"
# A replay aborted by hand leaves the amend, which the hint resets to
_ST_PZ_NEW re6
_ST_PZ_C f.txt $'1\n2\n3' "RE6 base"
_ST_PZ_C f.txt $'1\n2x\n3' "RE6 x"
_ST_PZ_C f.txt $'1\n2xy\n3' "RE6 y"
_ST_RUN HEAD~1
RE_WT=$(_ST_PZ_WT)
print -r -- $'1\n2z\n3' > "${RE_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
RE_AMENDED=$(sed -n 's/^amended=//p' .git/git-edit-state | tail -1)
git -C "${RE_WT:-$ST_NO_WT}" rebase --abort
_ST_RUN --continue
_ST_OUT_HAS "a replay aborted by hand points the reset at the amend" "reset --hard ${RE_AMENDED:0:12}"
_ST_RUN --abort
# A commit an edit empties goes, whether or not a post-rewrite hook makes the replay interactive
for RE_N in plain hooked; do
	_ST_PZ_NEW "re7-$RE_N"
	_ST_PZ_C f.txt $'1\n2\n3' "RE7 base"
	_ST_PZ_C g.txt g "RE7 g"
	_ST_PZ_C f.txt $'1\n2\n3\n4' "RE7 adds 4"
	_ST_PZ_C h.txt h "RE7 h"
	[ $RE_N = hooked ] && printf '#!/bin/sh\ncat >/dev/null\n' > .git/hooks/post-rewrite && chmod +x .git/hooks/post-rewrite
	_ST_RUN HEAD~2
	RE_WT=$(_ST_PZ_WT)
	print -r -- $'1\n2\n3\n4' > "${RE_WT:-$ST_NO_WT}/f.txt"
	_ST_RUN --continue
	_ST_EQ "a commit the edit emptied is dropped – $RE_N" "$RC:$(git log --format=%s | tr '\n' ' ')" "0:RE7 h RE7 g RE7 base "
done
# Dropping every commit leaves nothing to land
_ST_PZ_NEW re8
_ST_PZ_C a.txt a "RE8 a"
_ST_PZ_C b.txt b "RE8 b"
RE_TIP=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~1 HEAD
_ST_EQ "dropping every commit refuses" "$RC:$(git rev-parse HEAD)" "1:$RE_TIP"
_ST_OUT_HAS "saying why" 'leaves it none'
# A gate the run declined stays declined through its pauses
_ST_PZ_NEW re9
_ST_PZ_C f.txt $'1\n2\n3' "RE9 base"
_ST_PZ_C f.txt $'1\n2x\n3' "RE9 x"
_ST_PZ_C f.txt $'1\n2xy\n3' "RE9 y"
git config edit.verifyCmd false
_ST_RUN -d -y --no-verify HEAD~1
RE_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RE_WT:-$ST_NO_WT}" f.txt $'1\n2y\n3'
_ST_RUN --continue
_ST_EQ "a --no-verify run's resume skips the gate too" "$RC:$(git log -1 --format=%s)" "0:RE9 y"
_ST_OUT_HAS "saying so" 'Verify skipped – --no-verify was passed'
git config --unset edit.verifyCmd
# A pause's notes survive its rewrite, and a value with a newline is refused, never split into keys
(
	_STATE_OWNED=""
	STATE_RESOLVED=abc123
	_SAVE_STATE "operation=edit" "worktree=/nonexistent" >/dev/null 2>&1
	_SAVE_STATE "operation=edit" "worktree=/nonexistent" >/dev/null 2>&1
	grep -qx 'resolved=abc123' .git/git-edit-state
)
_ST_EQ "a pause rewritten keeps the trees resolved at its stops" "$?" "0"
rm -f .git/git-edit-state
( _STATE_OWNED=""; _SAVE_STATE "operation=edit" $'files=a\nbranch=refs/heads/x' >/dev/null 2>&1 )
_ST_EQ "a newline in a value refuses" "$?:$(test -e .git/git-edit-state && echo saved)" "1:"
cd "$TMP/repo"
