# A run's sync and `--carry` are one implementation, bringing each file from the tip it was last
# brought to:
# • A file a landing brought along, then a later one took back, loses that landing's line under the
#   bare carry a landing names, from the checkout's mark – a peer's staging on it keeping the carry's
#   one base
# • A file a landing's sync left as it was keeps that landing's old tip on record: the next landing
#   merges from there, taking neither back, and the record clears once the file holds the landing
# • A file moved to its new name by hand takes the landings' edits from its old name
# • A file brought along at every landing merges from the move's own old tip, as before
# • A sync and a carry of one state end alike
# • A carry over twice the files starts no more git calls
# • A carry partway through a rebase names it and its step, and a run killed or stopped twice past
#   its move names the carry that brings its checkout along
_ST_SCENARIO "\e[1;96m[214] one carry brings each file along from its own base\e[0m"
local PB_X PB_Y PB_T PB_B PB_OLD PB_S PB_C PB_F PB_REAL=${commands[git]}
local -i PB_K PB_P PB_C1 PB_C2
local -a PB_GOT

# Sets up a file one landing brings along and a conflicting one it leaves, then a later landing
# taking the first back, its sync not run – the carry it names starting before both
_PB214_SETUP () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	print -l {1..10} > f.txt && print -l {1..10} > h.txt && print o > o.txt && git add -A && git commit -qm "PB base"
	PB_X=$(git rev-parse HEAD)
	print -l 1 2 3 4 5-mine {6..10} > h.txt
	GIT_EDIT_ACTOR=pb-peer _ST_RUN --exec -- sh -c "printf '%s\n' 1 2 3 4 5 6 7 8 9 10 a > f.txt && printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > h.txt && git commit -qam 'PB L1'"
	print -l 1 2-mine 3 4 5 6 7 8 9 10 a > f.txt
	GIT_EDIT_ACTOR=pb-peer _ST_RUN_UNSYNCED --exec -- sh -c 'git revert --no-edit HEAD >/dev/null'
}
# Writes a `reference-transaction` hook holding the first committed move of `main` once
# `$TMP/<name>-arm` is there, until `$TMP/<name>-go`, then noting it went on
_PB214_HOOK () {
	# Args: <name>
	printf '#!/bin/sh\n[ "$1" = committed ] || exit 0\n[ -e "%s/%s-arm" ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\nrm -f "%s/%s-arm"\n: > "%s/%s-in"\n"%s/st-hold" "%s/%s-go"\n: > "%s/%s-out"\n' \
		"$TMP" "$1" "$TMP" "$1" "$TMP" "$1" "$TMP" "$TMP" "$1" "$TMP" "$1" > .git/hooks/reference-transaction
	chmod +x .git/hooks/reference-transaction
	: > "$TMP/$1-arm"
}
# Waits up to 120 s for <file>, or for <pid> to end first
_PB214_WAIT () {
	# Args: <file> <pid>
	PB_K=0
	until [ -e "$1" ] || ! kill -0 "$2" 2>/dev/null || (( ++PB_K > 1200 )); do sleep 0.1; done
}

# A file the first landing brought along loses its line the second took back, under the bare carry
# named – another file, left by the first, merging from its record's base – the net change none
_PB214_SETUP pb1
_ST_EQ "the first landing brings one file along and leaves the conflicting one" "$(tail -1 f.txt):$(sed -n 5p h.txt)" "a:5-mine"
_ST_OUT_HAS "the second names the bare carry, from the checkout's mark" "edits merged onto it: git edit --carry$"
_ST_RUN --carry
_ST_EQ "followed, the file brought along in between loses the line taken back, its edit kept" \
	"$RC:$(tr '\n' ' ' < f.txt)" "0:1 2-mine 3 4 5 6 7 8 9 10 "
_ST_EQ "while the conflicting one keeps its edit, the landing gone from it too" "$(tr '\n' ' ' < h.txt)" "1 2 3 4 5-mine 6 7 8 9 10 "
_ST_OUT_HAS "named as carried" 'Carried onto the new content: f\.txt$'
# A peer's staging on the file keeps the one base, from before both – with no record or mark, as
# an older build leaves the checkout
_PB214_SETUP pb1s
git update-index --cacheinfo "100644,$(print -r -- PEER | git hash-object -w --stdin),f.txt"
: > .git/git-edit-unbrought
: > .git/git-edit-brought
_ST_RUN --carry="$PB_X"
_ST_EQ "a peer's staging on it keeps the carry's one base, the file as it was" "$RC:$(tail -1 f.txt):$(git show :f.txt)" "0:a:PEER"

