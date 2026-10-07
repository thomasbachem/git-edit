# Squash (implicit, plumbing route)
_ST_SCENARIO "\e[1;96m[8] squash (plumbing)\e[0m"
PRE_TREE=$(git rev-parse 'HEAD^{tree}')
local PRE_COUNT=$(git rev-list --count HEAD)
_ST_RUN --text="C and D combined" "$(git rev-parse HEAD~1)" "$(git rev-parse HEAD)"
_ST_EQ "exits 0" "$RC" "0"
_ST_OUT_HAS "states tree identity" 'Tip tree identical'
_ST_EQ "one commit fewer" "$(git rev-list --count HEAD)" "$((PRE_COUNT-1))"
_ST_EQ "tip tree identical" "$(git rev-parse 'HEAD^{tree}')" "$PRE_TREE"
_ST_EQ "combined message" "$(git log --format=%s -1)" "C and D combined"
