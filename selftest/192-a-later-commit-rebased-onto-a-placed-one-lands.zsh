# A commit placed or moved below a later commit that rewrote its line lands once each stop is
# resolved as told – that commit, rebuilt, still rewriting the line, its change rebased onto the
# placed one's rather than taken in – while a stop that took that change in refuses, naming the
# placement past it that works
_ST_SCENARIO "\e[1;96m[192] a later commit rebased onto a placed one lands, one taken in refuses\e[0m"
local RB_C1 RB_C2 RB_X RB_T RB_CMD

# Commits f.txt's twelve lines, a.txt beside, then c1 (a.txt), c2 (line 5 – g.txt too, given
# <g>) and c3 (a.txt), leaving line 5 edited on top
_RB_SETUP () {
	# Args: <name> [<g>]
	_ST_PZ_NEW "$1"
	git config rerere.enabled false
	print -l -- "f line "{1..12} > f.txt && print a > a.txt && git add -A && git commit -qm "RB c0"
	print b >> a.txt && git commit -qam "RB c1 a" && RB_C1=$(git rev-parse HEAD)
	_RB_F "f line 5 v2" > f.txt
	[ -z "$2" ] || { print -r -- "$2" > g.txt && git add g.txt; }
	git commit -qam "RB c2 f line 5" && RB_C2=$(git rev-parse HEAD)
	print c >> a.txt && git commit -qam "RB c3 a" && RB_T=$(git rev-parse HEAD)
	_RB_F "f line 5 v2 wip" > f.txt
}
# Prints f.txt with line 5 as <line>
_RB_F () {
	# Args: <line>
	print -l -- "f line "{1..4} "$1" "f line "{6..12}
}
# Runs the checkout step a stop printed, as printed
_RB_PRINTED_STEP () {
	RB_CMD=$(sed -n 's/^  \(git -C .* checkout [0-9a-f]* -- f\.txt\)$/\1/p' <<<"$OUT")
	[ -n "$RB_CMD" ] && eval "$RB_CMD"
}

# Placed after c1, its stop resolved to its own change there and c2's to the printed step
_RB_SETUP rb1
_ST_RUN --commit --after="$RB_C1" --text "RB1 wip on line 5" -- f.txt
_ST_EQ "a commit placed below a later rewrite of its line stops" "$RC" "2"
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt "$(_RB_F "f line 5 wip")"
_ST_RUN --continue
_ST_EQ "the later commit stops in turn" "$RC" "2"
_RB_PRINTED_STEP
_ST_RUN --continue
_ST_EQ "resolved as printed, it lands" "$RC:$(git log --format=%s | tr '\n' '|')" \
	"0:RB c3 a|RB c2 f line 5|RB1 wip on line 5|RB c1 a|RB c0|"
_ST_EQ "holding the placed change" "$(git diff HEAD~3 HEAD~2 -- f.txt | grep '^[-+]f' | tr '\n' '|')" "-f line 5|+f line 5 wip|"
_ST_EQ "and the later change rebased onto it" "$(git diff HEAD~2 HEAD~1 -- f.txt | grep '^[-+]f' | tr '\n' '|')" \
	"-f line 5 wip|+f line 5 v2 wip|"
_ST_OUT_LACKS "never naming the line superseded" 'Superseded'

# The same commit moved there from the tip
_RB_SETUP rb2
_ST_RUN --commit --text "RB2 wip on line 5" -- f.txt
RB_X=$(git rev-parse HEAD)
_ST_RUN --move="$RB_X" --after="$RB_C1"
_ST_EQ "a move below a later rewrite of its line stops" "$RC" "2"
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt "$(_RB_F "f line 5 wip")"
_ST_RUN --continue
_RB_PRINTED_STEP
_ST_RUN --continue
_ST_EQ "resolved as printed, the move lands" "$RC:$(git log --format=%s | tr '\n' '|')" \
	"0:RB c3 a|RB c2 f line 5|RB2 wip on line 5|RB c1 a|RB c0|"
_ST_EQ "the later change rebased onto the moved one" "$(git diff HEAD~2 HEAD~1 -- f.txt | grep '^[-+]f' | tr '\n' '|')" \
	"-f line 5 wip|+f line 5 v2 wip|"

