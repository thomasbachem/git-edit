# An `--edits` fold's replay resolves its own stops – each commit it stops at that holds every old
# text exactly once takes the edits in its own content, with no pause – and pauses as before at the
# first one that doesn't – and a one-pass replay's transient ref goes with its run, a killed run's
# at the next one's start
_ST_SCENARIO "\e[1;96m[204] --edits folds resolve their stops by replacement, a replay's transient ref goes with its run\e[0m"
local RR_T RR_O RR_P RR_WT RR_I RR_N RR_REAL RR_PID RR_DEAD
local -a RR_C

# Counts the last <n> commits of <new> whose <path> is not <old>'s with <from> replaced once by <to>
_RR_MISMATCHES () {
	# Args: <old tip> <new tip> <n> <path> <from> <to>
	local -i K BAD=0
	local O N
	for (( K = 0; K < $3; K++ )); do
		O=$(git cat-file blob "$1~$K:$4" 2>/dev/null; print -n x)
		N=$(git cat-file blob "$2~$K:$4" 2>/dev/null; print -n x)
		[ "${${O%x}/$5/$6}" = "${N%x}" ] || BAD+=1
	done
	print -r -- $BAD
}
# Prints the author, date and message of <tip>'s last <n> commits, byte for byte
_RR_META () {
	# Args: <tip> <n>
	git log --format='%an%x1f%ae%x1f%ad%x1f%B%x1e' --date=raw -n "$2" "$1"
}

# 50 commits each rewriting the line beside the old text – a replay stops at every one of them
_ST_PZ_NEW rr1
_ST_PZ_C init.txt i "RR1 init"
RR_P=$(git rev-parse HEAD)
print -l head "OLD LINE" "after 0" tail > f.sh && chmod +x f.sh && git add f.sh && git commit -qm "RR1 target"
RR_T=$(git rev-parse HEAD)
for RR_I in {1..50}; do
	print -l head "OLD LINE" "after $RR_I" tail > f.sh && git commit -qam "RR1 c$RR_I"
done
RR_O=$(git rev-parse HEAD)
_ST_RUN --amend-into="$RR_T" --edits '{"f.sh": [["OLD LINE\n", "NEW LINE\n"]]}'
_ST_EQ "a 50-deep --edits fold through commits beside its old text lands with no pause" "$RC" "0"
_ST_OUT_HAS "making the edits at each of its stops" 'Made the edits in the 51 commit(s) the replay stopped at'
_ST_EQ "every commit is its original content with the edit made" "$(_RR_MISMATCHES "$RR_O" HEAD 51 f.sh $'OLD LINE\n' $'NEW LINE\n')" "0"
_ST_EQ "authors, dates and messages kept, on the target's own parent" \
	"$(_RR_META HEAD 51 | git hash-object --stdin):$(git rev-parse HEAD~50^)" "$(_RR_META "$RR_O" 51 | git hash-object --stdin):$RR_P"
_ST_EQ "and the file's executable bit in every one" "$(git log --format=%H -n 51 HEAD | while read -r RR_I; do git ls-tree "$RR_I" f.sh | cut -c1-6; done | sort -u)" "100755"
_ST_OUT_HAS "naming the amended commit" '  amended: [0-9a-f]* RR1 target'

# A commit that changed the old text pauses as before, the commits below replayed – a hook told of
# every commit the fold rewrote, through the pause
_ST_PZ_NEW rr2
_ST_PZ_C init.txt i "RR2 init"
print -l a "v=1" b c d e f g h z0 > f.txt && git add f.txt && git commit -qm "RR2 target"
RR_T=$(git rev-parse HEAD)
RR_C=()
for RR_N in "z0/z1" "z1/z2" "v=1/v=2" "z2/z3" "v=2/v=1" "z3/z4"; do
	sed "s/^${RR_N%/*}\$/${RR_N#*/}/" f.txt > f.new && mv f.new f.txt && git commit -qam "RR2 c$(( ${#RR_C} + 1 ))"
	RR_C+=("$(git rev-parse HEAD)")
done
RR_O=$(git rev-parse HEAD)
printf '#!/bin/sh\ncat >> "%s/rr2.rewrites"\n' "$TMP" > .git/hooks/post-rewrite && chmod +x .git/hooks/post-rewrite
: >| "$TMP/rr2.rewrites"
_ST_RUN --amend-into="$RR_T" --edits '{"f.txt": [["v=1\n", "v=9\n"]]}'
RR_WT=$(_ST_PZ_WT)
_ST_EQ "a fold whose later commit changed the old text stops at that commit" \
	"$RC:$(git -C "${RR_WT:-$ST_NO_WT}" log -1 --format=%s REBASE_HEAD 2>/dev/null):$(git -C "${RR_WT:-$ST_NO_WT}" diff --name-only --diff-filter=U 2>/dev/null)" "2:RR2 c3:f.txt"
