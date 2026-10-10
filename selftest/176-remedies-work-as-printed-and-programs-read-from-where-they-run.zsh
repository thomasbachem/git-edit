# Remedies work as printed, programs read from where they run:
# • A staged fold over a file a landing renamed names the unstage its carry needs, lands as printed
# • A sparse-checkout flag with no patterns file leaves the checkout full, as git reads it
# • An `--exec` program is read from where the command runs, a refusal naming that place and the
#   name that works there, a failure from a subdirectory naming where it ran
_ST_SCENARIO "\e[1;96m[176] remedies work as printed, programs read from where they run\e[0m"
local AX_T AX_OLD AX_RS AX_C AX_ADD AX_MV AX_WHY

# A staged fold taking back a landing that renamed one of its files names the unstage the carry
# needs, the re-stage under the new name – once, the carry it named refused the staged old path,
# and the fold refused again as before
_ST_PZ_NEW ax1
print -l {1..10} > f.txt && print -l {1..10} > h.txt && print -r -- x > t.txt && git add -A && git commit -qm "AX1 base"
print -l 1 2-A {3..10} > f.txt && print -l 1 2-A {3..10} > h.txt && git add f.txt h.txt
GIT_EDIT_ACTOR=ax-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c \
	"git mv f.txt g.txt && printf '%s\n' 1 2 3 4 5 6 7 8-B 9 10 > g.txt && printf '%s\n' 1 2 3 4 5 6 7 8-B 9 10 > h.txt && git commit -qam 'AX1 B'" </dev/null >/dev/null 2>&1
# The target above the landing, which a fold below it would apply again
print -r -- y > t.txt && git commit -qm "AX1 target" -- t.txt && AX_T=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=ax-self _ST_RUN --amend-into="$AX_T"
_ST_EQ "a staged fold over a file a landing renamed refuses" "$RC" "1"
_ST_OUT_HAS "naming the unstage the carry needs first" 'unstage those first, the files kept as they are: git restore --staged -- f\.txt$'
_ST_OUT_HAS "then the carry, which stages the file kept again" "Then merge what landed into the checkout with 'git edit --carry=[0-9a-f]\{12\}', which stages h\.txt again as merged"
_ST_OUT_HAS "and the re-stage under the new name alone" 'Then stage them again with: git add -- g\.txt ('
AX_RS=$(grep -o -e 'git restore --staged -- [^ ]*$' <<<"$OUT" | head -1)
AX_C=$(grep -o -e '--carry=[0-9a-f]*' <<<"$OUT" | head -1)
AX_ADD=$(grep -o -e 'git add -- [^(]*' <<<"$OUT" | head -1)
eval "$AX_RS"
GIT_EDIT_ACTOR=ax-self _ST_RUN "$AX_C"
_ST_EQ "the carry then takes the renamed file along" "$RC:$(sed -n 2p g.txt):$(sed -n 8p g.txt):$([ -e f.txt ] && echo left)" "0:2-A:8-B:"
eval "$AX_ADD"
GIT_EDIT_ACTOR=ax-self _ST_RUN --amend-into="$AX_T"
_ST_EQ "followed as printed, the fold lands keeping what landed" \
	"$RC:$(git show HEAD:g.txt | sed -n 2p):$(git show HEAD:g.txt | sed -n 8p):$(git show HEAD:h.txt | sed -n 2p):$(git show HEAD:h.txt | sed -n 8p)" "0:2-A:8-B:2-A:8-B"
# A landing renaming nothing keeps the one-step carry
_ST_PZ_NEW ax1b
print -l {1..10} > h.txt && print -r -- x > t.txt && git add -A && git commit -qm "AX1B base"
print -l 1 2-A {3..10} > h.txt && git add h.txt
GIT_EDIT_ACTOR=ax-peer GIT_EDIT_NO_AUTO_OPEN=1 _ST_UNSYNCED "$SELF" --exec -- sh -c \
	"printf '%s\n' 1 2 3 4 5 6 7 8-B 9 10 > h.txt && git commit -qam 'AX1B B'" </dev/null >/dev/null 2>&1
print -r -- y > t.txt && git commit -qm "AX1B target" -- t.txt && AX_T=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=ax-self _ST_RUN --amend-into="$AX_T"
_ST_OUT_HAS "a fold over a file a landing only edited names the carry alone" "merge that into the checkout with 'git edit --carry=[0-9a-f]\{12\}', which stages each file again as merged, as you staged it whole\."
_ST_OUT_LACKS "no unstage" 'git restore --staged'

# `core.sparseCheckout` with no patterns file is a full checkout, as git's own checkout writes it –
# once, a rename's new path was taken as outside it, its file never written, the edits left behind
_ST_PZ_NEW ax2
mkdir d && print -l {1..10} > d/a && print -r -- t > top && git add -A && git commit -qm "AX2 base"
git config core.sparseCheckout true
print -l 1 2-A {3..10} > d/a
_ST_TTY -- --exec -y -- sh -c "mkdir -p e && git mv d/a e/a && printf '%s\n' 1 2 3 4 5 6 7 8 9-B 10 > e/a && git commit -qam 'AX2 move'"
_ST_EQ "a terminal landing writes the renamed file, the edits merged onto it" \
	"$RC:$(sed -n 2p e/a 2>/dev/null):$(sed -n 9p e/a 2>/dev/null):$([ -e d/a ] && echo left):$(git ls-files -t -- e/a)" "0:2-A:9-B::H e/a"
