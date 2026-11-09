# A commit moved past a later one that edited, in place, other words of a line it rewrote never
# hands that edit to the moved commit, which left the later one landing without it, its other
# change alone – the stop pauses, saying where the edit goes, and resolved so, both keep theirs
_ST_SCENARIO "\e[1;96m[271] a move keeps a crossed commit's edit of other words in a line it rewrote\e[0m"
local WK_A WK_B WK_TREE WK_OLD=""
# Below git 2.50 no line identity is sure, so a stop pauses there before any words are read
[[ "$(git --version)" =~ '^git version 2\.([0-9]+)\.' ]] && (( match[1] < 50 )) && WK_OLD=1

# Prints `f.js` with the call's finders as given, and above its function the definition given
_WK_F () {
	# Args: <finders> [<definition>]
	print -l -- ${2:+"$2"} "function check(source) {" "	for(const v of [$1].sort()) {" "		report(v);" "	}" "}"
}

_ST_PZ_NEW wk1
git config rerere.enabled false
_WK_F "...findNested(), ...findMarkers(), ...findNumbers()" > f.js
git add f.js && git commit -qm "WK base"
_WK_F "...findNested(), ...findCostly(), ...findMarkers(), ...findNumbers()" > f.js
git commit -qam "WK A adds the costly finder" && WK_A=$(git rev-parse HEAD)
_WK_F "...findNested(), ...findCostly(), ...findMarkers(), ...findNumbers(), ...findUnbalanced()" "const findUnbalanced = () => [];" > f.js
git commit -qam "WK B adds the unbalanced finder" && WK_B=$(git rev-parse HEAD)
print x > g.js && git add g.js && git commit -qm "WK C"
WK_TREE=$(git rev-parse "HEAD^{tree}")
_ST_RUN --move="$WK_A" --after="$WK_B"
_ST_EQ "moved past a commit editing other words of its line, the move stops there" "$RC" "2"
[ -n "$WK_OLD" ] || _ST_OUT_HAS "saying the edit stays that commit's own" \
	'f\.js: its change at line 2 edits words a commit still to come left alone, on a line that commit rewrote'
_ST_OUT_LACKS "never handing it to the moved commit" 'edit(s) carried to it'
_ST_OUT_LACKS "nor naming a file staged clean, none holding the moved commit's lines" 'Staged clean, yet holding'
_ST_RESOLVE "$(_ST_PZ_WT)" f.js "$(_WK_F "...findNested(), ...findMarkers(), ...findNumbers(), ...findUnbalanced()" "const findUnbalanced = () => [];")"
_ST_RUN --continue
_ST_EQ "the moved commit's step stops in turn" "$RC" "2"
_ST_RESOLVE "$(_ST_PZ_WT)" f.js "$(git show "${WK_B}:f.js")"
_ST_RUN --continue
_ST_EQ "resolved so, it lands in the new order" "$RC:$(git log --format=%s | tr '\n' '|')" \
	"0:WK C|WK A adds the costly finder|WK B adds the unbalanced finder|WK base|"
_ST_EQ "the tip's tree unchanged" "$(git rev-parse "HEAD^{tree}")" "$WK_TREE"
_ST_EQ "the crossed commit landing its own finder" "$(git show --format= HEAD~2 -- f.js | grep -c -e '^+.*findUnbalanced()\].sort')" "1"
_ST_EQ "and the moved commit its own" "$(git show --format= HEAD~1 -- f.js | grep '^[-+]	for' | tr '\n' '|')" \
	"-	for(const v of [...findNested(), ...findMarkers(), ...findNumbers(), ...findUnbalanced()].sort()) {|+	for(const v of [...findNested(), ...findCostly(), ...findMarkers(), ...findNumbers(), ...findUnbalanced()].sort()) {|"

# Its edit right beside the moved commit's, no word between, still lands with the moved commit
if [ -z "$WK_OLD" ]; then
	_ST_PZ_NEW wk2
	git config rerere.enabled false
	_WK_F "...findNested(), ...findMarkers(), ...findNumbers()" > f.js
	git add f.js && git commit -qm "WK2 base"
	_WK_F "...findNested(), ...findCostly(), ...findMarkers(), ...findNumbers()" > f.js
	git commit -qam "WK2 A adds the costly finder" && WK_A=$(git rev-parse HEAD)
	_WK_F "...findNested(), ...findCostly(), ...findUnbalanced(), ...findMarkers(), ...findNumbers()" "const findUnbalanced = () => [];" > f.js
	git commit -qam "WK2 B adds the unbalanced finder" && WK_B=$(git rev-parse HEAD)
	print x > g.js && git add g.js && git commit -qm "WK2 C"
	_ST_RUN --move="$WK_A" --after="$WK_B"
	_ST_EQ "an edit touching the moved commit's words lands with it, the move landing" "$RC" "0"
	_ST_OUT_HAS "named as carried" '(WK2 A adds the costly finder) took the 1 edit(s) carried to it'
fi
unfunction _WK_F
