# A printed carry starts from the earliest landing the file lacks, so one carry takes in every
# later one too: the landings guard reads an edit a later landing renamed away at its new name,
# and orders two landings of one second as journaled, while a landing that can't bring the
# checkout along names the carry from an earlier landing an edited file predates as well – once,
# each named the newest landing's old tip, and followed as printed took the earlier landing's edit
# back under `ok`
_ST_SCENARIO "\e[1;96m[183] a printed carry takes in every earlier landing the file lacks\e[0m"
local CB_T CB_TIP CB_L1 CB_RS CB_C CB_ADD CB_JF
local -i CB_NOW

# A staged fold over a file one landing edited and a later one renamed carries from the first
_ST_PZ_NEW cb1
print -l {1..10} > f.txt && print -r -- x > t.txt && git add -A && git commit -qm "CB1 base"
CB_T=$(git rev-parse HEAD)
print -l 1 2-A {3..10} > f.txt && git add f.txt
GIT_EDIT_ACTOR=cb-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c \
	"printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > f.txt && git commit -qam 'CB1 L1'" </dev/null >/dev/null 2>&1
GIT_EDIT_ACTOR=cb-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c \
	"git mv f.txt g.txt && printf '%s\n' 1 2 3 4 5-L1 6 7 8-B 9 10 > g.txt && git commit -qam 'CB1 L2'" </dev/null >/dev/null 2>&1
CB_TIP=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=cb-self _ST_RUN --amend-into="$CB_TIP"
_ST_EQ "a staged fold lacking an edit a later landing renamed refuses" "$RC" "1"
_ST_OUT_HAS "naming the earlier landing, renamed since" "f\.txt – cb-peer's exec run .*, a later run renaming it to g\.txt$"
_ST_OUT_HAS "and the carry from its old tip" "Then merge what landed into the checkout with 'git edit --carry=${CB_T:0:12}'"
CB_RS=$(grep -o -e 'git restore --staged -- [^ ]*$' <<<"$OUT" | head -1)
CB_C=$(grep -o -e '--carry=[0-9a-f]*' <<<"$OUT" | head -1)
CB_ADD=$(grep -o -e 'git add -- [^(]*' <<<"$OUT" | head -1)
eval "$CB_RS"
GIT_EDIT_ACTOR=cb-self _ST_RUN "$CB_C"
eval "$CB_ADD"
GIT_EDIT_ACTOR=cb-self _ST_RUN --amend-into="$CB_TIP"
_ST_EQ "followed as printed, the fold keeps both landings' edits" \
	"$RC:$(git show HEAD:g.txt | sed -n '2p;5p;8p' | tr '\n' ' ')" "0:2-A 5-L1 8-B "

# As does `--commit`, naming the file's new name for the run again
_ST_PZ_NEW cb2
print -l {1..10} > f.txt && print -r -- x > t.txt && git add -A && git commit -qm "CB2 base"
CB_T=$(git rev-parse HEAD)
print -l 1 2-A {3..10} > f.txt
GIT_EDIT_ACTOR=cb-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c \
	"printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > f.txt && git commit -qam 'CB2 L1'" </dev/null >/dev/null 2>&1
GIT_EDIT_ACTOR=cb-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c \
	"git mv f.txt g.txt && printf '%s\n' 1 2 3 4 5-L1 6 7 8-B 9 10 > g.txt && git commit -qam 'CB2 L2'" </dev/null >/dev/null 2>&1
GIT_EDIT_ACTOR=cb-self _ST_RUN --commit --text "CB2 mine" -- f.txt
_ST_OUT_HAS "a commit of it names the same carry, then the new name to commit" \
	"with 'git edit --carry=${CB_T:0:12}', then run this again naming g\.txt in place of f\.txt\.$"
CB_C=$(grep -o -e '--carry=[0-9a-f]*' <<<"$OUT" | head -1)
GIT_EDIT_ACTOR=cb-self _ST_RUN "$CB_C"
GIT_EDIT_ACTOR=cb-self _ST_RUN --commit --text "CB2 mine" -- g.txt
_ST_EQ "and followed as printed keeps both landings' edits" \
	"$RC:$(git show HEAD:g.txt | sed -n '2p;5p;8p' | tr '\n' ' ')" "0:2-A 5-L1 8-B "

# A file made after the first landing lacks only the rename's, which keeps its one-step carry
_ST_PZ_NEW cb3
print -l {1..10} > f.txt && print -r -- x > t.txt && git add -A && git commit -qm "CB3 base"
_ST_PZ_C t.txt y "CB3 target" && CB_T=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=cb-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c \
	"printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > f.txt && git commit -qam 'CB3 L1'" </dev/null >/dev/null 2>&1
