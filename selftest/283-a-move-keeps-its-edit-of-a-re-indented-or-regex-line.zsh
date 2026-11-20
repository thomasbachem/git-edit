# A commit moved earlier past one only re-indenting a line it edits, or editing that line's regex
# elsewhere, keeps its edit – the stop pauses, saying so, and resolved so, both keep theirs
_ST_SCENARIO "\e[1;96m[283] a move keeps its edit of a line a crossed commit re-indented or edited apart\e[0m"
local RI_M RI_TREE RI_OLD=""
# Below git 2.50 no line identity is sure, so a stop pauses there before any words are read
[[ "$(git --version)" =~ '^git version 2\.([0-9]+)\.' ]] && (( match[1] < 50 )) && RI_OLD=1

# Prints `s.js` with the summary line given last in its block, the block in a `try` where <wrap> is
_RI_S () {
	# Args: <summary> <wrap>
	local I=${2:+$'\t'}
	[ -z "$2" ] || print -r -- 'try {'
	print -lr -- "${I}setup();" "" "${I}finish();" "${I}$1"
	[ -z "$2" ] || print -lr -- '} catch (e) {' $'\tcrash(e);' '}'
}
_ST_PZ_NEW ri
git config rerere.enabled false
_RI_S "summary(runs);" 1 > s.js && print t0 > t.js && git add . && git commit -qm "RI base"
_RI_S "summary(runs);" "" > s.js && git commit -qam "RI F drops the crash wrapper"
print y > y.js && git add y.js && git commit -qm "RI Y"
_RI_S "summary(runs); // counts every run" "" > s.js && print t1 > t.js && git commit -qam "RI M notes the count" && RI_M=$(git rev-parse HEAD)
RI_TREE=$(git rev-parse "HEAD^{tree}")
_ST_RUN --move="$RI_M" --after=HEAD~3
_ST_EQ "moved past a commit re-indenting a line it edits, the move stops at it" "$RC" "2"
[ -n "$RI_OLD" ] || _ST_OUT_HAS "saying the edit stays its own" \
	's\.js: its change at line 4 edits words a commit still to come left alone, on a line that commit rewrote'
_ST_OUT_LACKS "never handing it to that commit" 'land with [0-9a-f]* (RI F drops'
_ST_RESOLVE "$(_ST_PZ_WT)" s.js "$(_RI_S "summary(runs); // counts every run" 1)"
_ST_RUN --continue
_ST_EQ "the crossed commit's step stops in turn" "$RC" "2"
_ST_RESOLVE "$(_ST_PZ_WT)" s.js "$(_RI_S "summary(runs); // counts every run" "")"
_ST_RUN --continue
_ST_EQ "resolved so, it lands, the tip as it was" "$RC:$(git rev-parse "HEAD^{tree}")" "0:$RI_TREE"
_ST_OUT_HAS "its trailer naming no edit carried" '^git-edit: ok – refs/heads/main moved [0-9a-f]* → [0-9a-f]*$'
_ST_EQ "the moved commit adding its note" "$(git show --format= HEAD~2 -- s.js | grep '^[-+]' | tr '\n' '|')" \
	"--- a/s.js|+++ b/s.js|-	summary(runs);|+	summary(runs); // counts every run|"
_ST_EQ "the crossed one only re-indenting" "$(git show --format= HEAD~1 -- s.js | grep -c -e '^+summary(runs); // counts')" "1"

# Prints `f.js` with the regex's lookbehind and lookahead given, and the comment's ending
_RX_F () {
	# Args: <lookbehind> <lookahead> <ending>
	print -lr -- "// Splits a title at its trailing \"X\"$3" "const RE = /(?<![$1])X(?=$2)/g;" "export default RE;"
}
# Makes a repo where R edits the regex's lookbehind to <behind> and the moved
# M its lookahead, in `f.js` and, where <twice> is given, in `h.js` too
_RX_REPO () {
	# Args: <name> <behind> <M's lookbehind> [<twice>]
	local F
	_ST_PZ_NEW "$1"
	git config rerere.enabled false
	for F in f.js ${4:+h.js}; do _RX_F '\w' '\b' "" > $F; done
	git add . && git commit -qm "$1 base"
	for F in f.js ${4:+h.js}; do _RX_F "$2" '\b' "" > $F; done
	git commit -qam "$1 R widens the lookbehind"
	print y > y.js && git add y.js && git commit -qm "$1 Y"
	for F in f.js ${4:+h.js}; do _RX_F "$3" '\b|$' ", or the line" > $F; done
	git commit -qam "$1 M ends at the line too" && RI_M=$(git rev-parse HEAD)
	RI_TREE=$(git rev-parse "HEAD^{tree}")
}
_RX_REPO rx '\s\w' '\s\w'
_ST_RUN --move="$RI_M" --after=HEAD~3
_ST_EQ "moved past a commit editing its regex elsewhere, the move stops at it" "$RC" "2"
[ -n "$RI_OLD" ] || _ST_OUT_HAS "saying the edit stays its own" \
	'f\.js: its change at line 2 edits words a commit still to come left alone, on a line that commit rewrote'
