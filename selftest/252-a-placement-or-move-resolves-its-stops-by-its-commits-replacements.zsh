# A placed or moved commit's line replacements resolve its replay's stops as a fold's do – at its
# own step, and at a commit it moved across, taken back where it moved past it – on a resume too:
# • A `--commit` given `--edits` makes those, the gate checks a stop resolved by its words
# • A line the anchor lacks, or a file resolved by hand otherwise than they make it, stops
# • A move resolves by line identity what they leave, a later commit's edits to the moved lines
#   going with them, and pauses where a line's place or writer is not sure
_ST_SCENARIO "\e[1;96m[252] a placement or move resolves its stops by its commits' replacements\e[0m"
local PM_A PM_M PM_B PM_WT PM_OLD=""
# Below git 2.50 no least change is sure, so a move's line identity resolves nothing there
[[ "$(git --version)" =~ '^git version 2\.([0-9]+)\.' ]] && (( match[1] < 50 )) && PM_OLD=1
# Prints <rev>'s `f` on one line
_PM_AT () {
	# Args: <rev>
	git show "$1:f" | tr '\n' '|'
}
# Commits a line whose neighbors the next commit rewrites, then one beside – sets `PM_A`
_PM_REWRITTEN () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	print -l x1 "the comment" x3 > f && git add f && git commit -qm "PM anchor"
	PM_A=$(git rev-parse HEAD)
	print -l y1 "the comment" y3 > f && git commit -qam "PM around it"
	_ST_PZ_C g g1 "PM beside"
}

# Placed before the commit rewriting its line's neighbors, both stops resolve
_PM_REWRITTEN pm-place
print -l y1 "the fixed comment" y3 > f
_ST_RUN --commit --text "PM fix" --after="$PM_A" -- f
_ST_EQ "a placement lands, its own stop and the one it crossed resolved" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(_PM_AT HEAD~2):$(_PM_AT HEAD~1)" \
	"0:PM beside|PM around it|PM fix|PM anchor|:x1|the fixed comment|x3|:y1|the fixed comment|y3|"
_ST_OUT_HAS "saying so" "Made the placed commits' line replacements in the 2 commit(s) the replay stopped at"

# Moved earlier as a commit of its own, alike
_PM_REWRITTEN pm-move
print -l y1 "the fixed comment" y3 > f && git commit -qam "PM fix"
_ST_RUN --move=HEAD --after="$PM_A"
_ST_EQ "a move earlier lands alike" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(_PM_AT HEAD~2):$(_PM_AT HEAD~1)" \
	"0:PM beside|PM around it|PM fix|PM anchor|:x1|the fixed comment|x3|:y1|the fixed comment|y3|"
_ST_OUT_HAS "saying so" "Made the moved commits' line replacements in the 2 commit(s) the replay stopped at"

# Moved later past the commit rewriting its line's neighbors, that one takes its change back
_ST_PZ_NEW pm-later
print -l x1 "the comment" x3 > f && git add f && git commit -qm "PM base"
print -l x1 "the fixed comment" x3 > f && git commit -qam "PM fix"
PM_M=$(git rev-parse HEAD)
print -l y1 "the fixed comment" y3 > f && git commit -qam "PM around it"
PM_B=$(git rev-parse HEAD)
_ST_PZ_C g g1 "PM beside"
_ST_RUN --move="$PM_M" --after="$PM_B"
_ST_EQ "a move later lands, the commit it moved past holding the line without it" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(_PM_AT HEAD~2):$(_PM_AT HEAD~1)" \
	"0:PM beside|PM fix|PM around it|PM base|:y1|the comment|y3|:y1|the fixed comment|y3|"

# A `--commit` given `--edits` makes them, where the hunk its two lines make the anchor lacks
_ST_PZ_NEW pm-edits
print -l "alpha one" "bravo one" x3 > f && git add f && git commit -qm "PM anchor"
PM_A=$(git rev-parse HEAD)
print -l "alpha two" "bravo two" y3 > f && git commit -qam "PM around it"
_ST_PZ_C g g1 "PM beside"
_ST_RUN --commit --text "PM fix" --after="$PM_A" --edits '{"f": [["alpha", "ALPHA"], ["bravo", "BRAVO"]]}'
_ST_EQ "a placement's given edits resolve its stops" \
	"$RC:$(_PM_AT HEAD~2):$(_PM_AT HEAD~1)" "0:ALPHA one|BRAVO one|x3|:ALPHA two|BRAVO two|y3|"

