# Auto refuses ambiguous targets
_ST_SCENARIO "\e[1;96m[16] auto ambiguity refusal\e[0m" # needs 15
echo "em3" > m.txt && echo "en3" > n.txt
git add m.txt n.txt
_ST_RUN --amend-into=auto
_ST_CHECK "refuses" test "$RC" != "0"
_ST_OUT_HAS "lists candidates" 'different commits'
git reset -q && git checkout -q -- m.txt n.txt
