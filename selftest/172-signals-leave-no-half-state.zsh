# A signal sent to git-edit's whole process group, as a terminal's Ctrl-C is, ends the git call it
# waits on too – once the branch moved, that call's cut-short answer read as "nothing changed" or
# "nothing to journal", an abort stopped past its clear left the worktree without its pause, and a
# signal before the traps, after the trailer, at a prompt or inside a settle ended the run on a
# status or state that contradicted what it said
_ST_SCENARIO "\e[1;96m[172] signals leave no half state, and the code says what the trailer does\e[0m"
local SG_DIR="$TMP/sg" SG_BIN="$TMP/sg-bin" SG_B SG_WT SG_GROUP=""
mkdir -p "$SG_DIR" "$SG_BIN"
# A `git` holding one call: the first matching `SG_MATCH` once `$SG_DIR/armed` is there – made by
# the first call matching `SG_AFTER` – or, with `SG_OUT`, once that output holds a trailer, failing
# it instead under `SG_FAIL` – and a `sleep` holding a settle's nap where `$SG_DIR/nap` is
{
	print -r -- '#!/bin/sh'
	print -r -- 'D=$SG_DIR'
	print -r -- 'if [ -n "$D" ] && [ -e "$D/armed" ] && [ ! -e "$D/reached" ]; then'
	print -r -- '	case " $* " in *"$SG_MATCH"*)'
	print -r -- '		if [ -z "$SG_OUT" ] || grep -q "^git-edit: " "$SG_OUT"; then'
	print -r -- '			: > "$D/reached"'
	print -r -- '			[ -n "$SG_FAIL" ] && exit 128'
	print -r -- "			${(q)TMP}/st-hold \"\$D/go\""
	print -r -- '		fi ;;'
	print -r -- '	esac'
	print -r -- 'fi'
	print -r -- 'if [ -n "$D" ] && [ -n "$SG_AFTER" ] && [ ! -e "$D/armed" ]; then'
	print -r -- "	case \" \$* \" in *\"\$SG_AFTER\"*) ${(q)commands[git]} \"\$@\"; rc=\$?; : > \"\$D/armed\"; exit \$rc ;; esac"
	print -r -- 'fi'
	print -r -- "exec ${(q)commands[git]} \"\$@\""
} > "$SG_BIN/git"
{
	print -r -- '#!/bin/sh'
	print -r -- 'if [ "$1" = 0.05 ] && [ -n "$SG_DIR" ] && [ -e "$SG_DIR/nap" ] && { [ -z "$SG_OUT" ] || grep -q "^git-edit: " "$SG_OUT"; }; then'
	print -r -- "	rm -f \"\$SG_DIR/nap\"; : > \"\$SG_DIR/reached\"; ${(q)TMP}/st-hold \"\$SG_DIR/go\"; exit 0"
	print -r -- 'fi'
	print -r -- "exec ${(q)commands[sleep]} \"\$@\""
} > "$SG_BIN/sleep"
chmod +x "$SG_BIN/git" "$SG_BIN/sleep"
# A process group of its own, as a terminal gives the command it runs – `perl` makes one
(( ${+commands[perl]} )) && SG_GROUP=1
# Runs git edit <arg>... under the stand-ins, arming at once where <after> is `-`, and once its
# call is held sends <signal> as <how> – to git-edit alone, twice 0.3 s apart, to its whole
# process group, or not at all – leaving `OUT` and `RC`
_SG_GO () {
	# Args: <pid|twice|group|none> <signal> <after|-> <match> <arg>...
	local HOW=$1 SIG=$2 AFTER=$3 MATCH=$4 P
	local -i I=0
	shift 4
	rm -f "$SG_DIR/armed" "$SG_DIR/reached" "$SG_DIR/go" "$TMP/sg.out"
	[ "$AFTER" = - ] && { : > "$SG_DIR/armed"; AFTER=""; }
	if [ "$HOW" = group ]; then
		env PATH="$SG_BIN:$PATH" SG_DIR="$SG_DIR" SG_AFTER="$AFTER" SG_MATCH="$MATCH" GIT_EDIT_NO_AUTO_OPEN=1 \
			perl -e 'setpgrp(0, 0); exec @ARGV' "$SELF" "$@" </dev/null >"$TMP/sg.out" 2>&1 &
	else
		env PATH="$SG_BIN:$PATH" SG_DIR="$SG_DIR" SG_AFTER="$AFTER" SG_MATCH="$MATCH" GIT_EDIT_NO_AUTO_OPEN=1 \
			"$SELF" "$@" </dev/null >"$TMP/sg.out" 2>&1 &
	fi
	P=$!
	until [ -e "$SG_DIR/reached" ] || ! kill -0 $P 2>/dev/null || (( ++I > 600 )); do sleep 0.05; done
	case $HOW in
		group) kill -$SIG -- -$P 2>/dev/null ;;
		twice) kill -$SIG $P 2>/dev/null; sleep 0.3; kill -$SIG $P 2>/dev/null ;;
		pid)   kill -$SIG $P 2>/dev/null ;;
	esac
	: > "$SG_DIR/go"
	wait $P
	RC=$?
	OUT=$(<"$TMP/sg.out")
	unset SG_OUT SG_FAIL
}
# Makes repo <name> with `f1.txt`…`f5.txt`, a commit each
_SG_REPO () {
	# Args: <name>
	local I
	_ST_PZ_NEW "$1"
	for I in 1 2 3 4 5; do _ST_PZ_C "f$I.txt" "line $I" "SG c$I"; done
}
# Makes repo <name> paused on a drop's conflict
_SG_PAUSED () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	_ST_PZ_C g.txt a "SG g1" && _ST_PZ_C g.txt b "SG g2" && _ST_PZ_C g.txt c "SG g3"
	_ST_RUN -d -y HEAD~1
}

