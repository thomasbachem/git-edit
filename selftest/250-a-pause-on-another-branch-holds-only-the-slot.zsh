# A pause on another branch is in a run's way only where that run must pause itself:
# • A fold lands beside it, and that pause's own `--status` and `--continue` work on
# • A run reaching a conflict refuses with nothing applied, pointing at `--wait`, and one
#   reaching a refused gate waits there for the slot, then pauses – its check output kept
# • An edit, pausing at once, and a land of the paused branch still refuse at the start
# • A run stopped by a signal while it waits takes its replay in a `-C` path back, and one losing
#   the freed slot to another waiting run waits on for what is left of its bound
_ST_SCENARIO "\e[1;96m[250] a pause on another branch holds only the slot\e[0m"
local S_C1 S_G S_SIDE S_SF S_HELD S_WTS S_C S_WIN S_LOSE S_HOLD
local -i S_I

# Runs `git edit <arg>...` in the side worktree under label `s-side`, into `OUT` and `RC`
_S250_SIDE () {
	OUT=$(cd "$S_SIDE" && GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=s-side "$SELF" "$@" </dev/null 2>&1)
	RC=$?
}
# Starts `git edit <arg>...` in <dir> in the background under label <actor>
# – its output, pid and status into `$TMP/<name>.out`, `.pid` and `.rc`
_S250_BG () {
	# Args: <name> <dir> <actor> <arg>...
	local N=$1 D=$2 A=$3
	shift 3
	: > "$TMP/$N.out"; : > "$TMP/$N.pid"; : > "$TMP/$N.rc"
	( cd "$D" && env GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=$A "$SELF" "$@" </dev/null >"$TMP/$N.out" 2>&1 &
	  print -r -- $! >"$TMP/$N.pid"; wait $!; print -r -- $? >"$TMP/$N.rc" ) &
}
# Waits up to 60 s for <count> lines holding <text> in background run <name>'s output, or its end
_S250_UNTIL () {
	# Args: <name> <text> [<count>]
	local -i I=0
	until (( $(LC_ALL=C grep -cF -e "$2" "$TMP/$1.out" 2>/dev/null) >= ${3:-1} )) || [ -s "$TMP/$1.rc" ] || (( ++I > 600 )); do sleep 0.1; done
}
# Waits up to 60 s for background run <name> to end, its output and status into `OUT` and `RC`
_S250_END () {
	# Args: <name>
	local -i I=0
	until [ -s "$TMP/$1.rc" ] || (( ++I > 600 )); do sleep 0.1; done
	OUT=$(<"$TMP/$1.out")
	RC=$(<"$TMP/$1.rc")
}

_ST_PZ_NEW s250
_ST_PZ_C f.txt $'1\n2\n3' "S250 c1" && _ST_PZ_C g.txt g1 "S250 g" && \
	_ST_PZ_C f.txt $'1\n2x\n3' "S250 c2" && _ST_PZ_C f.txt $'1\n2xy\n3' "S250 c3"
S_C1=$(git rev-parse HEAD~3)
S_SF="$(git rev-parse --path-format=absolute --git-common-dir)/git-edit-state"
git branch side HEAD~1
S_SIDE="$TMP/s250-side"
git worktree add -q "$S_SIDE" side
_S250_SIDE "$S_C1"
_ST_EQ "an edit pauses on side" "$RC:$(sed -n 's/^branch=//p' "$S_SF")" "2:refs/heads/side"
S_HELD=$(<"$S_SF")

export GIT_EDIT_ACTOR=s-main
print -r -- g2 > g.txt && git add g.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" -- g.txt
_ST_EQ "a fold on main lands beside it" "$RC:$(git show HEAD~2:g.txt)" "0:g2"
_ST_OUT_LACKS "never waiting for it" "in flight"

