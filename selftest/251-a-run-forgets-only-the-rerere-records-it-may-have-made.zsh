# Under `rerere.enabled=false` a run forgets only the records it may have made itself
# – one made while another scope stood open, a run live beside it or the pause in the slot,
# waits for that scope's end, the last to close forgetting it
_ST_SCENARIO "\e[1;96m[251] a run forgets only the rerere records it may have made\e[0m"
local R_RR R_BASE R_SIDE R_E R_F=f251f251f251f251f251f251f251f251f251f251
local -i R_I

# Runs `git edit <arg>...` in the side worktree under label `s-side`, into `OUT` and `RC`
_S251_SIDE () {
	OUT=$(cd "$R_SIDE" && GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=s-side "$SELF" "$@" </dev/null 2>&1)
	RC=$?
}
# Lists rr-cache's entries on one line
_S251_RR () {
	print -r -- ${(o)$(ls "$R_RR" 2>/dev/null)}
}
# Writes gate `$TMP/<name>.sh`, which stalls its first run until `$TMP/<name>.go` is there
# – `$TMP/<name>.in` saying it got there – making rr-cache entry <id> first, where one is named
_S251_GATE () {
	# Args: <name> [<id>]
	{
		print -r -- '#!/bin/sh'
		print -r -- "[ -e ${(q)TMP}/$1.go ] && exit 0"
		[ -n "$2" ] && print -r -- "mkdir -p ${(q)R_RR}/$2 && echo x > ${(q)R_RR}/$2/preimage && echo x > ${(q)R_RR}/$2/postimage"
		print -r -- ": > ${(q)TMP}/$1.in"
		print -r -- "${(q)TMP}/st-hold ${(q)TMP}/$1.go"
	} > "$TMP/$1.sh"
	chmod +x "$TMP/$1.sh"
}
# Starts a fold of `g.txt` holding <content> into main's `HEAD~2` in the background under label
# `s-main`, gated by `$TMP/<name>.sh`, and waits up to 60 s for the gate to stall
_S251_FOLD () {
	# Args: <name> <content>
	R_I=0
	print -r -- "$2" > g.txt && git add g.txt
	( env GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=s-main "$SELF" --amend-into="$(git rev-parse HEAD~2)" --verify="$TMP/$1.sh" -- g.txt \
		</dev/null >"$TMP/$1.out" 2>&1; print -r -- $? >"$TMP/$1.rc" ) &
	until [ -e "$TMP/$1.in" ] || [ -s "$TMP/$1.rc" ] || (( ++R_I > 600 )); do sleep 0.1; done
}
# Lets fold <name> go on and waits up to 60 s for it to end, into `OUT` and `RC`
_S251_END () {
	# Args: <name>
	R_I=0
	: > "$TMP/$1.go"
	until [ -s "$TMP/$1.rc" ] || (( ++R_I > 600 )); do sleep 0.1; done
	OUT=$(<"$TMP/$1.out")
	RC=$(<"$TMP/$1.rc")
}

_ST_PZ_NEW s251
git config rerere.enabled false
_ST_PZ_C f.txt $'1\n2\n3' "S251 c1" && _ST_PZ_C g.txt g1 "S251 g" && \
	_ST_PZ_C f.txt $'1\n2x\n3' "S251 c2" && _ST_PZ_C f.txt $'1\n2xy\n3' "S251 c3"
R_RR="$(git rev-parse --path-format=absolute --git-common-dir)/rr-cache"
git branch side
R_SIDE="$TMP/s251-side"
git worktree add -q "$R_SIDE" side
R_BASE=$(_S251_RR)

# A record a live run made stays where a pause open before it ends
_S251_SIDE -d -y "$(git rev-parse side~1)"
_ST_EQ "a drop pauses on side at its conflict" "$RC" "2"
R_E=$(_S251_RR)
_ST_CHECK "recording it" test "$R_E" != "$R_BASE"
_S251_GATE s251a "$R_F"
_S251_FOLD s251a g2
_S251_SIDE --abort
_ST_EQ "the side pause ends while a fold on main is live" "$RC" "0"
_ST_CHECK "its own record forgotten" test ! -e "$R_RR/${R_E##* }"
_ST_CHECK "the fold's record left for the fold" test -d "$R_RR/$R_F"
_S251_END s251a
_ST_EQ "the fold lands" "$RC:$(git show HEAD~2:g.txt)" "0:g2"
_ST_OUT_HAS "forgetting its record itself" "Forgot 1 resolution"
_ST_EQ "rr-cache back as it began" "$(_S251_RR)" "$R_BASE"

# A record the pause in the slot made while a run was live
# stays where that run lands, which forgets its own all the same
_S251_GATE s251b "$R_F"
_S251_FOLD s251b g3
_S251_SIDE -d -y "$(git rev-parse side~1)"
_ST_EQ "a drop pauses on side while a fold on main is live" "$RC" "2"
R_E=$(_S251_RR)
R_E=${${R_E/$R_F/}// /}
_S251_END s251b
_ST_EQ "the fold lands beside it" "$RC:$(git show HEAD~2:g.txt)" "0:g3"
_ST_OUT_HAS "forgetting its own record" "Forgot 1 resolution"
_ST_EQ "the pause's record kept" "$(_S251_RR)" "$R_E"
_S251_SIDE --abort
_ST_EQ "until the pause ends" "$(_S251_RR)" "$R_BASE"
_ST_EQ "no scope left registered" "$(ls "${R_RR:h}/git-edit-rerere" 2>/dev/null)" ""
git config --unset rerere.enabled
