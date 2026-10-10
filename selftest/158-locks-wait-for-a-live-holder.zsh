# The journal's lock and a `-C` path's are broken only once their holder is gone –
# its process ended, or another started since under its pid, while another user's
# counts as live – and waited on while it lives
# A landing ends its pause in that same hold of the lock, a resume holds its pause's worktree, a
# note never makes a pause anew, and a second signal waits for the `update-ref`
_ST_SCENARIO "\e[1;96m[158] locks wait for a live holder, a landing ends its pause, a resume holds its path\e[0m"
local JL_WT JL_P JL_GD JL_PID JL_B JL_C JL_REAL JL_SF JL_N
local -i JL_I
local -a JL_PIDS
# Writes `<dir>/<command>` standing in for the real one, running <script> first where <dir>/arm is
# there and <case pattern> takes the call's arguments
_JL_STAND_IN () {
	# Args: <dir> <command> <case pattern> <script>
	mkdir -p "$1"
	{
		print -r -- '#!/bin/sh'
		print -r -- "case \" \$* \" in $3) if [ -e ${(q)1}/arm ]; then $4; fi ;; esac"
		print -r -- "exec ${(q)commands[$2]} \"\$@\""
	} > "$1/$2"
	chmod +x "$1/$2"
}
mkdir -p "$TMP/jl-nap" && print -l '#!/bin/sh' 'exit 0' > "$TMP/jl-nap/sleep" && chmod +x "$TMP/jl-nap/sleep"

# An abort meeting a resume of a temporary worktree's pause – its landing held by a slow hook here –
# refuses at once, naming that run, and the resume lands whole, its lock going with its worktree –
# once, an abort went ahead without the journal's lock after 5 s
_ST_PZ_NEW jl1
_ST_PZ_C a.txt a1 "JL1 a" && _ST_PZ_C b.txt b1 "JL1 b" && _ST_PZ_C c.txt c1 "JL1 c"
_ST_RUN HEAD~1
JL_WT=$(_ST_PZ_WT)
print -r -- b2 > "${JL_WT:-$ST_NO_WT}/b.txt"
printf '#!/bin/sh\n[ "$1" = prepared ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\n[ -e "%s/jl1-arm" ] || exit 0\n: > "%s/jl1-in"\n"%s/st-hold" "%s/jl1-go"\n' \
	"$TMP" "$TMP" "$TMP" "$TMP" > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
