# Every route composing a commit – whole files, puts, edits, patches, a fold's edits – takes the
# landings guard on the paths it changes:
# • A file a landing's sync left on its conflict takes that landing back, whatever route carries
#   it, until its owner changes the conflicting lines or it holds the landing – each refusal naming
#   the merge to run and `--base`, which takes it back on purpose
# • An edit or a patch built from a checkout file lacking a landing refuses as a whole file does,
#   while an edit made by hand on or beside a landed line lands as it always did
# • `--base` is taken beside edits alone, refusing a path changed since it
_ST_SCENARIO "\e[1;96m[215] every composed commit guards what another caller landed\e[0m"
local EG_T EG_X EG_B

# Lands eg-a's edit of line 3 while the checkout holds older edits of its own there, so the sync
# conflicts and leaves the file on its base
_EG215_SETUP () {
	# Args: <repo name> <the checkout's line 3>
	_ST_PZ_NEW "$1"
	print -l 1 2 3 4 5 > f.txt && print g > g.txt && git add -A && git commit -qm "EG base"
	EG_B=$(git rev-parse HEAD)
	print -l 1 2 "$2" 4 5 > f.txt
	touch -t 202601010000 f.txt
	GIT_EDIT_ACTOR=eg-a _ST_RUN --commit --text "EG A line 3" --edits '{"f.txt": [["3\n", "3A\n"]]}'
	EG_T=$(git rev-parse HEAD)
}

# The reproduced case: the file as it was, taken whole, as edits and a patch built from it, and put
_EG215_SETUP eg1 3B
_ST_EQ "the landing leaves the conflicting file as it was" "$RC:$(sed -n 3p f.txt)" "0:3B"
_ST_OUT_HAS "its sync says the next commit of the file is refused, by any route" 'its next commit of the file is refused, naming this merge'
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG B whole" -- f.txt
_ST_EQ "the file taken whole refuses" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
_ST_OUT_HAS "naming the merge its sync named" "git cat-file --filters ${EG_B:0:12}:f.txt > \"\$T/base\" && git cat-file --filters ${EG_T:0:12}:f.txt > \"\$T/landed\" && git merge-file -- f.txt"
_ST_OUT_HAS "and --base as the opt-out" "Pass --base=${EG_T:0:12} where taking it back is the point"
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG B edits" --edits '{"f.txt": [["3A\n", "3B\n"]]}'
_ST_EQ "edits built from it refuse" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
_ST_OUT_HAS "named as the edits' route" 'Changed by --edits, 1 file(s) would take back what another caller landed: f.txt'
_ST_OUT_HAS "naming the merge" 'git merge-file -- f.txt "$T/base" "$T/landed"'
_ST_OUT_HAS "and --base" "Pass --base=${EG_T:0:12}"
git diff HEAD -- f.txt > "$TMP/eg1.patch"
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG B patch" --patch "$TMP/eg1.patch"
_ST_EQ "a patch cut from it refuses" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
_ST_OUT_HAS "named as the patch's route" 'Changed by --patch, 1 file(s) would take back'
_ST_OUT_HAS "naming the merge" 'git merge-file -- f.txt "$T/base" "$T/landed"'
cp f.txt "$TMP/eg1-put"
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG B put" --put f.txt="$TMP/eg1-put"
_ST_EQ "a copy of it put refuses" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
_ST_OUT_HAS "naming the merge" 'git merge-file -- f.txt "$T/base" "$T/landed"'
_ST_OUT_LACKS "and not as a put that predates the tip" 'What you put predates what landed'
# Kept as it is on purpose
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG B keep mine" --base="$EG_T" -- f.txt
_ST_EQ "the owner's version lands with the tip as --base" "$RC:$(git show HEAD:f.txt | sed -n 3p)" "0:3B"

