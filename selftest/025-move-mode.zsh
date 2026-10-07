# Move mode: reposition one commit via derived span reorder
_ST_SCENARIO "\e[1;96m[25] move mode\e[0m"
for MC in m1 m2 m3 m4; do
	echo "$MC" > "$MC.txt" && git add "$MC.txt" && git commit -qm "Move $MC"
done
local MV_FIRST=$(git rev-parse HEAD~3)
local MV_TIP=$(git rev-parse HEAD)
_ST_RUN --move="$MV_TIP" --after="$MV_FIRST"
_ST_EQ "backward move exits 0" "$RC" "0"
_ST_EQ "span reordered as asked" "$(git log --format=%s -4 | tr '\n' ' ')" "Move m3 Move m2 Move m4 Move m1 "
local MV_M4=$(git log --format='%H %s' -4 | awk '$3=="m4"{print $1}')
_ST_RUN --move="$MV_M4" --after="$(git rev-parse HEAD)"
_ST_EQ "forward move exits 0" "$RC" "0"
_ST_EQ "restored original order" "$(git log --format=%s -4 | tr '\n' ' ')" "Move m4 Move m3 Move m2 Move m1 "
_ST_RUN --move="$(git rev-parse HEAD)" --after="$(git rev-parse HEAD~1)"
_ST_EQ "in-position move is a no-op" "$RC" "0"
_ST_OUT_HAS "no-op reports unchanged" 'unchanged'
_ST_RUN --move="$(git rev-parse HEAD)" --after="$(git rev-parse HEAD~2)" --before="$(git rev-parse HEAD~3)"
_ST_EQ "both anchors refused" "$RC" "1"
# Swapping two commits whose hunks abut conflicts on both steps – the first rebuilds an
# intermediate that never existed and is authored, while the last is fully determined,
# so the hint must name it there and only there
printf 'mv-base\n' > mv.txt && git add mv.txt && git commit -qm "MV base"
printf 'mv-base\nmv-A\n' > mv.txt && git add mv.txt && git commit -qm "MV A"
local MV_A=$(git rev-parse HEAD)
printf 'mv-base\nmv-B\nmv-A\n' > mv.txt && git add mv.txt && git commit -qm "MV B"
local MV_B=$(git rev-parse HEAD)
local MV_TREE=$(git rev-parse 'HEAD^{tree}')
_ST_RUN --move="$MV_A" --after="$MV_B"
_ST_EQ "abutting swap conflicts" "$RC" "2"
_ST_OUT_LACKS "no final-step hint on an intermediate step" 'Final step'
_ST_OUT_HAS "intermediate step says author it" 'rebuilds a state that never existed'
_ST_OUT_HAS "intermediate step rules out --3way" 'cannot work here'
local MV_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
printf 'mv-base\nmv-B\n' > "${MV_WT:-$ST_NO_WT}/mv.txt" && git -C "$MV_WT" add mv.txt
# The final step is fully determined, so it resolves itself rather than
# handing back a command the tool already derived
_ST_RUN --continue
_ST_EQ "final step needs no second continue" "$RC" "0"
_ST_OUT_HAS "says it auto-resolved the final step" 'Final step auto-resolved'
_ST_OUT_LACKS "no homework left for the caller" 'Final step – a reorder preserves'

_ST_EQ "tree preserved by the reorder" "$(git rev-parse 'HEAD^{tree}')" "$MV_TREE"
_ST_EQ "commits swapped" "$(git log --format=%s -2 | tr '\n' ' ')" "MV A MV B "