CB_L1=$(git rev-parse HEAD)
print -l 1 2-A 3 4 5-L1 {6..10} > f.txt && git add f.txt
GIT_EDIT_ACTOR=cb-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c \
	"git mv f.txt g.txt && printf '%s\n' 1 2 3 4 5-L1 6 7 8-B 9 10 > g.txt && git commit -qam 'CB3 L2'" </dev/null >/dev/null 2>&1
GIT_EDIT_ACTOR=cb-self _ST_RUN --amend-into="$CB_T"
_ST_OUT_HAS "a fold holding the first landing names the rename's own carry" \
	"Then merge what landed into the checkout with 'git edit --carry=${CB_L1:0:12}'"
_ST_OUT_HAS "the rename named as the landing" "f\.txt – cb-peer's exec run .*, which renamed it to g\.txt$"

# Two landings of one second on two files:
# the carry starts from the one journaled first, whichever file reads first
_ST_PZ_NEW cb4
print -l {1..10} > a.txt && print -l {1..10} > b.txt && git add -A && git commit -qm "CB4 base"
CB_T=$(git rev-parse HEAD)
print -l 1 2-A {3..10} > a.txt && print -l 1 2-A {3..10} > b.txt
GIT_EDIT_ACTOR=cb-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c \
	"printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > b.txt && git commit -qam 'CB4 L1'" </dev/null >/dev/null 2>&1
GIT_EDIT_ACTOR=cb-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c \
	"printf '%s\n' 1 2 3 4 5 6 7 8-B 9 10 > a.txt && git commit -qam 'CB4 L2'" </dev/null >/dev/null 2>&1
CB_JF="$(git rev-parse --git-common-dir)/git-edit-journal" CB_NOW=$(date +%s)
sed -E "s/^[0-9]+ /$CB_NOW /" "$CB_JF" > "$CB_JF.x" && mv "$CB_JF.x" "$CB_JF"
GIT_EDIT_ACTOR=cb-self _ST_RUN --commit --text "CB4 mine" -- a.txt b.txt
_ST_OUT_HAS "a commit lacking both names the carry from the one journaled first" "with 'git edit --carry=${CB_T:0:12}', then run this again\.$"
CB_C=$(grep -o -e '--carry=[0-9a-f]*' <<<"$OUT" | head -1)
GIT_EDIT_ACTOR=cb-self _ST_RUN "$CB_C"
GIT_EDIT_ACTOR=cb-self _ST_RUN --commit --text "CB4 mine" -- a.txt b.txt
_ST_EQ "followed as printed, it keeps both" \
	"$RC:$(git show HEAD:a.txt | sed -n '2p;8p' | tr '\n' ' ')$(git show HEAD:b.txt | sed -n '2p;5p' | tr '\n' ' ')" "0:2-A 8-B 2-A 5-L1 "

# An agent's landing on a file whose edits predate an earlier landing too
# names the carry from that one's old tip
_ST_PZ_NEW cb5
print -l {1..10} > f.txt && git add -A && git commit -qm "CB5 base"
CB_T=$(git rev-parse HEAD)
print -l 1 2-A {3..10} > f.txt
GIT_EDIT_ACTOR=cb-p1 _ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > f.txt && git commit -qam 'CB5 L1'"
_ST_OUT_HAS "the first landing names its own old tip" "edits merged onto it: git edit --carry=${CB_T:0:12}$"
GIT_EDIT_ACTOR=cb-p2 _ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7 8-B 9 10 > f.txt && git commit -qam 'CB5 L2'"
_ST_OUT_HAS "and the next one the same, which the file predates too" "edits merged onto it: git edit --carry=${CB_T:0:12}$"
CB_C=$(grep -o -e '--carry=[0-9a-f]*' <<<"$OUT" | head -1)
GIT_EDIT_ACTOR=cb-p2 _ST_RUN "$CB_C"
_ST_EQ "followed as printed, the file keeps both landings and its edits" "$RC:$(sed -n '2p;5p;8p' f.txt | tr '\n' ' ')" "0:2-A 5-L1 8-B "
# One edited after the first lacks only the second
_ST_PZ_NEW cb6
print -l {1..10} > f.txt && git add -A && git commit -qm "CB6 base"
GIT_EDIT_ACTOR=cb-p1 _ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > f.txt && git commit -qam 'CB6 L1'"
CB_L1=$(git rev-parse HEAD)
print -l 1 2-A 3 4 5-L1 {6..10} > f.txt
GIT_EDIT_ACTOR=cb-p2 _ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7 8-B 9 10 > f.txt && git commit -qam 'CB6 L2'"
_ST_OUT_HAS "while a file edited on the first names the second's old tip" "edits merged onto it: git edit --carry=${CB_L1:0:12}$"
