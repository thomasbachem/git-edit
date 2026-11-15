# A commit moved or reordered past a later one relocating its code lands where it and a commit it
# crosses rewrite one line's words, rebuilt making its own words' change where the code moved – its
# stop refusing nothing, its own lines staged there never a later commit's taken in:
# • A stop's resolution taking in a later commit's words there still refuses, at stop and landing
# • So does a stop taking in a rewrite the later commit also makes in another file, or one
#   making a commit's words on a line sharing too few others or in a file its code never moved to
_ST_SCENARIO "\e[1;96m[281] a rewrite carried across its code's relocation lands\e[0m"
local RW_O RW_X RW_M RW_TREE RW_WT
local -a RW_F=("const findCost = (src) => {" $'\tconst hits = scan(src)' $'\treturn hits.filter(costly)' "}")
local -a RW_S=("const findSlow = (src) => {" $'\tconst hits = scan(src)' $'\treturn hits.filter(slow)' "}")

# Writes <file>'s lines and stages it
_RW_W () {
	# Args: <file> <line>...
	print -l -- "${@:2}" > "$1" && git add -- "$1"
}

# Prints the call line of the checks <name>… in `a.js`
_RW_A () {
	# Args: <name>...
	local -a L=("${@/%/(src)}")
	print -r -- "for (const v of [...${(pj:, ...:)L}]) report(v)"
}

# Prints it as `s.js` holds it, moved there
_RW_S () {
	# Args: <name>...
	local -a L=("${@/%/()}")
	print -r -- $'\t'"return [...${(pj:, ...:)L}]"
}

# Makes a repo where O adds `findCost` to the call line, X adds `findBroken` there, M moves the
# checks into `s.js` and T adds a file – <kind> `helper` adding O's function, moved along, and
# T `findSlow` there, `list` O adding `findCost` to the list in `c.js` too, `extra` adding `x.js`
_RW_REPO () {
	# Args: <name> [<kind>]
	local -a F
	[ "$2" = helper ] && F=("${RW_F[@]}")
	_ST_PZ_NEW "$1"
	git config rerere.enabled false
	_RW_W a.js "const top = 1" "$(_RW_A findA findB)" "const bottom = 2"
	[ "$2" != list ] || _RW_W c.js "const checks = [findA, findB]"
	[ "$2" != extra ] || _RW_W x.js "const extra = [findZ]"
	git commit -qm "$1 base"
	_RW_W a.js "const top = 1" "${F[@]}" "$(_RW_A findA findCost findB)" "const bottom = 2"
	[ "$2" != list ] || _RW_W c.js "const checks = [findA, findCost, findB]"
	git commit -qm "$1 O adds the cost check" && RW_O=$(git rev-parse HEAD)
	_RW_W a.js "const top = 1" "${F[@]}" "$(_RW_A findA findCost findB findBroken)" "const bottom = 2"
	git commit -qm "$1 X adds the broken check" && RW_X=$(git rev-parse HEAD)
	_RW_W a.js "const top = 1" "const bottom = 2"
	_RW_W s.js "${F[@]}" "export function checks(src) {" "$(_RW_S findA findCost findB findBroken)" "}"
	git commit -qm "$1 M moves the checks into s.js" && RW_M=$(git rev-parse HEAD)
	print -r -- t > t.txt && git add t.txt
	[ "$2" != helper ] || _RW_W s.js "${F[@]}" "${RW_S[@]}" "export function checks(src) {" "$(_RW_S findA findCost findB findBroken)" "}"
	git commit -qm "$1 T top"
	RW_TREE=$(git rev-parse "HEAD^{tree}")
}

# Resolves the stops of O placed after M, each to its own commit's change alone
# – <take> what O's stop stages in `s.js` instead, <file> staged there as <content> too
_RW_STOPS () {
	# Args: [<take> [<file> <content>]]
	RW_WT=$(_ST_PZ_WT)
	_ST_RESOLVE "${RW_WT:-$ST_NO_WT}" a.js "$(print -l "const top = 1" "$(_RW_A findA findB findBroken)" "const bottom = 2")"
	_ST_RUN --continue
	_ST_RESOLVE "${RW_WT:-$ST_NO_WT}" a.js "$(print -l "const top = 1" "const bottom = 2")"
	_ST_RESOLVE "${RW_WT:-$ST_NO_WT}" s.js "$(print -l "export function checks(src) {" "$(_RW_S findA findB findBroken)" "}")"
	_ST_RUN --continue
	_ST_RESOLVE "${RW_WT:-$ST_NO_WT}" a.js "$(print -l "const top = 1" "const bottom = 2")"
	_ST_RESOLVE "${RW_WT:-$ST_NO_WT}" s.js "${1:-$(git show "${RW_M}:s.js")}"
	[ -z "$2" ] || _ST_RESOLVE "${RW_WT:-$ST_NO_WT}" "$2" "$3"
	_ST_RUN --continue
}
export GIT_EDIT_NO_SELF_RESOLVE=1
_RW_REPO rw
_ST_RUN --reorder "$RW_X" "$RW_M" "$RW_O" "$(git rev-parse HEAD)"
_ST_EQ "reordered past its code's relocation, the commit it crosses stops" "$RC" "2"
_RW_STOPS
_ST_EQ "resolved each to its own change, it lands in the new order, the tip as it was" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git rev-parse "HEAD^{tree}")" \
	"0:rw T top|rw O adds the cost check|rw M moves the checks into s.js|rw X adds the broken check|rw base|:$RW_TREE"
