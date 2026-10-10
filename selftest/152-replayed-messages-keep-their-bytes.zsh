# A commit a rebase-path mode replays keeps its message byte for byte – no trailing newline gained,
# trailing whitespace and blank lines kept, a `#`-led line too – resumed or not, whatever cleanup
# the caller configured, and no line git comments a message file with lands in one
_ST_SCENARIO "\e[1;96m[152] replayed commits keep their message bytes on every rebase path and resume\e[0m"
local CB_BASE CB_WT CB_X
local -A CB_SHA CB_SUBJ
CB_SUBJ=(x "CB target" nl "CB no newline" bl "CB blank lines" ws "CB trailing ws")
# Writes a commit on `HEAD` whose message is exactly <printf %b text>, <file> holding <content>,
# recorded under <key> in `CB_SHA`
_CB_MK () {
	# Args: <key> <message> <file> <content>
	local P=$(git rev-parse HEAD) T
	print -r -- "$4" > "$3" && git add -- "$3" && T=$(git write-tree)
	T=$(printf 'tree %s\nparent %s\nauthor C B <cb@x.invalid> 1700000000 +0000\ncommitter C B <cb@x.invalid> 1700000000 +0000\n\n%b' "$T" "$P" "$2" | command git hash-object -t commit -w --stdin)
	git update-ref "$(git symbolic-ref HEAD)" "$T" && git reset -q --hard
	CB_SHA[$1]=$T
}
# Puts <commit>'s message into `REPLY` as its bytes stand
_CB_BODY () {
	REPLY=$(git cat-file commit "$1"; print -n x)
	REPLY=${${REPLY%x}#*$'\n\n'}
}
# Checks the commit `HEAD` holds under <key>'s subject is a new one carrying the old one's message
_CB_KEPT () {
	# Args: <check> <key>
	local W N=$(git rev-list -1 --fixed-strings --grep="${CB_SUBJ[$2]}" HEAD)
	_CB_BODY "${CB_SHA[$2]}"; W=$REPLY; _CB_BODY "$N"
	_ST_EQ "$1" "$RC:${${N:#${CB_SHA[$2]}}:+rebuilt}:$REPLY" "0:rebuilt:$W"
}
# Checks no message from the base up holds a line git comments a message file with
_CB_CLEAN () {
	_ST_EQ "$1" "$(git log --format=%B "$CB_BASE..HEAD" | grep -c -e '^# Conflicts:' -e '^# This is ' -e '^# Please enter' -e '^# The commit message' -e '^# interactive rebase' -e '^# Lines starting')" "0"
}
# Makes repo `pz-<name>`: a base, the target `x` and three commits whose messages end unusually,
# each on its own file – or with <shared>, `x` and `nl` both on `f.txt`'s one line, with <abut> on
# its two abutting lines, neither building on the other – and `CB top` above them
_CB_FIX () {
	# Args: <name> [shared|abut]
	_ST_PZ_NEW "$1"
	if [ "$2" = abut ]; then _ST_PZ_C f.txt $'a\nb' "CB base"; else _ST_PZ_C f.txt a "CB base"; fi
	CB_BASE=$(git rev-parse HEAD)
	if [ "$2" = abut ]; then
		_CB_MK x 'CB target  \n\n#7 target ref\n\n' f.txt $'x\nb'
		_CB_MK nl 'CB no newline' f.txt $'x\nn'
	elif [ -n "$2" ]; then
		_CB_MK x 'CB target  \n\n#7 target ref\n\n' f.txt x
		_CB_MK nl 'CB no newline' f.txt n
	else
		_CB_MK x 'CB target  \n\n#7 target ref\n\n' x.txt x
		_CB_MK nl 'CB no newline' n.txt n
	fi
	_CB_MK bl 'CB blank lines\n\n\n\n' l.txt l
	_CB_MK ws 'CB trailing ws  \n\n#123 issue ref  \n' w.txt w
	_ST_PZ_C y.txt y "CB top"
}

# A drop replays what sits above it as it was
_CB_FIX cb1
_ST_RUN -d "${CB_SHA[x]}"
_CB_KEPT "a drop keeps a replayed message without a trailing newline" nl
_CB_KEPT "its trailing blank lines" bl
_CB_KEPT "and its trailing whitespace and # line" ws
# The caller's own cleanup changes nothing – `strip` would take the `#` lines
_CB_FIX cb2
git config commit.cleanup strip
_ST_RUN -d "${CB_SHA[x]}"
_CB_KEPT "as does a drop under the caller's commit.cleanup=strip" ws
git config --unset commit.cleanup
# A squash on the rebase path keeps its target's message, its fixup chain combining none, and the
# commits it replays above
_CB_FIX cb3
_ST_RUN -s "${CB_SHA[x]}" HEAD
_CB_KEPT "a -s keeps its target's message whole" x
_CB_KEPT "and the replayed ones" nl
_CB_KEPT "every one" ws
# While `--text` replaces the target's as given
_CB_FIX cb4
_ST_RUN -s "${CB_SHA[x]}" HEAD --text $'CB squashed\n\n#9 kept'
_CB_BODY "$(git rev-list -1 --fixed-strings --grep="CB squashed" HEAD)"
_ST_EQ "a -s --text takes its text as given, # line and all" "$RC:$REPLY" $'0:CB squashed\n\n#9 kept\n'
_CB_KEPT "and replays the others as they were" bl
# A reorder and a move
_CB_FIX cb5
_ST_RUN --reorder "${CB_SHA[bl]}" "${CB_SHA[nl]}"
_CB_KEPT "a reorder keeps a message without a trailing newline" nl
_CB_KEPT "and one ending on blank lines" bl
_CB_KEPT "and one ending on whitespace" ws
_CB_FIX cb6
_ST_RUN --move="$(git rev-parse HEAD)" --after="${CB_SHA[x]}"
_CB_KEPT "a move keeps a message without a trailing newline" nl
_CB_KEPT "and one ending on blank lines" bl
_CB_KEPT "and one ending on whitespace" ws
# A replant
_CB_FIX cb7
git checkout -q -b cb-up "$CB_BASE" && _ST_PZ_C u.txt u "CB up" && git checkout -q main
_ST_RUN --onto=cb-up
_CB_KEPT "a replant keeps every message it replays" x
_CB_KEPT "one without a trailing newline" nl
_CB_KEPT "one ending on blank lines" bl
# An edit's amend and its replay
_CB_FIX cb8
_ST_RUN -e "${CB_SHA[x]}"
CB_WT=$(_ST_PZ_WT)
[ -d "$CB_WT" ] && print x2 > "$CB_WT/x.txt"
_ST_RUN --continue
_CB_KEPT "an edit's amend keeps the commit's own message" x
_CB_KEPT "and its replay the ones above" nl
_CB_KEPT "every one" ws
_CB_FIX cb9
_ST_RUN -e "${CB_SHA[nl]}"
CB_WT=$(_ST_PZ_WT)
[ -d "$CB_WT" ] && print n2 > "$CB_WT/n.txt"
_ST_RUN --continue --text "CB edited"
_CB_BODY "$(git rev-list -1 --fixed-strings --grep="CB edited" HEAD)"
_ST_EQ "an edit's --text lands as given" "$RC:$REPLY" $'0:CB edited\n'
_CB_KEPT "its replay keeping the ones above" bl
# A fold into the target, its fixup combining no message
_CB_FIX cb10
print x2 > x.txt && git add x.txt
_ST_RUN --amend-into="${CB_SHA[x]}" -- x.txt
_CB_KEPT "a fold keeps its target's message" x
_CB_KEPT "and those it replays" nl
_CB_KEPT "every one" ws
_CB_CLEAN "no git comment line lands on a clean run"

# Resumed after a conflict, a replayed commit's own message lands, never git's conflict notes
_CB_FIX cb11 shared
_ST_RUN -d "${CB_SHA[x]}"
CB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$CB_WT" f.txt n
_ST_RUN --continue
_CB_KEPT "a drop's conflicted pick resumed keeps its message" nl
_CB_CLEAN "with no # Conflicts: line"
_CB_KEPT "and the picks after it theirs" ws
# A reorder whose both picks conflict, under the caller's commit.cleanup=strip – each stop resolved
# to its own commit's change alone
_CB_FIX cb12 abut
git config commit.cleanup strip
_ST_RUN --reorder "${CB_SHA[nl]}" "${CB_SHA[x]}"
CB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$CB_WT" f.txt $'a\nn'
_ST_RUN --continue
[ "$RC" = 2 ] && _ST_RESOLVE "$CB_WT" f.txt $'x\nn' && _ST_RUN --continue
git config --unset commit.cleanup
_CB_KEPT "a reorder's conflicted picks resumed keep a message without a trailing newline" nl
_CB_KEPT "and one ending on whitespace and a # line" x
_CB_CLEAN "with no git comment line"
# A fold conflicting on its target, then on the pick above it
_CB_FIX cb13 shared
print n2 > f.txt && git add f.txt
_ST_RUN --amend-into="${CB_SHA[x]}" -- f.txt
CB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$CB_WT" f.txt x2
_ST_RUN --continue
[ "$RC" = 2 ] && _ST_RESOLVE "$CB_WT" f.txt n2 && _ST_RUN --continue
_CB_KEPT "a fold resumed keeps its target's message" x
_CB_KEPT "and the conflicted pick's" nl
_CB_CLEAN "with no git comment line"
# A squash conflicting on its fixup, then on the pick above it
_CB_FIX cb14 shared
print t > f.txt && git add f.txt && git commit -qm "CB fix"
_ST_RUN -s "${CB_SHA[x]}" HEAD
CB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$CB_WT" f.txt x2
_ST_RUN --continue
[ "$RC" = 2 ] && _ST_RESOLVE "$CB_WT" f.txt t && _ST_RUN --continue
_CB_KEPT "a -s resumed keeps its target's message" x
_CB_KEPT "and the conflicted pick's" nl
_CB_CLEAN "with no git comment line"
# As with --text
_CB_FIX cb15 shared
print t > f.txt && git add f.txt && git commit -qm "CB fix"
_ST_RUN -s "${CB_SHA[x]}" HEAD --text "CB squashed"
CB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$CB_WT" f.txt x2
_ST_RUN --continue
[ "$RC" = 2 ] && _ST_RESOLVE "$CB_WT" f.txt t && _ST_RUN --continue
_CB_KEPT "a -s --text resumed keeps the conflicted pick's message" nl
_CB_BODY "$(git rev-list -1 --fixed-strings --grep="CB squashed" HEAD)"
_ST_EQ "its fold taking the text" "$REPLY" $'CB squashed\n'
_CB_CLEAN "with no git comment line"
# An edit whose replay conflicts
_CB_FIX cb16 shared
_ST_RUN -e "${CB_SHA[x]}"
CB_WT=$(_ST_PZ_WT)
[ -d "$CB_WT" ] && print x2 > "$CB_WT/f.txt"
_ST_RUN --continue
_ST_RESOLVE "$CB_WT" f.txt n
_ST_RUN --continue
_CB_KEPT "an edit's replay resumed keeps the conflicted pick's message" nl
_CB_KEPT "and the amended commit's" x
_CB_CLEAN "with no git comment line"
# A replant resumed, and one stepping over its conflicted commit
_CB_FIX cb17
git checkout -q -b cb-up "$CB_BASE" && _ST_PZ_C x.txt u "CB up" && git checkout -q main
_ST_RUN --onto=cb-up
CB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$CB_WT" x.txt x
_ST_RUN --continue
_CB_KEPT "a replant resumed keeps the conflicted pick's message" x
_CB_KEPT "and the ones after it" nl
_CB_CLEAN "with no git comment line"
_CB_FIX cb18
git checkout -q -b cb-up "$CB_BASE" && _ST_PZ_C x.txt u "CB up" && git checkout -q main
_ST_RUN --onto=cb-up
_ST_RUN --skip
_ST_EQ "a replant's --skip steps over the conflicted commit" "$RC:$(git log --format=%s | grep -c '^CB target$')" "0:0"
_CB_KEPT "keeping the messages after it" nl
_CB_KEPT "every one" ws

# A squash whose commits cancel each other out keeps its target's message on the empty commit
_ST_PZ_NEW cb19
_ST_PZ_C f.txt a "CB base"
CB_BASE=$(git rev-parse HEAD)
_CB_MK x 'CB target  \n\n#7 target ref\n\n' z.txt z
_CB_MK nl 'CB no newline' n.txt n
_ST_PZ_C z.txt z2 "CB fix one"
git rm -q z.txt && git commit -qm "CB fix two"
_ST_RUN -s "${CB_SHA[x]}" HEAD~1 HEAD
_ST_OUT_HAS "a squash cancelling out stays, empty" 'cancel each other out'
_CB_KEPT "keeping its target's message" x
_CB_KEPT "and the one it replays" nl
_CB_CLEAN "with no git comment line"

unfunction _CB_MK _CB_BODY _CB_KEPT _CB_CLEAN _CB_FIX
cd "$TMP/repo"
