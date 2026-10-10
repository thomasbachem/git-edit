# A move is re-synced or journaled for a run only where something proves that run died:
# • A revert staged by hand stays staged after a branch switch overwrote the checkout's mark, and
#   after an older build's move, with no mark at all or one naming the move before it
# • A killed run's journaled move is still re-synced – owed by its mark, or unmarked where it died
#   holding the journal's lock
# • An unjournaled move – an older build's, which journals it a moment later – is adopted only
#   once 15 s old or where a run died holding the lock, so no line is journaled twice
# • Two `--undo` runs over a journal holding a move twice take back two different runs
# • A lock or mark whose run could not read its start time holds while its pid lives
_ST_SCENARIO "\e[1;96m[208] re-syncs and adoptions need proof a run died, an undo passes over a repeat\e[0m"
local P8_OLD P8_NEW P8_M1 P8_BASE
# A journal lock a run left that died – its pid another process's since
local P8_DEAD="$$ Thu Jan 1 00:00:00 1970"
# Lands <path> as <content> on main as an older build does – the ref moved under `git edit: <label>`
# with the index re-synced, no mark written – journaling it where <journal> is 1, the reflog entry
# dated now where <fresh> is 1, else as the suite's clock has it, years ago
_P208_MOVE () {
	# Args: <path> <content> <label> <journal> <fresh>
	print -r -- "$2" > "$1" && git add -- "$1"
	P8_OLD=$(git rev-parse HEAD)
	P8_NEW=$(git commit-tree "$(git write-tree)" -p HEAD -m "P208 $3")
	if [ "$5" = 1 ]; then
		GIT_COMMITTER_DATE="@$EPOCHSECONDS +0000" command git update-ref -m "git edit: $3" refs/heads/main "$P8_NEW" "$P8_OLD"
	else
		git update-ref -m "git edit: $3" refs/heads/main "$P8_NEW" "$P8_OLD"
	fi
	[ "$4" = 1 ] && print -r -- "$EPOCHSECONDS refs/heads/main $P8_OLD $P8_NEW $3" >> .git/git-edit-journal
	return 0
}

# A branch switch in the checkout overwrites its mark with the other branch's move
_ST_PZ_NEW p8a
print -r -- a > F && print -r -- g > G && git add -A && git commit -qm "P208 base"
print -r -- b > F
_ST_RUN --commit --text "P208 F to b" -- F
git switch -q -c feat
print -r -- g2 > G
_ST_RUN --commit --text "P208 G on feat" -- G
git switch -q main
git checkout HEAD~1 -- F
_ST_RUN --status
_ST_OUT_LACKS "a branch switch's mark is no killed run" 'stopped before re-syncing'
_ST_EQ "a revert staged by hand after the switch stays staged" "$RC:$(git diff --cached --name-only):$(git show :F)" "0:F:a"

# An older build's move, no mark in the checkout at all
_ST_PZ_NEW p8b
print -r -- a > F && git add -A && git commit -qm "P208 base"
_P208_MOVE F b commit 1
git checkout HEAD~1 -- F
_ST_RUN --status
_ST_OUT_LACKS "an older build's move with no mark is no killed run" 'stopped before re-syncing'
_ST_EQ "a revert staged by hand after that move stays staged" "$RC:$(git diff --cached --name-only):$(git show :F)" "0:F:a"

# An older build's move after a landing whose mark names the move before it
_ST_PZ_NEW p8c
print -r -- a > F && git add -A && git commit -qm "P208 base"
print -r -- b > F
_ST_RUN --commit --text "P208 F to b" -- F
_P208_MOVE F c commit 1
git checkout HEAD~1 -- F
_ST_RUN --status
_ST_OUT_LACKS "an older build's move after a landing's mark is no killed run" 'stopped before re-syncing'
_ST_EQ "a revert staged by hand after the marked landing and that move stays staged" "$RC:$(git diff --cached --name-only):$(git show :F)" "0:F:b"
# Unmarked where the run that journaled it died holding the journal's lock – killed between its
# line and its mark – it is re-synced
_ST_PZ_NEW p8c2
print -r -- a > F && git add -A && git commit -qm "P208 base"
print -r -- b > F
_ST_RUN --commit --text "P208 F to b" -- F
_P208_MOVE F c commit 1
git reset -q "$P8_OLD" -- F
print -r -- "$P8_DEAD" > .git/git-edit-journal.lock
_ST_RUN --status
_ST_OUT_HAS "a move a run died journaling, its lock left, is re-synced" \
	"stopped before re-syncing the index: commit (${P8_OLD:0:7} → ${P8_NEW:0:7}) – index entries re-synced to it: F\$"
