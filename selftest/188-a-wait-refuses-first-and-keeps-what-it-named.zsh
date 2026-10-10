# A run refuses before any wait what its arguments earn, and keeps what it named across it:
# • A pushed target, a record header naming nothing, twice or with no message, and a split,
#   `--commit` or `--amend-into` path matching nothing refuse at once beside another caller's pause
# • `--onto=<rev>` naming no branch rebases onto what it named before the wait, a branch onto
#   where that branch stands after it
# • The body put-back command is offered only where the new message has no body of its own
# • A lost line counts as superseded only where the stop holds its old text alone, never its
#   hunk's replacement
# • An edit pause of an empty commit takes a new message at its continue
_ST_SCENARIO "\e[1;96m[188] a wait refuses first and keeps what it named, empty edits reword\e[0m"
local WR_WTD WR_OLD WR_HEAD WR_EC WR_ARGS WR_I
local -a WR_CASE WR_L WR_E WR_X WR_F WR_S WR_R
# Runs `git edit <arg>...` as caller w-self, outside the suite's no-wait pin
_W188_RUN () {
	OUT=$(env -u GIT_EDIT_SELFTEST_DEPTH GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=w-self "$SELF" "$@" </dev/null 2>&1)
	RC=$?
}
# Runs `git edit <arg>...` as caller w-peer
_W188_PEER () {
	export GIT_EDIT_ACTOR=w-peer
	_ST_RUN "$@"
	export GIT_EDIT_ACTOR=
}
# Starts `git edit <arg>...` in the background as caller w-self, outside the suite's no-wait pin –
# its output, pid and status into `$TMP/<name>.out`, `.pid` and `.rc`
_W188_BG () {
	# Args: <name> <arg>...
	local N=$1
	shift
	: > "$TMP/$N.out"; : > "$TMP/$N.pid"; : > "$TMP/$N.rc"
	( env -u GIT_EDIT_SELFTEST_DEPTH GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=w-self "$SELF" "$@" </dev/null >"$TMP/$N.out" 2>&1 &
	  print -r -- $! >"$TMP/$N.pid"; wait $!; print -r -- $? >"$TMP/$N.rc" ) &
}
# Waits for <text> in the output of background run <name> – fails where that run ends or 60 s pass
_W188_UNTIL () {
	# Args: <name> <text>
	local -i I=0
	until LC_ALL=C grep -qF -e "$2" "$TMP/$1.out" 2>/dev/null; do
		{ [ -s "$TMP/$1.rc" ] || (( ++I > 600 )); } && return 1
		sleep 0.1
	done
}
# Waits for background run <name> to end, its output and status into `OUT` and `RC` – at most
# 60 s, a run still going then stopped
_W188_END () {
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

# Beside another caller's pause, every refusal an argument earns comes at once – W3 and below
# stand on a remote, W4 is paused, W5 the tip
_ST_PZ_NEW wr1
_ST_PZ_C a.txt a "WR1 W1" && _ST_PZ_C b.txt b "WR1 W2" && _ST_PZ_C c.txt c "WR1 W3"
git update-ref refs/remotes/o/main HEAD
_ST_PZ_C d.txt d "WR1 W4" && _ST_PZ_C e.txt e "WR1 W5"
_W188_PEER HEAD~1
_ST_EQ "a peer pauses an edit" "$RC" "2"
for WR_ARGS in \
		"--split=HEAD --text x -- nomatch|Pathspec matches no changes in" \
		"--split=HEAD~1 --text x -- d.txt|Pathspec covers every change in" \
		"--commit --text x -- nonexist|nonexist: no such file, in the checkout or at the tip" \
		"--amend-into=HEAD -- nonexist|No staged changes under nonexist" \
		"--amend-into=HEAD --whole -- nonexist|nonexist: no such file, in the checkout or at the tip" \
		"-M --text x HEAD~2|is already pushed" \
		"-M --subject=x HEAD~2|is already pushed" \
		"-S HEAD~2|is already pushed" \
		"--reorder HEAD~1 HEAD~2|is already pushed" \
		"--move=HEAD~2 --after=HEAD|is already pushed" \
		"--split=HEAD~2 --text x -- c.txt|is already pushed" \
		"--amend-into=HEAD~2 -- a.txt|is already pushed"; do
	WR_CASE=(${=WR_ARGS%%|*})
	_W188_RUN --wait=2 "${WR_CASE[@]}"
	_ST_EQ "'git edit ${WR_ARGS%%|*}' beside a pause refuses" "$RC" "1"
	_ST_OUT_HAS "with its own refusal" "${WR_ARGS#*|}"
	_ST_OUT_LACKS "never waiting first" 'Waiting up to'
done
for WR_ARGS in \
		$'--- HEAD\nWR1 new\n--- nosuchref\nother|Commit nosuchr does not exist' \
		$'--- HEAD\nWR1 new\n--- HEAD\nother|is named by two records' \
		$'--- HEAD\n\n--- HEAD~1\nother|has an empty message' \
		$'--- HEAD\nWR1 new\n--- HEAD~2\nother|is already pushed'; do
	_W188_RUN --wait=2 -M --text="${WR_ARGS%%|*}"
	_ST_EQ "records '${${WR_ARGS%%|*}//$'\n'/ }' beside a pause refuse" "$RC" "1"
	_ST_OUT_HAS "with their own refusal" "${WR_ARGS#*|}"
	_ST_OUT_LACKS "never waiting first" 'Waiting up to'
done
# The neighbors: consent to a pushed target, and valid records, wait as ever
_W188_RUN -M --text x --allow-pushed --wait=1 HEAD~2
_ST_OUT_HAS "a pushed target under --allow-pushed waits" '^Waiting up to 1s'
_W188_RUN -M --text=$'--- HEAD\nWR1 new\n--- HEAD~1\nWR1 other' --wait=1
_ST_OUT_HAS "valid records wait" '^Waiting up to 1s'
_W188_PEER --abort
WR_HEAD=$(git rev-parse HEAD)
_ST_RUN --reorder HEAD~3 HEAD~2
_ST_EQ "a reorder keeping pushed commits' order changes nothing, refusing nothing" "$RC:$(git rev-parse HEAD)" "0:$WR_HEAD"
_ST_OUT_HAS "saying so" 'Desired order matches the current order'

# `--onto` waiting out a landing that rewrote main – a relative name rebases onto the commit it
# named when called, a branch onto where it stands once the wait is over
for WR_I in 1 2; do
	_ST_PZ_NEW wr2-$WR_I
	_ST_PZ_C a.txt a "WR2 base"
	git branch feat
	_ST_PZ_C m.txt m1 "WR2 M1" && _ST_PZ_C n.txt n1 "WR2 M2"
	WR_OLD=$(git rev-parse HEAD~1)
	git checkout -q feat
	_ST_PZ_C f.txt f "WR2 F"
	git worktree add -q "$TMP/pz-wr2-$WR_I-main" main
	( cd "$TMP/pz-wr2-$WR_I-main" && _W188_PEER HEAD~1 )
	if [ $WR_I = 1 ]; then
		_W188_BG wr2 --onto=main~1 --wait=30
	else
		_W188_BG wr2 --onto=main --wait=30
	fi
	_W188_UNTIL wr2 "Waiting up to 30s"
	_ST_EQ "--onto beside a pause waits ($WR_I)" "$?" "0"
	WR_WTD=$(_ST_PZ_WT)
	print -r -- m2 > "${WR_WTD:-$ST_NO_WT}/m.txt"
	( cd "$TMP/pz-wr2-$WR_I-main" && _W188_PEER --continue )
	_W188_END wr2
	if [ $WR_I = 1 ]; then
		_ST_EQ "--onto=main~1 replants onto the commit main~1 was when called" \
			"$RC:$(git rev-parse HEAD~1):$(git log -1 --format=%s HEAD)" "0:$WR_OLD:WR2 F"
	else
		_ST_EQ "--onto=main replants onto main as the landing left it" \
			"$RC:$(git rev-parse HEAD~1):$(git show HEAD:m.txt)" "0:$(git rev-parse main):m2"
	fi
done

# A new message with a body of its own is never offered a command putting the old body back,
# which would drop the new one – a subject-only one is
_ST_PZ_NEW wr3
_ST_PZ_C a.txt a "WR3 base"
git commit -q --allow-empty -m $'WR3 old\n\nOld body A\nOld body B'
WR_OLD=$(git rev-parse HEAD)
_ST_RUN -M --text=$'WR3 new\n\nMy new body' HEAD
_ST_EQ "a reword with a body of its own lands" "$RC:$(git log -1 --format=%b HEAD)" "0:My new body"
_ST_OUT_HAS "naming the old body still readable" "drops – it is still readable at ${WR_OLD:0:12}"
_ST_OUT_LACKS "with no command putting it back" 'To put the body back'
git commit -q --allow-empty -m $'WR3 second\n\nSecond body'
_ST_RUN -M --text="WR3 second new" HEAD
_ST_OUT_HAS "a subject-only reword is offered it" '^To put the body back under the new subject: git edit -M'
_ST_PZ_C b.txt b $'WR3 edited\n\nEdited body' && _ST_PZ_C c.txt c "WR3 top"
_ST_RUN HEAD~1
_ST_RUN --continue --text=$'WR3 edited new\n\nIts own body'
_ST_EQ "an edit's continue with a body of its own lands" "$RC:$(git log -1 --format=%b HEAD~1)" "0:Its own body"
_ST_OUT_LACKS "with no command putting the old body back" 'To put the body back'

# A stop holding a later commit's replacement line took that line in – the line it replaced
# is never superseded, so the loss of that commit's other line refuses as before
_ST_PZ_NEW wr4
git config rerere.enabled false
WR_L=(); for WR_I in {01..20}; do WR_L+=("line$WR_I"); done; WR_L[10]="alpha = 1"
print -l -- "${WR_L[@]}" > f && git add f && git commit -qm "WR4 base"
WR_E=("${WR_L[@]}"); WR_E[2]="line02 edited by E"
print -l -- "${WR_E[@]}" > f && git commit -qam "WR4 E edits line02" && WR_EC=$(git rev-parse HEAD)
WR_X=("${WR_E[@]}"); WR_X[10]="alpha = 2"$'\n'"beta = 3"; WR_X[16]="k1 changed"; WR_X[17]="k2 changed"; WR_X[18]="k3 changed"
print -l -- "${WR_X[@]}" > f && git commit -qam "WR4 X sets alpha 2, adds beta, changes k1-k3"
_ST_PZ_C g top "WR4 T top"
WR_HEAD=$(git rev-parse HEAD)
WR_F=("${WR_X[@]}"); WR_F[16]="k1 changed again"
print -l -- "${WR_F[@]}" > f && git add f
_ST_RUN --amend-into="$WR_EC" -- f
WR_S=("${WR_E[@]}"); WR_S[10]="alpha = 2"
_ST_RESOLVE "$(_ST_PZ_WT)" f "${(F)WR_S}"
_ST_RUN --continue
_ST_EQ "E's stop takes in X's alpha line, X's stop follows" "$RC" "2"
WR_R=("${WR_F[@]}"); WR_R[10]="alpha = 2"
_ST_RESOLVE "$(_ST_PZ_WT)" f "${(F)WR_R}"
_ST_RUN --continue
_ST_EQ "X's stop resolved without beta refuses, nothing moved" "$RC:$(git rev-parse HEAD)" "1:$WR_HEAD"
_ST_OUT_HAS "naming X as the commit that lost its change" 'WR4 X sets alpha 2, adds beta, changes k1-k3 – f$'
_ST_OUT_LACKS "never naming its alpha line superseded" 'Superseded'
_ST_RUN --abort

# An edit pause of an empty commit takes a new message or subject at its continue – tip and below
# it alike – while an edit emptying a commit that had a change still refuses
_ST_PZ_NEW wr5
_ST_PZ_C a.txt a "WR5 base"
git commit -q --allow-empty -m $'WR5 empty\n\nWR5 body'
_ST_RUN HEAD
_ST_RUN --continue --text="WR5 empty new"
_ST_EQ "an empty tip's continue --text lands, still empty" \
	"$RC:$(git log -1 --format=%s HEAD):$(git diff-tree --no-commit-id --name-only HEAD | wc -l | tr -d ' ')" "0:WR5 empty new:0"
_ST_PZ_C b.txt b "WR5 above"
_ST_RUN HEAD~1
_ST_RUN --continue --subject="WR5 empty newer"
_ST_EQ "an empty commit below the tip takes --subject, the one above replayed" \
	"$RC:$(git log -2 --format=%s HEAD | tr '\n' '|')" "0:WR5 above|WR5 empty newer|"
_ST_RUN HEAD~1
print -r -- e > "$(_ST_PZ_WT)/e.txt"
_ST_RUN --continue --text="WR5 no longer empty"
_ST_EQ "one gaining a file lands with it" "$RC:$(git diff-tree --no-commit-id --name-only HEAD~1)" "0:e.txt"
WR_HEAD=$(git rev-parse HEAD)
_ST_RUN HEAD
git -C "$(_ST_PZ_WT)" rm -q b.txt
_ST_RUN --continue --text="WR5 emptied"
_ST_EQ "an edit emptying a commit with a change refuses, nothing moved" "$RC:$(git rev-parse HEAD)" "1:$WR_HEAD"
_ST_OUT_HAS "as git's amend does" 'would make'
_ST_RUN --abort
cd "$TMP/repo"