# Pauses a placement at its own stop, a line it inserts beside one the anchor lacks – sets `PM_WT`
_PM_PAUSED () {
	# Args: <repo name> [move – committed, then moved]
	_ST_PZ_NEW "$1"
	print -l x1 "the comment" x3 > f && print -l h1 h2 > h && git add f h && git commit -qm "PM anchor"
	PM_A=$(git rev-parse HEAD)
	print -l y1 "the comment" y3 > f && git commit -qam "PM around it"
	print -l h1 hb h2 > h && git commit -qam "PM h"
	_ST_PZ_C g g1 "PM beside"
	print -l y1 "the fixed comment" y3 > f && print -l h1 hb hN h2 > h
	if [ "$2" = move ]; then
		git commit -qam "PM fix" && _ST_RUN --move=HEAD --after="$PM_A"
	else
		_ST_RUN --commit --text "PM fix" --after="$PM_A" -- f h
	fi
	PM_WT=$(_ST_PZ_WT)
}
# A resume goes on so – bar a file resolved by hand otherwise than they make it
_PM_PAUSED pm-resume
_ST_EQ "a stop inserting a line pauses" "$RC:$(git -C "$PM_WT" diff --name-only --diff-filter=U | tr '\n' ' ')" "2:f h "
print -l x1 "the fixed comment" x3 > "$PM_WT/f" && print -l h1 hN h2 > "$PM_WT/h" && git -C "$PM_WT" add f h
_ST_RUN --continue
_ST_EQ "its resume resolving the next stop, pausing at one in that file" \
	"$RC:$(git -C "$PM_WT" diff --name-only --diff-filter=U | tr '\n' ' '):$(git -C "$PM_WT" show HEAD:f | tr '\n' '|')" \
	"2:h :y1|the fixed comment|y3|"
_ST_OUT_HAS "saying so" "Made the placed commits' line replacements in the 1 later commit(s)"
_ST_RUN --abort
# A move's own stop its line identity resolves, it goes on to the stop a crossed commit's line
# inserted beside a moved one makes, where nothing it builds tells their order
_PM_PAUSED pm-move-resume move
if [ -n "$PM_OLD" ]; then
	_ST_EQ "as does a move's, its own stop paused before git 2.50" "$RC:$(git -C "$PM_WT" diff --name-only --diff-filter=U | tr '\n' ' ')" "2:f h "
	_ST_RUN --abort
else
_ST_EQ "as does a move's, by line identity" \
	"$RC:$(git -C "$PM_WT" diff --name-only --diff-filter=U | tr '\n' ' '):$(git -C "$PM_WT" show HEAD:f | tr '\n' '|')" \
	"2:h :y1|the fixed comment|y3|"
_ST_OUT_HAS "saying so" "Made the moved commits' line replacements in the 2 commit(s)"
print -l h1 hb hN h2 > "$PM_WT/h" && git -C "$PM_WT" add h
_ST_RUN --continue
_ST_EQ "landing once that stop is resolved" "$RC:$(git log --format=%s | tr '\n' '|')" "0:PM beside|PM h|PM around it|PM fix|PM anchor|"
fi
_PM_PAUSED pm-own
print -l x1 "the comment, fixed otherwise" x3 > "$PM_WT/f" && print -l h1 hN h2 > "$PM_WT/h" && git -C "$PM_WT" add f h
_ST_RUN --continue
_ST_EQ "a file resolved by hand otherwise pauses the next stop" "$RC:$(git -C "$PM_WT" diff --name-only --diff-filter=U | tr '\n' ' ')" "2:f "
_ST_RUN --abort

# A line only a later commit wrote is missing where it is placed
_ST_PZ_NEW pm-later-line
print -l x1 "an older comment" x3 > f && git add f && git commit -qm "PM anchor"
PM_A=$(git rev-parse HEAD)
print -l x1 "the comment" x3 > f && git commit -qam "PM writes it"
_ST_PZ_C g g1 "PM beside"
print -l x1 "the fixed comment" x3 > f
_ST_RUN --commit --text "PM fix" --after="$PM_A" -- f
_ST_EQ "a placement's line the anchor lacks pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort

# As does every stop the switch leaves to the resolver
_PM_REWRITTEN pm-off
print -l y1 "the fixed comment" y3 > f
OUT=$(GIT_EDIT_NO_SELF_RESOLVE=1 GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "PM fix" --after="$PM_A" -- f </dev/null 2>&1)
RC=$?
_ST_EQ "GIT_EDIT_NO_SELF_RESOLVE leaves a placement's stop" "$RC" "2"
_ST_RUN --abort

