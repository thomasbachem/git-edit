# Each checkout keeps the tip its last sync or carry finished at, which tells an edit from a file a
# landing never brought:
# • An uncommitted edit putting a brought landing's file, or a line of it, back as before stays,
#   unstaged or staged, the next landing merged onto it – a file no landing brought still comes along
# • A landing whose sync can't run names the bare carry, which brings every landing the checkout
#   missed since, in it and in the branch's other checkout alike
# • A run stopped past its move leaves the mark, so the next landing's sync brings its file along –
#   a composed commit names the carry, stopped or killed, a plain one of the files as they stand none
# • A path left unbrought that a later landing renames merges from its record's base, an undo of a
#   landing whose sync conflicted finds no conflict, and a file the run put, edited or patched
#   keeps its later edits, merged cleanly or not, taking in only a landing its checkout never had
#   and what its commit's hooks made of it
# • A rename's source is no file taken out, paths outside a sparse checkout are named apart, a
#   peer's merge leaks no raw git line, and a run stopped inside its own index lock re-syncs
# • The branch's other checkout records the files a landing leaves there, so a commit taking the
#   landing back from there is refused
_ST_SCENARIO "\e[1;96m[216] a checkout keeps what it was brought to\e[0m"
local BR_X BR_P
local -i BR_K

# Makes and enters repo <name> with `f` of twelve lines and `g` of six, committed
_BR216_REPO () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	print -l l{1..12} > f && print -l g{1..6} > g && git add f g && git commit -qm "BR base"
	BR_X=$(git rev-parse HEAD)
}

# A hand revert of a brought landing's line stays as an edit, the next landing merged onto it – once,
# the walk read it as a file left at the tip before and put the landing back
_BR216_REPO br1
print -l l1 A2 l{3..12} > f
_ST_RUN --commit --text "BR1 A" -- f
print -l l{1..12} > f
_ST_RUN --commit --text "BR1 C" --edits='{"f": [["l10\n", "C10\n"]]}'
_ST_EQ "an unstaged edit taking a brought landing's line back stays, the next landing merged onto it" \
	"$RC:$(sed -n 2p f):$(sed -n 10p f):$(git show :f | sed -n 2p)" "0:l2:C10:A2"
# Staged, it stays staged so
_BR216_REPO br2
print -l l1 A2 l{3..12} > f
_ST_RUN --commit --text "BR2 A" -- f
git show "$BR_X:f" > f && git add f
_ST_RUN --commit --text "BR2 C" --edits='{"f": [["l10\n", "C10\n"]]}'
_ST_EQ "a staged one too, its staging kept with the landing merged in" \
	"$RC:$(sed -n 2p f):$(git show :f | sed -n 2p):$(git show :f | sed -n 10p)" "0:l2:l2:C10"
# As does one line of it beside an edit of the file's own
_BR216_REPO br3
_ST_RUN --commit --text "BR3 A" --edits='{"f": [["l2\n", "l2\nA-new\n"]]}'
print -l l{1..10} W11 l12 > f
_ST_RUN --commit --text "BR3 C" --edits='{"f": [["l6\n", "C6\n"]]}'
_ST_EQ "a line taken out of a brought landing stays out, the file's own edit kept" \
	"$RC:$(grep -c A-new f):$(sed -n 6p f):$(sed -n 11p f)" "0:0:C6:W11"
# A file a landing's sync left as it was still comes along with the next landing, though that one
# changes another file
_BR216_REPO br4
_ST_RUN --commit --text "BR4 A" --edits='{"g": [["g3\n", "A3\n"]]}'
_ST_RUN_UNSYNCED --commit --text "BR4 L1" --edits='{"f": [["l10\n", "L10\n"]]}'
_ST_EQ "a landing whose sync can't run leaves the file as it was" "$(sed -n 10p f)" "l10"
_ST_OUT_HAS "naming the bare carry" "edits merged onto it: git edit --carry$"
_ST_RUN --commit --text "BR4 L2" --edits='{"g": [["g1\n", "D1\n"]]}'
_ST_EQ "the next landing brings it along, the checkout clean" "$RC:$(sed -n 10p f):$(git status --porcelain)" "0:L10:"
# A file edited on the content before, with no mark, as an older build left the checkout, is
# brought along from where its walk tells
_BR216_REPO br5
_ST_RUN_UNSYNCED --commit --text "BR5 L1" --edits='{"f": [["l10\n", "L10\n"]]}'
rm -f .git/git-edit-brought
print -l l1 l2 W3 l{4..12} > f
_ST_RUN --commit --text "BR5 L2" --edits='{"f": [["l1\n", "D1\n"]]}'
_ST_EQ "with no mark, an edited file the landing before left comes along from its walk's base" \
	"$RC:$(sed -n 1p f):$(sed -n 3p f):$(sed -n 10p f)" "0:D1:W3:L10"

