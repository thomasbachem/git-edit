# At a terminal a pause asks rather than exits: Enter resumes it as `--continue` would, Escape
# twice cancels, q leaves it for later – and nothing ends it but a choice, a hangup leaving it too
_ST_SCENARIO "\e[1;96m[125] a terminal pause is a prompt\e[0m"
local PP_WT PP_TIP PP_PID PP_C
_ST_PZ_NEW pp1
_ST_PZ_C a.txt a "PP a"
_ST_PZ_C b.txt b "PP b"
_ST_PZ_C c.txt c "PP c"
PP_TIP=$(git rev-parse HEAD)
_ST_TTY_START -- HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	zpty -wn ST_TTY $'\e[A'
	_ST_TTY_AT 'Press Enter to continue' && zpty -wn ST_TTY q
fi
_ST_TTY_END
_ST_EQ "q leaves an edit paused" "$RC:$(git rev-parse HEAD)" "2:$PP_TIP"
_ST_OUT_HAS "an arrow key read as no answer, never as Escape" 'Press Enter to continue, Escape to cancel'
_ST_OUT_HAS "saying how to take it up" 'Left paused – resume with git edit --continue'
PP_WT=$(_ST_PZ_WT)
print -r -- b2 > "${PP_WT:-$ST_NO_WT}/b.txt"
_ST_TTY -- --continue
_ST_EQ "a terminal --continue lands it" "$RC:$(git show HEAD~1:b.txt)" "0:b2"
_ST_EQ "the checkout brought along" "$(<b.txt)" "b2"
# A hangup at the prompt leaves the pause, what was authored there kept for a later resume
PP_TIP=$(git rev-parse HEAD)
PP_C=$(git rev-parse HEAD~1)
_ST_TTY_START -- "$PP_C"
if _ST_TTY_AT 'Make your changes in'; then
	PP_WT=$(_ST_PZ_WT)
	print -r -- b3 > "${PP_WT:-$ST_NO_WT}/b.txt"
	PP_PID=$(ps -eo pid=,args= 2>/dev/null | command grep -F -- "$SELF $PP_C" | command grep -v grep | awk 'NR == 1 {print $1}')
	[ -n "$PP_PID" ] && kill -HUP "$PP_PID"
fi
_ST_TTY_END
_ST_EQ "a hangup at the prompt leaves the edit paused" "$RC:$(git rev-parse HEAD)" "129:$PP_TIP"
_ST_CHECK "what was authored there kept" grep -qx b3 "${PP_WT:-$ST_NO_WT}/b.txt"
_ST_RUN --continue
_ST_EQ "for a later --continue to land" "$RC:$(git show HEAD~1:b.txt)" "0:b3"
# A refused amend asks again, naming why, and the authored edit stays
printf '#!/bin/sh\necho "PP hook says no" >&2\nexit 1\n' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
_ST_TTY_START -- HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	PP_WT=$(_ST_PZ_WT)
	print -r -- b4 > "${PP_WT:-$ST_NO_WT}/b.txt"
	zpty -wn ST_TTY $'\r'
	_ST_TTY_AT 'to leave it paused' 2 && zpty -wn ST_TTY q
fi
_ST_TTY_END
_ST_OUT_HAS "a refused amend names its reason" 'Amend failed – nothing was applied: PP hook says no'
_ST_EQ "asking again rather than discarding the edit" "$RC:$(<"${PP_WT:-$ST_NO_WT}/b.txt")" "1:b4"
rm -f .git/hooks/pre-commit
_ST_RUN --continue
_ST_EQ "which lands once the hook lets it" "$RC:$(git show HEAD~1:b.txt)" "0:b4"
# A conflict at a terminal resolves at its prompt – Enter stages a file
# left without markers, never one still holding them
_ST_PZ_NEW pp2
_ST_PZ_C f.txt $'1\n2\n3' "PP2 base"
_ST_PZ_C f.txt $'1\n2x\n3' "PP2 x"
_ST_PZ_C f.txt $'1\n2xy\n3' "PP2 y"
_ST_TTY_START -- -d -y HEAD~1
if _ST_TTY_AT 'Resolve the conflicts in'; then
	zpty -wn ST_TTY $'\r'
	if _ST_TTY_AT 'Resolve the conflicts in' 2; then
		PP_WT=$(_ST_PZ_WT)
		print -r -- $'1\n2y\n3' > "${PP_WT:-$ST_NO_WT}/f.txt"
		zpty -wn ST_TTY $'\r'
	fi