_ST_OUT_LACKS "resolving none of it" 'Made the edits in'
_ST_EQ "its stop holds what a replay holds there – the commit below with the edit made" \
	"$(git -C "${RR_WT:-$ST_NO_WT}" log -1 --format=%s HEAD 2>/dev/null):$(_RR_MISMATCHES "${RR_C[2]}" "$(git -C "${RR_WT:-$ST_NO_WT}" rev-parse HEAD 2>/dev/null)" 3 f.txt $'v=1\n' $'v=9\n'):$(git -C "${RR_WT:-$ST_NO_WT}" diff --name-only "${RR_C[2]}" HEAD 2>/dev/null)" \
	"RR2 c2:0:f.txt"
_ST_EQ "the branch untouched meanwhile" "$(git rev-parse HEAD)" "$RR_O"
_ST_RESOLVE "${RR_WT:-$ST_NO_WT}" f.txt "$(git show "${RR_C[3]}:f.txt")"
_ST_RUN --continue
_ST_EQ "resolved, it lands" "$RC:$(git show HEAD~6:f.txt | sed -n 2p):$(git show HEAD~4:f.txt | sed -n 2p):$(git show HEAD~3:f.txt | sed -n 2p)" "0:v=9:v=9:v=2"
_ST_EQ "the hook told of each commit once, old to new" \
	"$(cut -d' ' -f1 "$TMP/rr2.rewrites" 2>/dev/null | LC_ALL=C sort | tr '\n' ' '):$(cut -d' ' -f2 "$TMP/rr2.rewrites" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')" \
	"$(git rev-list -n 7 "$RR_O" | LC_ALL=C sort | tr '\n' ' '):$(git rev-list -n 7 HEAD | LC_ALL=C sort | tr '\n' ' ')"

# Several edits in one call, the second matching what the first made, in two files
_ST_PZ_NEW rr3
_ST_PZ_C init.txt i "RR3 init"
print -l a1 alpha "a2 0" > a.txt && print -l b1 beta "b2 0" > b.txt && git add . && git commit -qm "RR3 target"
RR_T=$(git rev-parse HEAD)
for RR_I in {1..8}; do
	print -l a1 alpha "a2 $RR_I" > a.txt && print -l b1 beta "b2 $RR_I" > b.txt && git commit -qam "RR3 c$RR_I"
done
RR_O=$(git rev-parse HEAD)
_ST_RUN --amend-into="$RR_T" --edits '{"a.txt": [["alpha\n", "ALPHA\n"], ["ALPHA\n", "ALPHA!\n"]], "b.txt": [["beta\n", "BETA\n"]]}'
_ST_EQ "several edits in one call, in turn, land with no pause" \
	"$RC:$(_RR_MISMATCHES "$RR_O" HEAD 9 a.txt $'alpha\n' $'ALPHA!\n'):$(_RR_MISMATCHES "$RR_O" HEAD 9 b.txt $'beta\n' $'BETA\n')" "0:0:0"
_ST_OUT_HAS "each stop resolved" 'Made the edits in the 9 commit(s) the replay stopped at'

# A file renamed in the span takes the edits under each name it had
_ST_PZ_NEW rr4
_ST_PZ_C init.txt i "RR4 init"
print -l h OLD "after 0" x1 x2 x3 x4 x5 x6 > old.txt && git add old.txt && git commit -qm "RR4 target"
RR_T=$(git rev-parse HEAD)
print -l h OLD "after 1" x1 x2 x3 x4 x5 x6 > old.txt && git commit -qam "RR4 c1"
git mv old.txt new.txt && print -l h OLD "after 1" x1 x2 x3 x4 x5 x6b > new.txt && git add new.txt && git commit -qm "RR4 c2 renames"
print -l h OLD "after 3" x1 x2 x3 x4 x5 x6b > new.txt && git commit -qam "RR4 c3"
RR_O=$(git rev-parse HEAD)
_ST_RUN --amend-into="$RR_T" --edits '{"new.txt": [["OLD\n", "NEW\n"]]}'
_ST_EQ "a file renamed in the span takes the edits under each name" \
	"$RC:$(_RR_MISMATCHES "$RR_O~2" HEAD~2 2 old.txt $'OLD\n' $'NEW\n'):$(_RR_MISMATCHES "$RR_O" HEAD 2 new.txt $'OLD\n' $'NEW\n')" "0:0:0"
_ST_EQ "the rename kept" "$(git diff-tree -r -M --name-status --no-commit-id HEAD~1 | cut -c1)" "R"
_ST_OUT_HAS "its stops under the old name resolved too" 'Made the edits in the 3 commit(s) the replay stopped at'