# Resolved by combining both sides on the line lands, by the merge named or by hand
_EG215_SETUP eg2 3B
print -l 1 2 3AB 4 5 > f.txt
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG2 B combined" -- f.txt
_ST_EQ "a file combining both sides on the line lands" "$RC:$(git show HEAD:f.txt | sed -n 3p)" "0:3AB"
_EG215_SETUP eg2e 3B
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG2 B combined edits" --edits '{"f.txt": [["3A\n", "3A and 3B\n"]]}'
_ST_EQ "as do edits combining them" "$RC:$(git show HEAD:f.txt | sed -n 3p)" "0:3A and 3B"
_EG215_SETUP eg2l 3B
print -l 1 2 3A 3B 4 5 > f.txt
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG2 B both lines" -- f.txt
_ST_EQ "and a file keeping both lines, the landed one among them" "$RC:$(git show HEAD:f.txt | sed -n 3,4p | tr '\n' ' ')" "0:3A 3B "

# An edit elsewhere in the file resolves nothing
_EG215_SETUP eg3 3B
print -l 1 2 3B 4 5X > f.txt
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG3 B elsewhere" -- f.txt
_ST_EQ "an edit elsewhere in the file still refuses" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG3 B elsewhere edits" --edits '{"f.txt": [["3A\n", "3B\n"], ["5\n", "5X\n"]]}'
_ST_EQ "as edits doing the same" "$RC:$(git rev-parse HEAD)" "1:$EG_T"

# A stale file lacking a landing, its edits apart from it, refuses through edits and a patch alike
_ST_PZ_NEW eg4
print -l 1 2 3 4 5 > f.txt && git add -A && git commit -qm "EG4 base"
print -l 1 2 3 4 5B > f.txt
GIT_EDIT_ACTOR=eg-a _ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1A 2 3 4 5 > f.txt && git commit -qam 'EG4 A line 1'"
EG_T=$(git rev-parse HEAD)
EG_X=$(git rev-parse HEAD~1)
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG4 B edits" --edits '{"f.txt": [["1A\n", "1\n"], ["5\n", "5B\n"]]}'
_ST_EQ "edits built from a file lacking a landing refuse" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
_ST_OUT_HAS "naming the carry that brings the file along" "bring the file along with 'git edit --carry=${EG_X:0:12}'"
git diff HEAD -- f.txt > "$TMP/eg4.patch"
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG4 B patch" --patch "$TMP/eg4.patch"
_ST_EQ "as does a patch cut from it" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
_ST_OUT_HAS "named as the patch's route" 'Changed by --patch, 1 file(s) would take back'
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG4 B line 5" --edits '{"f.txt": [["5\n", "5B\n"]]}'
_ST_EQ "while the edit alone lands" "$RC:$(git show HEAD:f.txt | tr '\n' ' ')" "0:1A 2 3 4 5B "

# Edits made by hand on and beside landed lines land, a deletion of an added one refuses
_ST_PZ_NEW eg5
print -l 1 2 3 4 5 > f.txt && git add -A && git commit -qm "EG5 base"
GIT_EDIT_ACTOR=eg-a _ST_RUN --commit --text "EG5 A line 3" --edits '{"f.txt": [["3\n", "3A\n"]]}'
GIT_EDIT_ACTOR=eg-a _ST_RUN --commit --text "EG5 A added" --edits '{"f.txt": [["5\n", "5\nadded\n"]]}'
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG5 B reword" --edits '{"f.txt": [["3A\n", "3X\n"]]}'
_ST_EQ "an edit rewording a landed line lands" "$RC:$(git show HEAD:f.txt | sed -n 3p)" "0:3X"
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG5 B beside" --edits '{"f.txt": [["4\n", "4X\n"]]}'
_ST_EQ "as does one beside it" "$RC:$(git show HEAD:f.txt | sed -n 4p)" "0:4X"
EG_T=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG5 B drop" --edits '{"f.txt": [["added\n", ""]]}'
_ST_EQ "a deletion of the line a landing added refuses" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
_ST_OUT_HAS "naming --base" "Pass --base=${EG_T:0:12} where taking it back is the point"
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG5 B drop" --edits '{"f.txt": [["added\n", ""]]}' --base="$EG_T"
_ST_EQ "and lands with the tip as --base" "$RC:$(git show HEAD:f.txt | grep -c added)" "0:0"