# The gate checks a commit its changed words alone resolved, as a resolver's own
_ST_PZ_NEW pm-words
print -l "// alpha bravo charlie delta" "// echo foxtrot golf hotel" > c && git add c && git commit -qm "PM anchor"
PM_A=$(git rev-parse HEAD)
print -l "// alpha bravo charlie" "// delta echo foxtrot golf hotel" > c && git commit -qam "PM rewrap one"
print -l "// alpha bravo" "// charlie delta echo foxtrot golf hotel" > c && git commit -qam "PM rewrap two"
_ST_PZ_C g g1 "PM beside"
git config edit.verifyCmd "sh -c 'git log -1 --format=%s \"\$GIT_EDIT_VERIFY_COMMIT\" >> \"$TMP/pm-verified\"'"
: > "$TMP/pm-verified"
print -l "// alpha bravo" "// charlie delta echo FOXTROT golf hotel" > c
_ST_RUN --commit --text "PM fix" --after="$PM_A" -- c
_ST_EQ "a placement's stops resolve by the words, each wrap kept" \
	"$RC:$(git show HEAD~3:c | tr '\n' '|'):$(git show HEAD~2:c | tr '\n' '|')" \
	"0:// alpha bravo charlie delta|// echo FOXTROT golf hotel|:// alpha bravo charlie|// delta echo FOXTROT golf hotel|"
_ST_EQ "the gate checking the rewrap the words alone resolved" "$(grep -c -x 'PM rewrap one' "$TMP/pm-verified")" "1"
git config --unset edit.verifyCmd

# A block of two, the second building on the first, makes both at the commit they crossed
_ST_PZ_NEW pm-block
print -l 1 a b c 5 > f && git add f && git commit -qm "PM base"
print -l 1 a B c 5 > f && git commit -qam "PM around it"
PM_B=$(git rev-parse HEAD)
print -l 1 A B c 5 > f && git commit -qam "PM one"
print -l 1 A2 B c 5 > f && git commit -qam "PM two"
_ST_PZ_C g g1 "PM beside"
_ST_RUN --move=HEAD~2 --move=HEAD~1 --before="$PM_B"
_ST_EQ "a block moved earlier lands, the crossed commit taking both" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(_PM_AT HEAD~1)" "0:PM beside|PM around it|PM two|PM one|PM base|:1|A2|B|c|5|"

# Commits a line a later commit's own change shifts by writing a line before it, which a change
# placed before them follows – never the same text a commit wrote elsewhere
_PM_SHIFTED () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	print -l foo baz > f && git add f && git commit -qm "PM anchor"
	PM_A=$(git rev-parse HEAD)
	print -l bar foo > f && git commit -qam "PM rewrites"
	_ST_PZ_C g g1 "PM beside"
}
_PM_SHIFTED pm-shifted
print -l bar qux > f
_ST_RUN --commit --text "PM fix" --after="$PM_A" -- f
_ST_EQ "a placement follows its line where a commit's own change only shifted it" \
	"$RC:$(_PM_AT HEAD~2):$(_PM_AT HEAD~1)" "0:qux|baz|:bar|qux|"
_PM_SHIFTED pm-shifted-move
print -l bar qux > f && git commit -qam "PM fix"
_ST_RUN --move=HEAD --before=HEAD~2
_ST_EQ "as does such a move" "$RC:$(_PM_AT HEAD~2):$(_PM_AT HEAD~1)" "0:qux|baz|:bar|qux|"
# But a line another of its text beside a commit's change could as well pair with pauses
_ST_PZ_NEW pm-pairs
print -l 1 a z > f && git add f && git commit -qm "PM anchor"
PM_A=$(git rev-parse HEAD)
print -l 1 a b a z > f && git commit -qam "PM inserts beside it"
print -l X A b a z > f
_ST_RUN --commit --text "PM fix" --after="$PM_A" -- f
_ST_EQ "a placement beside a run ending in its line's text pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
_ST_PZ_NEW pm-pairs-later
print -l 1 q b a z > f && git add f && git commit -qm "PM base"
print -l X a b a z > f && git commit -qam "PM fix"
PM_M=$(git rev-parse HEAD)
print -l X a z > f && git commit -qam "PM removes beside it"
PM_B=$(git rev-parse HEAD)
_ST_PZ_C g g1 "PM beside"
_ST_RUN --move="$PM_M" --after="$PM_B"
_ST_EQ "as does a move later past one removing such a run" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
_ST_PZ_NEW pm-pairs-far
print -l h P x a b a > f && git add f && git commit -qm "PM base"
print -l h Q a a b a > f && git commit -qam "PM fix"
PM_M=$(git rev-parse HEAD)
print -l H Q a a a b > f && git commit -qam "PM rewrites and moves"
PM_B=$(git rev-parse HEAD)
_ST_PZ_C g g1 "PM beside"
_ST_RUN --move="$PM_M" --after="$PM_B"
_ST_EQ "as does one past a line of its text beyond that change's next hunk" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
_ST_PZ_NEW pm-relocated
print -l 1 foo 3 4 baz 6 > f && git add f && git commit -qm "PM base"
print -l 1 qux 3 4 baz 6 > f && git commit -qam "PM fix"
PM_M=$(git rev-parse HEAD)
print -l 1 bar 3 4 qux 6 > f && git commit -qam "PM relocates"
PM_B=$(git rev-parse HEAD)
_ST_PZ_C g g1 "PM beside"
_ST_RUN --move="$PM_M" --after="$PM_B"
if [ -n "$PM_OLD" ]; then
	_ST_EQ "a move later past a commit relocating its line pauses before git 2.50" "$RC" "2"
	_ST_RUN --abort