# A conflict a landing's sync leaves records the file's base, which the next landing merges from –
# from the entry, now on what landed, its stale line would read as an edit taking the first back
_ST_PZ_NEW pb2
print -l {1..10} > f.txt && print o > o.txt && git add -A && git commit -qm "PB2 base"
PB_X=$(git rev-parse HEAD)
print -l 1 2 3-mine {4..10} > f.txt
GIT_EDIT_ACTOR=pb-a _ST_RUN --exec -- sh -c "printf '%s\n' 1 2 3-L1 4 5 6 7 8 9 10 > f.txt && git commit -qam 'PB2 L1'"
_ST_EQ "a conflicting landing leaves the file as it was, its entry on what landed" "$(sed -n 3p f.txt):$(git show :f.txt | sed -n 3p)" "3-mine:3-L1"
_ST_EQ "and records the landing's old tip as its base" \
	"$(cut -f2 .git/git-edit-unbrought 2>/dev/null):$(cut -f1 .git/git-edit-unbrought 2>/dev/null | cut -d' ' -f5)" "f.txt:$PB_X"
GIT_EDIT_ACTOR=pb-b _ST_RUN --exec -- sh -c "printf '%s\n' 1 2 3-L1 4 5 6 7 8-L2 9 10 > f.txt && git commit -qam 'PB2 L2'"
_ST_EQ "the next landing takes neither back, the file left as it was" "$RC:$(sed -n 3p f.txt):$(sed -n 8p f.txt)" "0:3-mine:8"
_ST_OUT_HAS "named as conflicting" 'conflict with what landed – left as they were, as changes to it: f\.txt$'
_ST_OUT_HAS "with its merge from the base on record" "git cat-file --filters ${PB_X:0:12}:f\.txt"
_ST_EQ "which keeps it" "$(cut -f1 .git/git-edit-unbrought 2>/dev/null | cut -d' ' -f5)" "$PB_X"
# Merged by hand, the next landing brings it along and the record clears
print -l 1 2-mine 3-L1 {4..7} 8-L2 9 10 > f.txt
GIT_EDIT_ACTOR=pb-c _ST_RUN --exec -- sh -c "printf '%s\n' 1 2 3-L1 4 5 6 7 8-L2 9 10-L3 > f.txt && git commit -qam 'PB2 L3'"
_ST_EQ "a file merged by hand comes along" "$RC:$(tr '\n' ' ' < f.txt)" "0:1 2-mine 3-L1 4 5 6 7 8-L2 9 10-L3 "
_ST_EQ "its record cleared" "$(cat .git/git-edit-unbrought 2>/dev/null | grep -c f.txt)" "0"

# A file moved to its new name by hand takes every landing's edits from its old name
_ST_PZ_NEW pb3
print -l "f line "{1..20} > f && print o > o.txt && git add -A && git commit -qm "PB3 base"
print -l "f line 1 MINE" "f line "{2..20} > f
GIT_EDIT_ACTOR=pb-b _ST_RUN_UNSYNCED --commit --text "PB3 B" --edits '{"f": [["f line 8\n", "f line 8 B\n"]]}'
GIT_EDIT_ACTOR=pb-c _ST_RUN_UNSYNCED --exec -- sh -c "git mv f h && git commit -qm 'PB3 C'"
mv f h
GIT_EDIT_ACTOR=pb-d _ST_RUN --commit --text "PB3 D" --edits '{"h": [["f line 18\n", "f line 18 D\n"]]}'
_ST_EQ "a landing brings a file moved by hand along from its old name, every landing kept" \
	"$RC:$(grep -cE 'MINE$| B$| D$' h):$([ -e f ] && print f)" "0:3:"

