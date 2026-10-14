# A fold of `--edits` beside files taken whole resolves its replay's stops as either alone does –
# the pairs given as given, inside a line too, the files taken whole as their replaced lines –
# while one whose whole file inserts a line pauses as before
_ST_SCENARIO "\e[1;96m[231] folds of --edits beside whole files resolve their stops by replacement\e[0m"
local MX_T MX_O MX_WT

# Makes and enters repo <name>: `doc.md` and `notes.md` in the target, a later commit inserting a
# line right after the one each fold edits, another rewording the last – sets `MX_T` and `MX_O`
_MX231_DOCS () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	_ST_PZ_C init.txt i "MX init"
	print -l "# Title" "" "First paragraph, one line." "" "Last paragraph, as written." > doc.md
	print -l "Notes" "Keep the setting at one second." "End" > notes.md
	git add doc.md notes.md && git commit -qm "MX target"
	MX_T=$(git rev-parse HEAD)
	print -l "# Title" "" "First paragraph, one line." "Inserted paragraph." "" "Last paragraph, as written." > doc.md
	print -l "Notes" "Keep the setting at one second." "Inserted note." "End" > notes.md
	git commit -qam "MX c1 inserts"
	print -l "# Title" "" "First paragraph, one line." "Inserted paragraph." "" "Last paragraph, reworded." > doc.md
	git commit -qam "MX c2 rewords"
	MX_O=$(git rev-parse HEAD)
}

_MX231_DOCS mx1
sed 's/^First paragraph, one line\.$/First paragraph, edited./' doc.md > doc.new && mv doc.new doc.md
_ST_RUN --amend-into="$MX_T" --edits '{"notes.md": [["at one second", "at two seconds"]]}' --whole -- doc.md
_ST_EQ "an --edits fold beside a whole file, each beside a later insertion, lands with no pause" "$RC" "0"
_ST_OUT_HAS "making the edits at each stop" "Made the edits in the 2 commit(s) the replay stopped at"
_ST_EQ "the target holds both edits" "$(git show HEAD~2:doc.md | sed -n 3p):$(git show HEAD~2:notes.md | sed -n 2p)" \
	"First paragraph, edited.:Keep the setting at two seconds."
_ST_EQ "the commit inserting beside them keeps its insertions" \
	"$(git show HEAD~1:doc.md | sed -n 3,4p | tr '\n' '|'):$(git show HEAD~1:notes.md | sed -n 2,3p | tr '\n' '|')" \
	"First paragraph, edited.|Inserted paragraph.|:Keep the setting at two seconds.|Inserted note.|"
_ST_EQ "the tip holds both, the checkout's whole file clean" \
	"$(git show HEAD:doc.md | sed -n 6p):$(git show HEAD:notes.md | sed -n 2p):$(git status --porcelain -- doc.md)" \
	"Last paragraph, reworded.:Keep the setting at two seconds.:"

# Its whole file inserting a line derives nothing – the stop pauses, and `--abort` leaves it all
_MX231_DOCS mx2
print -l "# Title" "Subtitle." "" "First paragraph, one line." "Inserted paragraph." "" "Last paragraph, reworded." > doc.md
_ST_RUN --amend-into="$MX_T" --edits '{"notes.md": [["at one second", "at two seconds"]]}' --whole -- doc.md
MX_WT=$(_ST_PZ_WT)
_ST_EQ "one whose whole file inserts a line stops at its target" \
	"$RC:$(git -C "${MX_WT:-$ST_NO_WT}" log -1 --format=%s HEAD 2>/dev/null):$(git rev-parse HEAD)" "2:MX target:$MX_O"
_ST_OUT_LACKS "resolving none of it" "Made the"
_ST_RUN --abort
_ST_EQ "--abort leaves the branch and the checkout's file" "$RC:$(git rev-parse HEAD):$(sed -n 2p doc.md):$(_ST_PZ_WT)" "0:$MX_O:Subtitle.:"
cd "$TMP/repo"
