# A run takes a `-C` path, a resume its pause, as they stand once it holds them – a pause recorded
# in that path meanwhile refuses the run, never reset, and a pause another resume moved on refuses
# the stale one – a half-broken lock a dead breaker left is waited out, never named a live run, and
# a fresh lock taken during a stalled break stays
# An undo a hook vetoes says nothing was undone, and a run under a landing's own
# hook refuses its journal at once
_ST_SCENARIO "\e[1;96m[164] paths and pauses are taken as they stand once held\e[0m"
local ZL_P ZL_WT ZL_GD ZL_LOCK ZL_N ZL_X ZL_PID ZL_LIVE
local -i ZL_I
# Writes `<dir>/<command>` standing in for the real one, running <script> first where <dir>/arm is
# there and <case pattern> takes the call's arguments
_ZL_STAND_IN () {
	# Args: <dir> <command> <case pattern> <script>
	mkdir -p "$1"
	{
		print -r -- '#!/bin/sh'
		print -r -- "case \" \$* \" in $3) if [ -e ${(q)1}/arm ]; then $4; fi ;; esac"
		print -r -- "exec ${(q)commands[$2]} \"\$@\""
	} > "$1/$2"
	chmod +x "$1/$2"
}
# Waits for <file>, or for <pid> to end – bounded
_ZL_WAIT () {
	# Args: <file> <pid>
	ZL_I=0
	until [ -e "$1" ] || ! kill -0 "$2" 2>/dev/null || (( ++ZL_I > 1200 )); do sleep 0.1; done
}
mkdir -p "$TMP/zl-nap" && print -l '#!/bin/sh' 'exit 0' > "$TMP/zl-nap/sleep" && chmod +x "$TMP/zl-nap/sleep"

