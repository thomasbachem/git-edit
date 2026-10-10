# A waiting run acts on what it named:
# • A run that waits out another caller's pause acts on the commits its arguments named as it
#   started – pinned by SHA before the wait, then resolved as any stale SHA is – and an argument
#   it refuses refuses before any wait
# • A signal ends the wait at once, `--wait` beside `--undo` says why it has nothing to bound
# • A `--subject` changing nothing at an edit's continue refuses as nothing to amend, one replacing
#   a first paragraph of several lines names them
# • The documented grep keeps a fold's tip-tree note
_ST_SCENARIO "\e[1;96m[182] a waiting run acts on what it named, and a bad argument never waits\e[0m"
local PW_WTD PW_HEAD PW_C PW_MAN PW_RE PW_RD PW_ARGS
local PW_T
local -a PW_CASE
# Starts `git edit <arg>...` in the background as caller w-self, outside the suite's no-wait pin –
# its output, pid and status into `$TMP/<name>.out`, `.pid` and `.rc`
_W182_BG () {
	# Args: <name> <arg>...
	local N=$1
	shift
	: > "$TMP/$N.out"; : > "$TMP/$N.pid"; : > "$TMP/$N.rc"
	( env -u GIT_EDIT_SELFTEST_DEPTH GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=w-self "$SELF" "$@" </dev/null >"$TMP/$N.out" 2>&1 &
	  print -r -- $! >"$TMP/$N.pid"; wait $!; print -r -- $? >"$TMP/$N.rc" ) &
}
# Waits for <text> in the output of background run <name> – fails where that run ends or 60 s pass
_W182_UNTIL () {
	# Args: <name> <text>
	local -i I=0
	until LC_ALL=C grep -qF -e "$2" "$TMP/$1.out" 2>/dev/null; do
		{ [ -s "$TMP/$1.rc" ] || (( ++I > 600 )); } && return 1
		sleep 0.1
	done
}
# Waits for background run <name> to end, its output and status into `OUT` and `RC` –
# at most 60 s, a run still going then stopped
_W182_END () {
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
# Runs `git edit <arg>...` as `_ST_RUN` does, but as caller w-self outside the suite's no-wait pin
_W182_RUN () {
	OUT=$(env -u GIT_EDIT_SELFTEST_DEPTH GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=w-self "$SELF" "$@" </dev/null 2>&1)
	RC=$?
}
# Runs `git edit <arg>...` as caller w-peer
_W182_PEER () {
	export GIT_EDIT_ACTOR=w-peer
	_ST_RUN "$@"
	export GIT_EDIT_ACTOR=
}
# Makes repo <name> – main holding "PW B" and "PW C" above a base its branch `feature` forked from,
# feature one commit on that base clashing with "PW B" – and pauses w-peer's land of feature
_W182_LANDING () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	_ST_PZ_C f.txt 1 "PW base"
	git branch feature
	_ST_PZ_C f.txt 2 "PW B"
	_ST_PZ_C c.txt c "PW C"
	git checkout -q feature
	_ST_PZ_C f.txt F "PW F"
	git checkout -q main
	_W182_PEER --land=feature
}
# Resolves w-peer's paused land and lands it, "PW F" then on top of "PW C"
_W182_LANDED () {
	PW_WTD=$(_ST_PZ_WT)
	_ST_RESOLVE "${PW_WTD:-$ST_NO_WT}" f.txt 2F
	_W182_PEER --continue
}

# A reword of `HEAD` waiting out a land acts on the commit `HEAD` was,
# never the one the land put there
_W182_LANDING pw1
_ST_EQ "a peer's land pauses" "$RC" "2"
_W182_BG pw1 -M --subject="PW C reworded" --wait=30 HEAD
_W182_UNTIL pw1 "Waiting up to 30s"
_ST_EQ "a reword of HEAD waits for it" "$?" "0"
_W182_LANDED
_ST_EQ "the land goes on meanwhile, putting a commit on top" "$RC:$(git log -1 --format=%s HEAD)" "0:PW F"
_W182_END pw1
_ST_EQ "the waiting reword lands, rewording the commit HEAD named when it was called" \
	"$RC:$(git log -3 --format=%s HEAD | tr '\n' '|')" "0:PW F|PW C reworded|PW B|"
_ST_OUT_HAS "naming it as the one replaced" '^  replaced: PW C$'

