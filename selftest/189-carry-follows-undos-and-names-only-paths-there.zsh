# A printed carry follows the landings through an undo to the earliest one the file lacks, and one
# from a landing renaming a file by case alone reads it under its old spelling – once, each named a
# later landing's old tip, and followed as printed the earlier landing's edit went back under `ok`
# Every step named works as printed: a rename's remedy names a carry and the new name only where
# that name is at the tip, a staged fold's names it as a commit's does, an empty pathspec never
# sends a fold to everything staged, and a git that flags files it can't place in a sparse
# checkout names each with the `reapply` – `--carry` too – and never calls the checkout current
_ST_SCENARIO "\e[1;96m[189] a carry follows an undo, and every step named works as printed\e[0m"
local CU_T0 CU_T1 CU_TIP CU_C CU_REAL=${commands[git]}

# Writes `<dir>/git` standing in for a git before 2.35 – one flagging a file it adds outside a
# sparse checkout's patterns, and asking none
_CU_OLD_GIT () {
	# Args: <dir>
	mkdir -p "$1"
	{
		print -r -- '#!/bin/sh'
		print -r -- 'case " $* " in'
		print -r -- '	" --version ") echo "git version 2.31.8"; exit 0 ;;'
		print -r -- '	*" sparse-checkout check-rules "*) exit 129 ;;'
		print -r -- 'esac'
		print -r -- "exec ${(q)CU_REAL} \"\$@\""
	} > "$1/git"
	chmod +x "$1/git"
}

# Two landings on a file with edits made before both, the second undone and a third made: the
# bare carry the third names takes the file from the first's old tip, and the file then committed
# keeps all
_ST_PZ_NEW cu1
print -l {1..10} > f.txt && print -r -- x > t.txt && git add -A && git commit -qm "CU1 base"
CU_T0=$(git rev-parse HEAD)
print -l 1 2-A {3..10} > f.txt
_ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > f.txt && git commit -qam 'CU1 L1'"
CU_T1=$(git rev-parse HEAD)
_ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7-L2 8 9 10 > f.txt && git commit -qam 'CU1 L2'"
_ST_RUN --undo
_ST_EQ "the second landing undone" "$RC:$(git rev-parse HEAD)" "0:$CU_T1"
_ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7 8 9-L3 10 > f.txt && git commit -qam 'CU1 L3'"
_ST_OUT_HAS "a landing after an undo names the bare carry" "edits merged onto it: git edit --carry$"
_ST_RUN --carry
_ST_EQ "followed as printed, the file keeps the first and third landings and its edits" "$RC:$(sed -n '2p;5p;7p;9p' f.txt | tr '\n' ' ')" "0:2-A 5-L1 7 9-L3 "
_ST_RUN --commit --text "CU1 mine" -- f.txt
_ST_EQ "and committed whole, as nothing guards an unlabeled caller's own landings, it keeps them" \
	"$RC:$(git show HEAD:f.txt | sed -n '2p;5p;7p;9p' | tr '\n' ' ')" "0:2-A 5-L1 7 9-L3 "
_ST_EQ "a commit of the checkout's own file leaves it current" "$(git status --porcelain -- f.txt)" ""
_ST_OUT_LACKS "naming nothing to bring along" 'came along\|Left as they were\|conflict with'
# A file made on the first landing lacks only the third
_ST_PZ_NEW cu2
print -l {1..10} > f.txt && git add -A && git commit -qm "CU2 base"
_ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > f.txt && git commit -qam 'CU2 L1'"
CU_T1=$(git rev-parse HEAD)
_ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7-L2 8 9 10 > f.txt && git commit -qam 'CU2 L2'"
_ST_RUN --undo
print -l 1 2-A 3 4 5-L1 {6..10} > f.txt
_ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7 8 9-L3 10 > f.txt && git commit -qam 'CU2 L3'"
_ST_OUT_HAS "while one made on the first names it too" "edits merged onto it: git edit --carry$"
_ST_RUN --carry
_ST_EQ "which merges it from the third's own old tip" "$RC:$(sed -n '2p;5p;7p;9p' f.txt | tr '\n' ' ')" "0:2-A 5-L1 7 9-L3 "

# A landing renaming a file by case, its content changed too,
# reads an earlier landing the file lacks under the old spelling
if [ "$(git config --type=bool core.ignorecase)" = true ]; then
	_ST_PZ_NEW cu3
	print -l {1..10} > README.md && print -r -- x > t.txt && git add -A && git commit -qm "CU3 base"
	CU_T0=$(git rev-parse HEAD)
	print -l 1 2-A {3..10} > README.md
	_ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > README.md && git commit -qam 'CU3 L1'"
	_ST_RUN_UNSYNCED --exec -- sh -c "git mv README.md cu3.tmp && git mv cu3.tmp readme.md && printf '%s\n' 1 2 3 4 5-L1 6 7 8-L2 9 10 > readme.md && git commit -qam 'CU3 L2'"
	_ST_OUT_HAS "a case-only rename names the bare carry" "edits merged onto it: git edit --carry$"
	_ST_RUN --carry
	_ST_EQ "followed as printed, the file keeps both landings and its edits" "$RC:$(git ls-files | tr '\n' ' '):$(sed -n '2p;5p;8p' readme.md | tr '\n' ' ')" "0:readme.md t.txt :2-A 5-L1 8-L2 "