# --base beside edits alone, refusing a path changed since
EG_X=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG5 B base" --edits '{"f.txt": [["1\n", "1B\n"]]}' --base="$EG_X"
_ST_EQ "--base beside edits alone is taken" "$RC:$(git show HEAD:f.txt | sed -n 1p)" "0:1B"
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG5 B old base" --edits '{"f.txt": [["2\n", "2B\n"]]}' --base="$EG_X"
_ST_EQ "and refuses a path changed since it" "$RC:$(git show HEAD:f.txt | sed -n 2p)" "1:2"
_ST_OUT_HAS "naming the change between" 'Changed between --base .* so changed by --edits they would take that back: f.txt'

# A fold's edits are guarded as a commit's
_EG215_SETUP eg6 3B
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG6 B own" --edits '{"g.txt": [["g\n", "g-b\n"]]}'
EG_X=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=eg-b _ST_RUN --amend-into="$EG_X" --edits '{"f.txt": [["3A\n", "3B\n"]]}'
_ST_EQ "a fold's edits built from the file refuse" "$RC:$(git rev-parse HEAD)" "1:$EG_X"
_ST_OUT_HAS "naming the merge" 'git merge-file -- f.txt "$T/base" "$T/landed"'

# A file committed in stages from a checkout holding the finished version keeps it, each stage
# landing without a conflict to resolve, while a peer's stale edits on a file the same landing edits
# still conflict, recorded, and refuse its commit
_ST_PZ_NEW eg7
print -l 1 2 3 4 5 6 > f.txt && print -l 1 2 3 4 5 > h.txt && git add -A && git commit -qm "EG7 base"
print -l 1 2-final 3-final 4 5 6-final > f.txt
print -l 1 2 3P 4 5 > h.txt
touch -t 202601010000 f.txt h.txt
print -l 1 2-partial 3 4 5 6 > "$TMP/eg7-a"
print -l 1 2-final 3-partial 4 5 6 > "$TMP/eg7-b"
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG7 stage A" --put f.txt="$TMP/eg7-a" --edits '{"h.txt": [["3\n", "3A\n"]]}'
_ST_EQ "a first stage lands, the checkout keeping the finished file" "$RC:$(git show HEAD:f.txt | sed -n 2p):$(sed -n 2p f.txt)" "0:2-partial:2-final"
_ST_OUT_HAS "the file put named as keeping the later edits" 'keep your later edits, now changes to what landed: f\.txt$'
_ST_OUT_HAS "while the peer's file the edits changed conflicts" 'conflict with what landed – left as they were, as changes to it: h\.txt$'
_ST_OUT_LACKS "no merge offered for the file put" 'git merge-file -- f\.txt'
_ST_EQ "its index entry on what landed" "$(git rev-parse :f.txt)" "$(git rev-parse HEAD:f.txt)"
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG7 stage B" --put f.txt="$TMP/eg7-b"
_ST_EQ "a second stage lands" "$RC:$(git show HEAD:f.txt | sed -n 3p)" "0:3-partial"
_ST_OUT_LACKS "with no conflict reported" 'conflict with what landed'
GIT_EDIT_ACTOR=eg-b _ST_RUN --commit --text "EG7 the rest" -- f.txt
_ST_EQ "the rest lands whole, the tree holding the finished file" "$RC:$(git show HEAD:f.txt | tr '\n' ' ')" "0:1 2-final 3-final 4 5 6-final "
_ST_OUT_LACKS "again with no conflict reported" 'conflict with what landed'
_ST_EQ "and the record keeps the peer's file alone" "$(cut -f2 .git/git-edit-unbrought 2>/dev/null | tr '\n' ' ')" "h.txt "
EG_T=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=eg-c _ST_RUN --commit --text "EG7 peer h" -- h.txt
_ST_EQ "the peer's stale file refuses" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
_ST_OUT_HAS "naming the merge" 'git merge-file -- h.txt "$T/base" "$T/landed"'
