# Auto refuses pushed-only history
_ST_SCENARIO "\e[1;96m[17] auto pushed-history refusal\e[0m"
echo "beta2" > b.txt && git add b.txt
_ST_RUN --amend-into=auto
_ST_CHECK "refuses" test "$RC" != "0"
_ST_OUT_HAS "names the reason" 'pushed commit'
git reset -q && git checkout -q -- b.txt