_ST_RESOLVE "$(_ST_PZ_WT)" f.js "$(_RX_F '\w' '\b|$' ", or the line")"
_ST_RUN --continue
_ST_EQ "the crossed commit's step stops in turn" "$RC" "2"
_ST_RESOLVE "$(_ST_PZ_WT)" f.js "$(_RX_F '\s\w' '\b|$' ", or the line")"
_ST_RUN --continue
_ST_EQ "resolved so, it lands, the tip as it was" "$RC:$(git rev-parse "HEAD^{tree}")" "0:$RI_TREE"
_ST_EQ "the moved commit widening its lookahead" "$(git show --format= HEAD~2 -- f.js | grep -c -e '^+const RE = /(?<!\[\\w\])X(?=\\b|\$)/g;')" "1"
# Its edit right beside the crossed commit's, no character between, still lands with that commit
if [ -z "$RI_OLD" ]; then
	_RX_REPO rt '\s\w' '\s\d\w' 1
	_ST_RUN --move="$RI_M" --after=HEAD~3
	_ST_EQ "an edit touching the crossed commit's characters lands with it, the move landing" "$RC" "0"
	_ST_OUT_HAS "named as carried" '(rt R widens the lookbehind) took the 2 edit(s) carried to it'
	_ST_OUT_HAS "its trailer naming the first, as rebuilt, and how many more" \
		"^git-edit: ok – refs/heads/main moved [0-9a-f]* → [0-9a-f]* – $(git rev-parse HEAD~2 | cut -c1-7)'s edits to f\.js landed with $(git rev-parse HEAD~1 | cut -c1-7) and 1 more\$"
	# Landed by a resume, as past a verify pause, its trailer names them too
	_RX_REPO rv '\s\w' '\s\d\w'
	git config edit.verifyCmd false
	_ST_RUN --move="$RI_M" --after=HEAD~3
	_ST_EQ "a carrying move whose verify fails pauses" "$RC" "2"
	_ST_RUN --no-verify --continue
	_ST_EQ "applied anyway, it lands" "$RC" "0"
	_ST_OUT_HAS "its trailer naming the edit carried" \
		"^git-edit: ok – refs/heads/main moved [0-9a-f]* → [0-9a-f]* – $(git rev-parse HEAD~2 | cut -c1-7)'s edits to f\.js landed with $(git rev-parse HEAD~1 | cut -c1-7)\$"
fi

# Prints `r.js` with its block at the indent given and the check's comment
_RR_F () {
	# Args: <indent> <comment>
	print -lr -- "function run() {" "$1setup(a);" "$1check(b);$2" "$1finish(c);" "}"
}
# The moved commit only re-indenting a line the crossed one appended to keeps its re-indent too
_ST_PZ_NEW rr
git config rerere.enabled false
_RR_F $'\t' "" > r.js && git add . && git commit -qm "RR base"
_RR_F $'\t' " // first" > r.js && git commit -qam "RR R notes the check"
print y > y.js && git add y.js && git commit -qm "RR Y"
_RR_F $'\t\t' " // first" > r.js && git commit -qam "RR M indents the block" && RI_M=$(git rev-parse HEAD)
RI_TREE=$(git rev-parse "HEAD^{tree}")
_ST_RUN --move="$RI_M" --after=HEAD~3
_ST_EQ "moved past a commit appending to a line it only re-indents, the move stops at it" "$RC" "2"
[ -n "$RI_OLD" ] || _ST_OUT_HAS "saying the re-indent stays its own" \
	'r\.js: its change at line 3 edits words a commit still to come left alone, on a line that commit rewrote'