# One before the traps were set ended the run with no trailer at all
_SG_GO pid TERM - " config --get i18n.commitEncoding " --status
_ST_EQ "a signal at the first git call stops the run" "$RC" "143"
_ST_OUT_HAS "with a trailer naming it" '^git-edit: error – stopped by SIGTERM$'

if [ -n "$SG_GROUP" ]; then
	# Ctrl-C before the move stops the run, nothing moved and nothing left
	_SG_REPO sg1
	SG_B=$(git rev-parse HEAD)
	_SG_GO group INT - " rebase " -d -y HEAD~1
	_ST_EQ "a group signal before the move stops the drop, nothing moved or left" "$RC:$(git rev-parse HEAD):$(git worktree list | wc -l | tr -d ' ')" "130:$SG_B:1"
	# Ending the `update-ref` itself, it read as git refusing the move
	_SG_GO group TERM - "update-ref -m git edit: drop" -d -y HEAD~1
	_ST_EQ "one ending the update-ref stops the run as that signal" "$RC:$(git rev-parse HEAD)" "143:$SG_B"
	_ST_OUT_HAS "saying so, not that git refused" '^git-edit: error – stopped by SIGTERM$'
	# Once the branch moved, the git call it ended named no journal – the move went unjournaled
	_ST_RUN -M --text "SG c1 reworded" HEAD~4
	SG_B=$(git rev-parse HEAD)
	_SG_GO group TERM update-ref "" -d -y HEAD~1
	_ST_EQ "a group signal once the branch moved lets the drop finish" "$RC:$(git log --format=%s | grep -c 'SG c4')" "0:0"
	_ST_OUT_HAS "naming the signal above the trailer" '^SIGTERM arrived once the branch had moved'
	_ST_EQ "the move journaled" "$(tail -1 .git/git-edit-journal | cut -d' ' -f5)" "drop"
	_ST_RUN --undo
	_ST_EQ "so --undo takes back that drop alone" "$RC:$(git rev-parse HEAD)" "0:$SG_B"
	# The index re-sync read a cut-short diff as "nothing changed", leaving the dropped file staged
	_SG_REPO sg2
	_SG_GO group TERM update-ref "--name-only --no-renames" -d -y HEAD~1
	_ST_EQ "a group signal at the re-sync's diff leaves no entry stranded" "$RC:$(git diff --cached --name-only HEAD)" "0:"
	_ST_OUT_HAS "the re-sync named" 'Index entries re-synced to the new tip: f4.txt'
	_ST_OUT_LACKS "and the checkout not called untouched" 'left as it was'
	# As after a commit, whose file stayed staged at its old blob
	print -r -- "line 1 more" > f1.txt
	_SG_GO group TERM update-ref "--name-only --no-renames" --commit --text "SG c6" -- f1.txt
	_ST_EQ "nor after a commit" "$RC:$(git log -1 --format=%s):$(git diff --cached --name-only HEAD)" "0:SG c6:"
	# The tip the trailer names, read after the move, came back empty
	_SG_REPO sg3
	SG_B=$(git rev-parse HEAD)
	_SG_GO group TERM update-ref " rev-parse refs/heads/main " -d -y HEAD~1
	_ST_OUT_HAS "a group signal at the trailer's read still names the new tip" "^git-edit: ok – refs/heads/main moved $SG_B → $(git rev-parse HEAD)\$"
	# An abort ended past its clear left the worktree registered, the pause gone
	_SG_PAUSED sg4
	SG_WT=$(_ST_PZ_WT)
	_SG_GO group TERM - " rebase --abort " --abort
	_ST_EQ "a group signal once an abort cleared the pause lets it finish" "$RC:$([ -e .git/git-edit-state ] && echo state):$(git worktree list | wc -l | tr -d ' '):$([ -d "${SG_WT:-$ST_NO_WT}" ] && echo wt)" "0::1:"
	_ST_OUT_HAS "saying so above its trailer" '^SIGTERM arrived once the pause was cleared'