# Two landings whose syncs can't run, the index locked, each name the bare carry, which brings both
# – once, each named its own old tip, so the last printed left the first landing's file reverted
_BR216_REPO br6
print -l g1 W2 g{3..6} > g
: > .git/index.lock
_ST_RUN --commit --text "BR6 L1" --edits='{"f": [["l10\n", "L1\n"]]}'
_ST_RUN --commit --text "BR6 L2" --edits='{"g": [["g5\n", "L5\n"]]}'
rm -f .git/index.lock
_ST_OUT_HAS "a second landing the checkout missed names the bare carry" "edits merged onto it: git edit --carry$"
_ST_RUN --carry
_ST_EQ "which brings both landings along, the edit kept" \
	"$RC:$(sed -n 10p f):$(tr '\n' ' ' < g):$(git status --porcelain | tr '\n' ' ')" "0:L1:g1 W2 g3 g4 L5 g6 : M g "
_ST_RUN --carry
_ST_EQ "a bare carry once brought along has nothing to carry" "$RC:${OUT##*$'\n'}" "0:git-edit: ok – carried 0 path(s) across ${$(git rev-parse HEAD):0:7}..${$(git rev-parse HEAD):0:7}"
# The branch's other checkout too, its files left as they were by two landings from the first
_BR216_REPO br7
git worktree add -q -f "$TMP/br7-x" main
print -l g1 X2 g{3..6} > "$TMP/br7-x/g"
_ST_RUN --commit --text "BR7 L1" --edits='{"f": [["l10\n", "L1\n"]]}'
_ST_RUN --commit --text "BR7 L2" --edits='{"g": [["g5\n", "L5\n"]]}'
_ST_OUT_HAS "a landing names the other checkout's bare carry" "bring it along with git -C .*br7-x.* edit --carry$"
( cd "$TMP/br7-x" && _ST_RUN --carry && print -r -- "$RC:$(sed -n 10p f):$(tr '\n' ' ' < g)" > "$TMP/br7.got" )
_ST_EQ "which brings both landings along there" "$(<"$TMP/br7.got")" "0:L1:g1 X2 g3 g4 L5 g6 "
git worktree remove --force "$TMP/br7-x"

# A run stopped twice past its move leaves the checkout's mark, so the next landing's sync brings
# its file along, though that one changes another file
_BR216_REPO br8
_ST_RUN --commit --text "BR8 A" --edits='{"g": [["g3\n", "A3\n"]]}'
printf '#!/bin/sh\n[ "$1" = committed ] || exit 0\n[ -e "%s/br8-arm" ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\nrm -f "%s/br8-arm"\n: > "%s/br8-in"\n"%s/st-hold" "%s/br8-go"\n' \
	"$TMP" "$TMP" "$TMP" "$TMP" "$TMP" > .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
: > "$TMP/br8-arm"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --exec -- sh -c "sed 's/^l10\$/S10/' f > f.new && mv f.new f && git commit -qam 'BR8 S'" </dev/null >"$TMP/br8.out" 2>&1 &
BR_P=$!
BR_K=0; until [ -e "$TMP/br8-in" ] || ! kill -0 $BR_P 2>/dev/null || (( ++BR_K > 1200 )); do sleep 0.1; done
kill -TERM $BR_P
sleep 0.3
kill -TERM $BR_P
: > "$TMP/br8-go"
wait $BR_P
rm -f .git/hooks/reference-transaction
_ST_EQ "a run stopped twice past its move leaves the file as it was" "$(sed -n 10p f)" "l10"
_ST_RUN --commit --text "BR8 L2" --edits='{"g": [["g1\n", "D1\n"]]}'
_ST_EQ "the next landing brings it along" "$RC:$(sed -n 10p f):$(git status --porcelain)" "0:S10:"