: > "$TMP/jl1-arm"
( GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null > "$TMP/jl1.c" 2>&1; print -r -- $? > "$TMP/jl1.crc" ) &
JL_PIDS=($!)
JL_I=0; until [ -e "$TMP/jl1-in" ] || ! kill -0 "${JL_PIDS[1]}" 2>/dev/null || (( ++JL_I > 1200 )); do sleep 0.1; done
( GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --abort </dev/null > "$TMP/jl1.a" 2>&1; print -r -- $? > "$TMP/jl1.arc" ) &
JL_PIDS+=($!)
JL_I=0; until [ -e "$TMP/jl1.arc" ] || ! kill -0 "${JL_PIDS[2]}" 2>/dev/null || (( ++JL_I > 1200 )); do sleep 0.1; done
_ST_EQ "an abort while a resume of a temporary worktree's pause lands refuses at once" "$([ -e "$TMP/jl1-in" ] && echo held):$(<"$TMP/jl1.arc")" "held:1"
OUT=$(<"$TMP/jl1.a")
_ST_OUT_HAS "naming that run" 'in use by a run in flight (pid '
: > "$TMP/jl1-go"
wait "${JL_PIDS[@]}"
rm -f .git/hooks/reference-transaction "$TMP/jl1-arm"
OUT=$(<"$TMP/jl1.c")
_ST_EQ "while the resume lands" "$(<"$TMP/jl1.crc"):$(git show HEAD~1:b.txt)" "0:b2"
_ST_OUT_HAS "its worktree there to the end, its net change read from it" 'b\.txt | 2'
_ST_EQ "leaving no pause, lock or worktree record behind" "$(command ls .git | grep -c -E '^git-edit-(state|journal\.lock)'):$(command ls .git/worktrees 2>/dev/null | wc -l | tr -d ' ')" "0:0"
# It holds that lock while it lives, and one that died leaves it to the next abort, broken at once
_ST_PZ_NEW jl1b
_ST_PZ_C a.txt a1 "JL1B a" && _ST_PZ_C b.txt b1 "JL1B b" && _ST_PZ_C c.txt c1 "JL1B c"
_ST_RUN HEAD~1
JL_WT=$(_ST_PZ_WT)
print -r -- b2 > "${JL_WT:-$ST_NO_WT}/b.txt"
JL_GD=$(git -C "${JL_WT:-$ST_NO_WT}" rev-parse --absolute-git-dir)
_JL_STAND_IN "$TMP/jl1b-git" git '*" rebase "*' "mv ${(q)TMP}/jl1b-git/arm ${(q)TMP}/jl1b-in; ${(q)TMP}/st-hold ${(q)TMP}/jl1b-go; exit 1"
: > "$TMP/jl1b-git/arm"
PATH="$TMP/jl1b-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null >/dev/null 2>&1 &
JL_PID=$!
JL_I=0; until [ -e "$TMP/jl1b-in" ] || ! kill -0 $JL_PID 2>/dev/null || (( ++JL_I > 1200 )); do sleep 0.1; done
_ST_EQ "a resume holds its temporary worktree's lock while it runs" "$(cut -d' ' -f1 "$JL_GD/git-edit-run.lock" 2>/dev/null)" "$JL_PID"
_ST_RUN --abort
_ST_EQ "an abort refusing meanwhile" "$RC:$([ -f .git/git-edit-state ] && echo kept)" "1:kept"
kill -9 $JL_PID
: > "$TMP/jl1b-go"
wait $JL_PID
_ST_RUN --abort
_ST_EQ "while one after it died breaks its lock at once and cancels" "$RC:$([ -f .git/git-edit-state ] && echo kept):$([ -d "${JL_WT:-$ST_NO_WT}" ] && echo wt):$([ -e "$JL_GD" ] && echo admin)" "0:::"
# One pausing again at a later stop lets go of it, the pause kept for the next resume or abort
_ST_PZ_NEW jl1c
git config rerere.enabled false
_ST_PZ_C f.txt 1 "JL1C base" && _ST_PZ_C f.txt B "JL1C B" && JL_B=$(git rev-parse HEAD)
_ST_PZ_C f.txt C "JL1C C" && JL_C=$(git rev-parse HEAD)
_ST_PZ_C f.txt D "JL1C D"
_ST_RUN --reorder "$(git rev-parse HEAD)" "$JL_C" "$JL_B"
JL_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${JL_WT:-$ST_NO_WT}" f.txt D
_ST_RUN --continue
JL_GD=$(git -C "${JL_WT:-$ST_NO_WT}" rev-parse --absolute-git-dir)
_ST_EQ "a resume pausing again at a later stop lets go of its worktree" "$RC:$([ -n "$JL_GD" ] && [ -e "$JL_GD/git-edit-run.lock" ] && echo lock)" "2:"
_ST_RUN --abort
_ST_EQ "which the next abort takes and removes with it" "$RC:$([ -n "$JL_GD" ] && [ -e "$JL_GD" ] && echo admin)" "0:"