else
	ECHO_E "  \e[1;33mNOTE\e[0m no perl to give a run a process group of its own – its group signals go untried"
fi

# A second signal once the undo moved the branch named no move, read as an undo that did nothing
_SG_REPO sg5
_ST_RUN -M --text "SG c1 reworded" HEAD~4
_ST_RUN -M --text "SG c3 reworded" HEAD~2
SG_B=$(git rev-parse HEAD)
_SG_GO twice TERM update-ref "" --undo
_ST_EQ "a second signal stops an undo past its move" "$RC" "143"
_ST_OUT_HAS "its trailer naming the move" "^git-edit: error – stopped by SIGTERM after refs/heads/main moved $SG_B → $(git rev-parse HEAD)\$"
_ST_EQ "which the journal holds" "$(tail -1 .git/git-edit-journal | cut -d' ' -f5-6)" "undo reword"

# Stopped by a second one there, an abort still takes its worktree, the trailer naming the cancel
_SG_PAUSED sg6
SG_WT=$(_ST_PZ_WT)
_SG_GO twice TERM - " rebase --abort " --abort
_ST_EQ "a second signal stops an abort past its clear" "$RC:$([ -e .git/git-edit-state ] && echo state):$(git worktree list | wc -l | tr -d ' '):$([ -d "${SG_WT:-$ST_NO_WT}" ] && echo wt)" "143::1:"
_ST_OUT_HAS "naming the pause it cancelled" '^git-edit: error – stopped by SIGTERM after cancelling the pause (drop '
# While one ahead of the clear keeps the pause whole
_SG_PAUSED sg7
SG_WT=$(_ST_PZ_WT)
_SG_GO pid TERM - " config --get i18n.commitEncoding " --abort
_ST_EQ "one before an abort cleared anything keeps the pause" "$RC:$([ -e .git/git-edit-state ] && echo state):$([ -d "${SG_WT:-$ST_NO_WT}" ] && echo wt)" "143:state:wt"
# Once the trailer is out, the status is the trailer's
SG_OUT=$TMP/sg.out
export SG_OUT
_SG_GO pid TERM - "" --abort
_ST_EQ "a signal after an abort's ok trailer exits 0" "$RC:${${OUT##*$'\n'}%% –*}" "0:git-edit: ok"
# As past a conflict's trailer, while the pause is still being settled
_ST_PZ_NEW sg7b
_ST_PZ_C g.txt a "SG7B g1" && _ST_PZ_C g.txt b "SG7B g2" && _ST_PZ_C g.txt c "SG7B g3"
SG_OUT=$TMP/sg.out
export SG_OUT
_SG_GO pid TERM - "" -d -y HEAD~1
_ST_EQ "a signal after a conflict's trailer exits as the pause it leaves" "$RC:$([ -e .git/git-edit-state ] && echo state)" "2:state"
_ST_OUT_LACKS "naming no signal" 'stopped by SIGTERM'
_ST_RUN --abort