_ST_OUT_LACKS "never refused as taking in a later change" 'took in what a later commit changes'
_ST_EQ "the moved commit making its rewrite where its code moved" \
	"$(git show --format= HEAD~1 | grep -e '^[-+]	return' | tr '\n' '|')" \
	"-	return [...findA(), ...findB(), ...findBroken()]|+	return [...findA(), ...findCost(), ...findB(), ...findBroken()]|"
_ST_EQ "the commits it crossed holding none of it" "$(git log --format=%s -G findCost HEAD~3..HEAD~1 | tr '\n' '|')" "rw O adds the cost check|"
_RW_REPO rm
_ST_RUN --move="$RW_O" --after="$RW_M"
_RW_STOPS
_ST_EQ "moved there instead, it lands the same" "$RC:$(git log --format=%s | tr '\n' '|'):$(git rev-parse "HEAD^{tree}")" \
	"0:rm T top|rm O adds the cost check|rm M moves the checks into s.js|rm X adds the broken check|rm base|:$RW_TREE"
_ST_OUT_LACKS "never refused as taking in a later change either" 'took in what a later commit changes'
# Its function moved along, a later commit writing one of its lines there too refuses nowhere
_RW_REPO rh helper
_ST_RUN --move="$RW_O" --after="$RW_M"
_RW_STOPS
_ST_OUT_LACKS "its own lines staged where its code moved never refused at its stop" "The staged resolution takes in"
_ST_EQ "it lands, the tip as it was" "$RC:$(git rev-parse "HEAD^{tree}")" "0:$RW_TREE"
_ST_EQ "its function written where its code moved" \
	"$(git log -1 --format=%s HEAD~1):$(git show --format= HEAD~1 -- s.js | grep -c -e '^+	return hits.filter(costly)$')" "rh O adds the cost check:1"
# A stop taking in a later commit's words where the code moved refuses there and at the landing
_RW_REPO rt
_RW_W s.js "export function checks(src) {" "$(_RW_S findA findCost findB findBroken findSlow)" "}"
git commit -qm "rt S adds the slow check"
_ST_RUN --move="$RW_O" --after="$RW_M"
_RW_STOPS "$(git show HEAD:s.js)"
_ST_EQ "a stop taking in a later commit's words where the code moved refuses there" "$RC" "2"
_ST_OUT_HAS "naming that commit and its file" "rt S adds the slow check – s\.js$"
_ST_OUT_HAS "and the line held" 'its line "	return \[\.\.\.findA(), \.\.\.findCost(), .*" held here'
_ST_RUN --continue
_ST_OUT_HAS "the same resolution again goes on, to the commit it emptied" "Could not apply [0-9a-f]*\.\.\. .*rt S adds the slow check"
_ST_RUN --continue
_ST_EQ "where the landing refuses it" "$RC" "1"
_ST_OUT_HAS "as that commit's change taken in" "^  [0-9a-f]* rt S adds the slow check – s\.js"
_ST_RUN --abort
# A stop taking in a rewrite the later commit also makes in another file refuses at the landing
_RW_REPO rn list
_ST_RUN --move="$RW_O" --after="$RW_M"
RW_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RW_WT:-$ST_NO_WT}" a.js "$(git show "${RW_X}:a.js")"
_ST_RUN --continue
_ST_RESOLVE "${RW_WT:-$ST_NO_WT}" a.js "$(print -l "const top = 1" "const bottom = 2")"
_ST_RUN --continue
_ST_EQ "a stop taking in a rewrite the later commit makes in another file too refuses at the landing" "$RC" "1"
_ST_OUT_HAS "naming that commit's file it lost it in" "^  [0-9a-f]* rn O adds the cost check – a\.js$"
_ST_RUN --abort
# So does one staging those words on a line sharing too few others, the stop's code moved or not
_RW_REPO rx extra
_RW_W x.js "const extra = [findZ, findCost]" && git commit -qm "rx S adds the cost check to the extras"
_ST_RUN --move="$RW_O" --after="$RW_M"
_RW_STOPS "" x.js "const extra = [findZ, findCost]"
_ST_EQ "a resolution staging its words on an unrelated line refuses at the stop" "$RC" "2"
_ST_OUT_HAS "naming the commit making them there" "rx S adds the cost check to the extras – x\.js$"
_ST_RUN --abort
# A resolution making a later commit's words in a file the stop's code never moved to refuses there
_ST_PZ_NEW rk
git config rerere.enabled false
_RW_W a.js "$(_RW_A findA findB)" && _RW_W b.js "const checks = [findA, findB]" && _RW_W n.txt one
git commit -qm "rk base"
_RW_W a.js "$(_RW_A findA findCost findB)" && _RW_W n.txt two && git commit -qm "rk O adds the cost check"
RW_O=$(git rev-parse HEAD)
_RW_W n.txt three && git commit -qm "rk Y" && RW_X=$(git rev-parse HEAD)
_RW_W b.js "const checks = [findA, findCost, findB]" && git commit -qm "rk G lists the cost check"
_ST_RUN --move="$RW_O" --after="$RW_X"
RW_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RW_WT:-$ST_NO_WT}" n.txt three
_ST_RUN --continue
_ST_RESOLVE "${RW_WT:-$ST_NO_WT}" n.txt three-two
_ST_RESOLVE "${RW_WT:-$ST_NO_WT}" b.js "const checks = [findA, findCost, findB]"
_ST_RUN --continue
_ST_EQ "a resolution making a later commit's words where its code never moved refuses at the stop" "$RC" "2"
_ST_OUT_HAS "naming that commit and its file" "rk G lists the cost check – b\.js$"
_ST_RUN --abort
unset GIT_EDIT_NO_SELF_RESOLVE