# A live run's journal lock – another user's here – refuses an abort once the wait runs out, that
# wait cut short by a `sleep` returning at once, while one whose run is gone is broken at once
_ST_PZ_NEW jl2
_ST_PZ_C a.txt a1 "JL2 a" && _ST_PZ_C b.txt b1 "JL2 b"
_ST_RUN HEAD~1
JL_WT=$(_ST_PZ_WT)
_PID_START 1
print -r -- "1 $REPLY" > .git/git-edit-journal.lock
PATH="$TMP/jl-nap:$PATH" _ST_RUN --abort
_ST_EQ "an abort under a live run's journal lock cancels nothing" "$RC:$([ -f .git/git-edit-state ] && echo kept):$([ -d "${JL_WT:-$ST_NO_WT}" ] && echo wt)" "1:kept:wt"
_ST_OUT_HAS "naming that run" 'journal is locked by another run (pid 1)'
sh -c 'exit 0' & JL_PID=$!
wait $JL_PID
print -r -- "$JL_PID Thu Jan 1 00:00:00 1970" > .git/git-edit-journal.lock
_ST_RUN --abort
_ST_EQ "while a gone run's lock is broken at once, the abort cancelling under it" "$RC:$([ -f .git/git-edit-state ] && echo kept):$([ -e .git/git-edit-journal.lock ] && echo lock)" "0::"

# Waiters breaking a gone run's journal lock all at once take it one at a time, every one in turn
JL_GD="$TMP/jl-g"
mkdir -p "$JL_GD"
functions _JOURNAL_LOCK _JOURNAL_UNLOCK _LOCK_STALE _HOLDER_GONE _LOCK_BREAK _LOCK_MARK_SET _PID_START > "$TMP/jl-fns.zsh" 2>/dev/null
print -r -- '
J=$1 NAME=$2 G=$3
_JOURNAL_HELD="" _LOCK_MARK=""
source "$4"
if _JOURNAL_LOCK "$J"; then
	( setopt noclobber; : > "$G/inside" ) 2>/dev/null || : > "$G/overlap"
	sleep 0.2
	command rm -f "$G/inside"
	_JOURNAL_UNLOCK "$J"
	: > "$G/held-$NAME"
fi' > "$TMP/jl-claim.zsh"
sh -c 'exit 0' & JL_PID=$!
wait $JL_PID
print -r -- "$JL_PID Thu Jan 1 00:00:00 1970" > "$JL_GD/journal.lock"
JL_PIDS=()
for JL_I in 1 2 3 4 5 6; do
	zsh "$TMP/jl-claim.zsh" "$JL_GD/journal" "r$JL_I" "$JL_GD" "$TMP/jl-fns.zsh" 2>/dev/null &
	JL_PIDS+=($!)
done
wait "${JL_PIDS[@]}"
_ST_EQ "waiters breaking a gone run's journal lock at once take it one at a time, each in turn" \
	"$(cd "$JL_GD" && print -r -- held-*(N) | wc -w | tr -d ' '):$([ -e "$JL_GD/overlap" ] && echo overlap)" "6:"
_ST_EQ "leaving no lock or second name" "$(cd "$JL_GD" && print -r -- journal.lock*(N))" ""