# A commit composed from inputs, stopped twice past its move or killed there, names the carry – it
# never took the checkout's files – while a plain one of the files as they stand names none
_BR216_HOOK () {
	# Args: <name> – holds the first committed move of `main` till `$TMP/<name>-go`
	printf '#!/bin/sh\n[ "$1" = committed ] || exit 0\n[ -e "%s/%s-arm" ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\nrm -f "%s/%s-arm"\n: > "%s/%s-in"\n"%s/st-hold" "%s/%s-go"\n' \
		"$TMP" "$1" "$TMP" "$1" "$TMP" "$1" "$TMP" "$TMP" "$1" > .git/hooks/reference-transaction
	chmod +x .git/hooks/reference-transaction
	: > "$TMP/$1-arm"
}
# Runs `git edit <arg>...` held at its move by `_BR216_HOOK <name>`, sends it <signal>s, and lets it
# go, its output in `OUT`
_BR216_STOPPED () {
	# Args: <name> <signals> <arg>...
	local N=$1 S
	local -a SIGS=(${=2})
	shift 2
	_BR216_HOOK "$N"
	GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" "$@" </dev/null >"$TMP/$N.out" 2>&1 &
	BR_P=$!
	BR_K=0; until [ -e "$TMP/$N-in" ] || ! kill -0 $BR_P 2>/dev/null || (( ++BR_K > 1200 )); do sleep 0.1; done
	for S in "${SIGS[@]}"; do kill -$S $BR_P; sleep 0.3; done
	: > "$TMP/$N-go"
	wait $BR_P
	rm -f .git/hooks/reference-transaction
	OUT=$(<"$TMP/$N.out")
}
_BR216_REPO br9
_BR216_STOPPED br9 "TERM TERM" --commit --text "BR9 C" --edits='{"f": [["l10\n", "C10\n"]]}'
_ST_EQ "a composed commit stopped twice past its move names the carry" "$(print -r -- "$OUT" | tail -2 | head -1)" \
	"The checkout was not brought along before the stop – bring it along with: git edit --carry"
_BR216_REPO br9b
print -l l1 W2 l{3..12} > f
_BR216_STOPPED br9b "TERM TERM" --commit --text "BR9B C" -- f
_ST_EQ "a plain one of the files as they stand names none" "$(print -r -- "$OUT" | grep -c 'not brought along'):$(git show HEAD:f | sed -n 2p)" "0:W2"
_BR216_REPO br10
_BR216_STOPPED br10 KILL --commit --text "BR10 C" --edits='{"f": [["l10\n", "C10\n"]]}'
_ST_RUN --status
_ST_OUT_HAS "one killed past its move has the run adopting it name the carry" "^Its checkout was not brought along – bring it along with: git edit --carry$"

# A path left unbrought that a later landing renames merges from its record's base, the record going
# to the new name – once, it merged from the old tip, dropping the landing the record protected
_BR216_REPO br11
print -l l1 l2 l3 l4 W5 l{6..12} > f
_ST_RUN --commit --text "BR11 A" --edits='{"f": [["l5\n", "A5\n"]]}'
_ST_RUN --exec -- sh -c "git mv f h && git commit -qm 'BR11 rename'"
_ST_OUT_HAS "the rename's merge conflicts again" 'conflict with what landed.*f → h'
_ST_EQ "the new name as landed, the edits at the old, the record moved there" \
	"$(sed -n 5p h):$(sed -n 5p f):$(cut -f2 .git/git-edit-unbrought 2>/dev/null)" "A5:W5:h"

# An undo of a landing whose sync conflicted finds the file on its own target already – no conflict,
# and the edits' owner commits it after
_BR216_REPO br12
git branch -q br12-side
git worktree add -q "$TMP/br12-side" br12-side
print -l l1 l2 l3 l4 SIDE5 l{6..12} > "$TMP/br12-side/f" && git -C "$TMP/br12-side" commit -qam "BR12 side"
print -l l1 l2 l3 l4 W5 l{6..12} > f
_ST_RUN --land=br12-side
_ST_OUT_HAS "a land's sync conflicts with the edits" 'conflict with what landed'
_ST_RUN --undo
_ST_OUT_LACKS "its undo finds no conflict" 'conflict'
_ST_EQ "the edits kept" "$RC:$(sed -n 5p f)" "0:W5"
_ST_RUN --commit --text "BR12 W" -- f
_ST_EQ "which their owner commits" "$RC:$(git show HEAD:f | sed -n 5p)" "0:W5"
git worktree remove --force "$TMP/br12-side"

