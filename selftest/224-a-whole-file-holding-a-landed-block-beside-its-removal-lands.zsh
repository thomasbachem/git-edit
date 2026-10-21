# A whole file holding a peer's landed block lands where the caller removed the lines above
# it, a merge of the landing then doubling the block – while one lacking it, holding fewer
# copies than the landing left, or doubling a block of lines it held before, still refuses
_ST_SCENARIO "\e[1;96m[224] a whole file holding a landed block beside its own removal lands, ones lacking it refuse\e[0m"
local W224_TIP W224_OWN

# Prints a lockfile entry <name> at version <v>
_W224_ENTRY () {
	# Args: <name> <v>
	printf '  "%s": {\n    "v": %s,\n    "dev": true\n  },\n' "$1" "$2"
}
# Commits <file> holding <before> unjournaled, then lands <after> on it as a peer
_W224_LAND () {
	# Args: <file> <before> <after>
	print -rn -- "$2" > "$1" && git add -- "$1" && git commit -qm "W224 base $1" -- "$1"
	print -rn -- "$3" > "$1"
	GIT_EDIT_ACTOR=w224-peer _ST_RUN --commit --text "W224 peer lands $1" -- "$1"
}
export GIT_EDIT_ACTOR=w224-self

# The peer adds entry c after b, the caller removes a and b
_W224_LAND w224-a.json "{
$(_W224_ENTRY a 1; _W224_ENTRY b 2)
  \"d\": 4
}
" "{
$(_W224_ENTRY a 1; _W224_ENTRY b 2; _W224_ENTRY c 3)
  \"d\": 4
}
"
print -r -- "{
$(_W224_ENTRY c 3)
  \"d\": 4
}" > w224-a.json
W224_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "W224 a and b removed" -- w224-a.json
_ST_EQ "a whole file holding the landed entry beside its own removal lands" \
	"$RC:$(git show HEAD:w224-a.json | grep -c '\"c\"'):$(git rev-parse HEAD~1)" "0:1:$W224_TIP"

# The same shape folded whole into a commit above the landing
_W224_LAND w224-b.json "{
$(_W224_ENTRY a 1; _W224_ENTRY b 2)
  \"d\": 4
}
" "{
$(_W224_ENTRY a 1; _W224_ENTRY b 2; _W224_ENTRY c 3)
  \"d\": 4
}
"
print -r -- own > w224-own.txt
_ST_RUN --commit --text "W224 own commit to fold into" -- w224-own.txt
W224_OWN=$(git rev-parse HEAD)
print -r -- "{
$(_W224_ENTRY c 3)
  \"d\": 4
}" > w224-b.json
print -r -- "own, folded" > w224-own.txt
_ST_RUN --amend-into="$W224_OWN" --whole -- w224-b.json w224-own.txt
_ST_EQ "as does such a file folded whole" \
	"$RC:$(git show HEAD:w224-b.json | grep -c '\"c\"'):$(git show HEAD:w224-own.txt)" "0:1:own, folded"

# A file lacking the landed entry, edited elsewhere, merges clean without doubling anything
_W224_LAND w224-c.json "{
$(_W224_ENTRY a 1; _W224_ENTRY b 2)
  \"d\": 4
}
" "{
$(_W224_ENTRY a 1; _W224_ENTRY b 2; _W224_ENTRY c 3)
  \"d\": 4
}
"
print -r -- "{
$(_W224_ENTRY a 9; _W224_ENTRY b 2)
  \"d\": 4
}" > w224-c.json
W224_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- w224-c.json
_ST_OUT_HAS "a whole file lacking the landed entry still refuses" 'would take back what another caller landed: w224-c.json'
_ST_EQ "the branch unmoved" "$(git rev-parse HEAD)" "$W224_TIP"
git checkout -q -- w224-c.json

# A landing repeating a block, which merging in doubles beside a copy the file held before
_W224_LAND w224-d.txt $'x1\nx2\nend\n' $'x1\nx2\nx1\nx2\nend\n'
W224_TIP=$(git rev-parse HEAD)
printf 'top\nx1\nx2\nend\n' > w224-d.txt
_ST_RUN --commit --text "x" -- w224-d.txt
_ST_OUT_HAS "a whole file holding a repeated block only as often as before refuses" 'would take back what another caller landed: w224-d.txt'
_ST_EQ "the branch unmoved" "$(git rev-parse HEAD)" "$W224_TIP"
git checkout -q -- w224-d.txt

# A landed line merged in beside one equal to it only as a number is no second copy
_W224_LAND w224-e.txt $'x\n1\ny\n' $'x\n1.0\n1\ny\n'
W224_TIP=$(git rev-parse HEAD)
printf '1.0\nx\n1\ny\n' > w224-e.txt
_ST_RUN --commit --text "x" -- w224-e.txt
_ST_OUT_HAS "a whole file lacking a landed line beside its numeric twin refuses" 'would take back what another caller landed: w224-e.txt'
_ST_EQ "the branch unmoved" "$(git rev-parse HEAD)" "$W224_TIP"
git checkout -q -- w224-e.txt

# A landed line repeating the one beside it, lacked there by a file adding that line elsewhere
_W224_LAND w224-f.txt $'a\n}\nb\n' $'a\n}\n}\nb\n'
W224_TIP=$(git rev-parse HEAD)
printf 'a\n}\nb\nnew() {\n}\n' > w224-f.txt
_ST_RUN --commit --text "x" -- w224-f.txt
_ST_OUT_HAS "a whole file holding a landed line only elsewhere refuses" 'would take back what another caller landed: w224-f.txt'
_ST_EQ "the branch unmoved" "$(git rev-parse HEAD)" "$W224_TIP"
git checkout -q -- w224-f.txt
export GIT_EDIT_ACTOR=
