# A checkout's "brought" mark tells only what it was brought to, and every carry it names brings it:
# • A mark written before the checkout switched away and back counts as none, so a hand revert of a
#   line the switch brought stays – a mark kept across the checkout's own landings still counts
_ST_SCENARIO "\e[1;96m[220] a mark tells only what the checkout was brought to\e[0m"
local MK_X MK_T

# Makes and enters repo <name> with `f` of twelve lines and `g` of six, committed
_MK220_REPO () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	print -l l{1..12} > f && print -l g{1..6} > g && git add f g && git commit -qm "MK base"
	MK_X=$(git rev-parse HEAD)
}

# RC-1: the checkout switches away and back while another checkout of the branch lands – the mark
# still names the tip before, so the next sync read a hand revert of the landed line as a file the
# switch never brought and put the line back
_MK220_REPO mk1
_ST_RUN --commit --text "MK1 A" --edits='{"f": [["l11\n", "A11\n"]]}'
git switch -q -c mk1-feat
git worktree add -q -f "$TMP/mk1-x" main
( cd "$TMP/mk1-x" && _ST_RUN --commit --text "MK1 X" --edits='{"f": [["l2\n", "X2\n"]]}' )
git switch -q --ignore-other-worktrees main
print -l l{1..10} A11 l12 > f
_ST_RUN --commit --text "MK1 C" --edits='{"g": [["g5\n", "C5\n"]]}'
_ST_EQ "a hand revert after a switch away and back stays, though the mark predates the switch" \
	"$RC:$(sed -n 2p f):$(sed -n 5p g):$(git status --porcelain | tr '\n' ' ')" "0:l2:C5: M f "
git worktree remove --force "$TMP/mk1-x"
# Its own landings and undos keep it, though an undo moves its `HEAD` – a hand revert of a brought
# line stays
_MK220_REPO mk2
_ST_RUN --commit --text "MK2 A" --edits='{"f": [["l2\n", "A2\n"]]}'
_ST_RUN --commit --text "MK2 B" --edits='{"g": [["g2\n", "B2\n"]]}'
_ST_RUN --undo
print -l l{1..12} > f
_ST_RUN --commit --text "MK2 C" --edits='{"g": [["g5\n", "C5\n"]]}'
_ST_EQ "a mark the checkout's own landings and undos followed still counts, a hand revert kept" \
	"$RC:$(sed -n 2p f):$(tr -d '\n' < g):$(git status --porcelain | tr '\n' ' ')" "0:l2:g1B2g3g4C5g6: M f  M g "

# RC-4: a fold of staged content below a peer's landing on its file – the replay brings the landing
# into the commit, and the sync merges it into the file from what the fold read, which once took
# the entry alone and left the file taking the landing back
_MK220_FOLD () {
	# Args: <repo name> – the caller's commit of `f` line 7, a peer's of line 2 on top
	_MK220_REPO "$1"
	GIT_EDIT_ACTOR=mk-b _ST_RUN --commit --text "MK own f" --edits='{"f": [["l7\n", "B7\n"]]}'
	MK_X=$(git rev-parse HEAD)
	GIT_EDIT_ACTOR=mk-a _ST_RUN --commit --text "MK peer f" --edits='{"f": [["l2\n", "A2\n"]]}'
}
_MK220_FOLD mk3
print -l l1 l2 l{3..5} B6 B7 l{8..12} > f
git add f
GIT_EDIT_ACTOR=mk-b _ST_RUN --amend-into="$MK_X"
_ST_EQ "a staged fold below a peer's landing brings the landing into the file" \
	"$RC:$(tr -d '\n' < f):$(git status --porcelain | tr '\n' ' ')" "0:l1A2l3l4l5B6B7l8l9l10l11l12:"
# Edits made since on a line beside the landing's write nothing – named with the merge from what
# the fold read, the path recorded
_MK220_FOLD mk4
print -l l1 l2 l{3..5} B6 B7 l{8..12} > f
git add f
MK_T=$(git write-tree)
print -l l1 l2 W3 l4 l5 B6 B7 l{8..12} > f
GIT_EDIT_ACTOR=mk-b _ST_RUN --amend-into="$MK_X"
_ST_EQ "edits since conflicting with it stay as they were" \
	"$RC:$(tr -d '\n' < f):$(git show :f | sed -n 2p)" "0:l1l2W3l4l5B6B7l8l9l10l11l12:A2"
_ST_OUT_HAS "named with the merge from what the fold read" "cat-file --filters ${MK_T:0:12}:f > .* git merge-file -- f "
_ST_EQ "and recorded as left unbrought" "$(cut -f2 .git/git-edit-unbrought 2>/dev/null)" "f"
# A fold at the tip, its file edited since, keeps the edits – nothing merged, nothing named
_MK220_REPO mk5
print -l l1 l2 l{3..5} B6 l{7..12} > f
git add f
print -l l1 l2 l{3..5} B6 W7 l{8..12} > f
_ST_RUN --amend-into=HEAD
_ST_EQ "a fold at the tip keeps the file's later edits" \
	"$RC:$(sed -n 6p f):$(sed -n 7p f):$(git status --porcelain | tr '\n' ' ')" "0:B6:W7: M f "