fi

# A file a landing renamed and a later one removed takes the removal's remedy, not a carry
# naming a name the tip has not
_ST_PZ_NEW cu4
print -l {1..10} > f.txt && print -r -- x > t.txt && git add -A && git commit -qm "CU4 base"
print -l 1 2-A {3..10} > f.txt
GIT_EDIT_ACTOR=cu-peer _ST_RUN_UNSYNCED --exec -- sh -c "git mv f.txt h.txt && printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > h.txt && git commit -qam 'CU4 L1'"
GIT_EDIT_ACTOR=cu-peer _ST_RUN_UNSYNCED --exec -- sh -c "git rm -q h.txt && git commit -qm 'CU4 L2'"
GIT_EDIT_ACTOR=cu-self _ST_RUN --commit --text "CU4 mine" -- f.txt
_ST_EQ "a file renamed then removed since refuses" "$RC" "1"
_ST_OUT_HAS "naming the rename and the removal" "f\.txt – cu-peer's exec run .*, which renamed it to h\.txt, removed since$"
_ST_OUT_HAS "with the removal's remedy" "Leave out what was removed: f\.txt$"
_ST_OUT_LACKS "and no carry naming a path the tip lacks" "naming h\.txt in place of f\.txt"
# One a later run renamed again names the carry and the name at the tip, which work as printed
_ST_PZ_NEW cu5
print -l {1..10} > f.txt && print -r -- x > t.txt && git add -A && git commit -qm "CU5 base"
CU_T0=$(git rev-parse HEAD)
print -l 1 2-A {3..10} > f.txt
GIT_EDIT_ACTOR=cu-peer _ST_RUN_UNSYNCED --exec -- sh -c "git mv f.txt h.txt && printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > h.txt && git commit -qam 'CU5 L1'"
GIT_EDIT_ACTOR=cu-peer _ST_RUN_UNSYNCED --exec -- sh -c "git mv h.txt k.txt && git commit -qm 'CU5 L2'"
GIT_EDIT_ACTOR=cu-self _ST_RUN --commit --text "CU5 mine" -- f.txt
_ST_OUT_HAS "a file renamed twice names where it is at the tip" "f\.txt – cu-peer's exec run .*, which renamed it to h\.txt, k\.txt at the tip$"
_ST_OUT_HAS "with the carry and that name" "with 'git edit --carry=${CU_T0:0:12}', then run this again naming k\.txt in place of f\.txt\.$"
CU_C=$(grep -o -e '--carry=[0-9a-f]*' <<<"$OUT" | head -1)
GIT_EDIT_ACTOR=cu-self _ST_RUN "$CU_C"
GIT_EDIT_ACTOR=cu-self _ST_RUN --commit --text "CU5 mine" -- k.txt
_ST_EQ "followed as printed, it keeps the landing and the edits" "$RC:$(git show HEAD:k.txt | sed -n '2p;5p' | tr '\n' ' ')" "0:2-A 5-L1 "

# A staged fold over a file renamed since names the new name for the run again, as a commit does,
# where it names paths – and where nothing is staged under them, never says to drop them
_ST_PZ_NEW cu6
print -l {1..10} > f.txt && print -r -- x > t.txt && git add -A && git commit -qm "CU6 base"
print -l 1 2-A {3..10} > f.txt
GIT_EDIT_ACTOR=cu-peer _ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > f.txt && git commit -qam 'CU6 L1'"
GIT_EDIT_ACTOR=cu-peer _ST_RUN_UNSYNCED --exec -- sh -c "git mv f.txt h.txt && git commit -qm 'CU6 L2'"
print -r -- y > t.txt && git commit -qm "CU6 target" -- t.txt && CU_TIP=$(git rev-parse HEAD)
git add f.txt
GIT_EDIT_ACTOR=cu-self _ST_RUN --amend-into="$CU_TIP" -- f.txt
_ST_OUT_HAS "a staged fold of a file renamed since names the new name for the run again" \
	"Then stage them again with: git add -- h\.txt .* – and run this again naming h\.txt in place of f\.txt\.$"
