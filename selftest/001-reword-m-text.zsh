# Reword (-M --text): plumbing, tree-identical, trailer
_ST_SCENARIO "\e[1;96m[1] reword (-M --text)\e[0m"
local PRE_HEAD=$(git rev-parse HEAD)
local PRE_TREE=$(git rev-parse 'HEAD^{tree}')
_ST_RUN -M --text="C reworded" "$SHA_C"
_ST_EQ "exits 0" "$RC" "0"
_ST_OUT_HAS "emits ok trailer" '^git-edit: ok – refs/heads/main moved'
_ST_OUT_HAS "states tree identity" 'Trees unchanged'
_ST_OUT_HAS "echoes the resulting subject" '[0-9a-f]\{7,\} C reworded'
# A symbolic target resolves once, so the summary has to name what it
# replaced – otherwise rewording the wrong commit reads as success
_ST_OUT_HAS "names the subject it replaced" 'replaced:.*C commit'
_ST_CHECK "HEAD moved" test "$(git rev-parse HEAD)" != "$PRE_HEAD"
_ST_EQ "tip tree identical" "$(git rev-parse 'HEAD^{tree}')" "$PRE_TREE"
_ST_EQ "message applied" "$(git log --format=%s -3 | tail -1)" "C reworded"