_ST_OUT_LACKS "naming no sparse checkout" 'sparse checkout'
_ST_PZ_NEW ax2b
mkdir d && print -l {1..10} > d/a && print -r -- t > top && git add -A && git commit -qm "AX2B base"
AX_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && mkdir e && git mv d/a e/a && git commit -qm "AX2B move" && git checkout -q main
git config core.sparseCheckout true
print -l 1 2-A {3..10} > d/a
# A move of the branch's own, the checkout left as it was
git update-ref refs/heads/main topic "$AX_OLD"
_ST_RUN --carry="$AX_OLD"
_ST_EQ "and a carry takes the edits along to it" "$RC:$(sed -n 2p e/a 2>/dev/null):$([ -e d/a ] && echo left):$(git ls-files -t -- e/a)" "0:2-A::H e/a"
# A patterns file still holds the rest outside
_ST_PZ_NEW ax2c
mkdir d && print -l {1..10} > d/a && print -r -- t > top && git add -A && git commit -qm "AX2C base"
git sparse-checkout set --cone d
print -l 1 2-A {3..10} > d/a
# A git before 2.42 asks no patterns, so it takes the new path as maybe outside
AX_MV="git mv" AX_WHY="maybe outside your sparse checkout, which this git can't ask"
_ST_SPARSE_RULES_OK && AX_WHY="outside your sparse checkout"
_ST_MV_SPARSE_OK && AX_MV="git mv --sparse"
_ST_TTY -- --exec -y -- sh -c "mkdir -p e && $AX_MV d/a e/a && git commit -qm 'AX2C move'"
_ST_EQ "while one with patterns leaves the new path outside, the edits where they were" \
	"$RC:$([ -e e/a ] && echo written):$(sed -n 2p d/a):$(git ls-files -t -- e/a)" "0::2-A:S e/a"
_ST_OUT_HAS "and says so" "d/a → e/a – renamed $AX_WHY"

# A relative program is read where the command runs, a refusal naming that place and the name
# that works from it – once, one committed was "not at the tip", one named from the top a bare 127
_ST_PZ_NEW ax3
mkdir tools sub && print -l '#!/bin/sh' 'echo "fmt-ran $*"' > tools/fmt.sh && chmod +x tools/fmt.sh && print -r -- s > sub/s.txt
git add -A && git commit -qm "AX3 base" && AX_T=$(git rev-parse HEAD)
mkdir newdir && cd newdir
_ST_RUN --exec -- ../tools/fmt.sh x
_ST_EQ "a program named from a directory the tip lacks refuses" "$RC:$(git rev-parse HEAD)" "1:$AX_T"
_ST_OUT_HAS "naming where the command runs and the tip's file" '--exec \.\./tools/fmt\.sh: nothing there where the command runs, in a fresh worktree of the tip (at the top, as the tip has no newdir/) – the tip holds tools/fmt\.sh$'
_ST_OUT_HAS "and its name from there" 'Name it from there: git edit --exec -- tools/fmt\.sh x$'
_ST_OUT_LACKS "never as not at the tip" 'not at the tip'
_ST_RUN --exec -- tools/fmt.sh x
_ST_EQ "which runs" "$RC" "0"
_ST_OUT_HAS "as its output shows" '^fmt-ran x$'
cd ../sub
_ST_RUN --exec -- tools/fmt.sh
_ST_EQ "a program named from the top, given from a subdirectory, refuses" "$RC" "1"
_ST_OUT_HAS "naming the subdirectory it runs in" '--exec tools/fmt\.sh: nothing there where the command runs, in a fresh worktree of the tip (in sub/) – the tip holds tools/fmt\.sh$'
_ST_OUT_HAS "and the name from there" 'Name it from there: git edit --exec -- \.\./tools/fmt\.sh$'
_ST_RUN --exec -- ../tools/fmt.sh
_ST_EQ "which runs" "$RC" "0"
_ST_OUT_HAS "as its output shows" '^fmt-ran $'
print -l '#!/bin/sh' 'echo fix' > fix.sh && chmod +x fix.sh
_ST_RUN --exec -- ./fix.sh
_ST_OUT_HAS "one only the checkout holds is still not at the tip, its place named" '--exec \./fix\.sh: not at the tip – the command runs in a fresh worktree of it (in sub/), which holds no uncommitted file'
_ST_RUN --exec -- ./nope.sh
_ST_EQ "one nowhere refuses before it runs" "$RC" "1"
_ST_OUT_HAS "naming where it looked" '--exec \./nope\.sh: nothing there where the command runs, in a fresh worktree of the tip (in sub/), nor where you stand'
_ST_RUN --exec -- sh -c 'exit 3'
_ST_EQ "a command failing in a subdirectory fails" "$RC" "3"
_ST_OUT_HAS "naming where it ran" 'Command exited with status 3 (run in sub/) – leaving original branch unchanged'
cd ..
_ST_RUN --exec -- sh -c 'exit 3'
_ST_OUT_HAS "from the top naming no place" 'Command exited with status 3 – leaving original branch unchanged'
cd "$TMP/repo"
