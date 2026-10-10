# A move the ref took lands and is journaled once whatever stops the run around it, a second undo
# of one run takes back nothing more, and a `-C` path is this repository's and one run's at a time
_ST_SCENARIO "\e[1;96m[143] a landing holds under signals and races, -C only this repo's and one run's\e[0m"
local LK_T LK_I LK_P LK_C3 LK_C5
# `update-ref` killed once the ref moved – a signal to the terminal's group while a hook runs on the
# committed transaction – lands, journaled, and `--undo` takes it back
_ST_PZ_NEW lk1
for LK_I in 1 2 3 4 5; do _ST_PZ_C "f$LK_I.txt" "$LK_I" "LK1 c$LK_I"; done
LK_T=$(git rev-parse HEAD)
printf '#!/bin/sh\n[ "$1" = committed ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\nkill -KILL $PPID\n' > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
_ST_RUN -d -y HEAD~2
rm -f .git/hooks/reference-transaction
_ST_EQ "a move the ref took lands though update-ref was killed" "${RC}:$(git log --format=%s | grep -c 'LK1 c3')" "0:0"
_ST_RUN --undo
_ST_EQ "journaled, so --undo takes it back" "${RC}:$(git rev-parse HEAD)" "0:$LK_T"
# Two undos of one run – the second finds it taken back, rather than take back the run before
_ST_PZ_NEW lk3
for LK_I in 1 2 3 4 5; do _ST_PZ_C "f$LK_I.txt" "$LK_I" "LK3 c$LK_I"; done
_ST_RUN -M --text "LK3 c4 reworded" HEAD~1
_ST_RUN -M --text "LK3 c5 reworded" HEAD
printf '#!/bin/sh\n[ "$1" = prepared ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\nsleep 2\n' > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
( GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --undo </dev/null > "$TMP/lk3.u1" 2>&1 ) &
LK_I=0; until [ -e .git/git-edit-journal.lock ] || (( ++LK_I > 200 )); do sleep 0.05; done
( GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --undo </dev/null > "$TMP/lk3.u2" 2>&1 ) &
wait
rm -f .git/hooks/reference-transaction
OUT=$(<"$TMP/lk3.u2")
_ST_OUT_HAS "a second undo of the same run says it is undone" 'Another undo took back'
_ST_EQ "the run before it kept" "$(git log -2 --format=%s | tr '\n' '|')" "LK3 c5|LK3 c4 reworded|"
# A second signal right after the move is journaled journals it no second time
_ST_PZ_NEW lk6
for LK_I in 1 2 3 4 5; do _ST_PZ_C "f$LK_I.txt" "$LK_I" "LK6 c$LK_I"; done
printf '#!/bin/sh\n[ "$1" = committed ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\n: > "%s/lk6.in"\nsleep 1\n' "$TMP" > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
: > .git/git-edit-journal
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -d HEAD~2 </dev/null > "$TMP/lk6.out" 2>&1 &
LK_P="$!"
LK_I=0; until [ -e "$TMP/lk6.in" ] || (( ++LK_I > 200 )); do sleep 0.05; done
kill -TERM "$LK_P"
LK_I=0; while [[ "$(<.git/git-edit-journal)" != *drop* ]] && (( ++LK_I < 2000000 )); do :; done
kill -TERM "$LK_P"
wait "$LK_P"
rm -f .git/hooks/reference-transaction
_ST_EQ "a second signal after the journal write leaves one line for the move" "$(grep -c ' drop ' .git/git-edit-journal)" "1"
# A `-C` path of another repository refuses before anything runs there
_ST_PZ_NEW lk2
for LK_I in 1 2 3 4 5; do _ST_PZ_C "f$LK_I.txt" "$LK_I" "LK2 c$LK_I"; done
git clone -q . "$TMP/lk2-other" && git -C "$TMP/lk2-other" switch -q --detach
LK_T=$(git -C "$TMP/lk2-other" rev-parse main)
_ST_RUN -d HEAD~2 -C="$TMP/lk2-other"
_ST_EQ "-C naming another repository's work tree refuses, its branch kept" "${RC}:$(git -C "$TMP/lk2-other" rev-parse main)" "1:$LK_T"
_ST_OUT_HAS "naming why" 'a working tree of another repository'
# As does a worktree of this one with someone's rebase going on in it
git worktree add -q --detach "$TMP/lk2-peer" HEAD
( cd "$TMP/lk2-peer" && GIT_SEQUENCE_EDITOR="sed -i.bak 1s/^pick/edit/" git rebase -i -q HEAD~2 >/dev/null 2>&1 )
_ST_RUN -C="$TMP/lk2-peer" -d -y HEAD~1
_ST_OUT_HAS "a -C worktree with a rebase in progress refuses" 'rebase-merge in progress'
_ST_EQ "its rebase left going" "$([ -d "$(git -C "$TMP/lk2-peer" rev-parse --path-format=absolute --git-path rebase-merge)" ] && echo going)" "going"
git -C "$TMP/lk2-peer" rebase --abort 2>/dev/null
git worktree remove --force "$TMP/lk2-peer"
# Two runs on one `-C` path – the second refuses while the first holds it
_ST_PZ_NEW lk4
for LK_I in 1 2 3 4 5; do _ST_PZ_C "f$LK_I.txt" "$LK_I" "LK4 c$LK_I"; done
git config edit.verifyCmd 'sleep 3; test ! -e f3.txt'
LK_C3=$(git rev-parse HEAD~2) LK_C5=$(git rev-parse HEAD)
( GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -d "$LK_C3" -C </dev/null > "$TMP/lk4.A" 2>&1 ) &
LK_I=0; until grep -q verify "$TMP/lk4.A" 2>/dev/null || (( ++LK_I > 200 )); do sleep 0.1; done
_ST_RUN -d "$LK_C5" -C --no-verify
_ST_OUT_HAS "a second run on a -C path in use refuses" 'is in use by another run'
wait
_ST_EQ "while the first lands what it built" "$(git log --format=%s | tr '\n' '|')" "LK4 c5|LK4 c4|LK4 c2|LK4 c1|"
git config --unset edit.verifyCmd
cd "$TMP/repo"