# A file the run put, holding what was put and later edits, takes its entry alone – one lacking a
# line the put brought merges it in, as any edit's file
_BR216_REPO br13
print -l l1 S2 l{3..9} S10 l11 l12 > f
print -l l1 S2 l3 l4 l5 l6 l7 l8 l9 l10 l11 l12 > "$TMP/br13-stage"
_ST_RUN --commit --text "BR13 stage" --put="f=$TMP/br13-stage" --base="$BR_X"
_ST_EQ "a put's file holding it keeps the caller's later edits" "$RC:$(tr '\n' ' ' < f)" "0:l1 S2 l3 l4 l5 l6 l7 l8 l9 S10 l11 l12 "
_ST_OUT_HAS "named as the caller's" '^Files you committed keep your later edits'
print -l l1 S2 l3 l4 l5 TMP6 l7 l8 l9 l10 l11 l12 > "$TMP/br13-stage"
_ST_RUN --commit --text "BR13 stage 2" --put="f=$TMP/br13-stage"
_ST_EQ "one lacking a line the put brought merges it in" "$RC:$(tr '\n' ' ' < f)" "0:l1 S2 l3 l4 l5 TMP6 l7 l8 l9 S10 l11 l12 "
_ST_OUT_HAS "named as merged" '^Uncommitted edits merged onto what landed: f$'

# A rename's source is no file taken out of the checkout
_BR216_REPO br14
_ST_RUN --exec -- sh -c "git mv f h && git commit -qm 'BR14 rename'"
_ST_EQ "a rename lands, the file at its new name" "$RC:$([ -e f ] || print gone):$(sed -n 1p h)" "0:gone:l1"
_ST_OUT_LACKS "its old name not listed as taken out" 'Taken out of your checkout'
# Paths outside a sparse checkout, whose entries alone came along, named apart
if _ST_SPARSE_RULES_OK; then
	_ST_PZ_NEW br15
	mkdir in out && print -l l{1..6} > in/f && print -l l{1..6} > out/f && git add -A && git commit -qm "BR15 base"
	git sparse-checkout set --cone in
	_ST_RUN --exec -- sh -c "printf 'x\n' > in/f && git add in/f && git update-index --cacheinfo \"100644,\$(printf 'y\n' | git hash-object -w --stdin),out/f\" && git commit -qm 'BR15 both'"
	_ST_OUT_HAS "a file in the cone came along" '^Your checkout came along – now as they landed: in/f$'
	_ST_OUT_HAS "one outside it named apart" '^Outside your sparse checkout, no file written – their index entries now as they landed: out/f$'
fi

# A peer's merge in progress leaks no raw git line into a landing's output
_BR216_REPO br16
git branch -q br16-other
print -l l1 l2 l3 l4 MAIN5 l{6..12} > f && git commit -qam "BR16 main"
git checkout -q br16-other && print -l l1 l2 l3 l4 OTHER5 l{6..12} > f && git commit -qam "BR16 other" && git checkout -q main
git merge -q br16-other >/dev/null 2>&1
_ST_RUN --exec -- sh -c "printf 'G\n' > g && git add g && git commit -qm 'BR16 g'"
_ST_EQ "a landing beside a peer's unmerged file lands" "$RC:$(git ls-files -u | wc -l | tr -d ' ')" "0:3"
_ST_OUT_LACKS "printing no raw 'needs merge'" 'needs merge'
git merge --abort 2>/dev/null

# A run stopped twice inside its sync's own index lock re-syncs its entries, never naming the index
# locked by another
_BR216_REPO br17
mkdir -p "$TMP/br17-git"
{
	print -r -- '#!/bin/sh'
	print -r -- "case \"\$GIT_INDEX_FILE\" in *index.git-edit.*) case \" \$* \" in *' read-tree -m -u '*) if [ -e ${(q)TMP}/br17-arm ]; then rm -f ${(q)TMP}/br17-arm; : > ${(q)TMP}/br17-in; ${(q)TMP}/st-hold ${(q)TMP}/br17-go; fi ;; esac ;; esac"
	print -r -- "exec ${(q)commands[git]} \"\$@\""
} > "$TMP/br17-git/git"
chmod +x "$TMP/br17-git/git"
: > "$TMP/br17-arm"
PATH="$TMP/br17-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "BR17 C" --edits='{"f": [["l10\n", "C10\n"]]}' </dev/null >"$TMP/br17.out" 2>&1 &
BR_P=$!
BR_K=0; until [ -e "$TMP/br17-in" ] || ! kill -0 $BR_P 2>/dev/null || (( ++BR_K > 1200 )); do sleep 0.1; done
kill -TERM $BR_P; sleep 0.3; kill -TERM $BR_P
: > "$TMP/br17-go"
wait $BR_P
OUT=$(<"$TMP/br17.out")
_ST_OUT_HAS "a run stopped twice inside its sync re-syncs its entries" 'stopped by SIGTERM after .* – index entries re-synced to it: f'
_ST_OUT_LACKS "never calling its own lock another's" 'index locked'

