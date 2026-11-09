# A commit moved past a later one whose change sits beside its added block, in lines so alike no
# alignment is sure, has that block taken back out at the later commit's stop – each way the
# block aligns found once, taking out the same lines – the moved commit's own step adding it again
_ST_SCENARIO "\e[1;96m[272] a move takes back a block only its commit adds, wherever it aligns\e[0m"
local TB_A TB_B TB_TREE

# Prints a list of entries, one `"id": <n>` each, in the order given
_TB_F () {
	# Args: <id>...
	local ID
	print -r -- "["
	for ID in "$@"; do print -l -- "  {" "    \"id\": $ID" "  },"; done
	print -r -- "]"
}

_ST_PZ_NEW tb1
git config rerere.enabled false
_TB_F 1 2 > w.json && git add w.json && git commit -qm "TB base"
_TB_F 1 9 2 > w.json && git commit -qam "TB A adds entry 9" && TB_A=$(git rev-parse HEAD)
_TB_F 1 9 3 2 > w.json && git commit -qam "TB B adds entry 3" && TB_B=$(git rev-parse HEAD)
print x > g.txt && git add g.txt && git commit -qm "TB C"
TB_TREE=$(git rev-parse "HEAD^{tree}")
_ST_RUN --move="$TB_A" --after="$TB_B"
_ST_OUT_HAS "the later commit's stop takes the moved block back out" \
	"^${TB_B:0:7} (TB B adds entry 3) takes the 3 line(s) ${TB_A:0:7} (TB A adds entry 9) adds to w\.json back out"
_ST_EQ "the moved commit's own step adding it again, it lands in the new order" \
	"$RC:$(git log --format=%s | tr '\n' '|')" "0:TB C|TB A adds entry 9|TB B adds entry 3|TB base|"
_ST_EQ "the tip's tree unchanged" "$(git rev-parse "HEAD^{tree}")" "$TB_TREE"
_ST_EQ "the later commit holding its entry alone" "$(git show HEAD~2:w.json)" "$(_TB_F 1 3 2)"

# Where the later commit holds a second copy of the block, its stop is left to the hand
_ST_PZ_NEW tb2
git config rerere.enabled false
_TB_F 1 2 > w.json && git add w.json && git commit -qm "TB2 base"
_TB_F 1 9 2 > w.json && git commit -qam "TB2 A adds entry 9" && TB_A=$(git rev-parse HEAD)
_TB_F 1 9 3 9 2 > w.json && git commit -qam "TB2 B adds entry 3 and 9 again" && TB_B=$(git rev-parse HEAD)
print x > g.txt && git add g.txt && git commit -qm "TB2 C"
_ST_RUN --move="$TB_A" --after="$TB_B"
_ST_EQ "a block found twice stops the later commit's stop" "$RC:$(grep -c 'This stop builds .* TB2 B adds' <<<"$OUT")" "2:1"
_ST_OUT_LACKS "never taking a copy back" 'back out, as what precedes it lacks'
_ST_RUN --abort

# Moved earlier past the commit adding the block, the moved commit's stop takes that block back out
_ST_PZ_NEW tb3
git config rerere.enabled false
_TB_F 1 2 > w.json && git add w.json && git commit -qm "TB3 base"
_TB_F 1 9 2 > w.json && git commit -qam "TB3 A adds entry 9" && TB_A=$(git rev-parse HEAD)
_TB_F 1 9 3 2 > w.json && git commit -qam "TB3 B adds entry 3" && TB_B=$(git rev-parse HEAD)
print x > g.txt && git add g.txt && git commit -qm "TB3 C"
TB_TREE=$(git rev-parse "HEAD^{tree}")
_ST_RUN --move="$TB_B" --before="$TB_A"
_ST_OUT_HAS "moved earlier, its stop takes the crossed commit's block back out" \
	"^${TB_B:0:7} (TB3 B adds entry 3) takes the 3 line(s) ${TB_A:0:7} (TB3 A adds entry 9) adds to w\.json back out"
_ST_EQ "and lands in the new order" "$RC:$(git log --format=%s | tr '\n' '|')" "0:TB3 C|TB3 A adds entry 9|TB3 B adds entry 3|TB3 base|"
_ST_EQ "the tip's tree unchanged, the moved commit holding its entry alone" \
	"$(git rev-parse "HEAD^{tree}"):$(git show HEAD~2:w.json | tr '\n' ' ')" "$TB_TREE:$(_TB_F 1 3 2 | tr '\n' ' ')"

# Where the later commit changed a line one way the block aligns takes in, its stop is left to the hand
_ST_PZ_NEW tb4
git config rerere.enabled false
_TB_F 1 2 > w.json && git add w.json && git commit -qm "TB4 base"
_TB_F 1 9 2 > w.json && git commit -qam "TB4 A adds entry 9" && TB_A=$(git rev-parse HEAD)
_TB_F 1 9 2 | sed '8s/^  {$/  { "kept": true,/' > w.json && git commit -qam "TB4 B marks entry 2 kept" && TB_B=$(git rev-parse HEAD)
print x > g.txt && git add g.txt && git commit -qm "TB4 C"
_ST_RUN --move="$TB_A" --after="$TB_B"
_ST_EQ "a block one of whose alignments the later commit changed stops its stop" \
	"$RC:$(grep -c 'This stop builds .* TB4 B marks entry 2 kept' <<<"$OUT")" "2:1"
_ST_OUT_LACKS "never taking it back" 'back out, as what precedes it lacks'
_ST_RUN --abort
unfunction _TB_F
