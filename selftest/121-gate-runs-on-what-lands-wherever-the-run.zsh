_ST_SCENARIO "\e[1;96m[121] the gate runs on what lands, wherever the run starts\e[0m"
local GL_WT GL_TIP GL_N GL_PID
local -i GL_WAIT
# A resolution's file left unstaged would feed the gate and never land, so the resume refuses
_ST_PZ_NEW g1
git config edit.verifyCmd true
for GL_N in 1 2 3; do _ST_PZ_C f.txt "$GL_N" "GL $GL_N"; done
_ST_RUN -d HEAD~1
_ST_EQ "a drop conflicting with what follows pauses" "$RC" "2"
GL_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${GL_WT:-$ST_NO_WT}" f.txt 3
print -r -- note > "${GL_WT:-$ST_NO_WT}/notes.txt"
_ST_RUN --continue
_ST_EQ "an untracked file blocks a gated conflict resume" "$RC" "1"
_ST_OUT_HAS "naming it" 'never land: notes.txt'
rm -f "$GL_WT/notes.txt"
_ST_RUN --continue
_ST_EQ "and the resume lands once it is gone" "$RC" "0"
# An edit being authored stages its worktree wholesale, so the file lands there instead
_ST_RUN HEAD~1
GL_WT=$(_ST_PZ_WT)
print -r -- new > "${GL_WT:-$ST_NO_WT}/new.txt"
_ST_RUN --continue
_ST_EQ "an edit's authoring stage takes an untracked file under a gate" "$RC" "0"
_ST_CHECK "into the edited commit" git cat-file -e "HEAD~1:new.txt"
# A reused `-C` worktree's untracked files would feed the gate the same way
git worktree add -q --detach "$TMP/pz-g1-wt" HEAD
print -r -- u > "$TMP/pz-g1-wt/u.txt"
GL_TIP=$(git rev-parse HEAD)
_ST_RUN -d HEAD -C="$TMP/pz-g1-wt"
_ST_EQ "a -C worktree holding untracked files refuses under a gate" "$RC" "1"
_ST_OUT_HAS "saying why" 'holds untracked files the verify check would run over'
_ST_EQ "moving nothing" "$(git rev-parse HEAD)" "$GL_TIP"
git worktree remove --force "$TMP/pz-g1-wt"
# Each check starts from its commit alone – a run's leftovers failed the next run, blamed the
# commit it replaces and blocked the resume – while a file someone adds there still refuses
_ST_PZ_NEW g7
for GL_N in a b c; do _ST_PZ_C "$GL_N.txt" "$GL_N" "GL $GL_N"; done
echo a2 > a.txt && git add a.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" --verify='test ! -e marker && touch marker' -- a.txt
_ST_EQ "a check leaving a file behind passes at each commit it runs at" "$RC:$(git show HEAD~2:a.txt)" "0:a2"
_ST_OUT_HAS "naming what it left" "Removed what the check left untracked, so no run saw another's: marker"
_ST_PZ_NEW g8
for GL_N in a b c; do _ST_PZ_C "$GL_N.txt" "$GL_N" "GL $GL_N"; done
echo a3 > a.txt && git add a.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" --verify='test ! -e marker && touch marker && { test ! -e c.txt || ! grep -q a3 a.txt; }' -- a.txt
_ST_EQ "one failing at the tip pauses" "$RC" "2"
_ST_OUT_LACKS "never blaming the commit it replaces for its own leftovers" 'replaces fails the same check'
GL_WT=$(_ST_PZ_WT)
_ST_RUN --continue
_ST_EQ "and its resume checks again rather than refuse" "$RC" "2"
_ST_OUT_LACKS "on a file the check left" 'never land: marker'
print -r -- mine > "${GL_WT:-$ST_NO_WT}/mine.txt"
_ST_RUN --continue
_ST_EQ "while a file someone adds there still refuses" "$RC" "1"
_ST_OUT_HAS "naming it" 'never land: mine.txt'
_ST_RUN --abort
# The default `-C` path is the tool's own, so what a run cut off mid-check left there is removed
_ST_PZ_NEW g1d
for GL_N in a b c d; do _ST_PZ_C "$GL_N.txt" "$GL_N" "GL $GL_N"; done
git config edit.verifyCmd true
_ST_RUN -d -y -C HEAD~2
print -r -- stale > "$TMP/pz-g1d.git-edit/stale.log"
_ST_RUN -d -y -C HEAD~1
_ST_EQ "a second gated run in the default -C path lands" "$RC:$(git log --format=%s | tr '\n' ' ')" "0:GL d GL a "
_ST_OUT_HAS "naming what the first one left" 'Removed what an earlier run left untracked in .*: stale.log'
git worktree remove --force "$TMP/pz-g1d.git-edit"
# An `--exec` command's untracked litter never lands, so the gate runs
# without it – an ignored file stays, as the links do
_ST_PZ_NEW g2
print -r -- '*.log' > .gitignore && git add .gitignore && git commit -qm "GL ignore"
git config edit.verifyCmd '! test -e litter.txt && test -e keep.log'
_ST_RUN --exec -- sh -c 'echo x > litter.txt; echo y > keep.log; git commit -q --allow-empty -m "GL exec"'
_ST_EQ "an --exec gate runs without the command's litter" "$RC" "0"
_ST_OUT_HAS "saying it was removed" 'left untracked, which never lands: litter.txt'
# A check leaving a process behind holds no pipe the gate waits on – that process outliving the
# run proves it, where a clock reads a loaded machine as a wait
rm -f "$TMP/gl-bg"
_ST_RUN --exec --verify="(sleep 300 & echo \$! > '$TMP/gl-bg'); true" -- git commit -q --allow-empty -m "GL bg"
_ST_EQ "a check leaving a background process lands" "$RC" "0"
_ST_CHECK "without waiting on it" sh -c "kill -0 \"\$(cat '$TMP/gl-bg')\" 2>/dev/null"
kill "$(<"$TMP/gl-bg")" 2>/dev/null
# A terminal run builds in a worktree of its own, where a configured gate runs as on an agent's,
# and a configured link the checkout lacks is named, a check needing it failing on that
_ST_PZ_NEW g3
for GL_N in a b c; do _ST_PZ_C "$GL_N.txt" "$GL_N" "GL $GL_N"; done
git config edit.verifyCmd false
git config edit.worktreeLink node_modules
GL_TIP=$(git rev-parse HEAD)
_ST_TTY_START -- -d -y HEAD~1
_ST_TTY_AT 'to leave it paused' && zpty -wn ST_TTY q
_ST_TTY_END
_ST_OUT_HAS "a terminal run builds in a worktree of its own" 'git worktree add --detach .*git-edit-auto-iso'
_ST_EQ "where the failing gate pauses it, left paused from the prompt" "$RC" "2"
_ST_EQ "moving nothing" "$(git rev-parse HEAD)" "$GL_TIP"
_ST_OUT_HAS "a configured link the checkout lacks is named" 'Not linking node_modules – .* has none to link'
_ST_RUN --abort
git config --unset edit.worktreeLink
# Detached, a result would land nowhere, so the run refuses
git checkout -q --detach
_ST_TTY -- -d -y HEAD~1
_ST_OUT_HAS "a detached terminal run refuses, naming what it needs" 'requires being on a branch'
git checkout -q main
# The reword template comments in the configured character, which is what gets stripped
git config core.commentChar ';'
GL_TIP=$(git rev-parse HEAD)
_ST_TTY GIT_EDITOR=: -- -M HEAD
_ST_EQ "a reword left as opened keeps its message" "$(git log -1 --format=%B)" "$(git log -1 --format=%B "$GL_TIP")"
git config --unset core.commentChar
# A dumb terminal skips `VISUAL`, and git refuses rather than fall back to vi there
_ST_TTY TERM=dumb GIT_EDITOR= EDITOR= VISUAL=false -- -M HEAD
_ST_OUT_HAS "a dumb terminal with no EDITOR refuses as git does" 'Terminal is dumb, but EDITOR unset'
# What a person authors at a terminal edit's prompt lands only once the check passes on it, a
# failing one pausing into `--continue`, and Escape twice leaving nothing
_ST_PZ_NEW g6
for GL_N in a b c; do _ST_PZ_C "$GL_N.txt" "$GL_N" "GL $GL_N"; done
git config edit.verifyCmd '! grep -q bad b.txt'
_ST_TTY_EDIT HEAD~1 b.txt b2
_ST_OUT_HAS "a terminal edit pauses with a worktree at the commit" 'Worktree at the commit'
_ST_EQ "landing what was authored at the prompt once the check passes" "$RC:$(git show HEAD~1:b.txt)" "0:b2"
_ST_OUT_HAS "saying so" 'Verified '
_ST_EQ "and leaving no worktree behind" "$(git worktree list | wc -l | tr -d ' ')" "1"
git reset -q --hard
GL_TIP=$(git rev-parse HEAD)
_ST_TTY_EDIT HEAD~1 b.txt bad
_ST_EQ "a check failing on the edit pauses, moving nothing" "$RC:$(git rev-parse HEAD)" "2:$GL_TIP"
_ST_OUT_HAS "into a resume" 'paused – verify failed'
git config edit.verifyCmd true
_ST_RUN --continue
_ST_EQ "which lands the edit once the check passes" "$RC:$(git show HEAD~1:b.txt)" "0:bad"
git reset -q --hard
GL_TIP=$(git rev-parse HEAD)
_ST_TTY_START -- HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	zpty -wn ST_TTY $'\e'
	_ST_TTY_AT 'Press Escape again' && zpty -wn ST_TTY $'\e'