fi
_ST_TTY_END
_ST_OUT_HAS "Enter on markers still there asks again" 'Conflict continues'
_ST_EQ "a resolved one lands" "$RC:$(git log --format=%s | tr '\n' ' '):$(tr '\n' ' ' < f.txt)" "0:PP2 y PP2 base :1 2y 3 "
_ST_OUT_HAS "naming what it staged" 'Staged as resolved: f.txt'
# Escape asks once more – a second Escape cancels, as the confirm before a drop does at once
PP_TIP=$(git rev-parse HEAD)
_ST_TTY_START -- -d HEAD
_ST_TTY_AT 'Press Enter to confirm' && zpty -wn ST_TTY $'\e'
_ST_TTY_END
_ST_EQ "Escape at a drop's confirm cancels" "$RC:$(git rev-parse HEAD)" "1:$PP_TIP"
_ST_OUT_HAS "saying nothing changed" 'Cancelled – nothing was changed'
_ST_EQ "leaving no worktree" "$(git worktree list | wc -l | tr -d ' ')" "1"
# The resume runs as a caller's own would – its environment as the caller had it, git -c and all,
# the tool's own config pins added once
_ST_PZ_NEW pp3
_ST_PZ_C a.txt a "PP3 a"
_ST_PZ_C b.txt b "PP3 b"
git config edit.verifyCmd 'test "$(printf %s "$GIT_CONFIG_PARAMETERS" | grep -o maintenance.auto | wc -l | tr -d " ")" = 1 && printf %s "$GIT_CONFIG_PARAMETERS" | grep -q pp3.caller'
_ST_TTY_START "GIT_CONFIG_PARAMETERS='pp3.caller=yes'" -- HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	PP_WT=$(_ST_PZ_WT)
	print -r -- a2 > "${PP_WT:-$ST_NO_WT}/a.txt"
	zpty -wn ST_TTY $'\r'
	_ST_TTY_AT 'to leave it paused' 2 && zpty -wn ST_TTY q
fi
_ST_TTY_END
_ST_EQ "the resume gets the caller's config and the pins once" "$RC:$(git show HEAD~1:a.txt)" "0:a2"
git config --unset edit.verifyCmd
# -m opens the editor on the message at the amend, at a terminal
printf '#!/bin/sh\nprintf "PP3 reworded\\n" > "$1"\n' > "$TMP/pp-editor"
chmod +x "$TMP/pp-editor"
_ST_TTY_START "GIT_EDITOR=$TMP/pp-editor" -- -m HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	zpty -wn ST_TTY $'\r'
	_ST_TTY_AT 'to leave it paused' 2 && zpty -wn ST_TTY q
fi
_ST_TTY_END
_ST_EQ "a terminal edit with -m takes the message from the editor" "$RC:$(git log -1 --format=%s HEAD~1)" "0:PP3 reworded"
# As does a squash with -m after a conflict, at the fold its resume reaches
_ST_PZ_NEW pp4
for PP_C in 1 2 3 4; do
	printf 'pp%s\n' {1..$PP_C} > pp.txt && git add pp.txt && git commit -qm "PP4 $PP_C"
done
_ST_TTY_START "GIT_EDITOR=$TMP/pp-editor" -- -s="$(git rev-parse HEAD~2)" -m -y HEAD
if _ST_TTY_AT 'Resolve the conflicts in'; then
	PP_WT=$(_ST_PZ_WT)
	print -r -- $'pp1\npp2\npp4' > "${PP_WT:-$ST_NO_WT}/pp.txt"
	zpty -wn ST_TTY $'\r'
	if _ST_TTY_AT 'Resolve the conflicts in' 2; then
		print -r -- $'pp1\npp2\npp3\npp4' > "${PP_WT:-$ST_NO_WT}/pp.txt"
		zpty -wn ST_TTY $'\r'
	fi
	_ST_TTY_AT 'to leave it paused' 3 && zpty -wn ST_TTY q
fi
_ST_TTY_END
_ST_EQ "a terminal squash with -m opens the editor at the fold its resume reaches" \
	"$RC:$(git log --format=%s | tr '\n' ' ')" "0:PP4 3 PP3 reworded PP4 1 "
# -C names where an edit's worktree goes, and it stays – the caller's path
_ST_RUN -C="$TMP/pp-c" HEAD~1
_ST_EQ "an edit pauses in the -C path" "$RC:$(_ST_PZ_WT)" "2:$TMP/pp-c"
print -r -- cx > "$TMP/pp-c/cx.txt"
_ST_RUN --continue
_ST_EQ "which lands from there" "$RC:$(git show HEAD~1:cx.txt)" "0:cx"
_ST_CHECK "and stays" test -d "$TMP/pp-c"
git worktree remove --force "$TMP/pp-c"
cd "$TMP/repo"