else
	_ST_EQ "a move later past a commit relocating its line lands, the edit of that line going with it" \
		"$RC:$(_PM_AT HEAD~2):$(_PM_AT HEAD~1)" "0:1|foo|3|4|qux|6|:1|bar|3|4|qux|6|"
	_ST_OUT_HAS "naming it" "(PM relocates)'s edits to lines in f land with [0-9a-f]* (PM fix)"
fi
_ST_PZ_NEW pm-neighbor
print -l "p alpha beta delta q" "z alpha beta gamma w" > f && git add f && git commit -qm "PM base"
print -l "p alpha beta gamma q" "z alpha beta gamma w" > f && git commit -qam "PM rewords"
print -l "p alpha BETA gamma q" "z alpha beta gamma w" > f && git commit -qam "PM fix"
_ST_PZ_C g g1 "PM beside"
_ST_RUN --move=HEAD~1 --before=HEAD~2
_ST_EQ "a move whose changed words a neighbor holds pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort

# Commits a line, one moving the lines after it, then one writing its text anew further down,
# which a change followed through each commit's own diff never takes for it
_PM_ANEW () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	print -l foo k26 k17 t k5 > f && git add f && git commit -qm "PM anchor"
	PM_A=$(git rev-parse HEAD)
	print -l foo k26 k11 t k5 k17 > f && git commit -qam "PM moves"
	print -l k26 k11 foo k5 k17 > f && git commit -qam "PM writes anew"
}
_PM_ANEW pm-anew-place
print -l k26 k11 FOO k5 k17 > f
_ST_RUN --commit --text "PM fix" --after="$PM_A" -- f
_ST_EQ "a placement of the line written anew pauses" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
_PM_ANEW pm-anew-move
print -l k26 k11 FOO k5 k17 > f && git commit -qam "PM fix"
_ST_RUN --move=HEAD --before=HEAD~2
_ST_EQ "as does such a move" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
# Commits a fix, then ones moving its line and writing its text anew – a commit beside
# the fix for a block – which taking the fix back past them never takes for its line
_PM_LATER () {
	# Args: <repo name> [block – a second moved commit beside it]
	_ST_PZ_NEW "$1"
	print -l k4 k24 foo k16 k26 k0 > f && git add f && git commit -qm "PM base"
	print -l k4 k24 FOO k16 k26 k0 > f && git commit -qam "PM fix"
	PM_M=$(git rev-parse HEAD)
	[ -n "$2" ] && _ST_PZ_C g m2 "PM beside it"
	print -l k26 k24 FOO k16 k0 k5 > f && git commit -qam "PM moves"
	print -l FOO k26 k24 t k16 k0 k5 > f && git commit -qam "PM writes anew"
	PM_B=$(git rev-parse HEAD)
	_ST_PZ_C h d "PM tip"
}
_PM_LATER pm-anew-later
_ST_RUN --move="$PM_M" --after="$PM_B"
if [ -n "$PM_OLD" ]; then
	_ST_EQ "a move later past them pauses before git 2.50" "$RC" "2"
	_ST_RUN --abort
else
	_ST_EQ "a move later past them lands, the edit of its line going with it, the text written anew staying" \
		"$RC:$(_PM_AT HEAD~2):$(_PM_AT HEAD~1)" "0:FOO|k26|k24|foo|k16|k0|k5|:FOO|k26|k24|t|k16|k0|k5|"
fi
_PM_LATER pm-anew-block block
_ST_RUN --move="$PM_M" --move=HEAD~3 --after="$PM_B"
_ST_EQ "a block moved so pauses where the edit no longer finds its line once" "$RC" "2"
[ -n "$PM_OLD" ] || _ST_OUT_HAS "saying so" "the lines a carried edit changes no longer occur once there"
_ST_RUN --abort
unfunction _PM_AT _PM_REWRITTEN _PM_PAUSED _PM_ANEW _PM_LATER _PM_SHIFTED
cd "$TMP/repo"