# A resume run from its own landing's hook was told to wait for the run that waits on it
_SG_PAUSED sg7c
SG_WT=$(_ST_PZ_WT)
print -r -- c > "${SG_WT:-$ST_NO_WT}/g.txt" && git -C "${SG_WT:-$ST_NO_WT}" add g.txt
printf '#!/bin/sh\n[ "$1" = prepared ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\n[ -e "%s/sg-inner.out" ] && exit 0\n%s --continue </dev/null > "%s/sg-inner.out" 2>&1\nexit 0\n' \
	"$TMP" "${(q)SELF}" "$TMP" > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
rm -f "$TMP/sg-inner.out"
_ST_RUN --continue
rm -f .git/hooks/reference-transaction
_ST_EQ "the resume lands all the same" "$RC:$(git log -1 --format=%s HEAD~1)" "0:SG g1"
OUT=$(<"$TMP/sg-inner.out")
_ST_OUT_HAS "while one its landing's hook runs names the run it runs under" 'is held by the run this one runs under (pid '

# A diff that failed outright was read as "nothing changed" too
_SG_REPO sg8
SG_FAIL=1
export SG_FAIL
_SG_GO none TERM update-ref "--name-only --no-renames" -d -y HEAD~1
_ST_OUT_HAS "a re-sync whose diff failed says so" 'git could not list what changed, so your checkout was not reconciled'
_ST_OUT_LACKS "rather than calling the checkout untouched" 'left as it was'

# A settle stopped mid-nap left its files flagged assume-unchanged, hiding a later edit there – the
# pause's, which runs once the conflict's trailer is out
_ST_PZ_NEW sg9
git config rerere.enabled false
printf 'one\r\ntwo\r\n' > crlf.txt && git update-index --add --cacheinfo "100644,$(git hash-object -w --no-filters -- crlf.txt),crlf.txt" && git commit -qm "SG9 crlf"
print -r -- '*.txt text eol=lf' > .gitattributes && git add .gitattributes && git commit -qm "SG9 attrs"
_ST_PZ_C f.txt a "SG9 f1" && _ST_PZ_C f.txt b "SG9 f2"
# Replayed ahead of the stop, so the stop's worktree holds it freshly written
printf 'three\r\n' > crlf.txt && git update-index --cacheinfo "100644,$(git hash-object -w --no-filters -- crlf.txt),crlf.txt" && git commit -qm "SG9 crlf2"
_ST_PZ_C f.txt c "SG9 f3"
: > "$SG_DIR/nap"
SG_OUT=$TMP/sg.out
export SG_OUT
_SG_GO pid TERM - "SG9 none" -d -y HEAD~2
rm -f "$SG_DIR/nap"
SG_WT=$(_ST_PZ_WT)
_ST_EQ "a run stopped while its settle holds a file flagged takes the flag off" "$([ -e "$SG_DIR/reached" ] && echo held):$(git -C "${SG_WT:-$ST_NO_WT}" ls-files -v -- crlf.txt | cut -c1)" "held:H"
_ST_EQ "the pause kept" "$([ -e .git/git-edit-state ] && echo state)" "state"
_ST_RUN --abort

# Ctrl-C at a prompt that followed a refusal ended on that refusal's signal, not as q does
_SG_REPO sg10
_ST_TTY_START -- HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	zpty -wn ST_TTY $'\r'
	_ST_TTY_AT 'to leave it paused' 2 && zpty -wn ST_TTY $'\003'
fi
_ST_TTY_END
_ST_EQ "Ctrl-C at a prompt after a refusal leaves the pause as q does" "$RC" "2"
_ST_OUT_HAS "on a paused trailer" '^git-edit: paused – edit '
_ST_RUN --abort
# And at a conflict's prompt it exited 130 under that conflict's trailer
_SG_PAUSED sg11
_ST_RUN --abort
_ST_TTY_START -- -d -y HEAD~1
_ST_TTY_AT 'Resolve the conflicts in' && zpty -wn ST_TTY $'\003'
_ST_TTY_END
_ST_EQ "Ctrl-C at a conflict's prompt exits as the pause it leaves" "$RC:$([ -e .git/git-edit-state ] && echo state)" "2:state"
_ST_OUT_LACKS "naming no signal" 'stopped by SIGINT'
_ST_RUN --abort
rm -rf "$SG_DIR" "$SG_BIN"
cd "$TMP/repo"
