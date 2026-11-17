# A paused edit taking in lines a later commit adds lands, a commit between re-indenting them at its
# stop as it does their region – the later commit no longer adding them, as the edit moved them:
# • A stop before that re-indent taking them in still refuses at the landing, naming that stop
# • A stop taking in a later commit's own re-indent of a line still refuses
# • So does one taking in one later commit's removal of lines and another's adding them back
_ST_SCENARIO "\e[1;96m[282] a paused edit moving a later commit's lines lands\e[0m"
local PM_E PM_M PM_TREE PM_WT
local -a PM_LINES=("const changes = listChanges();" "if (changes.length) {" $'\tlog(changes);' "}")

# Prints `f.js` with <setup> in its setup call, the call wrapped in an else
# where <wrap> is given, and the listed lines after the report where <lines> is
_PM_F () {
	# Args: <setup> <wrap> <lines>
	local I=$'\t'
	print -r -- "function main() {"
	[ -z "$2" ] || { print -l -- $'\tif (quick) {' $'\t\tskip();' $'\t} else {'; I=$'\t\t'; }
	print -r -- "${I}setup($1);"
	print -r -- "${I}report();"
	[ -z "$3" ] || print -l -- "${PM_LINES[@]/#/$I}"
	[ -z "$2" ] || print -r -- $'\t}'
	print -l -- $'\trun();' "}"
}

# Makes a repo where E changes `e.js` and L adds the listed lines, M wrapping their region
# in an else between – <fast> making a commit before M set the setup call's argument to `fast`
_PM_REPO () {
	# Args: <name> [<fast>]
	_ST_PZ_NEW "$1"
	git config rerere.enabled false
	_PM_F "" "" "" > f.js && print e0 > e.js && print l0 > l.js && git add . && git commit -qm "$1 base"
	print e1 > e.js && git commit -qam "$1 E" && PM_E=$(git rev-parse HEAD)
	[ -z "$2" ] || { _PM_F fast "" "" > f.js && git commit -qam "$1 F sets the setup fast" && PM_M=$(git rev-parse HEAD); }
	_PM_F "${2:+fast}" 1 "" > f.js && git commit -qam "$1 M wraps the setup"
	_PM_F "${2:+fast}" 1 1 > f.js && print l1 > l.js && git commit -qam "$1 L lists the changes"
	PM_TREE=$(git rev-parse "HEAD^{tree}")
}
export GIT_EDIT_NO_SELF_RESOLVE=1 GIT_EDIT_ACTOR=pm-1
_PM_REPO pm
_ST_RUN "$PM_E"
PM_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${PM_WT:-$ST_NO_WT}" f.js "$(_PM_F "" "" 1)"
_ST_RUN --continue
_ST_EQ "the edit adding the later commit's lines stops at the commit re-indenting their region" "$RC" "2"
_ST_RESOLVE "${PM_WT:-$ST_NO_WT}" f.js "$(_PM_F "" 1 1)"
_ST_RUN --continue
_ST_EQ "its stop re-indenting them too, it lands, the tip as it was" "$RC:$(git rev-parse "HEAD^{tree}")" "0:$PM_TREE"
_ST_OUT_LACKS "never refused at the stop" "The staged resolution takes in"
_ST_OUT_LACKS "nor as taking in a later change" 'took in what a later commit changes'
_ST_EQ "the edited commit adding them, the later one no longer" \
	"$(git show --format= HEAD~2 -- f.js | grep -c -e '^+	const changes'):$(git show --format= --name-only HEAD | tr '\n' ' ')" "1:l.js "