# A file brought along at every landing merges from the move's own old tip, as ever
_ST_PZ_NEW pb4
print -l {1..10} > f.txt && print o > o.txt && git add -A && git commit -qm "PB4 base"
print -l 1 2-mine {3..10} > f.txt
_ST_RUN --exec -- sh -c "printf '%s\n' 1 2 3 4 5 6 7 8-L1 9 10 > f.txt && git commit -qam 'PB4 L1'"
_ST_EQ "the first landing merges onto the file" "$(sed -n 2p f.txt):$(sed -n 8p f.txt)" "2-mine:8-L1"
PB_T=$(git rev-parse HEAD)
_ST_RUN --exec -- sh -c "printf '%s\n' 1 2 3 4-L2 5 6 7 8-L1 9 10 > f.txt && git commit -qam 'PB4 L2'"
_ST_EQ "and the next" "$(sed -n 2p f.txt):$(sed -n 4p f.txt):$(sed -n 8p f.txt)" "2-mine:4-L2:8-L1"
PB_T=$(git rev-parse HEAD)
_ST_RUN --exec -- sh -c "printf '%s\n' 1 2-L3 3 4-L2 5 6 7 8-L1 9 10 > f.txt && git commit -qam 'PB4 L3'"
_ST_OUT_HAS "a conflict at the third names the merge from that landing's own old tip" "git cat-file --filters ${PB_T:0:12}:f\.txt"
_ST_EQ "recording that tip" "$(cut -f1 .git/git-edit-unbrought 2>/dev/null | cut -d' ' -f5)" "$PB_T"
git checkout -q -- f.txt

# A sync and a carry of one state end alike – an untouched file, edits beside what landed and on it,
# a removed and an added file, a renamed one with edits
for PB_S in sync carry; do
	_ST_PZ_NEW "pb5-$PB_S"
	for PB_F in u e c r m; do print -l 1 2 3 4 5 > $PB_F.txt; done
	git add -A && git commit -qm "PB5 base"
	PB_OLD=$(git rev-parse HEAD)
	print -l 1 2 3 4 5-mine > e.txt && print -l 1 2 3-mine 4 5 > c.txt && print -l 1-mine 2 3 4 5 > m.txt
	PB_C="sed 's/^3\$/3-L/' u.txt > t && mv t u.txt && sed 's/^3\$/3-L/' e.txt > t && mv t e.txt && sed 's/^3\$/3-L/' c.txt > t && mv t c.txt"
	PB_C+=" && git mv m.txt n.txt && sed 's/^4\$/4-L/' n.txt > t && mv t n.txt && git rm -q r.txt && echo new > a.txt && git add -A && git commit -qm 'PB5 L'"
	if [ $PB_S = sync ]; then
		_ST_RUN --exec -- sh -c "$PB_C"
	else
		_ST_RUN_UNSYNCED --exec -- sh -c "$PB_C"
		_ST_RUN --carry="$PB_OLD"
	fi
	PB_GOT+=("$(for PB_F in u e c m n r a; do print -rn -- "$PB_F:$(tr '\n' ' ' < $PB_F.txt 2>/dev/null)|"; done);$(git status --porcelain | LC_ALL=C sort | tr '\n' '|');$(git ls-files -s | cut -d' ' -f2 | tr '\n' ' ')")
done
_ST_EQ "a sync and a carry of one state end alike" "${PB_GOT[1]}" "${PB_GOT[2]}"
_ST_EQ "each file as it should be, what conflicts left as it was" "${${PB_GOT[1]%;*}}" \
	"u:1 2 3-L 4 5 |e:1 2 3-L 4 5-mine |c:1 2 3-mine 4 5 |m:|n:1-mine 2 3 4-L 5 |r:|a:new |; M c.txt| M e.txt| M n.txt|"

# Twice the files a carry brings along start no more git calls – counted through a stand-in
mkdir -p "$TMP/pb-si"
{
	print -r -- '#!/bin/sh'
	print -r -- "echo \"\$1\" >> ${(q)TMP}/pb-si/log"
	print -r -- "exec ${(q)PB_REAL} \"\$@\""
} > "$TMP/pb-si/git"
chmod +x "$TMP/pb-si/git"
for PB_K in 8 16; do
	_ST_PZ_NEW "pb6-$PB_K"
	for (( PB_P = 1; PB_P <= PB_K; PB_P++ )); do print -l l1 l2 l3 > "f$PB_P.txt"; done
	print -r -- o > o.txt && git add -A && git commit -qm "PB6 base"
	PB_OLD=$(git rev-parse HEAD)
	_ST_RUN_UNSYNCED --exec -- sh -c 'for f in f*.txt; do echo more >> "$f"; done; git commit -qam "PB6 bulk"'
	: > "$TMP/pb-si/log"
	PATH="$TMP/pb-si:$PATH" _ST_RUN --carry="$PB_OLD"
	PB_GOT+=("$RC:$(grep -c . "$TMP/pb-si/log"):$(tail -1 f1.txt)")