S_WTS=$(git worktree list | wc -l | tr -d ' ')
S_G=$(git rev-parse HEAD)
_ST_RUN -d -y "$(git rev-parse HEAD~1)"
_ST_EQ "a drop reaching its conflict refuses, main unmoved" "$RC:$(git rev-parse HEAD)" "1:$S_G"
_ST_OUT_HAS "naming that pause and why" "in flight on side (paused for resolution – s-side's) – this run must pause too, and the repository holds one pause at a time, so nothing was applied"
_ST_OUT_HAS "and the rerun that waits at its stop" "Rerun with --wait=540: it waits at its stop for that pause to clear, then pauses there"
_ST_EQ "its worktree gone" "$(git worktree list | wc -l | tr -d ' ')" "$S_WTS"
_ST_EQ "the side pause as it was" "$(<"$S_SF")" "$S_HELD"

print -r -- g3 > g.txt && git add g.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" --verify=false --wait=1 -- g.txt
_ST_EQ "a fold whose gate refuses waits out its bound, then refuses" "$RC:$(git rev-parse HEAD)" "1:$S_G"
_ST_OUT_HAS "having waited at its stop" "still in flight on side after waiting 1s at this run's stop"
_ST_OUT_HAS "pointing at a longer wait" "Wait longer with --wait=540"
_ST_EQ "its staging kept" "$(git diff --cached --name-only)" "g.txt"
_ST_EQ "the side pause still as it was" "$(<"$S_SF")" "$S_HELD"

_ST_RUN "$(git rev-parse HEAD~3)"
_ST_EQ "an edit on main can't go ahead" "$RC" "1"
_ST_OUT_HAS "refused as in flight at its start" "Another git-edit operation is in flight on side, paused for its resolution"
_ST_RUN --land=side
_ST_EQ "nor can a land of the paused branch" "$RC" "1"
_ST_OUT_HAS "refused alike" "Another git-edit operation is in flight on side, paused for its resolution"
export GIT_EDIT_ACTOR=

_S250_SIDE --status
_ST_OUT_HAS "the side pause's --status names it" "paused – edit"
print -r -- h > "$(_ST_PZ_WT)/h.txt" && git -C "$(_ST_PZ_WT)" add h.txt
_S250_SIDE --continue
_ST_EQ "and its --continue lands on side" "$RC:$(git show side:h.txt 2>/dev/null)" "0:h"
_ST_EQ "main as the fold left it" "$(git rev-parse HEAD)" "$S_G"

# A gate pause waits at its stop for the slot, taking it once the side pause clears
_S250_SIDE "$(git rev-parse side~2)"
_ST_EQ "another edit pauses on side" "$RC" "2"
( env GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=s-main "$SELF" --amend-into="$(git rev-parse HEAD~2)" --verify=false --wait=60 -- g.txt \
	</dev/null >"$TMP/s250w.out" 2>&1; print -r -- $? >"$TMP/s250w.rc" ) &
S_I=0
until grep -q 'Waiting up to' "$TMP/s250w.out" 2>/dev/null || [ -s "$TMP/s250w.rc" ] || (( ++S_I > 600 )); do sleep 0.1; done
_S250_SIDE --abort
S_I=0
until [ -s "$TMP/s250w.rc" ] || (( ++S_I > 600 )); do sleep 0.1; done
OUT=$(<"$TMP/s250w.out")
_ST_EQ "a fold whose gate refuses beside it then pauses on main" "$(<"$TMP/s250w.rc"):$(sed -n 's/^branch=//p' "$S_SF")" "2:refs/heads/main"
_ST_OUT_HAS "having waited at its stop" "Waiting up to 60s for s-side's paused edit .* on side .*, then pausing here"
_ST_OUT_HAS "until it cleared" "The pause cleared after .* – pausing here."
_ST_OUT_HAS "its check output kept for its own pause" "output in .*git-edit-state-verify"
_ST_CHECK "the sidecar holding that check" grep -qx 'command: false' "$S_SF-verify"
export GIT_EDIT_ACTOR=s-main
_ST_RUN --abort
export GIT_EDIT_ACTOR=
git reset -q