fi
_ST_TTY_END
_ST_EQ "Escape twice at the prompt cancels" "$RC:$(git rev-parse HEAD)" "0:$GL_TIP"
_ST_EQ "leaving no worktree behind" "$(git worktree list | wc -l | tr -d ' ')" "1"
_ST_CHECK "nor a pause" test ! -e "$(git rev-parse --git-common-dir)/git-edit-state"
# A counterpart lacking a path the check names fails on that alone, so the walk answers instead
_ST_PZ_NEW g4
_ST_PZ_C base.txt base "GL base"
_ST_PZ_C app.sh app "GL Add app"
_ST_PZ_C v2.sh v2 "GL Add v2 feature"
mkdir tests && print -r -- 'test -f v2.sh' > tests/t.sh && git add tests/t.sh
_ST_RUN --amend-into="$(git rev-parse ':/GL Add app')" --allow-new-path --verify='sh tests/t.sh' -- tests/t.sh
_ST_EQ "a fold failing its check pauses" "$RC" "2"
_ST_OUT_LACKS "never blaming a counterpart without the check's file" 'commit it replaces fails'
_ST_OUT_HAS "but naming where it heals" 'first green: [0-9a-f]* GL Add v2 feature'
_ST_RUN --abort
# A TERM during a split's check takes its throwaway worktree along
_ST_PZ_NEW g5
_ST_PZ_C s1.txt s1 "GL S base"
print -r -- a > sa.txt && print -r -- b > sb.txt && git add sa.txt sb.txt && git commit -qm "GL S both"
GL_N=$(git worktree list | wc -l | tr -d ' ')
git config edit.verifyCmd "sh -c 'echo \$\$ > \"$TMP/gl-check\"; \"$TMP/st-hold\" \"$TMP/gl-release\"'"
rm -f "$TMP/gl-check" "$TMP/gl-release"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --split=HEAD --text="GL S a" -- sa.txt </dev/null >"$TMP/gl-out" 2>&1 &
GL_PID=$!
GL_WAIT=0
until [ -s "$TMP/gl-check" ] || ! kill -0 $GL_PID 2>/dev/null || (( ++GL_WAIT > 1200 )); do
	sleep 0.1
done
kill -TERM $GL_PID
: > "$TMP/gl-release"
wait $GL_PID
RC=$?
kill "$(cat "$TMP/gl-check" 2>/dev/null)" 2>/dev/null
_ST_EQ "a TERM mid-check stops the split" "$RC" "143"
_ST_EQ "and takes its verify worktree along" "$(git worktree list | wc -l | tr -d ' ')" "$GL_N"
# An implicit squash routed to plumbing has no gate to keep an explicit --verify's promise
GL_TIP=$(git rev-parse HEAD)
_ST_RUN HEAD~1 HEAD --verify=true
_ST_EQ "an implicit squash routed to plumbing refuses --verify" "$RC" "1"
_ST_OUT_HAS "as -S does" 'cannot gate this squash'
_ST_EQ "moving nothing" "$(git rev-parse HEAD)" "$GL_TIP"
cd "$TMP/repo"
