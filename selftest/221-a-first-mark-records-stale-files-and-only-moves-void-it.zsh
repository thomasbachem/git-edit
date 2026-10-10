# A checkout's first mark ends the walk for every file, each file a landing left stale recorded:
# • A sync starting with no mark writes it final, recording each other file a landing left stale with
#   its base – uncommitted work no landing touched records nothing, so a hand revert stays
_ST_SCENARIO "\e[1;96m[221] a first mark records stale files, and only a move voids it\e[0m"
local RT_X RT_T RT_O

# Makes and enters repo <name> with `f` of twelve lines and `u` of six, committed
_RT221_REPO () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	print -l l{1..12} > f && print -l u{1..6} > u && git add f u && git commit -qm "RT base"
	RT_X=$(git rev-parse HEAD)
}

# RC2-1: a first sync beside another session's uncommitted file wrote the mark held for good, so the
# walk went on past it and read a hand revert of the newest landing's line as a file lacking it
_RT221_REPO rt1
print -l u1 u2 W3 u{4..6} > u
_ST_RUN --commit --text "RT1 A2" --edits='{"f": [["l2\n", "A2\n"]]}'
_ST_EQ "a first sync beside uncommitted work no landing touched writes the mark final" \
	"$(sed -n 1p .git/git-edit-brought | cut -d' ' -f3):$([ -s .git/git-edit-unbrought ] && echo recorded)" ":"
_ST_RUN --commit --text "RT1 A4" --edits='{"f": [["l4\n", "A4\n"]]}'
print -l l1 A2 l{3..12} > f
_ST_RUN --commit --text "RT1 C10" --edits='{"f": [["l10\n", "C10\n"]]}'
_ST_EQ "so a hand revert of the newest landing's line stays past the next landing" \
	"$RC:$(tr -d '\n' < f):$(git status --porcelain | tr '\n' ' ')" "0:l1A2l3l4l5l6l7l8l9C10l11l12: M f  M u "
# A file a landing before the mark left stale – an older git-edit's, which kept neither – is recorded
# with that landing, its edits kept, and the bare carry brings it along
_RT221_REPO rt2
print -l W1 u{2..6} > u
_ST_RUN_UNSYNCED --commit --text "RT2 old" --edits='{"u": [["u5\n", "O5\n"]]}'
RT_O=$(git rev-parse HEAD)
rm -f .git/git-edit-brought .git/git-edit-unbrought
_ST_RUN --commit --text "RT2 f" --edits='{"f": [["l10\n", "L10\n"]]}'
_ST_EQ "a first sync records a file an earlier landing left stale, with that landing and its base" \
	"$(sed -n 1p .git/git-edit-brought | cut -d' ' -f3):$(cut -d' ' -f3-5 .git/git-edit-unbrought 2>/dev/null):$(cut -f2 .git/git-edit-unbrought 2>/dev/null)" \
	":$RT_X $RT_O ${RT_X}:u"
_ST_RUN --status
_ST_OUT_HAS "--status names it with its carry" "lacking what landed past ${RT_X:0:7}: u – bring them along with: git edit --carry=${RT_X:0:12}$"
_ST_RUN --carry
_ST_EQ "the bare carry brings the recorded file along, its edits kept, the record cleared" \
	"$RC:$(tr -d '\n' < u):$([ -s .git/git-edit-unbrought ] && echo recorded)" "0:W1u2u3u4O5u6:"

# RC2-2: a `HEAD` reflog entry that moves nothing – an unstaging reset, a stash and its pop, a checkout
# of the branch it is on – voided the mark, so the bare carry the missed landings named brought only
# the last one, and `--status` named none
# Makes repo <name> whose checkout missed two landings, its sync unable to run, `u` edited
_RT221_MISSED () {
	# Args: <name>
	_RT221_REPO "$1"
	print -l u1 W2 u{3..6} > u
	_ST_RUN_UNSYNCED --commit --text "RR f" --edits='{"f": [["l2\n", "B2\n"]]}'
	_ST_RUN_UNSYNCED --commit --text "RR u" --edits='{"u": [["u5\n", "B5\n"]]}'
}
_RT221_MISSED rr1
git reset -q
_ST_RUN --carry
_ST_EQ "past an unstaging reset the bare carry brings both missed landings, the edit kept" \
	"$RC:$(sed -n 2p f):$(tr -d '\n' < u)" "0:B2:u1W2u3u4B5u6"