# A file stored with CRLF line ends keeps them
_ST_PZ_NEW rr5
_ST_PZ_C init.txt i "RR5 init"
printf 'a\r\nOLD\r\nafter 0\r\n' > c.txt && git add c.txt && git commit -qm "RR5 target"
RR_T=$(git rev-parse HEAD)
for RR_I in {1..5}; do
	printf 'a\r\nOLD\r\nafter %s\r\n' $RR_I > c.txt && git commit -qam "RR5 c$RR_I"
done
RR_O=$(git rev-parse HEAD)
_ST_RUN --amend-into="$RR_T" --edits '{"c.txt": [["OLD\r\n", "NEW\r\n"]]}'
_ST_EQ "a CRLF file takes the edits byte for byte" "$RC:$(_RR_MISMATCHES "$RR_O" HEAD 6 c.txt $'OLD\r\n' $'NEW\r\n')" "0:0"
_ST_EQ "its line ends kept" "$(git cat-file blob HEAD~5:c.txt | tr -cd '\r' | wc -c | tr -d ' ')" "3"

# A version holding the old text twice replays on – the copy it added kept as it was
_ST_PZ_NEW rr6
_ST_PZ_C init.txt i "RR6 init"
print -l h OLD "after 0" m1 m2 m3 m4 m5 m6 end > f.txt && git add f.txt && git commit -qm "RR6 target"
RR_T=$(git rev-parse HEAD)
print -l h OLD "after 1" m1 m2 m3 m4 m5 m6 end > f.txt && git commit -qam "RR6 c1"
print -l h OLD "after 1" m1 m2 m3 m4 m5 m6 end OLD > f.txt && git commit -qam "RR6 c2 copies"
print -l h OLD "after 1" m1 m2 M3 m4 m5 m6 end OLD > f.txt && git commit -qam "RR6 c3"
print -l h OLD "after 1" m1 m2 M3 m4 m5 m6 end > f.txt && git commit -qam "RR6 c4 drops the copy"
print -l h OLD "after 1" m1 m2 M3 m4 M5 m6 end > f.txt && git commit -qam "RR6 c5"
_ST_RUN --amend-into="$RR_T" --edits '{"f.txt": [["OLD\n", "NEW\n"]]}'
_ST_EQ "a version holding the old text twice replays on and lands" \
	"$RC:$(git show HEAD~5:f.txt | sed -n 2p):$(git show HEAD~4:f.txt | sed -n 2p):$(git show HEAD~3:f.txt | sed -n '2p;$p' | tr '\n' ' '):$(git show HEAD:f.txt | grep -c OLD)" \
	"0:NEW:NEW:NEW OLD :0"
_ST_OUT_HAS "the stops below it resolved" 'Made the edits in the 2 commit(s) the replay stopped at'
# A replay that never stops resolves nothing
_ST_PZ_NEW rr6b
print -l OLD x OLD y > f.txt && git add f.txt && git commit -qm "RR6b target"
RR_T=$(git rev-parse HEAD)
print -l OLD x z y > f.txt && git commit -qam "RR6b c1"
_ST_RUN --amend-into="$RR_T" --edits '{"f.txt": [["OLD\n", "NEW\n"]]}'
_ST_EQ "a replay running clean lands as before" "$RC:$(git show HEAD~1:f.txt | tr '\n' ' ')" "0:NEW x OLD y "
_ST_OUT_LACKS "resolving nothing" 'Made the edits in'

# The gate checks the fold per its tier, and a failure pauses with the result to resume
_ST_PZ_NEW rr7
_ST_PZ_C init.txt i "RR7 init"
print -l h OLD "after 0" > f.txt && git add f.txt && git commit -qm "RR7 target"
RR_T=$(git rev-parse HEAD)
for RR_I in {1..3}; do
	print -l h OLD "after $RR_I" > f.txt && git commit -qam "RR7 c$RR_I"
done
git config edit.verifyCmd 'grep -q NEW f.txt'
_ST_RUN --amend-into="$RR_T" --edits '{"f.txt": [["OLD\n", "NEW\n"]]}'
_ST_EQ "a fold the gate passes lands" "$RC:$(git show HEAD~3:f.txt | sed -n 2p)" "0:NEW"
_ST_OUT_HAS "checked at the default tier's commits" '^Verified 2 of 4 commit(s) with `grep -q NEW f.txt`'
RR_O=$(git rev-parse HEAD)
git config edit.verifyCmd '! grep -q BAD f.txt'
_ST_RUN --amend-into="$(git rev-parse HEAD~3)" --edits '{"f.txt": [["NEW\n", "BAD\n"]]}'
RR_WT=$(_ST_PZ_WT)
_ST_EQ "one it rejects pauses, the branch untouched" "$RC:$(git rev-parse HEAD):$(git -C "${RR_WT:-$ST_NO_WT}" show HEAD:f.txt 2>/dev/null | sed -n 2p)" "2:$RR_O:BAD"
_ST_OUT_HAS "as a verify pause" 'git-edit: paused – verify failed at'
_ST_RUN --no-verify --continue
_ST_EQ "and --no-verify --continue lands it" "$RC:$(git show HEAD~3:f.txt | sed -n 2p):$(git show HEAD:f.txt | sed -n 2p)" "0:BAD:BAD"
git config --unset edit.verifyCmd

