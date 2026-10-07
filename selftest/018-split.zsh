# Split by pathspec
_ST_SCENARIO "\e[1;96m[18] split\e[0m"
echo "s1" > s1.txt && echo "s2" > s2.txt
git add s1.txt s2.txt && git commit -qm "S mixed commit"
PRE_TREE=$(git rev-parse 'HEAD^{tree}')
_ST_RUN --split="$(git rev-parse HEAD)" --text="S extracted" -- s1.txt
_ST_EQ "exits 0" "$RC" "0"
_ST_OUT_HAS "states tree identity" 'Tip tree identical'
_ST_EQ "tip tree identical" "$(git rev-parse 'HEAD^{tree}')" "$PRE_TREE"
_ST_EQ "tip keeps original message" "$(git log --format=%s -1)" "S mixed commit"
_ST_EQ "extracted commit below it" "$(git log --format=%s -2 | tail -1)" "S extracted"
_ST_CHECK "extracted has s1" git cat-file -e 'HEAD~1:s1.txt'
_ST_CHECK "extracted lacks s2" sh -c "! git cat-file -e 'HEAD~1:s2.txt'"
_ST_RUN --split="$(git rev-parse HEAD)" --text="x" -- nomatch.txt
_ST_CHECK "refuses non-matching pathspec" test "$RC" != "0"
_ST_RUN --split="$(git rev-parse HEAD~1)" --text="x" -- s1.txt
_ST_CHECK "refuses whole-commit pathspec" test "$RC" != "0"
_ST_OUT_HAS "names the reason" 'covers every change'
_ST_OUT_HAS "single-file split points at the content form" 'drop the pathspec and split by content'