_RT221_MISSED rr2
git stash -q && git stash pop -q
_ST_RUN --status
_ST_OUT_HAS "past a stash and its pop --status names the mark" "left behind at ${RT_X:0:7}, .* git edit --carry$"
_RT221_MISSED rr3
git checkout -q main
_ST_RUN --status
_ST_OUT_HAS "as past a checkout of the branch it is on" "left behind at ${RT_X:0:7}, .* git edit --carry$"
_RT221_MISSED rr4
git reset -q --keep HEAD
_ST_RUN --status
_ST_OUT_HAS "and past a keeping reset to HEAD" "left behind at ${RT_X:0:7}, .* git edit --carry$"
# A switch away and back still voids it, as does a branch reset in place
_RT221_MISSED rr5
git switch -q -c rr5-side && git switch -q main
_ST_RUN --status
_ST_OUT_LACKS "a switch away and back still voids the mark" "left behind at"
_ST_OUT_HAS "--status ran" "no operation in flight"
_RT221_MISSED rr6
git checkout -q -B main HEAD
_ST_RUN --status
_ST_OUT_LACKS "as does a checkout resetting the branch in place" "left behind at"

# RC2-3: a staged fold below a peer's landing whose merge into the file conflicts recorded the tip
# before the fold, which holds the landing – `--status` named nothing, the bare carry had nothing to
# carry, and the guard named a carry from the tip the fold rewrote, which cleared the record
# Makes repo <name>: the caller's commit of `f` line 11, a peer's of line 2 on top, then the caller's
# fold of staging that predates the peer's, its file edited beside the peer's line
_RT221_FOLD () {
	# Args: <name> [<command running the fold>]
	_RT221_REPO "$1"
	GIT_EDIT_ACTOR=sf-b _ST_RUN --commit --text "SF own f" --edits='{"f": [["l11\n", "B11\n"]]}'
	RT_T=$(git rev-parse HEAD)
	GIT_EDIT_ACTOR=sf-a _ST_RUN --commit --text "SF peer" --edits='{"f": [["l2\n", "A2\n"]], "u": [["u2\n", "A2\n"]]}'
	print -l l{1..5} B6 l{7..10} B11 l12 > f
	git add f
	RT_O=$(git write-tree)
	print -l l1 l2 W3 l4 l5 B6 l{7..10} B11 l12 > f
	GIT_EDIT_ACTOR=sf-b ${2:-_ST_RUN} --amend-into="$RT_T" -- f
}
_RT221_FOLD sf1
_ST_EQ "the conflict records what the fold read, the base its printed merge uses" \
	"$RC:$(cut -d' ' -f5 .git/git-edit-unbrought 2>/dev/null):$(cut -f2 .git/git-edit-unbrought 2>/dev/null)" "0:$RT_O:f"
_ST_RUN --status
_ST_OUT_HAS "--status names that merge" "its edits conflicting with what landed: f – merge that in, markers and all, .*--filters ${RT_O:0:12}:f > "
_ST_RUN --carry
_ST_EQ "the bare carry merges from there, the conflict left as it was" "$RC:$(sed -n 2p f):$(sed -n 3p f)" "1:l2:W3"
_ST_OUT_HAS "named with that merge" "--filters ${RT_O:0:12}:f > "
GIT_EDIT_ACTOR=sf-b _ST_RUN --commit --text "SF rest" -- f
_ST_OUT_HAS "the guard refusing the file names the record's merge" "still sits on ${RT_O:0:7}, .*--filters ${RT_O:0:12}:f > "
_ST_OUT_LACKS "never a carry from the tip the fold rewrote" "--carry="
_ST_EQ "and refuses" "$RC:$(git log -1 --format=%s)" "1:SF peer"
# With no record, the guard names the merge from the landing's own old tip, which the fold replaced
rm -f .git/git-edit-unbrought
GIT_EDIT_ACTOR=sf-b _ST_RUN --commit --text "SF rest" -- f
_ST_OUT_HAS "with no record, the guard names the merge from the rewritten tip's file" "predates ${RT_T:0:7}, its landing replaced by a rewrite since – .*--filters ${RT_T:0:12}:f > "
_ST_OUT_LACKS "no carry there either" "--carry="
# A fold's own old tip is off the branch anyway – a checkout missing the fold still takes its carry
_RT221_REPO sf3
GIT_EDIT_ACTOR=sf-a _ST_RUN --commit --text "SF3 top" --edits='{"u": [["u1\n", "T1\n"]]}'
RT_T=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=sf-a _ST_RUN --amend-into="$RT_X" --edits='{"f": [["l2\n", "A2\n"]]}'
print -l l{1..11} M12 > f
GIT_EDIT_ACTOR=sf-b _ST_RUN --commit --text "SF3 mine" -- f
_ST_OUT_HAS "a checkout missing a fold is named the carry from the fold's old tip" "--carry=${RT_T:0:12}"
_ST_OUT_LACKS "not the merge for a landing a rewrite replaced" "replaced by a rewrite"
# A fold whose sync can't run records the file the same, its merge named
_RT221_FOLD sf2 _ST_RUN_UNSYNCED
_ST_EQ "a fold whose sync can't run records what it read" \
	"$RC:$(cut -d' ' -f5 .git/git-edit-unbrought 2>/dev/null):$(cut -f2 .git/git-edit-unbrought 2>/dev/null)" "0:$RT_O:f"
