# A commit moved past a later one that relocated its code into another file lands,
# its rewrite of lines a stop rewrites again named as superseded – the code it
# added, still written in the file it moved to, never counted as lost
_ST_SCENARIO "\e[1;96m[269] a commit moved past its code's relocation lands, its lost rewrite superseded\e[0m"
local RL_O RL_M RL_TREE
local -a RL_F=("const findCost = (src) => {" $'\tconst hits = scan(src)' $'\tconst kept = hits.filter(costly)' $'\treturn kept' "}")

# Writes <file>'s lines and stages it
_RL_W () {
	# Args: <file> <line>...
	print -l -- "${@:2}" > "$1" && git add -- "$1"
}

# O rewrites two lines and adds a function, B rewrites the two again, M moves all three into `s.js`
_ST_PZ_NEW rl1
git config rerere.enabled false
export GIT_EDIT_NO_SELF_RESOLVE=1
_RL_W a.js "const top = 1" "// Checks the sheet for what drops" "for (const v of [...findA(src)]) report(v)" "const bottom = 2"
git commit -qm "RL base"
_RL_W a.js "const top = 1" "// Checks the sheet for what drops or costs" "${RL_F[@]}" \
	"for (const v of [...findA(src), ...findCost(src)]) report(v)" "const bottom = 2"
git commit -qm "RL O adds the cost check" && RL_O=$(git rev-parse HEAD)
_RL_W a.js "const top = 1" "// Checks the sheet for what drops, costs or breaks" "${RL_F[@]}" \
	"for (const v of [...findA(src), ...findCost(src), ...findBroken(src)]) report(v)" "const bottom = 2"
git commit -qm "RL B adds the broken check"
_RL_W a.js "const top = 1" "const bottom = 2"
_RL_W s.js "// Checks the sheet for what drops, costs or breaks" "${RL_F[@]}" \
	"for (const v of [...findA(src), ...findCost(src), ...findBroken(src)]) report(v)"
git commit -qm "RL M moves the checks into s.js" && RL_M=$(git rev-parse HEAD)
print -r -- t > t.txt && git add t.txt && git commit -qm "RL T top"
RL_TREE=$(git rev-parse "HEAD^{tree}")
_ST_RUN --move="$RL_O" --after="$RL_M"
_ST_EQ "moved past its code's relocation, the first commit it crosses stops" "$RC" "2"
_ST_RESOLVE "$(_ST_PZ_WT)" a.js $'const top = 1\n// Checks the sheet for what drops or breaks\nfor (const v of [...findA(src), ...findBroken(src)]) report(v)\nconst bottom = 2'
_ST_RUN --continue
_ST_EQ "the relocation stops in turn" "$RC" "2"
_ST_OUT_HAS "naming the file it staged clean holding the moved commit's lines" "^  s\.js – 4 line(s) ${RL_O:0:7} adds$"
_ST_RESOLVE "$(_ST_PZ_WT)" a.js $'const top = 1\nconst bottom = 2'
_ST_RESOLVE "$(_ST_PZ_WT)" s.js $'// Checks the sheet for what drops or breaks\nfor (const v of [...findA(src), ...findBroken(src)]) report(v)'
_ST_RUN --continue
_ST_EQ "the moved commit stops at its own step" "$RC" "2"
_ST_RESOLVE "$(_ST_PZ_WT)" a.js $'const top = 1\nconst bottom = 2'
_ST_RESOLVE "$(_ST_PZ_WT)" s.js "$(git show "${RL_M}:s.js")"
_ST_RUN --continue
_ST_EQ "resolved so, it lands in the new order" "$RC:$(git log --format=%s | tr '\n' '|')" \
	"0:RL T top|RL O adds the cost check|RL M moves the checks into s.js|RL B adds the broken check|RL base|"
_ST_EQ "the tip's tree unchanged" "$(git rev-parse "HEAD^{tree}")" "$RL_TREE"
_ST_OUT_HAS "its rewrite of a line the crossed commit rewrites again named as superseded" \
	'RL O adds the cost check – a\.js: for (const v of .\.\.\.findA(src).) report(v)'
_ST_OUT_LACKS "never refused as taking in a later change" 'took in what a later commit changes'
_ST_EQ "the moved commit writing its function into the file it moved to" \
	"$(git log -1 --format=%s HEAD~1):$(git show --format= HEAD~1 -- s.js | grep -c -e '^+	const kept = hits.filter(costly)$')" \
	"RL O adds the cost check:1"
unset GIT_EDIT_NO_SELF_RESOLVE