_ST_RESOLVE "$(_ST_PZ_WT)" r.js "$(_RR_F $'\t\t' "")"
_ST_RUN --continue
_ST_EQ "the crossed commit's step stops in turn" "$RC" "2"
_ST_RESOLVE "$(_ST_PZ_WT)" r.js "$(_RR_F $'\t\t' " // first")"
_ST_RUN --continue
_ST_EQ "resolved so, it lands, the tip as it was" "$RC:$(git rev-parse "HEAD^{tree}")" "0:$RI_TREE"

# Prints `c.js` with its save in a `wait(0)` where <wrap> is given, and where <named> is a
# `takesSeries()` defined above, the check below rewritten as one comment line and a call to it
_RC_F () {
	# Args: <wrap> <named>
	local I=$'\t\t'${1:+$'\t\t'}
	print -lr -- 'function f() {' $'\tconst takesLocal = () => !!read();'
	[ -z "$2" ] || print -lr -- $'\t// Checks whether a pick goes to the series' $'\tconst takesSeries = () => {' \
		$'\t\tconst stored = load();' $'\t\treturn (stored?.inherit() !== undefined && stored.pick()?.[\'scope\'] !== \'this\');' $'\t};'
	print -r -- $'\twatch(x => {'
	[ -z "$1" ] || print -lr -- $'\t\t// Read later – the hook runs first' $'\t\treturn (' $'\t\t\twait(0)' $'\t\t\t.then(() => {'
	print -lr -- "${I}const id = get();" "${I}const stored = load();"
	if [ -n "$2" ]; then
		print -lr -- "${I}// Written to the event alone where it isn't the series', as for a guest of one" "${I}const isAlone = !takesSeries();"
	else
		print -lr -- "${I}// Written to the event alone where no master passes a pick on, as for a guest" \
			"${I}// invited to one occurrence, or it holds its own" \
			"${I}const isAlone = (stored?.inherit() === undefined || stored.pick()?.['scope'] === 'this');"
	fi
	print -r -- "${I}return save(id, isAlone);"
	[ -z "$1" ] || print -lr -- $'\t\t\t})' $'\t\t);'
	print -lr -- $'\t});' '}'
}
# Its rewrite of lines the crossed commit only re-indented, into fewer lines than it replaces,
# stays its own too – no line pairs across such a hunk, so the re-indent alone decides
_ST_PZ_NEW rc
git config rerere.enabled false
_RC_F "" "" > c.js && git add . && git commit -qm "RC base"
_RC_F 1 "" > c.js && git commit -qam "RC X waits a tick" && RC_X=$(git rev-parse HEAD)
_RC_F 1 1 > c.js && git commit -qam "RC M names the check" && RI_M=$(git rev-parse HEAD)
RI_TREE=$(git rev-parse "HEAD^{tree}")
_ST_RUN --move="$RI_M" --before="$RC_X"
_ST_EQ "moved past a commit only re-indenting lines it rewrites into fewer, the move stops at it" "$RC" "2"
[ -n "$RI_OLD" ] || _ST_OUT_HAS "saying the rewrite stays its own" \
	'c\.js: its change at line [0-9]* edits words a commit still to come left alone, on a line that commit rewrote'
_ST_OUT_LACKS "never carrying it" 'carried to it'
_ST_RESOLVE "$(_ST_PZ_WT)" c.js "$(_RC_F "" 1)"
_ST_RUN --continue
# The crossed commit's re-indent replays over the rewrite – where git
# can't be sure of a line's identity, its step stops for the hand first
if [ "$RC" = 2 ]; then
	_ST_RESOLVE "$(_ST_PZ_WT)" c.js "$(_RC_F 1 1)"
	_ST_RUN --continue
fi
_ST_EQ "resolved so, it lands, the tip as it was" "$RC:$(git rev-parse "HEAD^{tree}")" "0:$RI_TREE"
_ST_EQ "the moved commit holding its rewrite" "$(git show --format= HEAD~1 -- c.js | grep -c -e '^+.*isAlone = !takesSeries')" "1"
_ST_EQ "the crossed one only re-indenting it" "$(git show --format= HEAD -- c.js | grep -c -e "inherit() === ")" "0"
unfunction _RI_S _RX_F _RX_REPO _RR_F _RC_F
