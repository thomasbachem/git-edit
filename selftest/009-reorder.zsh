# Reorder: swap two independent tip commits
_ST_SCENARIO "\e[1;96m[9] reorder\e[0m"
echo "ex" > x.txt && git add x.txt && git commit -qm "X commit"
echo "why" > y.txt && git add y.txt && git commit -qm "Y commit"
PRE_TREE=$(git rev-parse 'HEAD^{tree}')
_ST_RUN --reorder "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)"
_ST_EQ "exits 0" "$RC" "0"
_ST_OUT_HAS "states tree identity" 'Tip tree identical'
_ST_OUT_HAS "lists the new order oldest-first" 'new order (oldest-first)'
_ST_EQ "order swapped" "$(git log --format=%s -2 | tr '\n' ' ')" "X commit Y commit "
_ST_EQ "tip tree identical" "$(git rev-parse 'HEAD^{tree}')" "$PRE_TREE"
