# A commit renaming a file another caller added lands where the new name holds it, as added or
# edited – while one holding other content there still refuses, naming the old name's restore
_ST_SCENARIO "\e[1;96m[229] renaming a file another caller added lands where the new name holds it\e[0m"
local RN_TIP RN_LONG

# Lands a peer's old/<name>.json, then moves it to new/ holding <lines> and commits both names
# whole – leaving `OUT`, `RC`, and `RN_TIP` the tip before
_RN_TRY () {
	# Args: <name> <line>...
	mkdir -p old new
	print -l "$RN_LONG" one two three four > "old/$1.json"
	GIT_EDIT_ACTOR=rn-peer _ST_RUN --commit --text "RN peer adds $1" -- "old/$1.json"
	RN_TIP=$(git rev-parse HEAD)
	mv "old/$1.json" "new/$1.json"
	print -l "${@:2}" > "new/$1.json"
	_ST_RUN --commit --text "RN moves $1" -- "old/$1.json" "new/$1.json"
}
_ST_PZ_NEW rn
_ST_PZ_C init.txt i "RN init"
export GIT_EDIT_ACTOR=rn-self
# A long first line, so a rename holding little else still reads as one
RN_LONG=${(l:300::x:)}

_RN_TRY same "$RN_LONG" one two three four
_ST_EQ "a file another caller added, renamed byte for byte, lands" \
	"$RC:$(git rev-parse HEAD~1):$(git diff-tree -r -M --name-status --no-commit-id HEAD | tr '\t' ' ')" "0:$RN_TIP:R100 old/same.json new/same.json"
_RN_TRY edited "$RN_LONG" one two three four five
_ST_EQ "as does one renamed and edited, holding most of it" "$RC:$(git rev-parse HEAD~1):$(git show HEAD:new/edited.json | wc -l | tr -d ' ')" "0:$RN_TIP:6"
_RN_TRY other "$RN_LONG" six seven eight nine
_ST_EQ "one whose new name holds other content refuses" "$RC:$(git rev-parse HEAD)" "1:$RN_TIP"
_ST_OUT_HAS "naming the old name as added by that caller" 'old/other.json – rn-peer.s commit run .*, which added it'
_ST_OUT_HAS "pointed at the restore" 'Take what landed with: git restore --source=HEAD --worktree -- old/other.json'
rm -f new/other.json && git checkout -q -- old/other.json
export GIT_EDIT_ACTOR=
cd "$TMP/repo"
