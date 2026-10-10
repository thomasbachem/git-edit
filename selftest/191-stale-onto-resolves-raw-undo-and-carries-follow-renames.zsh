# A waiting `--onto` never replants onto a commit a landing rewrote, the raw undo's re-sync step is
# printed only where it works, and a carry and the landings guard follow a path back through
# renames into it:
# • `--onto=HEAD~1`, or the SHA of a commit on the branch, that a peer's landing rewrote meanwhile
#   resolves to its counterpart with the same diff, else refuses naming it
# • Where a re-synced path is flagged skip-worktree or lies outside a sparse checkout, the raw undo
#   is said to move the ref alone and `--undo` named, which puts every entry back, flags and all
# • A landing on a file's old name before a rename into it – a case-only one too – is the one a
#   printed carry starts from and the guard names, a file moved to its new name by hand going back
#   to the old one first – followed as printed, every landing stays
# • The move back stops where a file was put at the old name since, and where the name is taken – in
#   the checkout or at the tip – or a staged fold's unstaging would miss or unflag a sparse path,
#   the guard names the merge into the new name instead – followed as printed, the next run lands
_ST_SCENARIO "\e[1;96m[191] a stale --onto resolves, the raw undo names what works, carries follow renames back\e[0m"
local OV_C3 OV_PRE OV_T0 OV_T2 OV_TIP OV_CMD OV_I OV_ARG OV_RAW OV_HINT
# Runs `git edit <arg>...` as caller ov-peer
_OV_PEER () {
	export GIT_EDIT_ACTOR=ov-peer
	_ST_RUN "$@"
	export GIT_EDIT_ACTOR=
}
# Starts `git edit <arg>...` in the background as caller ov-self, outside the suite's no-wait pin –
# its output, pid and status into `$TMP/<name>.out`, `.pid` and `.rc`
_OV_BG () {
	# Args: <name> <arg>...
	local N=$1
	shift
	: > "$TMP/$N.out"; : > "$TMP/$N.pid"; : > "$TMP/$N.rc"
	( env -u GIT_EDIT_SELFTEST_DEPTH GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=ov-self "$SELF" "$@" </dev/null >"$TMP/$N.out" 2>&1 &
	  print -r -- $! >"$TMP/$N.pid"; wait $!; print -r -- $? >"$TMP/$N.rc" ) &
}
# Waits for <text> in the output of background run <name> – fails where that run ends or 60 s pass
_OV_UNTIL () {
	# Args: <name> <text>
	local -i I=0
	until LC_ALL=C grep -qF -e "$2" "$TMP/$1.out" 2>/dev/null; do
		{ [ -s "$TMP/$1.rc" ] || (( ++I > 600 )); } && return 1
		sleep 0.1
	done
}
# Waits for background run <name> to end, its output and status into `OUT` and `RC` – at most
# 60 s, a run still going then stopped
_OV_END () {
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
# Follows a printed command step by step – its `git edit` steps through `_ST_RUN`, the rest as
# printed – stopping at a step that fails
_OV_FOLLOW () {
	# Args: <command as printed>
	local STEP
	local -a W
	for STEP in "${(@s: && :)1}"; do
		W=("${(@Q)${(z)STEP}}")
		if [ "${W[1]} ${W[2]}" = "git edit" ]; then
			_ST_RUN "${(@)W[3,-1]}"
			[ "$RC" = 0 ] || return 1
		else
			eval "$STEP" || return 1
		fi
	done
}
# The lines a file holds of what the caller and the three landings put there
_OV_KEPT () {
	# Args: <file content>
	LC_ALL=C grep -cE 'A-EDIT| B$| D$' <<<"$1"
}

# `--onto` waiting out a peer's landing that rewrote the commit it named – by `HEAD~1`, by SHA –
# takes that commit's counterpart, replanting nothing, and refuses where its content changed
for OV_I in 1 2 3; do
	_ST_PZ_NEW ov1-$OV_I
	_ST_PZ_C f0 0 "OV1 base" && _ST_PZ_C f1 1 "OV1 c1" && _ST_PZ_C f2 2 "OV1 c2" && _ST_PZ_C f3 3 "OV1 c3" && _ST_PZ_C f4 4 "OV1 c4"
	OV_C3=$(git rev-parse HEAD~1)
	OV_ARG=--onto=HEAD~1
	[ $OV_I = 2 ] && OV_ARG=--onto=$OV_C3
	if [ $OV_I = 3 ]; then _OV_PEER HEAD~1; else _OV_PEER HEAD~2; fi
	_ST_EQ "a peer pauses an edit ($OV_I)" "$RC" "2"
	_OV_BG ov1 "$OV_ARG" --wait=30
	_OV_UNTIL ov1 "Waiting up to 30s"
	_ST_EQ "'git edit $OV_ARG' beside the pause waits ($OV_I)" "$?" "0"
	if [ $OV_I = 3 ]; then
		print -r -- 3x > "$(_ST_PZ_WT)/f3"
		_OV_PEER --continue
	else
		_OV_PEER --continue --text "OV1 c2 reworded"
	fi
	_OV_END ov1
	if [ $OV_I = 3 ]; then
		_ST_EQ "one whose content the landing changed refuses, moving nothing" \
			"$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:f3)" "1:OV1 c4|OV1 c3|OV1 c2|OV1 c1|OV1 base|:3x"
		_ST_OUT_HAS "naming it and its counterpart" "Upstream ${OV_C3:0:7} (OV1 c3) is not in HEAD's history"
		_ST_OUT_HAS "with the commit to retry with" "Its counterpart on HEAD is $(git rev-parse --short=12 HEAD~1) (same subject, changed content)"
	else
		_ST_EQ "'git edit $OV_ARG' keeps the peer's rewrite, replanting nothing" \
			"$RC:$(git log --format=%s | tr '\n' '|')" "0:OV1 c4|OV1 c3|OV1 c2 reworded|OV1 c1|OV1 base|"
		_ST_OUT_HAS "taking the rewritten commit's counterpart ($OV_I)" "Commit ${OV_C3:0:7} was rewritten – using its current identity $(git rev-parse --short=12 HEAD~1) (identical diff)"
		_ST_OUT_HAS "and saying it is on top of it already ($OV_I)" "nothing to replay\.$"
	fi
done

# A run re-syncing paths outside a sparse checkout prints no raw re-sync step, which there misses
# one and unflags another, but the `--undo` that puts back each entry, flags and all
_ST_PZ_NEW ov2
mkdir in out && print a > in/a && print b > out/b && print c > in/c && print t > top && git add -A && git commit -qm "OV2 base"
{ git sparse-checkout set --cone in || { git sparse-checkout init --cone && git sparse-checkout set in; }; } >/dev/null 2>&1
print x > in/c && git add in/c
OV_PRE="$(git ls-files -t | LC_ALL=C sort | tr '\n' '|'):$(git status --short | LC_ALL=C sort | tr '\n' '|')"
_ST_EQ "an out-of-cone file is flagged" "$(git ls-files -t -- out/b)" "S out/b"
_ST_RUN --exec -- sh -c 'mkdir -p out && echo b2 > out/b && echo a2 > in/a && echo n > out/new && { git add --sparse out/b in/a out/new 2>/dev/null || git add out/b in/a out/new; } && git commit -qm "OV2 land"'
_ST_OUT_HAS "a landing re-syncs entries out of the cone" "^Index entries re-synced to the new tip: .*out/b"
_ST_OUT_HAS "naming --undo for them, the raw undo moving the ref alone" "^The raw undo moves the ref alone, leaving these staged as the run's content – .* so undo with git edit --undo, which re-syncs them all$"
_ST_OUT_LACKS "never the raw re-sync step" "After the raw undo"
_ST_RUN --undo
_ST_EQ "the undo named puts every entry back, flags and all" \
	"$RC:$(git ls-files -t | LC_ALL=C sort | tr '\n' '|'):$(git status --short | LC_ALL=C sort | tr '\n' '|')" "0:$OV_PRE"
# Re-syncing paths inside the cone alone, a git that asks the patterns prints the raw step, which
# works as printed – one that can't ask names `--undo` there too
_ST_RUN --exec -- sh -c 'echo a3 > in/a && git add in/a && git commit -qm "OV2 in-cone"'
if _ST_SPARSE_RULES_OK; then
	_ST_OUT_HAS "inside the cone the raw re-sync step is printed" "^After the raw undo, re-sync them back"
	OV_RAW=$(sed -n 's/^Undo: git edit --undo  (or, the ref alone: \(.*\))$/\1/p' <<<"$OUT")
	OV_HINT=$(sed -n 's/^After the raw undo, re-sync them back – [^:]*: //p' <<<"$OUT")
	eval "$OV_RAW" && eval "$OV_HINT"
	_ST_EQ "and followed as printed, it puts the entries back" \
		"$?:$(git ls-files -t | LC_ALL=C sort | tr '\n' '|'):$(git status --short | LC_ALL=C sort | tr '\n' '|')" "0:$OV_PRE"
else
	_ST_OUT_HAS "a git that can't ask the patterns names --undo inside the cone too" "so undo with git edit --undo, which re-syncs them all$"
fi
git sparse-checkout disable >/dev/null 2>&1

# A case-only rename between two landings: the second's carry starts from before the first, and a
# file committed whole without it names the first, on the old spelling – followed, all three stay
if [ "$(git config --type=bool core.ignorecase)" = true ]; then
	_ST_PZ_NEW ov3
	print -l "f line "{1..20} > f && git add f && git commit -qm "OV3 base"
	OV_T0=$(git rev-parse HEAD)
	print -l "f line 1 A-EDIT" "f line "{2..20} > f
	GIT_EDIT_ACTOR=ov-b _ST_RUN --commit --text "OV3 B" --edits '{"f": [["f line 8\n", "f line 8 B\n"]]}'
	GIT_EDIT_ACTOR=ov-c _ST_RUN --exec -- sh -c "git mv f ov3.tmp && git mv ov3.tmp F && git commit -qm 'OV3 C'"
	GIT_EDIT_ACTOR=ov-d _ST_RUN --commit --text "OV3 D" --edits '{"F": [["f line 18\n", "f line 18 D\n"]]}'
	_ST_OUT_HAS "a landing after a case-only rename names the carry from before the landing on the old spelling" \
		"^Merge those edits onto the new content with: git edit --carry=${OV_T0:0:12}$"
	GIT_EDIT_ACTOR=ov-a _ST_RUN --commit --text "OV3 A" -- F
	_ST_EQ "the file committed whole without it refuses" "$RC" "1"
	_ST_OUT_HAS "naming the landing on the old spelling" "^ *F – ov-b's commit run .* (${OV_T0:0:7}\.\.[0-9a-f]*), on its old name f$"
	_ST_OUT_HAS "and the carry from before it" "Merge your edits onto what landed with 'git edit --carry=${OV_T0:0:12}', then run this again\.$"
	OV_CMD=$(sed -n "s/.*Merge your edits onto what landed with '\\(git edit --carry=[0-9a-f]*\\)', then run this again\\.$/\\1/p" <<<"$OUT")
	GIT_EDIT_ACTOR=ov-a _OV_FOLLOW "$OV_CMD"
	GIT_EDIT_ACTOR=ov-a _ST_RUN --commit --text "OV3 A" -- F
	_ST_EQ "followed as printed, the file lands with every landing" "$RC:$(_OV_KEPT "$(git show HEAD:F)")" "0:3"
fi

# A file renamed by a landing and moved to its new name by hand: the next landing's carry moves it
# back to the old name first, where the carry takes its edits from
_ST_PZ_NEW ov4
print -l "f line "{1..20} > f && git add f && git commit -qm "OV4 base"
OV_T0=$(git rev-parse HEAD)
print -l "f line 1 A-EDIT" "f line "{2..20} > f
GIT_EDIT_ACTOR=ov-b _ST_RUN --commit --text "OV4 B" --edits '{"f": [["f line 8\n", "f line 8 B\n"]]}'
GIT_EDIT_ACTOR=ov-c _ST_RUN --exec -- sh -c "git mv f h && git commit -qm 'OV4 C'"
mv f h
GIT_EDIT_ACTOR=ov-d _ST_RUN --commit --text "OV4 D" --edits '{"h": [["f line 18\n", "f line 18 D\n"]]}'
_ST_OUT_HAS "a landing names the move back and the carry from before the landing on the old name" \
	"^Merge those edits onto the new content with: \[ ! -e f \] && \[ ! -L f \] && mv -- h f && git edit --carry=${OV_T0:0:12}$"
OV_CMD=$(sed -n 's/^Merge those edits onto the new content with: //p' <<<"$OUT")
GIT_EDIT_ACTOR=ov-a _OV_FOLLOW "$OV_CMD"
_ST_EQ "followed as printed, the file holds every landing and its edits" "$?:$(_OV_KEPT "$(<h)"):$([ -e f ] && print f)" "0:3:"
GIT_EDIT_ACTOR=ov-a _ST_RUN --commit --text "OV4 A" -- h
_ST_EQ "and committed whole, it keeps them" "$RC:$(_OV_KEPT "$(git show HEAD:h)")" "0:3"

# Moved by hand once both landings are in, the file committed whole names the landing on the old
# name with the move back – while one made on that landing names the later one alone
for OV_I in 1 2; do
	_ST_PZ_NEW ov5-$OV_I
	print -l "f line "{1..20} > f && git add f && git commit -qm "OV5 base"
	OV_T0=$(git rev-parse HEAD)
	[ $OV_I = 1 ] && print -l "f line 1 A-EDIT" "f line "{2..20} > f
	GIT_EDIT_ACTOR=ov-b _ST_RUN --commit --text "OV5 B" --edits '{"f": [["f line 8\n", "f line 8 B\n"]]}'
	[ $OV_I = 2 ] && print -l "f line 1 A-EDIT" "f line "{2..7} "f line 8 B" "f line "{9..20} > f
	GIT_EDIT_ACTOR=ov-c _ST_RUN --exec -- sh -c "git mv f h && git commit -qm 'OV5 C'"
	OV_T2=$(git rev-parse HEAD)
	GIT_EDIT_ACTOR=ov-d _ST_RUN --commit --text "OV5 D" --edits '{"h": [["f line 18\n", "f line 18 D\n"]]}'
	mv f h
	GIT_EDIT_ACTOR=ov-a _ST_RUN --commit --text "OV5 A" -- h
	_ST_EQ "the file committed whole without a landing refuses ($OV_I)" "$RC" "1"
	if [ $OV_I = 1 ]; then
		_ST_OUT_HAS "naming the landing on the old name" "^ *h – ov-b's commit run .* (${OV_T0:0:7}\.\.[0-9a-f]*), on its old name f$"
		_ST_OUT_HAS "with the move back and the carry from before it" \
			"where the carry takes the edits from, with: \[ ! -e f \] && \[ ! -L f \] && mv -- h f && git edit --carry=${OV_T0:0:12} – then run this again\.$"
		OV_CMD=$(sed -n 's/.*where the carry takes the edits from, with: \(.*\) – then run this again\.$/\1/p' <<<"$OUT")
	else
		_ST_OUT_HAS "a file holding that landing names the later one" "^ *h – ov-d's commit run .* (${OV_T2:0:7}\.\.[0-9a-f]*)$"
		_ST_OUT_LACKS "never the one on the old name" "on its old name"
		_ST_OUT_HAS "with the carry from before it alone" "Merge your edits onto what landed with 'git edit --carry=${OV_T2:0:12}', then run this again\.$"
		OV_CMD=$(sed -n "s/.*Merge your edits onto what landed with '\\(git edit --carry=[0-9a-f]*\\)', then run this again\\.$/\\1/p" <<<"$OUT")
	fi
	GIT_EDIT_ACTOR=ov-a _OV_FOLLOW "$OV_CMD"
	GIT_EDIT_ACTOR=ov-a _ST_RUN --commit --text "OV5 A" -- h
	_ST_EQ "followed as printed, the file lands with every landing ($OV_I)" "$RC:$(_OV_KEPT "$(git show HEAD:h)"):$([ -e f ] && print f)" "0:3:"
done

# Staged so, a fold names the unstaging too, the staging there kept – followed, it folds them all
_ST_PZ_NEW ov6
print -l "f line "{1..20} > f && print -r -- x > t && git add -A && git commit -qm "OV6 base"
OV_T0=$(git rev-parse HEAD)
print -l "f line 1 A-EDIT" "f line "{2..20} > f
GIT_EDIT_ACTOR=ov-b _ST_RUN --commit --text "OV6 B" --edits '{"f": [["f line 8\n", "f line 8 B\n"]]}'
GIT_EDIT_ACTOR=ov-c _ST_RUN --exec -- sh -c "git mv f h && git commit -qm 'OV6 C'"
GIT_EDIT_ACTOR=ov-d _ST_RUN --commit --text "OV6 D" --edits '{"h": [["f line 18\n", "f line 18 D\n"]]}'
_ST_PZ_C t y "OV6 target" && OV_TIP=$(git rev-parse HEAD)
mv f h && git add h
GIT_EDIT_ACTOR=ov-a _ST_RUN --amend-into="$OV_TIP" -- h
_ST_OUT_HAS "a staged fold names the unstaging, the move back and the carry" \
	"which leaves the rest of the staging as it is, with: git restore --staged -- h && \[ ! -e f \] && \[ ! -L f \] && mv -- h f && git edit --carry=${OV_T0:0:12}$"
_ST_OUT_HAS "and the staging again" "^  Then stage them again with: git add -- h "
OV_CMD=$(sed -n 's/.*which leaves the rest of the staging as it is, with: //p' <<<"$OUT")
GIT_EDIT_ACTOR=ov-a _OV_FOLLOW "$OV_CMD"
git add -- h
GIT_EDIT_ACTOR=ov-a _ST_RUN --amend-into="$OV_TIP" -- h
_ST_EQ "followed as printed, the fold keeps every landing" "$RC:$(_OV_KEPT "$(git show HEAD:h)")" "0:3"

# The move back checks the old name again as it runs – a file put there since stops it, kept – and
# with the old name taken, a directory or a file at the tip, the guard merges into the new name
for OV_I in 1 2 3; do
	_ST_PZ_NEW ov7-$OV_I
	print -l "f line "{1..20} > f && git add f && git commit -qm "OV7 base"
	print -l "f line 1 A-EDIT" "f line "{2..20} > f
	GIT_EDIT_ACTOR=ov-b _ST_RUN --commit --text "OV7 B" --edits '{"f": [["f line 8\n", "f line 8 B\n"]]}'
	GIT_EDIT_ACTOR=ov-c _ST_RUN --exec -- sh -c "git mv f h && git commit -qm 'OV7 C'"
	mv f h
	[ $OV_I = 2 ] && GIT_EDIT_ACTOR=ov-e _ST_RUN --exec -- sh -c "echo unrelated > f && git add f && git commit -qm 'OV7 E'"
	[ $OV_I = 3 ] && mkdir f && print -r -- kept > f/inside
	OV_T2=$(git rev-parse HEAD)
	GIT_EDIT_ACTOR=ov-d _ST_RUN --commit --text "OV7 D" --edits '{"h": [["f line 18\n", "f line 18 D\n"]]}'
	if [ $OV_I = 1 ]; then
		GIT_EDIT_ACTOR=ov-a _ST_RUN --commit --text "OV7 A" -- h
		OV_CMD=$(sed -n 's/.*where the carry takes the edits from, with: \(.*\) – then run this again\.$/\1/p' <<<"$OUT")
		print -r -- precious > f
		GIT_EDIT_ACTOR=ov-a _OV_FOLLOW "$OV_CMD"
		_ST_EQ "a file put at the old name since stops the move back as printed, kept" "$?:$(<f):$(_OV_KEPT "$(<h)")" "1:precious:1"
	else
		_ST_OUT_HAS "with the old name taken, a landing names the carry from its own old tip ($OV_I)" \
			"^Merge those edits onto the new content with: git edit --carry=${OV_T2:0:12}$"
		GIT_EDIT_ACTOR=ov-a _OV_FOLLOW "git edit --carry=${OV_T2:0:12}"
	fi
	GIT_EDIT_ACTOR=ov-a _ST_RUN --commit --text "OV7 A" -- h
	_ST_EQ "the file committed whole then refuses ($OV_I)" "$RC" "1"
	_ST_OUT_LACKS "offering no move back ($OV_I)" "mv -- h f"
	_ST_OUT_HAS "but the merge into the new name ($OV_I)" "^  Merge what landed into the new name with: T=\$(mktemp -d) && git show [0-9a-f]* > .* && git merge-file -- h "
	OV_CMD=$(sed -n 's/^  Merge what landed into the new name with: //p' <<<"$OUT")
	GIT_EDIT_ACTOR=ov-a _OV_FOLLOW "$OV_CMD"
	GIT_EDIT_ACTOR=ov-a _ST_RUN --commit --text "OV7 A" -- h
	# What the old name holds here and at the tip, each left as it was
	case $OV_I in 1) OV_PRE="precious:" ;; 2) OV_PRE=":unrelated" ;; 3) OV_PRE="kept:" ;; esac
	_ST_EQ "followed as printed, the file lands with every landing, the old name's own kept ($OV_I)" \
		"$RC:$(_OV_KEPT "$(git show HEAD:h)"):$(cat f f/inside 2>/dev/null):$(git show HEAD:f 2>/dev/null)" "0:3:$OV_PRE"