# A drop past its look at the pause slot, a pause recorded in its `-C` path
# before it holds the path – that run gone, its commit amended there – refuses
# there, rather than reset what the pause holds
_ST_PZ_NEW zl1
_ST_PZ_C a.txt a1 "ZL1 a" && _ST_PZ_C b.txt b1 "ZL1 b" && _ST_PZ_C c.txt c1 "ZL1 c"
ZL_P="$TMP/zl1-wt"
git worktree add -q --detach "$ZL_P" HEAD
_ZL_STAND_IN "$TMP/zl1-git" git "*\" -C $ZL_P rev-parse --show-toplevel \"*" "mv ${(q)TMP}/zl1-git/arm ${(q)TMP}/zl1-in; ${(q)TMP}/st-hold ${(q)TMP}/zl1-go"
: > "$TMP/zl1-git/arm"
( PATH="$TMP/zl1-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -C "$ZL_P" -d -y "$(git rev-parse HEAD)" </dev/null > "$TMP/zl1.b" 2>&1; print -r -- $? > "$TMP/zl1.brc" ) &
ZL_PID=$!
_ZL_WAIT "$TMP/zl1-in" $ZL_PID
_ST_RUN -C "$ZL_P" HEAD~1
print -r -- b2 > "$ZL_P/b.txt"
git -C "$ZL_P" commit -qa --amend --no-edit
ZL_N=$(git -C "$ZL_P" rev-parse HEAD)
: > "$TMP/zl1-go"
wait $ZL_PID
OUT=$(<"$TMP/zl1.b")
_ST_EQ "a drop whose -C path a pause took before it held it refuses, the pause's commit kept" "$(<"$TMP/zl1.brc"):$(git -C "$ZL_P" rev-parse HEAD)" "1:$ZL_N"
_ST_OUT_HAS "naming the pause there" 'paused there as this run started'
_ST_RUN --continue
_ST_EQ "and the pause lands what was done there" "$RC:$(git show HEAD~1:b.txt)" "0:b2"
_ST_RUN -C "$ZL_P" -d -y HEAD
_ST_EQ "while a -C path no pause names is taken and reset as ever" "$RC:$(git log --format=%s | tr '\n' '|')" "0:ZL1 b|ZL1 a|"

# A resume that read its pause before another resume moved it on to a later stop refuses once it
# holds the pause's worktree, the other's notes kept – the next resume takes it up where it stands
_ST_PZ_NEW zl2
git config rerere.enabled false
print -r -- 1 > f && print -r -- 1 > g && git add f g && git commit -qm "ZL2 base"
print -r -- 2 > f && print -r -- 2 > g && git commit -qam "ZL2 X" && ZL_X=$(git rev-parse HEAD)
print -r -- 3 > f && git commit -qam "ZL2 Y"
print -r -- 3 > g && git commit -qam "ZL2 Z"
git config edit.verifyCmd false
_ST_RUN -d -y "$ZL_X"
ZL_WT=$(_ST_PZ_WT)
_ZL_STAND_IN "$TMP/zl2-git" git "*\" -C ${ZL_WT:-$ST_NO_WT} rev-parse --path-format=absolute \"*" "mv ${(q)TMP}/zl2-git/arm ${(q)TMP}/zl2-in; ${(q)TMP}/st-hold ${(q)TMP}/zl2-go"
: > "$TMP/zl2-git/arm"
( PATH="$TMP/zl2-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null > "$TMP/zl2.a" 2>&1; print -r -- $? > "$TMP/zl2.arc" ) &
ZL_PID=$!
_ZL_WAIT "$TMP/zl2-in" $ZL_PID
_ST_RESOLVE "${ZL_WT:-$ST_NO_WT}" f 3
_ST_RUN --continue
ZL_N=$RC
_ST_RESOLVE "${ZL_WT:-$ST_NO_WT}" g 3
: > "$TMP/zl2-go"
wait $ZL_PID
OUT=$(<"$TMP/zl2.a")
_ST_EQ "a resume whose pause another resume moved on meanwhile refuses" "$ZL_N:$(<"$TMP/zl2.arc")" "2:1"
_ST_OUT_HAS "saying another run resumed it" 'Another run resumed this pause while this one waited'
_ST_RUN --continue
_ST_EQ "the next resume taking it up where it stands, both stops' resolutions kept for the gate" \
	"$RC:$(sed -n 's/^resolved=//p' .git/git-edit-state 2>/dev/null | tail -1 | wc -w | tr -d ' ')" "2:2"
_ST_RUN --abort
git config --unset edit.verifyCmd

# A `-C` lock whose breaker died mid-break, leaving its second name, is waited out – past the wait,
# a `sleep` returning at once cutting it short, its holder named as gone, never as a live run
_ST_PZ_NEW zl3
_ST_PZ_C a.txt a1 "ZL3 a" && _ST_PZ_C b.txt b1 "ZL3 b"
ZL_P="$TMP/zl3-wt"
git worktree add -q --detach "$ZL_P" HEAD
ZL_LOCK="$(git -C "$ZL_P" rev-parse --absolute-git-dir)/git-edit-run.lock"
sh -c 'exit 0' & ZL_PID=$!
wait $ZL_PID
print -r -- "$ZL_PID Thu Jan 1 00:00:00 1970" > "$ZL_LOCK"
ln "$ZL_LOCK" "$ZL_LOCK.break"
PATH="$TMP/zl-nap:$PATH" _ST_RUN -C "$ZL_P" HEAD~1
_ST_EQ "a -C lock a dead breaker left half broken refuses past the wait" "$RC" "1"
_ST_OUT_HAS "naming its holder as gone" 'that is gone, but a break of it never finished'
_ST_OUT_LACKS "never as a live run" 'in use by another run'
_ST_RUN -C "$ZL_P" HEAD~1
_ST_EQ "while a run waiting it out takes the path" "$RC:$([ -e "$ZL_LOCK.break" ] && echo break)" "2:"
_ST_RUN --abort

# A break stalled past its second name's 10 s – another run breaking the lock meanwhile and a third
# taking it fresh – leaves that fresh lock in place, its run refusing the path as in use
_ST_PZ_NEW zl4
_ST_PZ_C a.txt a1 "ZL4 a" && _ST_PZ_C b.txt b1 "ZL4 b"
ZL_P="$TMP/zl4-wt"
git worktree add -q --detach "$ZL_P" HEAD
ZL_LOCK="$(git -C "$ZL_P" rev-parse --absolute-git-dir)/git-edit-run.lock"
sh -c 'exit 0' & ZL_PID=$!
wait $ZL_PID
print -r -- "$ZL_PID Thu Jan 1 00:00:00 1970" > "$ZL_LOCK"
_ZL_STAND_IN "$TMP/zl4-bin" rm "*\" -f $ZL_LOCK \"*" "mv ${(q)TMP}/zl4-bin/arm ${(q)TMP}/zl4-in; ${(q)TMP}/st-hold ${(q)TMP}/zl4-go"
_ZL_STAND_IN "$TMP/zl4-bin" mv "*\" -f $ZL_LOCK \"*" "mv ${(q)TMP}/zl4-bin/arm ${(q)TMP}/zl4-in; ${(q)TMP}/st-hold ${(q)TMP}/zl4-go"
: > "$TMP/zl4-bin/arm"
( PATH="$TMP/zl4-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -C "$ZL_P" HEAD~1 </dev/null > "$TMP/zl4.x" 2>&1; print -r -- $? > "$TMP/zl4.xrc" ) &
ZL_PID=$!
_ZL_WAIT "$TMP/zl4-in" $ZL_PID
mkdir -p "$TMP/zl4-aside"
[ -e "$ZL_LOCK.break" ] && mv "$ZL_LOCK.break" "$TMP/zl4-aside/break"
mv "$ZL_LOCK" "$TMP/zl4-aside/lock"
sleep 30 & ZL_LIVE=$!
_PID_START $ZL_LIVE
print -r -- "$ZL_LIVE $REPLY" > "$ZL_LOCK"
: > "$TMP/zl4-go"
wait $ZL_PID
OUT=$(<"$TMP/zl4.x")
_ST_EQ "a break stalled past its second name's age leaves a lock taken since in place" "$([ -e "$TMP/zl4-in" ] && echo stalled):$(<"$TMP/zl4.xrc"):$(cut -d' ' -f1 "$ZL_LOCK" 2>/dev/null)" "stalled:1:$ZL_LIVE"
_ST_OUT_HAS "its run refusing the path as in use" 'in use by another run (pid '
kill $ZL_LIVE; wait $ZL_LIVE 2>/dev/null
_ST_RUN -C "$ZL_P" HEAD~1
_ST_EQ "until that holder ends" "$RC:$(cd "${ZL_LOCK:h}" && print -r -- git-edit-run.lock.*(N))" "2:"
_ST_RUN --abort

# An undo a `reference-transaction` hook vetoes says nothing was undone,
# and one it lets through then undoes
_ST_PZ_NEW zl5
_ST_PZ_C a.txt a1 "ZL5 a" && _ST_PZ_C b.txt b1 "ZL5 b"
_ST_RUN -M --text "ZL5 b2" HEAD
ZL_N=$(git rev-parse HEAD)
printf '#!/bin/sh\n[ "$1" = prepared ] && [ -e "%s/zl5-veto" ] && exit 1\nexit 0\n' "$TMP" > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
: > "$TMP/zl5-veto"
_ST_RUN --undo
_ST_EQ "an undo a hook vetoes leaves the branch" "$RC:$(git rev-parse HEAD)" "1:$ZL_N"
_ST_OUT_HAS "saying nothing was undone" 'still at the tip this run read – nothing was undone'
_ST_OUT_LACKS "never that nothing was applied" 'nothing was applied'
mv "$TMP/zl5-veto" "$TMP/zl5-veto.off"
_ST_RUN --undo
_ST_EQ "while one it lets through undoes" "$RC:$(git log -1 --format=%s)" "0:ZL5 b"

# A git edit a landing's own `reference-transaction` hook runs refuses the journal that landing
# holds at once, naming it – no wait outlasts the run it runs under – the landing going through
_ST_PZ_NEW zl6
_ST_PZ_C a.txt a1 "ZL6 a" && _ST_PZ_C b.txt b1 "ZL6 b"
_ST_RUN -M --text "ZL6 b2" HEAD
printf '#!/bin/sh\n[ "$1" = prepared ] || exit 0\n[ -e "%s/zl6-arm" ] || exit 0\nmv "%s/zl6-arm" "%s/zl6-in"\nPATH="%s/zl-nap:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "%s" --undo </dev/null > "%s/zl6.u" 2>&1\necho $? > "%s/zl6.urc"\nexit 0\n' \
	"$TMP" "$TMP" "$TMP" "$TMP" "$SELF" "$TMP" "$TMP" > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
: > "$TMP/zl6-arm"
_ST_RUN -M --text "ZL6 b3" HEAD
_ST_EQ "a git edit a landing's hook runs refuses its journal, the landing going through" "$(<"$TMP/zl6.urc" 2>/dev/null):$RC:$(git log -1 --format=%s)" "1:0:ZL6 b3"
OUT=$(<"$TMP/zl6.u" 2>/dev/null)
_ST_OUT_HAS "naming the run it runs under" 'locked by the run this one runs under (pid '
mv .git/hooks/reference-transaction "$TMP/zl6-hook.off"
unfunction _ZL_STAND_IN _ZL_WAIT
cd "$TMP/repo"
