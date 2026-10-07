# A fold takes a non-ASCII or quoted path by its bytes, not git's quoting
# Read back from git's quoted output, `"\303\234ber.txt"` became a file beside the real one
_ST_SCENARIO "\e[1;96m[112] a fold takes a non-ASCII or quoted path by its bytes\e[0m"
printf 'u\nv\n' > 'Über.txt' && printf 'q\nr\n' > 'q"uote.txt' && git add 'Über.txt' 'q"uote.txt' && git commit -qm "UQ base"
local UQ_T=$(git rev-parse HEAD)
echo z > uq-other.txt && git add uq-other.txt && git commit -qm "UQ other"
printf 'U\nv\n' > 'Über.txt' && printf 'Q\nr\n' > 'q"uote.txt' && git add 'Über.txt' 'q"uote.txt'
_ST_RUN --amend-into="$UQ_T" -- 'Über.txt' 'q"uote.txt'
_ST_EQ "the fold lands" "$RC" "0"
_ST_EQ "in the files themselves" "$(git show 'HEAD~1:Über.txt' | head -1):$(git show 'HEAD~1:q"uote.txt' | head -1)" "U:Q"
_ST_EQ "with nothing beside them" "$(git ls-tree --name-only HEAD~1 | grep -c -e uote -e ber)" "2"
_ST_CHECK "and nothing left staged" test -z "$(git diff --cached --name-only)"
# A snapshot fold needs git 2.40, scenario 111 checking the refusal below it
if _ST_MERGE_BASE_OK; then
	printf 'UU\nv\n' > 'Über.txt' && git add 'Über.txt'
	_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --snapshot -- 'Über.txt'
	_ST_EQ "a snapshot fold too" "$RC:$(git show 'HEAD~1:Über.txt' | head -1):$(git ls-tree --name-only HEAD~1 | grep -c -e uote -e ber)" "0:UU:2"
	# A conflict on such a path is read from merge-tree and laid out by name as well
	printf 'W\nv\n' > 'Über.txt' && git commit -qam "UQ later"
	printf 'X\nv\n' > 'Über.txt' && git add 'Über.txt'
	_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --snapshot -- 'Über.txt'
	_ST_EQ "a snapshot conflict on it pauses" "$RC" "2"
	local UQ_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
	printf 'X\nv\n' > "${UQ_WT:-$ST_NO_WT}/Über.txt" && git -C "${UQ_WT:-$ST_NO_WT}" add 'Über.txt'
	_ST_RUN --continue
	_ST_EQ "and lands once resolved" "$RC:$(git show 'HEAD~1:Über.txt' | head -1)" "0:X"
fi