_ST_EQ "nothing left staged, the lock gone" "$(git diff --cached --name-only):$([ -e .git/git-edit-journal.lock ] && echo lock)" ":"

# An older build's move, unjournaled for the moment it takes to append its line
_ST_PZ_NEW p8d
print -r -- a > F && print -r -- g > G && git add -A && git commit -qm "P208 base"
P8_BASE=$(git rev-parse HEAD)
print -r -- b > F
_ST_RUN --commit --text "P208 M1" -- F
P8_M1=$(git rev-parse HEAD)
_P208_MOVE G g2 exec "" 1
git reset -q "$P8_OLD" -- G
_ST_RUN --status
_ST_OUT_LACKS "a fresh move no journal line holds yet is not adopted" 'journaled from the reflog'
_ST_EQ "its entry left to the run that is about to journal it" "$RC:$(grep -c . .git/git-edit-journal):$(git diff --cached --name-only)" "0:1:G"
# That run journals it and re-syncs its own entry
print -r -- "$EPOCHSECONDS refs/heads/main $P8_OLD $P8_NEW exec" >> .git/git-edit-journal
git reset -q -- G
_ST_RUN --status
_ST_EQ "journaled once" "$(grep -c " $P8_OLD $P8_NEW " .git/git-edit-journal)" "1"
_ST_RUN --undo
_ST_RUN --undo
_ST_EQ "two undos take back the older build's run and the one before it" "$RC:$(git rev-parse HEAD)" "0:$P8_BASE"
# One old enough that no older build is still about to journal it is adopted
_P208_MOVE G g3 exec "" ""
git reset -q "$P8_OLD" -- G
_ST_RUN --status
_ST_OUT_HAS "a move 15 s old no journal line holds is adopted" \
	"journaled from the reflog: exec (${P8_OLD:0:7} → ${P8_NEW:0:7}) – index entries re-synced to it: G\$"
_ST_EQ "one line for it, its entry re-synced" "$(grep -c " $P8_OLD $P8_NEW " .git/git-edit-journal):$(git diff --cached --name-only)" "1:"
# A fresh one whose run died holding the journal's lock is adopted at once
_P208_MOVE G g4 exec "" 1
print -r -- "$P8_DEAD" > .git/git-edit-journal.lock
_ST_RUN --status
_ST_OUT_HAS "a fresh move a run died holding the lock over is adopted at once" \
	"journaled from the reflog: exec (${P8_OLD:0:7} → ${P8_NEW:0:7})"

# A move journaled twice – an older build's line after another run adopted it – undone twice
_ST_PZ_NEW p8e
print -r -- a > F && git add -A && git commit -qm "P208 base"
P8_BASE=$(git rev-parse HEAD)
print -r -- b > F
_ST_RUN --commit --text "P208 M1" -- F
P8_M1=$(git rev-parse HEAD)
print -r -- c > F
_ST_RUN --commit --text "P208 M2" -- F
tail -1 .git/git-edit-journal >> .git/git-edit-journal
_ST_RUN --undo
_ST_EQ "a first undo takes back the repeated run" "$RC:$(git rev-parse HEAD)" "0:$P8_M1"
_ST_RUN --undo
_ST_OUT_LACKS "a second never reads its repeat as taken back by hand" 'already sat at'
_ST_EQ "but takes back the run before it" "$RC:$(git rev-parse HEAD)" "0:$P8_BASE"

# A run that could not read its own start time names it `-`, held while its pid lives – pid 1
_ST_EQ "a run whose start time can't be read marks its locks with -" \
	"$( _PID_START () { REPLY=""; }; _LOCK_MARK=""; _LOCK_MARK_SET; print -r -- "$_LOCK_MARK" )" "$$ -"
print -r -- "1 -" > "$TMP/p8-lock"
touch -t 202001010000 "$TMP/p8-lock"
_ST_EQ "its lock is no stale one past 60 s while that pid lives" "$(_LOCK_STALE "$TMP/p8-lock" && echo stale)" ""
print -r -- "refs/heads/main $P8_M1 $P8_BASE 1 -" > "$TMP/p8-mark"
_ST_EQ "nor is the re-sync its mark owes taken from it" "$(_RESYNC_OWED "$TMP/p8-mark" refs/heads/main "$P8_M1" "$P8_BASE"; print $?)" "1"
cd "$TMP/repo"
