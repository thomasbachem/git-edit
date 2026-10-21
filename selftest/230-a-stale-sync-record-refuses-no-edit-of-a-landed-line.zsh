# A sync record of a file merged by hand since refuses neither `--edits` editing
# a landed line nor the file whole – a file truly left unbrought refuses whole but takes
# `--edits` composed on the tip, and staging from before the hand merge refuses too
_ST_SCENARIO "\e[1;96m[230] a stale sync record refuses no edit of a landed line\e[0m"
local SR_X SR_T

# Makes and enters repo <name>: `f` of ten lines, a peer's landing of lines 3 and 7 on it,
# then the caller's edit of landed line 3 in the checkout, recorded as that landing left it
# – sets `SR_X` and `SR_T`, the tips before and after the landing
_SR230_REPO () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	print -l {1..10} > f && git add f && git commit -qm "SR base"
	SR_X=$(git rev-parse HEAD)
	GIT_EDIT_ACTOR=sr-peer _ST_RUN --commit --text "SR peer 3+7" --edits '{"f": [["3\n", "3P\n"], ["7\n", "7P\n"]]}'
	SR_T=$(git rev-parse HEAD)
	print -l 1 2 3P-C 4 5 6 7P 8 9 10 > f
	printf '%s refs/heads/main %s %s %s %s\tf\n' "$(date +%s)" "$SR_X" "$SR_T" "$SR_X" "$(git hash-object f)" > .git/git-edit-unbrought
}
export GIT_EDIT_ACTOR=sr-self

_SR230_REPO sr1
_ST_RUN --commit --text "SR1 edits" --edits '{"f": [["3P\n", "3P-C\n"]]}'
_ST_EQ "--edits of a landed line, the recorded file holding the landing so edited, lands" \
	"$RC:$(git show HEAD:f | tr '\n' ' '):$(git rev-parse HEAD~1)" "0:1 2 3P-C 4 5 6 7P 8 9 10 :$SR_T"

_SR230_REPO sr2
_ST_RUN --commit --text "SR2 whole" -- f
_ST_EQ "as does that file taken whole" "$RC:$(git show HEAD:f | tr '\n' ' '):$(git rev-parse HEAD~1)" "0:1 2 3P-C 4 5 6 7P 8 9 10 :$SR_T"

# A real record – the landing's sync conflicting with the checkout's edit of line 3
_ST_PZ_NEW sr3
print -l {1..10} > f && git add f && git commit -qm "SR3 base"
SR_X=$(git rev-parse HEAD)
print -l 1 2 3-mine {4..10} > f
GIT_EDIT_ACTOR=sr-peer _ST_RUN --exec -- sh -c "printf '%s\n' 1 2 3P 4 5 6 7P 8 9 10 > f && git commit -qam 'SR3 peer 3+7'"
SR_T=$(git rev-parse HEAD)
_ST_EQ "a landing whose sync conflicts with the edit records the file" "$(sed -n 3p f):$(cut -f2 .git/git-edit-unbrought 2>/dev/null)" "3-mine:f"
_ST_RUN --commit --text "SR3 whole" -- f
_ST_EQ "that file taken whole still refuses" "$RC:$(git rev-parse HEAD)" "1:$SR_T"
_ST_OUT_HAS "naming the record's merge" "still sits on ${SR_X:0:7}"
_ST_RUN --commit --text "SR3 edits back" --edits '{"f": [["3P\n", "3-mine\n"], ["7P\n", "7\n"]]}'
_ST_EQ "as do --edits composing that file" "$RC:$(git rev-parse HEAD)" "1:$SR_T"
_ST_OUT_HAS "naming the pairs, --base first" "Your change takes back what landed on f – what --edits compose there rewrites the landed lines: where that is meant pass --base as above, else merge what landed into the checkout file as below and build the change from it again, or leave out the part undoing them"
_ST_EQ "ahead of the checkout file's merge" "$(print -r -- "$OUT" | awk '/rewrites the landed lines: where/ { a = NR } /still sits on/ { b = NR } END { print (a && b > a ? "above" : "no") }')" above
cp f "$TMP/sr3-put"
_ST_RUN --commit --text "SR3 put back" --put "f=$TMP/sr3-put"
_ST_EQ "and that file put" "$RC:$(git rev-parse HEAD)" "1:$SR_T"
_ST_OUT_HAS "naming what was put" "What you put as f takes back what landed, rewriting the landed lines – where that is meant pass --base as above, else merge what landed into the checkout file as below and put it again"
_ST_EQ "ahead of the merge too" "$(print -r -- "$OUT" | awk '/rewriting the landed lines – where/ { a = NR } /still sits on/ { b = NR } END { print (a && b > a ? "above" : "no") }')" above
_ST_RUN --commit --text "SR3 edits" --edits '{"f": [["7P\n", "7P-C\n"]]}'
_ST_EQ "while --edits of a landed line, composed on the tip, lands" "$RC:$(git show HEAD:f | sed -n 3p):$(git show HEAD:f | sed -n 7p)" "0:3P:7P-C"

# Staging from before the landing refuses, its file merged by hand since – the staging is what folds
_ST_PZ_NEW sr4
print -l {1..10} > f && git add f && git commit -qm "SR4 base"
print -l 1 2 3-mine {4..10} > f && git add f
GIT_EDIT_ACTOR=sr-peer _ST_RUN --exec -- sh -c "printf '%s\n' 1 2 3P 4 5 6 7P 8 9 10 > f && git commit -qam 'SR4 peer 3+7'"
GIT_EDIT_ACTOR=sr-peer _ST_RUN --exec -- sh -c "echo g > g && git add g && git commit -qm 'SR4 target'"
SR_T=$(git rev-parse HEAD)
print -l 1 2 3P-mine 4 5 6 7P 8 9 10 > f && git hash-object -w f > /dev/null
_ST_RUN --amend-into="$SR_T" -- f
_ST_EQ "staging from before the landing refuses, its file merged by hand since" "$RC:$(git rev-parse HEAD)" "1:$SR_T"
export GIT_EDIT_ACTOR=
cd "$TMP/repo"
