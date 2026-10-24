# A replacement of one line also carries its changed words, a word on either side kept, which
# resolve a stop where that line stands wrapped otherwise – an `-s=auto` fixup's and a fold's alike:
# • The target and each rewrap take the words, the line breaks their own, words held twice widened
#   a word a side until they match once
# • The gate checks a commit the words alone resolved, as a resolver's own
_ST_SCENARIO "\e[1;96m[245] a replacement narrowed to its words resolves a rewrapped line's stops\e[0m"
local NW_T NW_R
# Commits a comment wrapped three ways – the target's, then two rewraps, the fix left for the last
_NW_REWRAPPED () {
	print -l "// alpha bravo charlie delta" "// echo foxtrot golf hotel" > c && git add c && git commit -qm "NW target"
	NW_T=$(git rev-parse HEAD)
	print -l "// alpha bravo charlie" "// delta echo foxtrot golf hotel" > c && git commit -qam "NW rewrap one"
	print -l "// alpha bravo" "// charlie delta echo foxtrot golf hotel" > c && git commit -qam "NW rewrap two"
}
_ST_PZ_NEW nw
_NW_REWRAPPED
print -l "// alpha bravo" "// charlie delta echo FOXTROT golf hotel" > c && git commit -qam "fixup! NW target"
git config edit.verifyCmd "sh -c 'git log -1 --format=%s \"\$GIT_EDIT_VERIFY_COMMIT\" >> \"$TMP/nw-verified\"'"
: > "$TMP/nw-verified"
_ST_RUN -s=auto HEAD
_ST_EQ "-s=auto's stops resolve by the words, each wrap kept" \
	"$RC:$(git show HEAD~2:c | tr '\n' '|'):$(git show HEAD~1:c | tr '\n' '|'):$(git show HEAD:c | tr '\n' '|')" \
	"0:// alpha bravo charlie delta|// echo FOXTROT golf hotel|:// alpha bravo charlie|// delta echo FOXTROT golf hotel|:// alpha bravo|// charlie delta echo FOXTROT golf hotel|"
_ST_EQ "the gate checking the rewrap the words alone resolved" "$(grep -c -x 'NW rewrap one' "$TMP/nw-verified")" "1"
git config --unset edit.verifyCmd
# Words matching more than once widen a word a side until they match once
_ST_PZ_NEW nw-wide
print -l "// alpha kilo lima mike november oscar" "// papa" "// lima mike november again" > c && git add c && git commit -qm "NW wide target"
print -l "// alpha" "// kilo lima mike november oscar papa" "// lima mike november again" > c && git commit -qam "NW wide rewrap"
print -l "// alpha" "// kilo lima MIKE november oscar papa" "// lima mike november again" > c && git commit -qam "fixup! NW wide target"
_ST_RUN -s=auto HEAD
_ST_EQ "a phrase held twice widens to the one place" "$RC:$(git show HEAD~1:c | tr '\n' '|')" \
	"0:// alpha kilo lima MIKE november oscar|// papa|// lima mike november again|"
# A fold of the same fix, taken whole from the checkout
_ST_PZ_NEW nw-fold
_NW_REWRAPPED
print -l "// alpha bravo" "// charlie delta echo FOXTROT golf hotel" > c
_ST_RUN --amend-into="$NW_T" --whole -- c
_ST_EQ "a fold's stops resolve by the words alike" \
	"$RC:$(git show HEAD~2:c | tr '\n' '|'):$(git show HEAD~1:c | tr '\n' '|')" \
	"0:// alpha bravo charlie delta|// echo FOXTROT golf hotel|:// alpha bravo charlie|// delta echo FOXTROT golf hotel|"
_ST_OUT_HAS "saying so" "Made the fold's line replacements in the"
unfunction _NW_REWRAPPED
cd "$TMP/repo"