# Stopped by a signal while it waits at its stop, a run takes its replay in a `-C` path back
_S250_SIDE "$(git rev-parse side~2)"
_ST_EQ "an edit pauses on side again" "$RC" "2"
S_C="$TMP/s250-cpath"
_S250_BG s250k "$PWD" s-main -d -y "$(git rev-parse HEAD~1)" -C="$S_C" --wait=60
_S250_UNTIL s250k 'Waiting up to'
kill -TERM "$(<"$TMP/s250k.pid")"
_S250_END s250k
_ST_OUT_HAS "a run stopped while waiting at its stop applies nothing" "while waiting for s-side's pause to clear – nothing was applied"
_ST_CHECK "its -C path left in no rebase" test ! -e "$(git -C "$S_C" rev-parse --absolute-git-dir)/rebase-merge"
_S250_SIDE --abort
export GIT_EDIT_ACTOR=s-main
_ST_RUN -d -y "$(git rev-parse HEAD~1)" -C="$S_C"
_ST_EQ "so its rerun there pauses at the conflict" "$RC:$(sed -n 's/^branch=//p' "$S_SF")" "2:refs/heads/main"
_ST_RUN --abort
export GIT_EDIT_ACTOR=

# Starts a drop on main and one on branch third, each at its conflict waiting `--wait=<secs>` for a
# pause on side, then frees the slot under the journal's lock, so both wake before either claims it
# – `<hold>` seconds more before letting go – the winner into `S_WIN`, the loser into `S_LOSE`
_S250_RACE () {
	# Args: <secs> <hold>
	printf 'actor=s-side\nactor_id=s-side\noperation=edit\nbranch=refs/heads/side\nworktree=/nonexistent/s250\n' > "$S_SF"
	_S250_BG s250m "$PWD" s-main -d -y "$(git rev-parse HEAD~1)" --wait=$1
	_S250_BG s250t "$TMP/s250-third" s-third -d -y "$(git rev-parse third~1)" --wait=$1
	_S250_UNTIL s250m 'Waiting up to'
	_S250_UNTIL s250t 'Waiting up to'
	# Its holder a live process outside the runs, as one they run under refuses them at once
	sleep 120 &
	S_HOLD=$!
	print -r -- "$S_HOLD -" > "${S_SF:h}/git-edit-journal.lock"
	rm -f "$S_SF"
	_S250_UNTIL s250m 'The pause cleared'
	_S250_UNTIL s250t 'The pause cleared'
	sleep $2
	rm -f "${S_SF:h}/git-edit-journal.lock"
	kill "$S_HOLD" 2>/dev/null
	S_I=0
	until [[ "$(sed -n 's/^branch=//p' "$S_SF" 2>/dev/null)" == refs/heads/(main|third) ]] || (( ++S_I > 600 )); do sleep 0.1; done
	S_WIN=${$(sed -n 's/^branch=//p' "$S_SF" 2>/dev/null)#refs/heads/}
	S_LOSE=main
	[ "$S_WIN" = main ] && S_LOSE=third
}
# Aborts the pause branch <name> holds, main's or third's
_S250_ABORT () {
	# Args: <name>
	if [ "$1" = main ]; then
		OUT=$(GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=s-main "$SELF" --abort </dev/null 2>&1)
	else
		OUT=$(cd "$TMP/s250-third" && GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=s-third "$SELF" --abort </dev/null 2>&1)
	fi
}

# Two runs waiting at their stops as the slot frees – the one losing it to the other waits on
git worktree add -q -b third "$TMP/s250-third" HEAD
_S250_RACE 60 0
_S250_UNTIL s250${S_LOSE:0:1} 'Waiting up to' 2
_ST_EQ "the run losing the freed slot waits again, still running" "$(grep -c 'Waiting up to' "$TMP/s250${S_LOSE:0:1}.out"):$(<"$TMP/s250${S_LOSE:0:1}.rc")" "2:"
_S250_ABORT "$S_WIN"
_S250_END s250${S_LOSE:0:1}
_ST_EQ "then pauses once the winner's pause clears" "$RC:$(sed -n 's/^branch=//p' "$S_SF")" "2:refs/heads/$S_LOSE"
_S250_ABORT "$S_LOSE"
# Its bound spent by then, it refuses as one that waited
_S250_RACE 3 3
_S250_END s250${S_LOSE:0:1}
_ST_EQ "one losing it with its bound spent refuses" "$RC" "1"
_ST_OUT_HAS "as having waited its whole bound" "still in flight on $S_WIN after waiting 3s at this run's stop"
_ST_OUT_HAS "pointing at a longer wait" "Wait longer with --wait=540"
_S250_ABORT "$S_WIN"