# So does a drop
_W182_LANDING pw2
_W182_BG pw2 -d --wait=30 HEAD
_W182_UNTIL pw2 "Waiting up to 30s"
_ST_EQ "a drop of HEAD waits for it" "$?" "0"
_W182_LANDED
_W182_END pw2
_ST_EQ "the waiting drop drops the commit HEAD named when it was called, the landed one kept" \
	"$RC:$(git log --format=%s HEAD | tr '\n' '|'):$(git ls-tree --name-only HEAD -- c.txt)" "0:PW F|PW B|PW base|:"

# And a record naming `HEAD`
_W182_LANDING pw3
_W182_BG pw3 -M --text=$'--- HEAD\nPW C by record' --wait=30
_W182_UNTIL pw3 "Waiting up to 30s"
_ST_EQ "a records reword waits for it" "$?" "0"
_W182_LANDED
_W182_END pw3
_ST_EQ "the waiting records reword rewords the commit its header named when it was called" \
	"$RC:$(git log -2 --format=%s HEAD | tr '\n' '|')" "0:PW F|PW C by record|"

# A pinned commit the landing rebuilt with its change intact resolves to its current identity
_ST_PZ_NEW pw4
_ST_PZ_C a.txt a "PW4 A" && _ST_PZ_C b.txt b "PW4 B" && _ST_PZ_C c.txt c "PW4 C"
PW_C=$(git rev-parse HEAD)
_W182_PEER HEAD~2
_W182_BG pw4 -M --subject="PW4 C reworded" --wait=30 HEAD
_W182_UNTIL pw4 "Waiting up to 30s"
PW_WTD=$(_ST_PZ_WT)
print -r -- a2 > "${PW_WTD:-$ST_NO_WT}/a.txt"
_W182_PEER --continue
_W182_END pw4
_ST_EQ "a pinned commit the landing rebuilt is reworded at its new identity" \
	"$RC:$(git log -1 --format=%s HEAD):$(git show HEAD:a.txt)" "0:PW4 C reworded:a2"
_ST_OUT_HAS "found by its unchanged diff" "^Commit ${PW_C:0:7} was rewritten – using its current identity"

# One the landing changed refuses, naming its counterpart,
# rather than take whatever the name means now
_ST_PZ_NEW pw5
_ST_PZ_C a.txt a "PW5 A" && _ST_PZ_C b.txt b "PW5 B" && _ST_PZ_C c.txt c "PW5 C"
_W182_PEER HEAD~1
_W182_BG pw5 -M --subject="PW5 B reworded" --wait=30 HEAD~1
_W182_UNTIL pw5 "Waiting up to 30s"
PW_WTD=$(_ST_PZ_WT)
print -r -- b2 > "${PW_WTD:-$ST_NO_WT}/b.txt"
_W182_PEER --continue
PW_HEAD=$(git rev-parse HEAD)
_W182_END pw5
_ST_EQ "a pinned commit the landing changed refuses, nothing moved" "$RC:$(git rev-parse HEAD)" "1:$PW_HEAD"
_ST_OUT_HAS "naming its counterpart" "Its counterpart on HEAD is $(git rev-parse --short=12 HEAD~1) (same subject, changed content)"

# Every argument the run would refuse refuses at once beside another caller's pause, never after
# the wait – a valid run alone waits
_ST_PZ_NEW pw6
_ST_PZ_C a.txt a "PW6 A" && _ST_PZ_C b.txt b "PW6 B" && _ST_PZ_C c.txt c "PW6 C"
_W182_PEER HEAD~1
for PW_ARGS in \
		"|Missing <commit> or mode" \
		"-M --subject=x|Missing <commit> – name the commit" \
		"--subject=x HEAD~1|Pass --subject with 'git edit --continue'" \
		"-d nonexistentref|Unknown <commit>: nonexistentref" \
		"--land=nope|Unknown branch: nope" \
		"--amend-into=nope|Unknown <sha>: nope" \
		"--move=nope --after=HEAD|Unknown <sha>: nope"; do
	PW_CASE=(${=PW_ARGS%%|*})
	_W182_RUN "${PW_CASE[@]}" --wait=3
	_ST_EQ "'git edit ${PW_ARGS%%|*}' beside a pause refuses" "$RC" "1"
	_ST_OUT_HAS "with its own refusal" "${PW_ARGS#*|}"
	_ST_OUT_LACKS "never waiting first" 'Waiting up to'
done
_W182_RUN -M --text="PW6 C new" --wait=1 HEAD
_ST_EQ "a valid run waits" "$RC" "1"
_ST_OUT_HAS "saying so" '^Waiting up to 1s'