# The branch's other checkout records each file a landing leaves other than what landed, so a
# commit there taking the landing back is refused
_BR216_REPO br18
git worktree add -q -f "$TMP/br18-x" main
print -l l1 l2 B3 l{4..12} > "$TMP/br18-x/f"
GIT_EDIT_ACTOR=br-a _ST_RUN --commit --text "BR18 A" --edits='{"f": [["l3\n", "A3\n"]]}'
( cd "$TMP/br18-x" && GIT_EDIT_ACTOR=br-b _ST_RUN --commit --text "BR18 B" -- f && print -r -- "$RC:$(git show HEAD:f | sed -n 3p)" > "$TMP/br18.got"; print -r -- "$OUT" > "$TMP/br18.out" )
_ST_EQ "a whole commit there taking it back is refused" "$(<"$TMP/br18.got")" "1:A3"
OUT=$(<"$TMP/br18.out")
_ST_OUT_HAS "naming the merge" 'would take back what another caller landed: f$'
git worktree remove --force "$TMP/br18-x"

# A file an `--edits` commit took part of, the rest of the caller's edits beside the committed hunk,
# takes its entry alone – once, its sync called the file a conflict and left a merge to do
_BR216_REPO br19
print -l l1 l2 l3 E4 E5 E6 l{7..12} > f
_ST_RUN --commit --text "BR19 part" --edits='{"f": [["l5\n", "E5\n"]]}'
_ST_EQ "an edited path's file keeps the edits left uncommitted, its entry as landed" \
	"$RC:$(sed -n '4,6p' f | tr '\n' ' '):$(git show :f | sed -n '4,6p' | tr '\n' ' ')" "0:E4 E5 E6 :l4 E5 l6 "
_ST_OUT_HAS "named as the caller's" '^Files you committed keep your later edits'
_ST_OUT_LACKS "no conflict and no merge left to do" 'conflict with what landed\|Still to do'
# One whose file predates a landing its checkout never took brings that one in, up to the tip
# before the run alone, the run's own change held already
_BR216_REPO br20
_ST_RUN --commit --text "BR20 A" --edits='{"g": [["g3\n", "A3\n"]]}'
_ST_RUN_UNSYNCED --commit --text "BR20 L1" --edits='{"f": [["l10\n", "L10\n"]]}'
print -l l1 l2 l3 E4 E5 E6 l{7..12} > f
_ST_RUN --commit --text "BR20 part" --edits='{"f": [["l5\n", "E5\n"]]}'
_ST_EQ "an edited path predating a landing it lacks takes that landing in, its own edits kept" \
	"$RC:$(sed -n '4,6p;10p' f | tr '\n' ' '):$(git show :f | sed -n '4,6p;10p' | tr '\n' ' ')" "0:E4 E5 E6 L10 :l4 E5 l6 L10 "
_ST_OUT_LACKS "no conflict there either" 'conflict with what landed\|Still to do'
# A put whose commit's hook changed it brings the hook's change alone into the later stage the
# checkout holds
_BR216_REPO br21
printf '#!/bin/sh\nprintf "hooked\\n" >> f && git add f\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
print -l l1 S2 l{3..9} S10 l11 l12 > f
print -l l1 S2 l{3..12} > "$TMP/br21-stage"
_ST_RUN --commit --text "BR21 stage" --put="f=$TMP/br21-stage"
rm -f .git/hooks/pre-commit
_ST_EQ "a put its hook changed takes the hook's change into the later stage, nothing more" \
	"$RC:$(sed -n '2p;10p;13p' f | tr '\n' ' '):$(git show HEAD:f | sed -n '10p;13p' | tr '\n' ' ')" "0:S2 S10 hooked :l10 hooked "
_ST_OUT_LACKS "no conflict" 'conflict with what landed\|Still to do'
cd "$TMP/repo"
