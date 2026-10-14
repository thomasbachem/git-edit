# A whole file editing a peer's inserted block with the line above or below it lands, holding each
# landed line as landed or edited in one place – while one lacking the block still refuses, its
# edits beside, in or across the block's gap, as does one dropping one of the block's lines – an
# input writing over a landed line lands, but beside the gap needs the block's lines too
_ST_SCENARIO "\e[1;96m[228] a whole file editing a landed block with the line beside it lands, stale ones refuse\e[0m"
local SE_TIP
local -i SE_K=0

# Commits a fresh file unjournaled and lands a peer's three lines after its line 2 – sets `SE_TIP`
_SE_LAND () {
	SE_K+=1
	print -l a 'size (95 nb MB)' c d e > "se$SE_K.txt" && git add "se$SE_K.txt" && git commit -qm "SE base $SE_K"
	print -l a 'size (95 nb MB)' 'case1 (95 nb MB)' 'case2 plain' 'case3 (95 nb MB)' c d e > "se$SE_K.txt"
	GIT_EDIT_ACTOR=se-peer _ST_RUN --commit --text "SE peer adds cases $SE_K" -- "se$SE_K.txt"
	SE_TIP=$(git rev-parse HEAD)
}
# Lands the peer's block on a fresh file, then commits <lines> as that file whole
_SE_TRY () {
	# Args: <line>...
	_SE_LAND
	print -l "$@" > "se$SE_K.txt"
	_ST_RUN --commit --text "SE caller $SE_K" -- "se$SE_K.txt"
}
# Checks the last `_SE_TRY` refused, the branch unmoved, and puts the file back
_SE_REFUSED () {
	# Args: <description>
	_ST_EQ "$1" "$RC:$(git rev-parse HEAD):$(grep -q -e "would take back what another caller landed: se$SE_K.txt" <<<"$OUT" && print named)" \
		"1:$SE_TIP:named"
	git checkout -q -- "se$SE_K.txt"
}
_ST_PZ_NEW se
_ST_PZ_C init.txt i "SE init"
export GIT_EDIT_ACTOR=se-self

_SE_TRY a 'size (95 MB)' 'case1 (95 MB)' 'case2 plain' 'case3 (95 MB)' c d e
_ST_EQ "a whole file editing the landed block and the line above it lands" "$RC:$(git rev-parse HEAD~1)" "0:$SE_TIP"
_SE_TRY a 'size (95 nb MB)' 'case1 (95 MB)' 'case2 plain' 'case3 (95 MB)' 'c!' d e
_ST_EQ "as does one editing it and the line below it" "$RC:$(git rev-parse HEAD~1)" "0:$SE_TIP"
_SE_TRY a 'size (95 MB)' 'case1 (95 nb MB), then more' 'case2 plain' 'case3 (95 MB)' 'c!' d e
_ST_EQ "and one editing both lines beside it, a landed line grown at its end" "$RC:$(git rev-parse HEAD~1)" "0:$SE_TIP"
_SE_TRY a 'size (95 nb MB)' 'case1 (95 nb MB)' 'case2 plain' 'case3 (95 nb MB)' mine c d e
_ST_EQ "while one adding its own line right after the block lands as before" "$RC:$(git rev-parse HEAD~1)" "0:$SE_TIP"

_SE_TRY a 'size (95 MB)' mine c d e
_SE_REFUSED "a stale file rewriting the line above the gap, growing with a line of its own, refuses"
_SE_TRY a 'size (95 MB)' 'case9 (95 MB)' 'case8 other' c d e
_SE_REFUSED "as does one growing there by lines like the block's"
_SE_TRY a 'size (95 nb MB)' mine c d e
_SE_REFUSED "one inserting a line of its own in the block's gap"
_SE_TRY a 'size (95 MB)' 'c!' d e
_SE_REFUSED "one rewriting the lines on both sides of the gap"
_SE_TRY a 'size (95 nb MB)' 'c!' mine d e
_SE_REFUSED "one rewriting the line below the gap, growing"
_SE_TRY a 'size (95 MB)' 'case1 (95 MB)' 'case3 (95 MB)' c d e
_SE_REFUSED "and one editing the block beside the line above, one of its lines dropped"

# Inputs compose on the tip's text, so a pair writing over a landed line edits what landed – the
# same content taken whole refuses
_SE_LAND
_ST_RUN --commit --text "SE caller $SE_K" --edits '{"se'"$SE_K"'.txt": [["case1 (95 nb MB)\n", "case one rewritten\n"]]}'
_ST_EQ "--edits writing over a landed line lands" "$RC:$(git show HEAD:se$SE_K.txt | sed -n 3p):$(git rev-parse HEAD~1)" "0:case one rewritten:$SE_TIP"
_SE_TRY a 'size (95 nb MB)' 'case one rewritten' 'case2 plain' 'case3 (95 nb MB)' c d e
_SE_REFUSED "while that file taken whole refuses"
_SE_LAND
_ST_RUN --commit --text "SE caller $SE_K" --edits '{"se'"$SE_K"'.txt": [["size (95 nb MB)\ncase1 (95 nb MB)\n", "size (95 MB)\ncase1 (95 MB)\n"]]}'
_ST_EQ "--edits of the line above with the block lands" "$RC:$(git show HEAD:se$SE_K.txt | sed -n 3p):$(git rev-parse HEAD~1)" "0:case1 (95 MB):$SE_TIP"
# A rewrite beside the gap needs the block's lines as a file does – a stale file's patch lacks them
_SE_LAND
print -l a 'size (95 MB)' c d e > "se$SE_K.txt" && git diff -- "se$SE_K.txt" > "$TMP/se-stale.patch" && git checkout -q -- "se$SE_K.txt"
_ST_RUN --commit --text "SE caller $SE_K" --patch "$TMP/se-stale.patch"
_SE_REFUSED "--patch of a stale file rewriting the line above the gap refuses"
export GIT_EDIT_ACTOR=
cd "$TMP/repo"