# Its neighbor: a stop taking in c2's change, c2 left with nothing there, refuses – naming the
# placement past c2, which then lands
_RB_SETUP rb3 g2
_ST_RUN --commit --before="$RB_C2" --text "RB3 wip on line 5" -- f.txt
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt "$(_RB_F "f line 5 v2 wip")"
_ST_RUN --continue
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt "$(_RB_F "f line 5 v2 wip")"
_ST_RUN --continue
_ST_EQ "a stop taking in a later commit's change refuses" "$RC:$(git rev-parse HEAD)" "1:$RB_T"
_ST_OUT_HAS "naming it" 'RB c2 f line 5 – f\.txt$'
_ST_OUT_HAS "and the placement past it" "or placed past the change it builds on: --after=${RB_C2:0:12} in place of --before=${RB_C2:0:7}"
_ST_RUN --abort
_ST_RUN --commit --after="${RB_C2:0:12}" --text "RB3 wip on line 5" -- f.txt
_ST_EQ "which lands" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:f.txt | sed -n 5p)" \
	"0:RB c3 a|RB3 wip on line 5|RB c2 f line 5|RB c1 a|RB c0|:f line 5 v2 wip"

# A move the same way names the move past c2
_RB_SETUP rb4 g2
_ST_RUN --commit --text "RB4 wip on line 5" -- f.txt
RB_X=$(git rev-parse HEAD)
_ST_RUN --move="$RB_X" --after="$RB_C1"
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt "$(_RB_F "f line 5 v2 wip")"
_ST_RUN --continue
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt "$(_RB_F "f line 5 v2 wip")"
_ST_RUN --continue
_ST_EQ "a move whose stop took in a later change refuses" "$RC:$(git rev-parse HEAD)" "1:$RB_X"
_ST_OUT_HAS "naming the move past it" "git edit --move=${RB_X:0:12} --after=${RB_C2:0:12}"
_ST_RUN --abort
_ST_RUN --move="${RB_X:0:12}" --after="${RB_C2:0:12}"
_ST_EQ "which lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:RB c3 a|RB4 wip on line 5|RB c2 f line 5|RB c1 a|RB c0|"

# One moved below the commit right before it offers no move, only their order kept or the squash
_ST_PZ_NEW rb5
git config rerere.enabled false
print -l 1 2 3 4 5 > f.txt && git add f.txt && git commit -qm "RB5 base"
print -l 1 2 3 4a 5 > f.txt && git commit -qam "RB5 A" && RB_C1=$(git rev-parse HEAD)
print -l 1 2 3 4b 5 > f.txt && git commit -qam "RB5 B" && RB_X=$(git rev-parse HEAD)
_ST_RUN --move="$RB_X" --before="$RB_C1"
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'1\n2\n3\n4b\n5'
_ST_RUN --continue
_ST_EQ "a move below the commit it builds on refuses" "$RC:$(git rev-parse HEAD)" "1:$RB_X"
_ST_OUT_LACKS "offering no move" 'git edit --move='
_ST_OUT_HAS "but the squash" "git edit -s=${RB_C1:0:12} ${RB_X:0:12}"
_ST_RUN --abort

# And 185's: a later commit that only rewords the line, left with nothing of its own, refuses
_ST_PZ_NEW rb6
git config rerere.enabled false
print -l "# Doc" "Restart: poll until it answers 200." "tail" > c.md && git add c.md && git commit -qm "RB6 base"
print -r -- x > o.txt && git add o.txt && git commit -qm "RB6 A other" && RB_C1=$(git rev-parse HEAD)
print -l "# Doc" "Restart: poll for a 200." "tail" > c.md && git commit -qam "RB6 L rewords"
print -r -- y > p.txt && git add p.txt && git commit -qm "RB6 T top" && RB_T=$(git rev-parse HEAD)
print -l "# Doc" "Restart: NOTE one curl waits it out." "tail" > c.md
_ST_RUN --commit --after="$RB_C1" --text "RB6 note the restart" -- c.md
_ST_RESOLVE "$(_ST_PZ_WT)" c.md $'# Doc\nRestart: NOTE one curl waits it out.\ntail'
_ST_RUN --continue
_ST_RESOLVE "$(_ST_PZ_WT)" c.md $'# Doc\nRestart: NOTE one curl waits it out.\ntail'
_ST_RUN --continue
_ST_EQ "a later commit losing all its change to the file refuses" "$RC:$(git rev-parse HEAD)" "1:$RB_T"
_ST_OUT_HAS "naming it" 'RB6 L rewords'
_ST_RUN --abort
unfunction _RB_SETUP _RB_F _RB_PRINTED_STEP
cd "$TMP/repo"