eval "$(grep -o -e 'git restore --staged -- [^ ]*$' <<<"$OUT" | head -1)"
CU_C=$(grep -o -e '--carry=[0-9a-f]*' <<<"$OUT" | head -1)
GIT_EDIT_ACTOR=cu-self _ST_RUN "$CU_C"
git add -- h.txt
GIT_EDIT_ACTOR=cu-self _ST_RUN --amend-into="$CU_TIP" -- f.txt
_ST_OUT_HAS "the old name then finds nothing staged, naming the files to stage and name" "Stage them with 'git add -- <files>', then run this again naming those files\.$"
_ST_OUT_LACKS "never folding everything staged" "drop the pathspec"
GIT_EDIT_ACTOR=cu-self _ST_RUN --amend-into="$CU_TIP" -- h.txt
_ST_EQ "and the new name folds, both edits kept" "$RC:$(git show HEAD:h.txt | sed -n '2p;5p' | tr '\n' ' ')" "0:2-A 5-L1 "
# A fold naming no paths needs no new name
_ST_PZ_NEW cu7
print -l {1..10} > f.txt && print -r -- x > t.txt && git add -A && git commit -qm "CU7 base"
print -l 1 2-A {3..10} > f.txt
GIT_EDIT_ACTOR=cu-peer _ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L1 6 7 8 9 10 > f.txt && git commit -qam 'CU7 L1'"
GIT_EDIT_ACTOR=cu-peer _ST_RUN_UNSYNCED --exec -- sh -c "git mv f.txt h.txt && git commit -qm 'CU7 L2'"
print -r -- y > t.txt && git commit -qm "CU7 target" -- t.txt && CU_TIP=$(git rev-parse HEAD)
git add f.txt
GIT_EDIT_ACTOR=cu-self _ST_RUN --amend-into="$CU_TIP"
_ST_OUT_HAS "a staged fold naming no paths is told to run again" "Then stage them again with: git add -- h\.txt .* – and run this again\.$"

# A landing on a path an earlier rename never moved in names it missing, not as edits there
_ST_PZ_NEW cu8
print -l {1..10} > f.txt && print -r -- x > t.txt && git add -A && git commit -qm "CU8 base"
print -l 1 2-A {3..10} > f.txt
GIT_EDIT_ACTOR=cu-peer _ST_RUN_UNSYNCED --exec -- sh -c "git mv f.txt h.txt && git commit -qm 'CU8 L1'"
GIT_EDIT_ACTOR=cu-peer _ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L2 6 7 8 9 10 > h.txt && git commit -qam 'CU8 L2'"
_ST_OUT_HAS "a path left missing by an earlier rename is named missing" "Worktree files left alone, missing from the checkout – deleted there, or never moved in from the old path of an earlier landing's rename: h\.txt$"
_ST_OUT_LACKS "never as edits there" "uncommitted edits there"

# A git before 2.35 flags the files an agent's landing adds in a sparse checkout, asking no
# patterns: the landing names them for the reapply, never calling the checkout current, and a
# carry names those still unwritten the same way
_ST_PZ_NEW cu9
mkdir in out && print -l {1..10} > in/a.txt && print o > out/o.txt && print t > top.txt
git add -A && git commit -qm "CU9 base"
git sparse-checkout set --cone in
_CU_OLD_GIT "$TMP/cu9-bin"
PATH="$TMP/cu9-bin:$PATH" _ST_RUN_UNSYNCED --exec -- sh -c "mkdir -p in out && echo n > in/new.txt && echo n > out/new.txt && git update-index --add -- in/new.txt out/new.txt && git commit -qm 'CU9 L1'"
_ST_OUT_HAS "a landing names the files it left out with the reapply" "the files the landing added, left out as outside it: in/new\.txt, out/new\.txt – write those inside it with: git sparse-checkout reapply$"
_ST_OUT_LACKS "never calling the checkout current" "your checkout is current"
_ST_EQ "both left out, flagged" "$(git ls-files -t -- in/new.txt out/new.txt | tr '\n' '|')" "S in/new.txt|S out/new.txt|"
CU_T0=$(git rev-parse HEAD~1)
print -l 1 2-A {3..10} > in/a.txt
PATH="$TMP/cu9-bin:$PATH" _ST_RUN_UNSYNCED --exec -- sh -c "printf '%s\n' 1 2 3 4 5-L2 6 7 8 9 10 > in/a.txt && git commit -qam 'CU9 L2'"
PATH="$TMP/cu9-bin:$PATH" _ST_RUN --carry="$CU_T0"
_ST_OUT_HAS "a carry names the ones still unwritten with the reapply" "the files the rewrite added, left out as outside it: in/new\.txt, out/new\.txt – write those inside it with: git sparse-checkout reapply$"
_ST_EQ "while carrying the edits" "$RC:$(sed -n '2p;5p' in/a.txt | tr '\n' ' ')" "0:2-A 5-L2 "
git sparse-checkout reapply 2>/dev/null
_ST_EQ "and the reapply writes the one inside it alone" "$(cat in/new.txt 2>/dev/null):$([ -e out ] && print there)" "n:"