# A signal while waiting ends the run at once, not once the current nap is over
_W182_BG pw6 -M --text="PW6 C signalled" --wait=60 HEAD
_W182_UNTIL pw6 "Waiting up to 60s"
# An observation window – a nap is under way, nothing to poll for
sleep 0.5
PW_T=$EPOCHREALTIME
kill -TERM "$(<"$TMP/pw6.pid")" 2>/dev/null
_W182_END pw6
_ST_EQ "TERM mid-nap ends the waiting run within a second" "$RC:$(( EPOCHREALTIME - PW_T < 1.0 ))" "143:1"

# `--wait` beside `--undo` and `--carry` names why it has nothing to bound
_ST_RUN --undo --wait=5
_ST_EQ "--undo --wait refuses" "$RC" "1"
_ST_OUT_HAS "as --undo never waits, refusing at once on a pause on its branch" \
	'--undo never waits for a pause – it refuses at once while one stands on the branch it would move'
_ST_RUN --carry --wait=5
_ST_OUT_HAS "and --carry" '--carry never waits for a pause, so --wait has nothing to bound'
_W182_PEER --abort

# An edit's continue with a `--subject` the commit has already and nothing else changed refuses as
# nothing to amend, the pause kept – a new subject lands
_ST_PZ_NEW pw8
_ST_PZ_C a.txt a "PW8 A" && _ST_PZ_C b.txt b "PW8 B" && _ST_PZ_C c.txt c "PW8 C"
PW_HEAD=$(git rev-parse HEAD)
_ST_RUN HEAD~1
_ST_RUN --continue --subject="PW8 B"
_ST_EQ "a continue whose --subject changes nothing refuses, nothing moved, the pause kept" \
	"$RC:$(git rev-parse HEAD):$([ -n "$(_ST_PZ_WT)" ] && echo paused)" "1:$PW_HEAD:paused"
_ST_OUT_HAS "as nothing to amend" "Nothing to amend – no changes in the worktree, and the commit's subject already reads as --subject gives it"
_ST_RUN --continue --subject="PW8 B renamed"
_ST_EQ "a new subject lands" "$RC:$(git log -1 --format=%s HEAD~1)" "0:PW8 B renamed"

# `--subject` replacing a first paragraph of several lines names them, with the `--text` keeping
# them – a reword and an edit's continue alike – where a one-line subject says nothing
_ST_PZ_NEW pw9
_ST_PZ_C a.txt a "PW9 A"
print -r -- b > b.txt && git add b.txt && git commit -qm $'PW9 one\n- detail a\n- detail b\n\nPW9 body'
PW_C=$(git rev-parse HEAD)
_ST_RUN -M --subject="PW9 new" HEAD
_ST_EQ "a reword replacing a 3-line first paragraph lands, the body kept" "$RC:$(git log -1 --format=%B HEAD)" $'0:PW9 new\n\nPW9 body'
_ST_OUT_HAS "naming the lines it replaced and where they are still readable" \
	"^--subject replaced a first paragraph of 3 lines, all of it git's subject – still readable at ${PW_C:0:12}:"
_ST_OUT_HAS "each of them" '^    - detail b$'
_ST_OUT_HAS "with the --text keeping them" "^To keep its later lines, give the whole message instead: git edit -M --text=\"…\" $(git rev-parse --short=12 HEAD)"
_ST_RUN -M --subject="PW9 newer" HEAD
_ST_EQ "a one-line subject rewords" "$RC" "0"
_ST_OUT_LACKS "saying nothing of lines" 'replaced a first paragraph'
print -r -- c > c.txt && git add c.txt && git commit -qm $'PW9 two\nmore detail\n\nPW9 second body'
PW_C=$(git rev-parse HEAD)
_ST_RUN HEAD
_ST_RUN --continue --subject="PW9 two new"
_ST_EQ "an edit's continue replacing a 2-line first paragraph lands" "$RC:$(git log -1 --format=%s HEAD)" "0:PW9 two new"
_ST_OUT_HAS "naming the lines too" "^--subject replaced a first paragraph of 2 lines, all of it git's subject – still readable at ${PW_C:0:12}:"
_ST_OUT_HAS "with the --text for the edited commit" "give the whole message instead: git edit -M --text=\"…\" $(git rev-parse --short=12 HEAD)"

