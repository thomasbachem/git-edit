# A reorder or move over a long span names what moves – the order it asks for and the one it
# lands, each as the new order around the moved commits, the stretches between counted
_ST_SCENARIO "\e[1;96m[270] long reorders and moves list the order around what moved\e[0m"
local -a OX_C
local OX_I

# Makes a repo with a base and fifteen commits above it, `OX c1` to `OX c15`, oldest first in `OX_C`
_OX_NEW () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	_ST_PZ_C base.txt base "OX base"
	for OX_I in {1..15}; do _ST_PZ_C "f$OX_I.txt" "$OX_I" "OX c$OX_I"; done
	OX_C=($(git rev-list --reverse HEAD~15..HEAD))
}

# Two commits, c3 and c4, reordered to just above c13
_OX_NEW ox1
_ST_RUN --reorder "${OX_C[1]}" "${OX_C[2]}" "${OX_C[@]:4:9}" "${OX_C[3]}" "${OX_C[4]}" "${OX_C[14]}" "${OX_C[15]}"
_ST_EQ "a long reorder lands" "$RC:$(git log --format=%s -6 | tr '\n' ,)" "0:OX c15,OX c14,OX c4,OX c3,OX c13,OX c12,"
_ST_OUT_HAS "asking for the new order around what moves" '^Reordering 15 commits – the new order around the 2 moved:$'
_ST_EQ "the commit each lands after, then them, the stretches either side counted" \
	"$(sed -n '/^Reordering 15 commits/,/^ - … 2 more/p' <<<"$OUT" | tail -n +2 | tr '\n' '|')" \
	" - … 10 more in their old order| - ${OX_C[13]:0:7} (OX c13)| - ${OX_C[3]:0:7} (OX c3)| - ${OX_C[4]:0:7} (OX c4)| - … 2 more in their old order|"
_ST_OUT_HAS "landing the same excerpt, over the commits it rebuilt" '^Tip tree identical ✓ – new order (oldest-first) around the 2 of 13 commits moved:$'
_ST_EQ "named by their new commits" \
	"$(sed -n '/around the 2 of 13 commits moved:$/,/^  … 2 more/p' <<<"$OUT" | tail -n +2 | tr '\n' '|')" \
	"  … 8 more in their old order|  $(git rev-parse --short=7 ':/OX c13') OX c13|  $(git rev-parse --short=7 ':/OX c3') OX c3|  $(git rev-parse --short=7 ':/OX c4') OX c4|  … 2 more in their old order|"
_ST_OUT_LACKS "never the whole order" "^ - ${OX_C[1]:0:7} "

# A move across them lands the excerpt alone, its own line naming the move
_OX_NEW ox2
_ST_RUN --move="${OX_C[2]}" --after="${OX_C[14]}"
_ST_EQ "a long move lands" "$RC:$(git log --format=%s -3 | tr '\n' ,)" "0:OX c15,OX c2,OX c14,"
_ST_OUT_HAS "listing the new order around the 1 moved" '^Tip tree identical ✓ – new order (oldest-first) around the 1 of 14 commits moved:$'
_ST_OUT_HAS "after the commit it lands on" "^  $(git rev-parse --short=7 ':/OX c14') OX c14$"
_ST_OUT_LACKS "never the old head of the order" "^  $(git rev-parse --short=7 ':/OX c3') OX c3$"

unfunction _OX_NEW