# --text rewords the target, its stops resolved as well
_ST_PZ_NEW rr8
_ST_PZ_C init.txt i "RR8 init"
print -l h OLD "after 0" > f.txt && git add f.txt && git commit -qm "RR8 target"
RR_T=$(git rev-parse HEAD)
for RR_I in {1..3}; do
	print -l h OLD "after $RR_I" > f.txt && git commit -qam "RR8 c$RR_I"
done
_ST_RUN --amend-into="$RR_T" --text "RR8 target, reworded" --edits '{"f.txt": [["OLD\n", "NEW\n"]]}'
_ST_EQ "--text rewords the target, the stops resolved" "$RC:$(git log -1 --format=%s HEAD~3):$(git show HEAD~3:f.txt | sed -n 2p):$(git log -1 --format=%s HEAD)" \
	"0:RR8 target, reworded:NEW:RR8 c3"
_ST_OUT_HAS "naming what it replaced" '  replaced: RR8 target'
_ST_OUT_HAS "with no pause" 'Made the edits in the 4 commit(s) the replay stopped at'

# A one-pass replay's transient ref goes with a run a signal ends there – `git replay`, from 2.44
_ST_PZ_NEW rr10
_ST_PZ_C a.txt a "RR10 a"
for RR_I in {1..6}; do _ST_PZ_C "n$RR_I.txt" $RR_I "RR10 c$RR_I"; done
if [[ "$(LC_ALL=C command git replay -h 2>&1)" == *--advance* ]]; then
	RR_REAL=${commands[git]}
	mkdir -p "$TMP/rr10-shim"
	printf '#!/bin/sh\ncase " $* " in *" replay "*" --advance "*) if [ -e "%s/rr10-arm" ]; then rm -f "%s/rr10-arm"; : > "%s/rr10-in"; "%s/st-hold" "%s/rr10-go"; fi ;; esac\nexec "%s" "$@"\n' \
		"$TMP" "$TMP" "$TMP" "$TMP" "$TMP" "$RR_REAL" > "$TMP/rr10-shim/git"
	chmod +x "$TMP/rr10-shim/git"
	: >| "$TMP/rr10-arm"
	PATH="$TMP/rr10-shim:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text "RR10 a, reworded" "$(git rev-parse HEAD~6)" </dev/null > "$TMP/rr10.out" 2>&1 &
	RR_PID=$!
	RR_I=0; until [ -e "$TMP/rr10-in" ] || ! kill -0 $RR_PID 2>/dev/null || (( ++RR_I > 600 )); do sleep 0.1; done
	_ST_EQ "a reword's one-pass replay holds its transient ref" "$(git for-each-ref --format='%(refname)' refs/git-edit | sed 's/-[0-9]*$//')" "refs/git-edit/replay"
	kill -TERM $RR_PID 2>/dev/null
	: >| "$TMP/rr10-go"
	RR_I=0; while kill -0 $RR_PID 2>/dev/null && (( ++RR_I < 600 )); do sleep 0.1; done
	wait $RR_PID; RC=$?
	OUT=$(<"$TMP/rr10.out")
	_ST_EQ "a signal ending the run there takes the ref with it, nothing landed" \
		"$RC:$(git for-each-ref refs/git-edit | wc -l | tr -d ' '):$(git log -1 --format=%s HEAD~6)" "143:0:RR10 a"
fi
# One a run killed outright left goes at the next run's start, once its process is gone
sh -c 'exit 0' & RR_DEAD=$!
wait $RR_DEAD
git update-ref "refs/git-edit/replay-$RR_DEAD" HEAD && git update-ref "refs/git-edit/replay-$$" HEAD
_ST_RUN -M --text "RR10 c6, reworded" HEAD
_ST_EQ "a killed run's transient ref is swept at the next run, a live run's kept" \
	"$RC:$(git for-each-ref --format='%(refname)' refs/git-edit)" "0:refs/git-edit/replay-$$"
git update-ref -d "refs/git-edit/replay-$$"
cd "$TMP/repo"
