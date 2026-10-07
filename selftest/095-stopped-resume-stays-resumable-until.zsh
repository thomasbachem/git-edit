# A signal mid-check leaves the pause for another `--continue`, while one after the landing
# must not leave a landed operation in flight for an `--abort` to call untouched
_ST_SCENARIO "\e[1;96m[95] a stopped resume stays resumable until it lands\e[0m"
local VR
for VR in base one two; do
	echo "$VR" > "vr_$VR.txt" && git add "vr_$VR.txt" && git commit -qm "VR $VR"
done
local VR_TWO=$(git rev-parse ':/VR two') VR_BASE=$(git rev-parse ':/VR base')
local VR_WORKTREES=$(git worktree list | wc -l | tr -d ' ')
# Fails until `vr-pass` exists, and holds each check open while `vr-slow` does
git config edit.verifyCmd "sh -c 'echo \$\$ > \"$TMP/vr-check\"; test -f \"$TMP/vr-slow\" && \"$TMP/st-hold\" \"$TMP/vr-release\"; test -f \"$TMP/vr-pass\"'"
rm -f "$TMP/vr-pass" "$TMP/vr-slow"
_ST_RUN --move="$VR_TWO" --after="$VR_BASE"
_ST_EQ "a failing gate pauses the move" "$RC" "2"
touch "$TMP/vr-slow"
rm -f "$TMP/vr-check" "$TMP/vr-release"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null >"$TMP/vr-out" 2>&1 &
local VR_PID=$!
local -i VR_WAIT=0
until [ -s "$TMP/vr-check" ] || ! kill -0 $VR_PID 2>/dev/null || (( ++VR_WAIT > 1200 )); do
	sleep 0.1
done
kill -TERM $VR_PID
: > "$TMP/vr-release"
wait $VR_PID
RC=$?
_ST_EQ "a TERM mid-check stops the resume" "$RC" "143"
_ST_RUN --status
_ST_OUT_HAS "leaving it paused for another" '^git-edit: paused'
rm -f "$TMP/vr-slow"
touch "$TMP/vr-pass"
# Holds the branch's move open, so the TERM lands after the resume started moving it
local VR_REF=$(git symbolic-ref HEAD) VR_HOOKS=$(git rev-parse --path-format=absolute --git-path hooks)
print -r -- "#!/bin/sh
[ \"\$1\" = committed ] || exit 0
while read -r old new ref; do [ \"\$ref\" = $VR_REF ] && { : > '$TMP/vr-moving'; '$TMP/st-hold' '$TMP/vr-release2'; }; done
exit 0" > "$VR_HOOKS/reference-transaction"
chmod +x "$VR_HOOKS/reference-transaction"
rm -f "$TMP/vr-moving" "$TMP/vr-release2"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null >"$TMP/vr-out" 2>&1 &
VR_PID=$!
until [ -f "$TMP/vr-moving" ] || ! kill -0 $VR_PID 2>/dev/null; do
	sleep 0.05
done
kill -TERM $VR_PID 2>/dev/null
: > "$TMP/vr-release2"
wait $VR_PID
RC=$?
OUT=$(<"$TMP/vr-out")
_ST_EQ "a TERM once the resume moves the branch lets it finish" "$RC" "0"
_ST_OUT_HAS "naming the signal above the trailer" '^SIGTERM arrived once the branch had moved'
_ST_RUN --status
_ST_OUT_HAS "leaves nothing in flight" 'no operation in flight'
_ST_EQ "and no worktree" "$(git worktree list | wc -l | tr -d ' ')" "$VR_WORKTREES"
# Only the state the run resumed – a pause another run wrote while this one was checking holds
# that run's work, so finishing this one leaves it be
local VR_SF="$(git rev-parse --git-common-dir)/git-edit-state"
local VR_ONE=$(git log -1 --format=%H --grep='^VR one$' HEAD)
git config edit.verifyCmd "sh -c 'echo \$\$ > \"$TMP/vr-check\"; \"$TMP/st-hold\" \"$TMP/vr-release3\"'"
rm -f "$TMP/vr-check" "$TMP/vr-moving" "$TMP/vr-release2" "$TMP/vr-release3"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --move="$VR_ONE" --after="$VR_BASE" </dev/null >"$TMP/vr-out" 2>&1 &
VR_PID=$!
VR_WAIT=0
until [ -s "$TMP/vr-check" ] || ! kill -0 $VR_PID 2>/dev/null || (( ++VR_WAIT > 1200 )); do
	sleep 0.1
done
printf 'operation=reorder\nworktree=%s\n' "$TMP/vr-foreign" > "$VR_SF"
: > "$TMP/vr-release3"
until [ -f "$TMP/vr-moving" ] || ! kill -0 $VR_PID 2>/dev/null; do
	sleep 0.05
done
kill -TERM $VR_PID 2>/dev/null
: > "$TMP/vr-release2"
wait $VR_PID
RC=$?
OUT=$(<"$TMP/vr-out")
rm -f "$VR_HOOKS/reference-transaction"
_ST_EQ "a TERM once a first run moves the branch lets it finish" "$RC" "0"
_ST_CHECK "keeping a pause another run wrote meanwhile" test -f "$VR_SF"
rm -f "$VR_SF"
_ST_EQ "and removing its own worktree" "$(git worktree list | wc -l | tr -d ' ')" "$VR_WORKTREES"
git config --unset edit.verifyCmd