done

# Staged outside a sparse checkout, a fold withholds the unstaging, which would miss or unflag it –
# merged into the new name and staged again as printed, it folds every landing
if [[ "$(git add -h 2>&1)" == *(--|\])sparse\ * ]]; then
	_ST_PZ_NEW ov8
	mkdir x && print -l "f line "{1..20} > x/f && print -r -- x > t && git add -A && git commit -qm "OV8 base"
	_ST_PZ_C t y "OV8 target" && OV_TIP=$(git rev-parse HEAD)
	{ git sparse-checkout set --cone x || { git sparse-checkout init --cone && git sparse-checkout set x; }; } >/dev/null 2>&1
	print -l "f line 1 A-EDIT" "f line "{2..20} > x/f
	GIT_EDIT_ACTOR=ov-b _ST_RUN --commit --text "OV8 B" --edits '{"x/f": [["f line 8\n", "f line 8 B\n"]]}'
	GIT_EDIT_ACTOR=ov-c _ST_RUN --exec -- sh -c "mkdir -p y && git mv --sparse x/f y/h && git commit -qm 'OV8 C'"
	mkdir -p y && mv x/f y/h && git add --sparse y/h
	GIT_EDIT_ACTOR=ov-a _ST_RUN --amend-into="$OV_TIP" -- y/h
	_ST_OUT_LACKS "a staged fold outside the cone offers no unstaging" "git restore --staged"
	_ST_OUT_HAS "but the merge into the new name" "^  Merge what landed into the new name with: .* && git merge-file -- y/h "
	_ST_OUT_HAS "and the staging again, past the cone" "^  Then stage them again with: git add --sparse -- y/h "
	OV_CMD=$(sed -n 's/^  Merge what landed into the new name with: //p' <<<"$OUT")
	OV_HINT=$(sed -n 's/^  Then stage them again with: \(.*\) (each holding just what you staged).*$/\1/p' <<<"$OUT")
	GIT_EDIT_ACTOR=ov-a _OV_FOLLOW "$OV_CMD" && eval "$OV_HINT"
	GIT_EDIT_ACTOR=ov-a _ST_RUN --amend-into="$OV_TIP" -- y/h
	_ST_EQ "followed as printed, the fold keeps every landing" "$RC:$(_OV_KEPT "$(git show HEAD:y/h)")" "0:2"
	git sparse-checkout disable >/dev/null 2>&1
fi