# A resume's landing and the end of its pause are one step – no git it runs between the two sees
# one without the other – and where its run died between them, an abort says the reorder landed
_ST_PZ_NEW jl3
_ST_PZ_C base.txt b "JL3 base" && _ST_PZ_C x.txt x "JL3 X" && JL_B=$(git rev-parse HEAD)
_ST_PZ_C y.txt y "JL3 Y" && JL_C=$(git rev-parse HEAD)
git config edit.verifyCmd "test -e '$TMP/jl3-pass'"
_ST_RUN --reorder "$JL_C" "$JL_B"
: > "$TMP/jl3-pass"
JL_SF="$PWD/.git/git-edit-state"
_JL_STAND_IN "$TMP/jl3-git" git '*' "[ -e ${(q)JL_SF} ] && grep -q ' reorder ' ${(q)PWD}/.git/git-edit-journal 2>/dev/null && : > ${(q)TMP}/jl3-seen"
: > "$TMP/jl3-git/arm"
PATH="$TMP/jl3-git:$PATH" _ST_RUN --continue
_ST_EQ "a resume ends its pause in the step that journals its landing" "$RC:$([ -e "$TMP/jl3-seen" ] && echo seen):$([ -e "$JL_SF" ] && echo paused)" "0::"
command rm -f "$TMP/jl3-pass"
_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
JL_WT=$(_ST_PZ_WT)
: > "$TMP/jl3-pass"
_JL_STAND_IN "$TMP/jl3-rm" rm "*/git-edit-state\ *" "kill -9 \$PPID; exit 0"
: > "$TMP/jl3-rm/arm"
PATH="$TMP/jl3-rm:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null >/dev/null 2>&1
JL_N=$(git rev-parse HEAD)
_ST_RUN --abort
_ST_EQ "a pause its run died on after landing is aborted, the branch kept" "$RC:$(git rev-parse HEAD):$([ -e "$JL_SF" ] && echo paused):$([ -d "${JL_WT:-$ST_NO_WT}" ] && echo wt)" "0:$JL_N::"
_ST_OUT_HAS "saying the reorder had landed, never that the branch was untouched" 'The reorder had landed already'
git config --unset edit.verifyCmd
# As does a split's, whose worktree stays at the commit it splits
_ST_PZ_NEW jl4
_ST_PZ_C a.txt a "JL4 base"
print -r -- a2 > a.txt && print -r -- n > n.txt && git add -A && git commit -qm "JL4 both"
_ST_RUN --split=HEAD
JL_WT=$(_ST_PZ_WT)
[ -d "${JL_WT:-$ST_NO_WT}" ] && command rm -f "$JL_WT/n.txt"
_JL_STAND_IN "$TMP/jl4-rm" rm "*/git-edit-state\ *" "kill -9 \$PPID; exit 0"
: > "$TMP/jl4-rm/arm"
PATH="$TMP/jl4-rm:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue --text "JL4 a" </dev/null >/dev/null 2>&1
JL_N=$(git rev-parse HEAD)
_ST_RUN --abort
_ST_EQ "a split's run dying after its landing leaves it aborted, the branch kept" "$RC:$(git log --format=%s | tr '\n' '|')" "0:JL4 both|JL4 a|JL4 base|"
_ST_OUT_HAS "saying it had landed" 'The split had landed already'