_ST_OUT_LACKS "naming no merge" "git merge-file"
# Where the sync can't run, the file stays, its merge named
_MK220_FOLD mk6
print -l l1 l2 l{3..5} B6 B7 l{8..12} > f
git add f
MK_T=$(git write-tree)
GIT_EDIT_ACTOR=mk-b _ST_RUN_UNSYNCED --amend-into="$MK_X"
_ST_EQ "a fold whose sync can't run leaves the file" "$RC:$(sed -n 2p f)" "0:l2"
_ST_OUT_HAS "naming the merge that brings the replay's change in" "cat-file --filters ${MK_T:0:12}:f > .* git merge-file -- f "

# RC-2: an undo whose sync can't run names the bare carry, which brings the undo along – once, the
# walk read no undo as a step, so a mark at the undone tip counted as none, and a later landing
# moved it past the undo, leaving the undone land's file in the checkout, staged
_MK220_UNDONE () {
	# Args: <repo name> – a land of `side`'s line 2, then its undo with the index locked
	_MK220_REPO "$1"
	git switch -q -c side && print -l l1 S2 l{3..12} > f && git commit -qam "MK side" && git switch -q main
	_ST_RUN --land=side
	: > .git/index.lock
	_ST_RUN --undo
	rm -f .git/index.lock
}
_MK220_UNDONE mk7
_ST_OUT_HAS "an undo whose sync can't run names the bare carry" "edits merged onto it: git edit --carry$"
_ST_RUN --commit --text "MK7 C" --edits='{"g": [["g5\n", "C5\n"]]}'
_ST_EQ "the next landing's sync brings the undo along" \
	"$RC:$(sed -n 2p f):$(git status --porcelain | tr '\n' ' ')" "0:l2:"
_MK220_UNDONE mk8
git worktree add -q -f "$TMP/mk8-x" main
( cd "$TMP/mk8-x" && _ST_RUN --commit --text "MK8 C" --edits='{"g": [["g5\n", "C5\n"]]}' )
_ST_RUN --carry
_ST_EQ "as does the bare carry after another checkout's landing" \
	"$RC:$(sed -n 2p f):$(sed -n 5p g):$(git status --porcelain | tr '\n' ' ')" "0:l2:C5:"
git worktree remove --force "$TMP/mk8-x"
# An undone commit keeps what it landed, as before, a later landing leaving it
_MK220_REPO mk9
_ST_RUN --commit --text "MK9 A" --edits='{"f": [["l2\n", "A2\n"]]}'
: > .git/index.lock
_ST_RUN --undo
rm -f .git/index.lock
_ST_RUN --commit --text "MK9 C" --edits='{"g": [["g5\n", "C5\n"]]}'
_ST_EQ "an undone commit's content stays in the checkout past a later landing" "$RC:$(sed -n 2p f)" "0:A2"
# The branch's other checkout keeps its mark below an undo, as the walk goes on past one – its bare
# carry brings the landing before the undone one too
_MK220_REPO mk12
git switch -q -c side && print -l g1 S2 g{3..6} > g && git commit -qam "MK side" && git switch -q main
git worktree add -q -f "$TMP/mk12-o" main
_ST_RUN --commit --text "MK12 A" --edits='{"f": [["l10\n", "A10\n"]]}'
_ST_RUN --land=side
_ST_RUN --undo
_ST_RUN --commit --text "MK12 C" --edits='{"g": [["g5\n", "C5\n"]]}'
( cd "$TMP/mk12-o" && _ST_RUN --carry && print -r -- "$RC:$(sed -n 10p f):$(tr -d '\n' < g):$(git status --porcelain | tr '\n' ' ')" > "$TMP/mk12.got" )
_ST_EQ "another checkout's carry past an undo brings the landing before it too" "$(<"$TMP/mk12.got")" "0:A10:g1g2g3g4C5g6:"
git worktree remove --force "$TMP/mk12-o"

# RC-3: a checkout an older build left with a stale file – the first landing elsewhere wrote the
# mark final, though its sync never looked at that file, so the next landing on it merged the stale
# file as edited, taking the older landing back
_MK220_REPO mk10
print -l W1 g{2..6} > g
_ST_RUN_UNSYNCED --commit --text "MK10 old" --edits='{"g": [["g5\n", "O5\n"]]}'
rm -f .git/git-edit-brought
_ST_RUN --commit --text "MK10 f" --edits='{"f": [["l10\n", "L10\n"]]}'
_ST_EQ "a sync that never looked at a differing file leaves the mark held" "$(sed -n 1p .git/git-edit-brought | cut -d' ' -f3)" "held"
_ST_RUN --commit --text "MK10 g" --edits='{"g": [["g3\n", "N3\n"]]}'
_ST_EQ "so the next landing on the file brings the older landing along, the edit kept" \
	"$RC:$(tr -d '\n' < g):$(git status --porcelain | tr '\n' ' ')" "0:W1g2N3g4O5g6: M g "
