# Runs wait out a pause, and renamed paths name their old one:
# • A run another caller's pause blocks waits for it to clear up to `--wait` – 90 s outside the
#   suite, none in it – then runs, or refuses naming whose pause and how long it waited
# • It never waits on its own pause, nor at a check made once it holds a path
# • A signal while waiting ends it with nothing taken
# • A staged path renamed after the target names its old name and the edit pause that works there
# • The documented grep keeps the tree lines
_ST_SCENARIO "\e[1;96m[180] a run waits out another's pause, a renamed path names its old name\e[0m"
local WT_HEAD WT_TIP WT_WTD WT_SF WT_N WT_RE WT_MAN WT_OLD WT_REN
local -i WT_T
# Starts `git edit <arg>...` in the background, outside the suite's no-wait pin, under the env
# assignments before `--` – its output, pid and status into `$TMP/<name>.out`, `.pid` and `.rc`
_W180_BG () {
	# Args: <name> [<name>=<value>...] `--` <arg>...
	local N=$1
	local -a ENVS=()
	shift
	while [ $# -gt 0 ] && [ "$1" != "--" ]; do ENVS+=("$1"); shift; done
	shift
	rm -f "$TMP/$N.out" "$TMP/$N.pid" "$TMP/$N.rc"
	( env -u GIT_EDIT_SELFTEST_DEPTH GIT_EDIT_NO_AUTO_OPEN=1 "${ENVS[@]}" "$SELF" "$@" </dev/null >"$TMP/$N.out" 2>&1 &
	  print -r -- $! >"$TMP/$N.pid"; wait $!; print -r -- $? >"$TMP/$N.rc" ) &
}
# Waits for <text> in the output of background run <name> – fails where that run ends or 60 s pass
_W180_UNTIL () {
	# Args: <name> <text>
	local -i I=0
	until LC_ALL=C grep -qF -e "$2" "$TMP/$1.out" 2>/dev/null; do
		{ [ -s "$TMP/$1.rc" ] || (( ++I > 600 )); } && return 1
		sleep 0.1
	done
}
# Waits for background run <name> to end, its output and status into `OUT` and `RC` –
# at most 60 s, a run still going then stopped
_W180_END () {
	# Args: <name>
	local -i I=0
	until [ -s "$TMP/$1.rc" ] || (( ++I > 600 )); do sleep 0.1; done
	if [ ! -s "$TMP/$1.rc" ]; then
		kill -TERM "$(<"$TMP/$1.pid")" 2>/dev/null
		I=0; until [ -s "$TMP/$1.rc" ] || (( ++I > 100 )); do sleep 0.1; done
	fi
	OUT=$(<"$TMP/$1.out")
	RC=$(<"$TMP/$1.rc")
}
# Pauses an edit of <commit> under label <label>, as a parallel session's run would
_W180_PAUSE () {
	# Args: <label> <commit>
	export GIT_EDIT_ACTOR=$1
	_ST_RUN "$2"
	export GIT_EDIT_ACTOR=
}

_ST_PZ_NEW w180
_ST_PZ_C a.txt a1 "WT a" && _ST_PZ_C b.txt b1 "WT b" && _ST_PZ_C c.txt c1 "WT c"
WT_HEAD=$(git rev-parse HEAD)
_W180_PAUSE w-peer HEAD~1
_ST_EQ "a peer's edit pause stands" "$RC" "2"
WT_N=$(git worktree list | wc -l | tr -d ' ')

# The bound runs out: the run waits it whole, then refuses,
# naming whose pause and how long it waited
WT_T=$EPOCHSECONDS
_W180_BG w1 GIT_EDIT_ACTOR=w-self -- -M --text="WT c reworded" --wait=2 HEAD
_W180_END w1
_ST_EQ "a run another caller's pause blocks waits out --wait, then refuses, nothing moved" "$RC:$(( EPOCHSECONDS - WT_T >= 2 )):$(git rev-parse HEAD)" "1:1:$WT_HEAD"
_ST_OUT_HAS "saying whose pause it waits on, its operation and how long it has stood" "^Waiting up to 2s for w-peer's paused edit [0-9a-f]\{7\} on main (paused [0-9]*s ago) to clear – re-checking every 2s, then running"
_ST_OUT_HAS "its refusal naming the owner and how long it waited" "still in flight on main after waiting [2-9]s, paused for its resolution – w-peer's – nothing ran"
_ST_OUT_HAS "and the longer form" "Wait longer with --wait=600 – run in the background, or in the foreground with a 10-minute call timeout"
_ST_OUT_LACKS "never saying it cleared" 'The pause cleared'
_ST_EQ "taking no worktree" "$(git worktree list | wc -l | tr -d ' ')" "$WT_N"

# The pause clears – its landing moving the branch – and the run goes on from the tip that left
_W180_BG w2 GIT_EDIT_ACTOR=w-self -- -M --text="WT c reworded" --wait 30 HEAD
_W180_UNTIL w2 "Waiting up to 30s"
_ST_EQ "a bound given apart waits too" "$?" "0"
WT_WTD=$(_ST_PZ_WT)
print -r -- b2 > "${WT_WTD:-$ST_NO_WT}/b.txt"
export GIT_EDIT_ACTOR=w-peer
_ST_RUN --continue
export GIT_EDIT_ACTOR=
WT_TIP=$(git rev-parse HEAD)
_ST_EQ "the peer lands meanwhile" "$RC:$(git show HEAD~1:b.txt)" "0:b2"
_W180_END w2
_ST_EQ "and the run lands once the pause clears, on the tip that landing left" "$RC:$(git log -1 --format=%s HEAD):$(git rev-parse HEAD~1)" "0:WT c reworded:$(git rev-parse "$WT_TIP~1")"
_ST_OUT_HAS "saying so" '^The pause cleared after [0-9]*s – running\.'
_ST_OUT_HAS "its trailer moving the branch from that tip" "^git-edit: ok – .*main moved $WT_TIP → "

# Outside the suite the bound is 90 s by default
_W180_PAUSE w-peer HEAD~1
_W180_BG w3 GIT_EDIT_ACTOR=w-self -- -M --text="WT c default" HEAD
_W180_UNTIL w3 "Waiting up to 90s"
_ST_EQ "outside the suite a run waits 90 s by default" "$?" "0"
export GIT_EDIT_ACTOR=w-peer
_ST_RUN --abort
export GIT_EDIT_ACTOR=
_W180_END w3
_ST_EQ "running once the pause is aborted" "$RC:$(git log -1 --format=%s HEAD)" "0:WT c default"

# The suite pins it to none, and --wait=0 refuses at once outside it, as before
_W180_PAUSE w-peer HEAD~1
WT_HEAD=$(git rev-parse HEAD)
_ST_RUN -M --text="WT c pinned" HEAD
_ST_EQ "under the suite a run refuses at once" "$RC" "1"
_ST_OUT_HAS "as before, naming the owner" "Another git-edit operation is in flight on main, paused for its resolution – w-peer's"
_ST_OUT_LACKS "without waiting" 'Waiting up to'
_W180_BG w5 GIT_EDIT_ACTOR=w-self -- -M --text="WT c zero" --wait=0 HEAD
_W180_END w5
_ST_EQ "--wait=0 refuses at once" "$RC:$(git rev-parse HEAD)" "1:$WT_HEAD"
_ST_OUT_HAS "as before" "if another session's, wait for it ('git edit --status' shows it)"
_ST_OUT_LACKS "never waiting" 'Waiting up to'

# The caller's own pause is never waited for – the same label, or both unlabeled – while a labeled
# caller waits on an unlabeled one
WT_T=$EPOCHSECONDS
_W180_BG w6 GIT_EDIT_ACTOR=w-peer -- -M --text="WT c own" --wait=30 HEAD
_W180_END w6
_ST_EQ "a pause under the caller's own label refuses at once" "$RC:$(( EPOCHSECONDS - WT_T < 15 ))" "1:1"
_ST_OUT_HAS "naming its continue and abort" "If it is yours, 'git edit --continue' or 'git edit --abort' it"
_ST_OUT_LACKS "never waited for" 'Waiting up to'
export GIT_EDIT_ACTOR=w-peer
_ST_RUN --abort
export GIT_EDIT_ACTOR=
_W180_PAUSE "" HEAD~1
WT_T=$EPOCHSECONDS
_W180_BG w6b -- -M --text="WT c own" --wait=30 HEAD
_W180_END w6b
_ST_EQ "an unlabeled caller's on an unlabeled pause refuses at once" "$RC:$(( EPOCHSECONDS - WT_T < 15 ))" "1:1"
_ST_OUT_LACKS "never waiting" 'Waiting up to'
_W180_BG w6c GIT_EDIT_ACTOR=w-self -- -M --text="WT c own" --wait=1 HEAD
_W180_END w6c
_ST_EQ "a labeled caller waits on an unlabeled pause" "$RC" "1"
_ST_OUT_HAS "naming it as such" "^Waiting up to 1s for an unlabeled caller's paused edit"
_ST_RUN --abort

# A pause another session takes meanwhile is waited out within the same bound, said once
_W180_PAUSE w-peer HEAD~1
_W180_BG w7 GIT_EDIT_ACTOR=w-self -- -M --text="WT c taken" --wait=30 HEAD
_W180_UNTIL w7 "Waiting up to 30s"
WT_SF="$(git rev-parse --path-format=absolute --git-common-dir)/git-edit-state"
# The slot changes hands in one move, as a pause taken between two of the run's looks
sed 's/^actor=.*/actor=w-other/;s/^actor_id=.*/actor_id=w-other/' "$WT_SF" > "$WT_SF.w180" && mv -f "$WT_SF.w180" "$WT_SF"
# An observation window – nothing to poll for while the run is meant to go on waiting
sleep 3
_ST_EQ "a pause another session takes meanwhile is waited out too" "$([ -s "$TMP/w7.rc" ] || echo waiting)" "waiting"
export GIT_EDIT_ACTOR=w-other
_ST_RUN --abort
export GIT_EDIT_ACTOR=
_W180_END w7
_ST_EQ "the run going on once that one clears" "$RC:$(git log -1 --format=%s HEAD)" "0:WT c taken"
_ST_EQ "having said it waits once" "$(grep -c 'Waiting up to' <<<"$OUT")" "1"

# A signal while waiting ends the run at once, nothing taken
_W180_PAUSE w-peer HEAD~1
WT_HEAD=$(git rev-parse HEAD)
WT_N=$(git worktree list | wc -l | tr -d ' ')
_W180_BG w8 GIT_EDIT_ACTOR=w-self -- -M --text="WT c signalled" --wait=60 HEAD
_W180_UNTIL w8 "Waiting up to 60s"
WT_T=$EPOCHSECONDS
kill -TERM "$(<"$TMP/w8.pid")" 2>/dev/null
_W180_END w8
_ST_EQ "TERM while waiting ends the run at once, nothing moved" "$RC:$(( EPOCHSECONDS - WT_T < 10 )):$(git rev-parse HEAD)" "143:1:$WT_HEAD"
_ST_OUT_HAS "with the usual trailer" "^git-edit: error – stopped by SIGTERM while waiting for w-peer's pause to clear – nothing ran"
_ST_EQ "no worktree taken, the peer's pause kept" "$(git worktree list | wc -l | tr -d ' '):$([ -f "$WT_SF" ] && echo paused)" "$WT_N:paused"
export GIT_EDIT_ACTOR=w-peer
_ST_RUN --abort
export GIT_EDIT_ACTOR=

# A pause recorded once the first check passed refuses at the check made holding the -C path, at
# once – waiting there would block that path for others
mkdir -p "$TMP/w180-git"
printf '#!/bin/sh\ncase " $* " in *" worktree add "*) if [ -e %s/arm ]; then mv %s/arm %s/in; %s/st-hold %s/go; fi ;; esac\nexec %s "$@"\n' \
	"${(q)TMP}/w180-git" "${(q)TMP}/w180-git" "${(q)TMP}/w180-git" "${(q)TMP}" "${(q)TMP}/w180-git" "${(q)commands[git]}" > "$TMP/w180-git/git"
chmod +x "$TMP/w180-git/git"
: > "$TMP/w180-git/arm"
_W180_BG w9 PATH="$TMP/w180-git:$PATH" GIT_EDIT_ACTOR=w-self -- --dir="$TMP/w180-dir" -d --wait=30 HEAD
WT_T=0; until [ -e "$TMP/w180-git/in" ] || [ -s "$TMP/w9.rc" ] || (( ++WT_T > 600 )); do sleep 0.1; done
_W180_PAUSE w-peer HEAD~1
WT_T=$EPOCHSECONDS
: > "$TMP/w180-git/go"
_W180_END w9
_ST_EQ "a pause recorded past the first check refuses once the path is held, at once" "$RC:$(( EPOCHSECONDS - WT_T < 15 ))" "1:1"
_ST_OUT_HAS "as in flight, naming the owner" "Another git-edit operation is in flight on main, paused for its resolution – w-peer's"
_ST_OUT_LACKS "never waiting there" 'Waiting up to'
export GIT_EDIT_ACTOR=w-peer
_ST_RUN --abort
export GIT_EDIT_ACTOR=

# The bound takes the value-flag forms – required, a whole number, given once – and none beside a
# resume or a standalone command, while with no pause in the way a run waits for nothing
_ST_RUN -M --text="WT c plain" --wait=5 HEAD
_ST_EQ "with no pause a run with --wait runs at once" "$RC:$(git log -1 --format=%s HEAD)" "0:WT c plain"
_ST_OUT_LACKS "saying nothing of waiting" 'Waiting up to'
_ST_RUN -M --text="WT x" HEAD --wait
_ST_EQ "--wait needs its value" "$RC" "1"
_ST_OUT_HAS "saying so" 'wait needs a value'
_ST_RUN -M --text="WT x" --wait --yes HEAD
_ST_OUT_HAS "a flag in its value's place refuses" '--wait takes a value, and got the flag --yes'
_ST_RUN -M --text="WT x" --wait=-1 HEAD
_ST_OUT_HAS "a negative bound refuses" '--wait takes a whole number of seconds (--wait=<secs>, 0 refusing at once), and got: -1'
_ST_RUN -M --text="WT x" --wait=soon HEAD
_ST_OUT_HAS "so does a word" 'and got: soon'
_ST_RUN -M --text="WT x" --wait=1 --wait=2 HEAD
_ST_OUT_HAS "a repeat refuses" '--wait given twice'
_ST_RUN -M --text="WT x" --waitfor=2 HEAD
_ST_OUT_HAS "a longer spelling is no --wait" 'Unknown option: --waitfor=2'
_W180_PAUSE w-peer HEAD~1
export GIT_EDIT_ACTOR=w-peer
_ST_RUN --abort --wait=5
_ST_EQ "beside --abort it refuses, the pause kept" "$RC:$([ -f "$WT_SF" ] && echo paused)" "1:paused"
_ST_OUT_HAS "saying the resume acts on the pause itself" '--abort acts on the pause itself, so nothing was done'
_ST_RUN --continue --wait 5
_ST_OUT_HAS "beside --continue too" '--continue acts on the pause itself'
_ST_RUN --skip --wait=5
_ST_OUT_HAS "and --skip" '--skip acts on the pause itself'
_ST_RUN --abort
export GIT_EDIT_ACTOR=
_ST_RUN --status --wait=5
_ST_EQ "beside a standalone command it refuses" "$RC" "1"
_ST_OUT_HAS "naming it" '--status never waits for a pause, so --wait has nothing to bound'

# A staged path renamed after the target, which the range-wide pairing misses as later edits outgrew
# the old content, names its old name and the edit pause that changes it there
_ST_PZ_NEW w180r
print -l r{01..20} > old.txt && git add old.txt && git commit -qm "WR target"
WT_OLD=$(git rev-parse HEAD)
git mv old.txt new.txt && git commit -qm "WR rename"
WT_REN=$(git rev-parse --short=7 HEAD)
print -l x{01..14} r{15..20} > new.txt && git commit -qam "WR rewrite"
print -r -- f1 > fresh.txt && git add fresh.txt && git commit -qm "WR fresh"
print -l x{01..14} r{15..19} r20-folded > new.txt && git add new.txt
_ST_RUN --amend-into="$WT_OLD" -- new.txt
_ST_EQ "a staged path renamed after the target refuses" "$RC" "1"
_ST_OUT_HAS "naming its old name there and the commit renaming it" "new\.txt – was old\.txt at ${WT_OLD:0:7}, renamed in $WT_REN (WR rename)"
_ST_OUT_HAS "as no file of that name at the target" 'do not exist at [0-9a-f]\{7\} by that name – renamed in a later commit'
_ST_OUT_HAS "naming the edit pause that changes it there" "Change it under its old name in an edit pause: 'git edit ${WT_OLD:0:7}', make the change to the old path in the worktree the pause names, then 'git edit --continue'"
_ST_OUT_LACKS "not the introducing commit's remedy" 'Fold into the introducing commit'
# Where the replay's merge pairs no renames, the change made at the old name would meet the rename
# as a modify/delete – it arrives there as an add, as before
git config merge.renames false
_ST_RUN --amend-into="$WT_OLD" -- new.txt
_ST_OUT_HAS "where the merge pairs no renames it arrives in that commit, as before" "new\.txt – arrives in $WT_REN (WR rename)"
_ST_OUT_LACKS "with no edit pause offered" 'under its old name'
git config --unset merge.renames
# Nor for a removal, which meets the rename as a rename/delete
git rm -q --cached new.txt
_ST_RUN --amend-into="$WT_OLD" -- new.txt
_ST_OUT_HAS "a removal of the renamed path keeps its refusal" "new\.txt – arrives in $WT_REN (WR rename), bringing back what the fold removes"
_ST_OUT_LACKS "with no edit pause offered" 'under its old name'
# The remedy as printed
git restore --staged -- new.txt && git checkout -- new.txt
_ST_RUN "${WT_OLD:0:7}"
WT_WTD=$(_ST_PZ_WT)
print -l r{01..19} r20-folded > "${WT_WTD:-$ST_NO_WT}/old.txt"
_ST_RUN --continue
_ST_EQ "which lands, carried through the rename and rewrite" "$RC:$(git show HEAD~3:old.txt | tail -1):$(git show HEAD:new.txt | tail -1)" "0:r20-folded:r20-folded"
git reset -q --hard
# A path truly added later keeps the introducing commit's remedy
print -r -- f2 > fresh.txt && git add fresh.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~3)" -- fresh.txt
_ST_OUT_HAS "a path added later still names where it arrives" 'fresh\.txt – arrives in [0-9a-f]\{7\} (WR fresh)'
_ST_OUT_HAS "and the fold into it" 'Fold into the introducing commit or later'
_ST_OUT_LACKS "no edit pause offered" 'under its old name'
git restore --staged -- fresh.txt && git checkout -- fresh.txt
# A rename the range-wide pairing finds still carries the fold
print -r -- p1 > pair.txt && git add pair.txt && git commit -qm "WR pair target"
WT_OLD=$(git rev-parse HEAD)
git mv pair.txt paired.txt && git commit -qm "WR pair rename"
print -r -- p2 > paired.txt && git add paired.txt
_ST_RUN --amend-into="$WT_OLD" -- paired.txt
_ST_EQ "a rename the range pairs still folds" "$RC:$(git show HEAD~1:pair.txt)" "0:p2"
_ST_OUT_HAS "noting it" 'paired\.txt is pair\.txt at [0-9a-f]\{7\} – git.s rename detection carries the fold there'

# The documented filter keeps the tree-identity lines a run prints
WT_MAN="${SELF:h}/man/man1/git-edit.1"
[ -f "$WT_MAN" ] || WT_MAN="${SELF:h}/../share/man/man1/git-edit.1"
# Its roff unescaped, a `\ ` being a space kept on one line
WT_RE=$(sed -n "s/.*grep -E '\(\^[^']*\)'.*/\1/p" "$WT_MAN" | head -1 | sed 's/\\ / /g')
_ST_PZ_C q.txt q1 "WR q" && _ST_PZ_C s.txt s1 "WR s"
_ST_RUN --reorder HEAD HEAD~1
_ST_EQ "a reorder lands" "$RC" "0"
_ST_EQ "the man page's grep keeps its tree line and trailer" "$(LC_ALL=C grep -cE -e "${WT_RE:-^$}" <<<"$OUT" ):$(LC_ALL=C grep -E -e "${WT_RE:-^$}" <<<"$OUT" | grep -c '^Tip tree identical')" "2:1"
cd "$TMP/repo"