done
PB_C1=${${PB_GOT[3]#*:}%%:*} PB_C2=${${PB_GOT[4]#*:}%%:*}
_ST_EQ "a carry of twice the files lands, starting no more git calls ($PB_C1, $PB_C2)" \
	"${PB_GOT[3]%%:*}:${PB_GOT[4]%%:*}:${PB_GOT[3]##*:}:$(( PB_C2 - PB_C1 < 4 ))" "0:0:more:1"

# A carry partway through a plain rebase names it, its branch and step, with the way on
_ST_PZ_NEW pb7
print -l 1 2 3 > f.txt && git add -A && git commit -qm "PB7 base"
git checkout -q -b side && print -l 1 side 3 > f.txt && git commit -qam "PB7 side" && print x > x.txt && git add x.txt && git commit -qm "PB7 side2"
git checkout -q main && print -l 1 main 3 > f.txt && git commit -qam "PB7 main"
git checkout -q side && git rebase main >/dev/null 2>&1
_ST_RUN --carry=main
_ST_EQ "a carry mid-rebase refuses" "$RC" "1"
_ST_OUT_HAS "naming the rebase, its branch and step, and the way on" \
	"halfway through a rebase of side, stopped at step 1 of 2, HEAD detached there – finish it with 'git rebase --continue' or abort it with 'git rebase --abort', then run --carry again"
_ST_OUT_LACKS "never a bare detached HEAD" 'HEAD is detached$'
git rebase --abort 2>/dev/null

# A run killed past its move, adopted by the next, names the carry its checkout needs, which brings
# it along as named
_ST_PZ_NEW pb8
printf 'f1\nf2\n' > F && print -r -- b > B.txt && git add -A && git commit -qm "PB8 base"
PB_X=$(git rev-parse HEAD)
_PB214_HOOK pb8
GIT_EDIT_ACTOR=A GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --exec -- sh -c "echo f3 >> F && git commit -qam 'PB8 f3'" </dev/null >/dev/null 2>&1 &
PB_P=$!
_PB214_WAIT "$TMP/pb8-in" $PB_P
kill -9 $PB_P
wait $PB_P
: > "$TMP/pb8-go"
_PB214_WAIT "$TMP/pb8-out" 0
rm -f .git/hooks/reference-transaction
GIT_EDIT_ACTOR=A _ST_RUN --status
_ST_OUT_HAS "the adopted move names the carry its checkout needs" "^Its checkout was not brought along – bring it along with: git edit --carry$"
_ST_RUN --carry
_ST_EQ "which brings it along" "$RC:$(tail -1 F):$(git status --porcelain)" "0:f3:"
# As does a run stopped twice past its move, right above its trailer
_ST_PZ_NEW pb9
printf 'f1\nf2\n' > F && print -r -- b > B.txt && git add -A && git commit -qm "PB9 base"
PB_X=$(git rev-parse HEAD)
_PB214_HOOK pb9
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --exec -- sh -c "echo f3 >> F && git commit -qam 'PB9 f3'" </dev/null >"$TMP/pb9.out" 2>&1 &
PB_P=$!
_PB214_WAIT "$TMP/pb9-in" $PB_P
kill -TERM $PB_P
sleep 0.3
kill -TERM $PB_P
: > "$TMP/pb9-go"
wait $PB_P
RC=$?
OUT=$(<"$TMP/pb9.out")
rm -f .git/hooks/reference-transaction
_ST_EQ "a second signal past the move stops the run" "$RC:$(tail -1 F)" "143:f2"
_ST_EQ "naming the carry right above its trailer" "$(print -r -- "$OUT" | tail -2 | head -1)" \
	"The checkout was not brought along before the stop – bring it along with: git edit --carry"
cd "$TMP/repo"