_ST_EQ "a sync that looked at every differing file writes it final" "$(sed -n 1p .git/git-edit-brought | cut -d' ' -f3)" ""
# A clean checkout's first sync writes it final at once
_MK220_REPO mk11
_ST_RUN --commit --text "MK11 f" --edits='{"f": [["l10\n", "L10\n"]]}'
_ST_EQ "a clean checkout's first mark is final" "$(sed -n 1p .git/git-edit-brought | cut -d' ' -f3)" ""

# RC-5: the branch's other checkout whose mark a later landing moved on – past 40 landings, the walk
# no longer reaching it – once carried only the landings since, though its record names the file an
# earlier one left there: the bare carry takes the record's paths too
_MK220_REPO mk13
git worktree add -q -f "$TMP/mk13-x" main
print -l l{1..5} X6 l{7..12} > "$TMP/mk13-x/f"
_ST_RUN --commit --text "MK13 A" --edits='{"f": [["l2\n", "A2\n"]]}'
MK_T=$(git rev-parse HEAD)
_ST_RUN --commit --text "MK13 B" --edits='{"g": [["g5\n", "B5\n"]]}'
# Where 40 landings later the hold leaves it
print -r -- "refs/heads/main $MK_T held"$'\n'"$(git -C "$TMP/mk13-x" reflog show -n 1 --date=unix --format='%H%x09%gd%x09%gs' HEAD --)" \
	> "$(git -C "$TMP/mk13-x" rev-parse --path-format=absolute --git-path git-edit-brought)"
( cd "$TMP/mk13-x" && _ST_RUN --carry && print -r -- "$RC:$(tr -d '\n' < f):$(sed -n 5p g)" > "$TMP/mk13.got" )
_ST_EQ "a bare carry from a mark moved past an earlier landing brings the file its record names" \
	"$(<"$TMP/mk13.got")" "0:l1A2l3l4l5X6l7l8l9l10l11l12:B5"
git worktree remove --force "$TMP/mk13-x"

# RC-6: an entry a missed landing left on the mark – the index locked then – is no one's staging, so
# the next landing on the file merges both into the edits, where it once left the file staged and
# edited both
_MK220_REPO mk14
: > .git/index.lock
_ST_RUN --commit --text "MK14 A" --edits='{"f": [["l2\n", "A2\n"]]}'
rm -f .git/index.lock
print -l l{1..5} W6 l{7..12} > f
_ST_RUN --commit --text "MK14 B" --edits='{"f": [["l10\n", "B10\n"]]}'
_ST_EQ "an entry left on the mark merges the missed landing and this one into the edits" \
	"$RC:$(tr -d '\n' < f):$(git status --porcelain | tr '\n' ' ')" "0:l1A2l3l4l5W6l7l8l9B10l11l12: M f "
# One a re-sync took ahead to what landed merges from the mark as well, a hand revert kept
_MK220_REPO mk15
_ST_RUN --commit --text "MK15 A" --edits='{"f": [["l2\n", "A2\n"]]}'
_ST_RUN_UNSYNCED --commit --text "MK15 L1" --edits='{"f": [["l10\n", "L10\n"]]}'
print -l l{1..12} > f
_ST_RUN --commit --text "MK15 L2" --edits='{"g": [["g1\n", "D1\n"]]}'
_ST_EQ "an entry a re-sync took ahead merges from the mark, the hand revert kept" \
	"$RC:$(sed -n 2p f):$(sed -n 10p f):$(git status --porcelain | tr '\n' ' ')" "0:l2:L10: M f "

# V1-7: a rename's source outside a sparse checkout is named with the other paths outside it, never
# as come along
if _ST_SPARSE_RULES_OK; then
	_ST_PZ_NEW mk16
	mkdir in out && print -l l{1..3} > in/f && print -l r{1..3} > out/r && git add -A && git commit -qm "MK base"
	git sparse-checkout set --cone in
	_ST_RUN --exec -- sh -c 'git update-index --add --cacheinfo "100644,$(git rev-parse HEAD:out/r),in/r" && git update-index --force-remove out/r && git commit -qm "MK16 mv"'
	_ST_OUT_HAS "a rename's source outside the sparse checkout is named apart" "Outside your sparse checkout, no file written – their index entries now as they landed: out/r$"
	_ST_OUT_HAS "its destination inside it came along" "came along – now as they landed: in/r$"
fi