# A resume holds its `-C` path – an abort and a new run there refuse while it rebases, and it lands
_ST_PZ_NEW jl5
_ST_PZ_C a.txt a1 "JL5 a" && _ST_PZ_C b.txt b1 "JL5 b" && _ST_PZ_C c.txt c1 "JL5 c"
JL_P="$TMP/jl5-wt"
_ST_RUN -C "$JL_P" HEAD~1
print -r -- b2 > "$JL_P/b.txt"
_JL_STAND_IN "$TMP/jl5-git" git '*" rebase "*' "mv ${(q)TMP}/jl5-git/arm ${(q)TMP}/jl5-in; ${(q)TMP}/st-hold ${(q)TMP}/jl5-go"
: > "$TMP/jl5-git/arm"
( PATH="$TMP/jl5-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null > "$TMP/jl5.c" 2>&1; print -r -- $? > "$TMP/jl5.crc" ) &
JL_PID=$!
JL_I=0; until [ -e "$TMP/jl5-in" ] || ! kill -0 $JL_PID 2>/dev/null || (( ++JL_I > 1200 )); do sleep 0.1; done
_ST_RUN --abort
_ST_EQ "an abort while a resume runs in its -C path cancels nothing" "$RC:$([ -f .git/git-edit-state ] && echo kept)" "1:kept"
_ST_OUT_HAS "naming that run" 'in use by a run in flight'
_ST_RUN -C "$JL_P" HEAD
_ST_EQ "nor does a new run take that path" "$RC" "1"
: > "$TMP/jl5-go"
wait $JL_PID
_ST_EQ "while the resume lands" "$(<"$TMP/jl5.crc"):$(git show HEAD~1:b.txt)" "0:b2"
# Its exit clears no pause another run took in that path once it landed – its lock taken away here,
# as nothing else lets a run in there
_ST_PZ_NEW jl6
_ST_PZ_C a.txt a1 "JL6 a" && _ST_PZ_C b.txt b1 "JL6 b" && _ST_PZ_C c.txt c1 "JL6 c"
JL_P="$TMP/jl6-wt"
_ST_RUN -C "$JL_P" HEAD~1
print -r -- b2 > "$JL_P/b.txt"
JL_GD=$(git -C "$JL_P" rev-parse --absolute-git-dir)
_JL_STAND_IN "$TMP/jl6-git" git '*' "[ -e ${(q)PWD}/.git/git-edit-state ] || { mv ${(q)TMP}/jl6-git/arm ${(q)TMP}/jl6-in; ${(q)TMP}/st-hold ${(q)TMP}/jl6-go; }"
: > "$TMP/jl6-git/arm"
( PATH="$TMP/jl6-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null >/dev/null 2>&1 ) &
JL_PID=$!
JL_I=0; until [ -e "$TMP/jl6-in" ] || ! kill -0 $JL_PID 2>/dev/null || (( ++JL_I > 1200 )); do sleep 0.1; done
command rm -f "$JL_GD/git-edit-run.lock"
_ST_RUN -C "$JL_P" HEAD
JL_N=$RC
: > "$TMP/jl6-go"
wait $JL_PID
_ST_EQ "a pause taken in a resume's -C path once it landed outlives the resume" "$JL_N:$(sed -n 's/^target=//p' .git/git-edit-state 2>/dev/null)" "2:$(git rev-parse HEAD)"
_ST_RUN --abort

# A `-C` lock's holder another user runs is live, signaling it failing – one from before start
# times were kept naming its pid alone – and a pid taken by a process started since is not
_ST_PZ_NEW jl7
_ST_PZ_C a.txt a1 "JL7 a" && _ST_PZ_C b.txt b1 "JL7 b"
JL_P="$TMP/jl7-wt"
git worktree add -q --detach "$JL_P" HEAD
JL_GD=$(git -C "$JL_P" rev-parse --absolute-git-dir)
print -r -- 1 > "$JL_GD/git-edit-run.lock"
_ST_RUN -C "$JL_P" HEAD~1
_ST_EQ "a -C lock another user's live run holds refuses" "$RC" "1"
_ST_OUT_HAS "as in use" 'is in use by another run (pid 1)'
sleep 30 & JL_PID=$!
print -r -- "$JL_PID Thu Jan 1 00:00:00 1970" > "$JL_GD/git-edit-run.lock"
_ST_RUN -C "$JL_P" HEAD~1
_ST_EQ "one whose pid a later process took is broken" "$RC:$([ -e "$JL_GD/git-edit-run.lock" ] && echo lock)" "2:"
_ST_RUN --abort
_PID_START $JL_PID
print -r -- "$JL_PID $REPLY" > "$JL_GD/git-edit-run.lock"
_ST_RUN -C "$JL_P" HEAD~1
_ST_EQ "while that process's own refuses" "$RC" "1"
kill $JL_PID; wait $JL_PID 2>/dev/null
_ST_RUN -C "$JL_P" HEAD~1
_ST_EQ "until it ends" "$RC:$([ -e "$JL_GD/git-edit-run.lock" ] && echo lock)" "2:"
_ST_RUN --abort

# A terminal's prompt holds no `-C` path, so an abort from elsewhere ends its pause, while Enter's
# resume holds it again through its gate
_ST_PZ_NEW jl8
_ST_PZ_C a.txt a1 "JL8 a" && _ST_PZ_C b.txt b1 "JL8 b" && _ST_PZ_C c.txt c1 "JL8 c"
JL_P="$TMP/jl8-wt"
_ST_TTY_START -- -C "$JL_P" HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	_ST_RUN --abort
	JL_N=$RC
	zpty -wn ST_TTY $'\r'
fi
_ST_TTY_END
_ST_EQ "an abort from elsewhere ends a -C pause its prompt awaits" "${JL_N:-none}:$([ -f .git/git-edit-state ] && echo kept)" "0:"
_ST_OUT_HAS "Enter then finding it no longer pending" 'no longer pending'
JL_GD=$(git -C "$JL_P" rev-parse --absolute-git-dir)
git config edit.verifyCmd "if [ -e '$JL_GD/git-edit-run.lock' ]; then echo held; else echo free; fi > '$TMP/jl8-gate'"
_ST_TTY_START -- -C "$JL_P" HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	print -r -- b2 > "$JL_P/b.txt"
	zpty -wn ST_TTY $'\r'
fi
_ST_TTY_END
git config --unset edit.verifyCmd
_ST_EQ "Enter's resume holds the -C path while its gate runs" "$RC:$(<"$TMP/jl8-gate"):$(git show HEAD~1:b.txt)" "0:held:b2"

# Races an abort against a resume stalled noting its resolution, `OUT` the resume's output
_JL_NOTE_RACE () {
	# Args: <name> <which read of the pause's keys, once a resolution is noted, stalls>
	_ST_PZ_NEW "$1"
	git config rerere.enabled false
	_ST_PZ_C f.txt 1 "JL base" && _ST_PZ_C f.txt B "JL B" && JL_B=$(git rev-parse HEAD)
	_ST_PZ_C f.txt C "JL C" && JL_C=$(git rev-parse HEAD)
	_ST_PZ_C f.txt D "JL D"
	_ST_RUN --reorder "$(git rev-parse HEAD)" "$JL_C" "$JL_B"
	JL_SF="$PWD/.git/git-edit-state"
	_ST_RESOLVE "${$(_ST_PZ_WT):-$ST_NO_WT}" f.txt D
	JL_REAL=${commands[grep]}
	mkdir -p "$TMP/$1-bin"
	{
		print -r -- '#!/bin/sh'
		print -r -- "out=\$(${(q)JL_REAL} \"\$@\"); rc=\$?"
		print -r -- "case \"\$*\" in *'orig_head|target|nonce)='*)"
		print -r -- "	if ${(q)JL_REAL} -q '^resolved=' ${(q)JL_SF} 2>/dev/null; then"
		print -r -- "		echo x >> ${(q)TMP}/$1-count"
		print -r -- "		[ \$(wc -l < ${(q)TMP}/$1-count) -eq $2 ] && { : > ${(q)TMP}/$1-in; ${(q)TMP}/st-hold ${(q)TMP}/$1-go; }"
		print -r -- '	fi ;;'
		print -r -- 'esac'
		print -r -- '[ -n "$out" ] && printf "%s\n" "$out"'
		print -r -- 'exit $rc'
	} > "$TMP/$1-bin/grep"
	chmod +x "$TMP/$1-bin/grep"
	# The abort's wait for the journal's lock seen as it happens – a retry's `sleep` while another
	# process holds it, as "Aborting" prints a few forks before the lock is tried, and a slow abort
	# let the resume land past its last check
	mkdir -p "$TMP/$1-abin"
	{
		print -r -- '#!/bin/sh'
		print -r -- "if [ \"\$1\" = 0.1 ] && [ -e ${(q)PWD}/.git/git-edit-journal.lock ]; then"
		print -r -- "	read -r H _ 2>/dev/null < ${(q)PWD}/.git/git-edit-journal.lock; [ \"\$H\" = \"\$PPID\" ] || : > ${(q)TMP}/$1-waiting"
		print -r -- 'fi'
		print -r -- "exec ${(q)commands[sleep]} \"\$@\""
	} > "$TMP/$1-abin/sleep"
	chmod +x "$TMP/$1-abin/sleep"
	( PATH="$TMP/$1-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null > "$TMP/$1.c" 2>&1; print -r -- $? > "$TMP/$1.crc" ) &
	JL_PID=$!
	JL_I=0; until [ -e "$TMP/$1-in" ] || ! kill -0 $JL_PID 2>/dev/null || (( ++JL_I > 1200 )); do sleep 0.1; done
	# The resume's worktree lock taken away, as nothing else lets an abort in while it lives – and one
	# stalled inside a note holds the journal's, so the abort waits there, under way, for the release
	command rm -f "$(git -C "$(_ST_PZ_WT)" rev-parse --absolute-git-dir 2>/dev/null)/git-edit-run.lock"
	( PATH="$TMP/$1-abin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --abort </dev/null > "$TMP/$1.a" 2>&1 ) &
	JL_PIDS=($!)
	JL_I=0; until [ -e "$TMP/$1-waiting" ] || ! kill -0 "${JL_PIDS[1]}" 2>/dev/null || (( ++JL_I > 1200 )); do sleep 0.1; done
	: > "$TMP/$1-go"
	wait $JL_PID "${JL_PIDS[1]}"
	OUT=$(<"$TMP/$1.c")
}
# A note goes into its pause under the journal's lock and onto the file there only – an abort
# ending the pause around one leaves the slot free, the resume refusing rather than leave a
# conflict for a pause gone, or a stub holding no operation where it was
_JL_NOTE_RACE jl9 1
_ST_EQ "a resume whose pause an abort ended as it named it refuses" "$([ -e "$TMP/jl9-in" ] && echo stalled):$(<"$TMP/jl9.crc"):$([ -e "$JL_SF" ] && echo slot)" "stalled:1:"
_ST_OUT_HAS "saying the pause was ended" 'ended by another run meanwhile'
_JL_NOTE_RACE jl10 2
_ST_EQ "one ending it before its notes makes no pause anew" "$([ -e "$TMP/jl10-in" ] && echo stalled):$([ -e "$JL_SF" ] && echo slot)" "stalled:"
_ST_RUN -d -y HEAD
_ST_EQ "so the next run runs" "$RC" "0"
_JL_NOTE_RACE jl12 3
_ST_EQ "nor does one waiting out a note it meets under way" "$([ -e "$TMP/jl12-in" ] && echo stalled):$([ -e "$JL_SF" ] && echo slot)" "stalled:"

# A second signal while the `update-ref` runs waits for it, so the move is journaled, the pause it
# landed ended and the trailer names it – once, it stopped the run and the move landed unjournaled
_ST_PZ_NEW jl11
_ST_PZ_C a.txt a1 "JL11 a" && _ST_PZ_C b.txt b1 "JL11 b" && _ST_PZ_C c.txt c1 "JL11 c"
_ST_RUN HEAD~1
JL_WT=$(_ST_PZ_WT)
print -r -- b2 > "${JL_WT:-$ST_NO_WT}/b.txt"
printf '#!/bin/sh\n[ "$1" = prepared ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\n: > "%s/jl11-in"\n"%s/st-hold" "%s/jl11-go"\n' \
	"$TMP" "$TMP" "$TMP" > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null > "$TMP/jl11.c" 2>&1 &
JL_PID=$!
JL_I=0; until [ -e "$TMP/jl11-in" ] || ! kill -0 $JL_PID 2>/dev/null || (( ++JL_I > 1200 )); do sleep 0.1; done
kill -TERM $JL_PID
# Apart, so the second is no repeat the first one's delivery absorbs
sleep 0.3
kill -TERM $JL_PID
: > "$TMP/jl11-go"
wait $JL_PID
JL_N=$?
rm -f .git/hooks/reference-transaction
OUT=$(<"$TMP/jl11.c")
_ST_EQ "a second signal while update-ref runs waits for it, journaling the move" "$JL_N:$(grep -c ' edit ' .git/git-edit-journal 2>/dev/null)" "143:1"
_ST_OUT_HAS "its trailer naming the move" 'stopped by SIGTERM after refs/heads/main moved'
_ST_EQ "ending the pause it landed, its worktree gone, no lock left" "$([ -e .git/git-edit-state ] && echo paused):$([ -d "${JL_WT:-$ST_NO_WT}" ] && echo wt):$(command ls .git | grep -c -E '^git-edit-journal\.lock')" "::0"
_ST_RUN --undo
_ST_EQ "and --undo takes it back" "$RC:$(git show HEAD~1:b.txt)" "0:b1"
cd "$TMP/repo"