# Prints commit <1>'s message as its object holds it, byte for byte
_W182_MSG () {
	local O
	O=$(git cat-file commit "$1"; print -n x)
	O=${O%x}
	print -rn -- "${O#*$'\n\n'}"
}
# Runs the put-back command the last run printed, as printed, `git edit` being this script
_W182_PUT_BACK () {
	local CMD=$(sed -n 's/^To put the body back under the new subject: //p' <<<"$OUT" | head -1)
	[ -n "$CMD" ] || { RC="no command printed"; return 1; }
	OUT=$(eval "GIT_EDIT_NO_AUTO_OPEN=1 ${CMD/#git edit /\"\$SELF\" }" </dev/null 2>&1)
	RC=$?
}
# A body `-M --text` or an edit's `--continue --text` dropped whole is named with a command that,
# run as printed, puts it back under the new subject on the landed commit – quotes, `$`, backticks,
# a backslash and blank lines kept, bar the trailing ones `--text`'s cleanup drops
_ST_PZ_NEW pw11
_ST_PZ_C a.txt a "PW11 base"
print -r -- b > b.txt && git add b.txt
printf '%s\n' "PW11 old" "" 'Body "quoted" $HOME, `date` and it'"'"'s' "" '  a \n backslash' "" "" > "$TMP/pw11-msg"
git commit -q --cleanup=verbatim -F "$TMP/pw11-msg"
PW_C=$(git rev-parse HEAD)
printf 'PW11 new $x\n\n%s\n' "$(git log -1 --format=%b "$PW_C")" > "$TMP/pw11-want"
_ST_RUN -M --text='PW11 new $x' HEAD
_ST_OUT_HAS "a reword dropping a body names it still readable" "drops – it is still readable at ${PW_C:0:12}"
_ST_OUT_HAS "and the command putting it back on the reworded commit" \
	"^To put the body back under the new subject: git edit -M --text=.* $(git rev-parse --short=12 HEAD)\$"
_W182_PUT_BACK
_ST_EQ "which, run as printed, lands" "$RC" "0"
_ST_CHECK "giving the commit its new subject over the old body, byte for byte" cmp -s <(_W182_MSG HEAD) "$TMP/pw11-want"
_ST_PZ_C c.txt c "PW11 top"
git commit -q --amend --cleanup=verbatim -F "$TMP/pw11-msg" && _ST_PZ_C d.txt d "PW11 above"
PW_C=$(git rev-parse HEAD~1)
printf "PW11 edit 'q'\n\n%s\n" "$(git log -1 --format=%b "$PW_C")" > "$TMP/pw11-want"
_ST_RUN HEAD~1
_ST_RUN --continue --text="PW11 edit 'q'"
_ST_OUT_HAS "an edit's continue dropping a body names the landed commit, the pause gone" \
	"^To put the body back under the new subject: git edit -M --text=.* $(git rev-parse --short=12 HEAD~1)\$"
_W182_PUT_BACK
_ST_EQ "and that command, run as printed, lands" "$RC:$(git log -1 --format=%s HEAD)" "0:PW11 above"
_ST_CHECK "putting the body back under the edit's subject, byte for byte" cmp -s <(_W182_MSG HEAD~1) "$TMP/pw11-want"

# The documented grep keeps a fold's note that the tip tree came out other than staged
PW_MAN="${SELF:h}/man/man1/git-edit.1"
[ -f "$PW_MAN" ] || PW_MAN="${SELF:h}/../share/man/man1/git-edit.1"
PW_RE=$(sed -n "s/.*grep -E '\(\^[^']*\)'.*/\1/p" "$PW_MAN" | head -1 | sed 's/\\ / /g')
_ST_PZ_NEW pw10
_ST_PZ_C fa.txt a1 "PW10 base"
print -r -- x1 > fb.txt && git add fb.txt && git commit -qm "PW10 x1"
PW_C=$(git rev-parse HEAD)
print -r -- x2 > fb.txt && git commit -qam "PW10 advance"
print -r -- a2 > fa.txt && print -r -- x1 > fb.txt && git add fa.txt fb.txt
_ST_RUN --amend-into="$PW_C"
_ST_OUT_HAS "a fold part of which dissolved lands with a note" '^Note: tip tree differs from the staged result'
_ST_EQ "which the man page's grep keeps, beside the trailer" \
	"$(LC_ALL=C grep -E -e "${PW_RE:-^$}" <<<"$OUT" | grep -c -e '^Note: tip tree differs' -e '^git-edit: ok')" "2"
PW_RD="${SELF:h}/README.md"
[ -f "$PW_RD" ] || PW_RD="${SELF:h}/../README.md"
if [ -f "$PW_RD" ]; then
	_ST_EQ "the README gives the same grep" "$(sed -n "s/.*grep -E '\(\^(Verif[^']*\)'.*/\1/p" "$PW_RD" | head -1)" "$PW_RE"
	_ST_EQ "its --text row claims no note --amend-into never prints" "$(grep -c 'a body it drops is named, with the' "$PW_RD")" "0"
fi
cd "$TMP/repo"