# A stop before the re-indent taking them in refuses at the landing, held at that stop
_PM_REPO pt fast
_ST_RUN "$PM_E"
PM_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${PM_WT:-$ST_NO_WT}" f.js "$(_PM_F slow "" "")"
_ST_RUN --continue
_ST_RESOLVE "${PM_WT:-$ST_NO_WT}" f.js "$(_PM_F fast "" 1)"
_ST_RUN --continue
_ST_EQ "taken in at their old indent, the replay goes on to the stop re-indenting them" "$RC" "2"
_ST_OUT_HAS "that stop's commit" "This stop builds [0-9a-f]* pt M wraps the setup"
_ST_RESOLVE "${PM_WT:-$ST_NO_WT}" f.js "$(_PM_F fast 1 1)"
_ST_RUN --continue
_ST_EQ "a stop taking them in before their re-indent refuses at the landing" "$RC" "1"
_ST_OUT_HAS "naming the later commit and its file" "^  [0-9a-f]* pt L lists the changes – f\.js"
_ST_OUT_HAS "held at the stop that took them in" "held at the stop for [0-9a-f]* (pt F sets the setup fast)"
_ST_RUN --abort
# So does a stop taking in a later commit's own re-indent of a line
_ST_PZ_NEW pr
git config rerere.enabled false
_PM_F "" "" "" > f.js && print e0 > e.js && print l0 > l.js && git add . && git commit -qm "pr base"
print e1 > e.js && git commit -qam "pr E" && PM_E=$(git rev-parse HEAD)
_PM_F 1 "" "" > f.js && git commit -qam "pr M sets the setup"
_PM_F 1 "" "" | sed $'s/^\treport/    report/' > f.js && print l1 > l.js && git commit -qam "pr L indents the report with spaces"
_ST_RUN "$PM_E"
PM_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${PM_WT:-$ST_NO_WT}" f.js "$(_PM_F 2 "" "")"
_ST_RUN --continue
_ST_RESOLVE "${PM_WT:-$ST_NO_WT}" f.js "$(_PM_F 1 "" "" | sed $'s/^\treport/    report/')"
_ST_RUN --continue
_ST_EQ "a stop taking in a later commit's re-indent refuses at the landing" "$RC" "1"
_ST_OUT_HAS "naming that commit and its file" "^  [0-9a-f]* pr L indents the report with spaces – f\.js"
_ST_RUN --abort
# A stop resolved to the tip, one later commit dropping two lines and another adding them in a block
_ST_PZ_NEW px
git config rerere.enabled false
# Prints `f.js` with <setup> in its setup call, the logs where <logs> says: `top` or `block`
_PX_F () {
	# Args: <setup> <logs>
	print -l -- "function main() {" $'\t'"setup($1);"
	[ "$2" != top ] || print -l -- $'\tlog(first);' $'\tlog(second);'
	print -l -- $'\tif (ready) {' $'\t\tgo();'
	[ "$2" != block ] || print -l -- $'\t\tlog(first);' $'\t\tlog(second);'
	print -l -- $'\t}' "}"
}
_PX_F "" top > f.js && print e0 > e.js && print z0 > z.js && print l0 > l.js && git add . && git commit -qm "px base"
print e1 > e.js && git commit -qam "px E" && PM_E=$(git rev-parse HEAD)
_PX_F 1 top > f.js && git commit -qam "px M sets the setup"
_PX_F 1 "" > f.js && print z1 > z.js && git commit -qam "px Z drops the logs"
_PX_F 1 block > f.js && print l1 > l.js && git commit -qam "px O logs in the block"
_ST_RUN "$PM_E"
PM_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${PM_WT:-$ST_NO_WT}" f.js "$(_PX_F 2 top)"
_ST_RUN --continue
_ST_RESOLVE "${PM_WT:-$ST_NO_WT}" f.js "$(git show main:f.js)"
_ST_RUN --continue
_ST_EQ "a stop taking in both refuses at the landing" "$RC" "1"
_ST_OUT_HAS "naming the commit dropping them" "^  [0-9a-f]* px Z drops the logs – f\.js"
_ST_OUT_HAS "and the one adding them back" "^  [0-9a-f]* px O logs in the block – f\.js"
_ST_RUN --abort
unset GIT_EDIT_NO_SELF_RESOLVE GIT_EDIT_ACTOR
