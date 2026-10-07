# The auto target is the consensus one, and a new file follows it
_ST_SCENARIO "\e[1;96m[15] amend-into=auto\e[0m"
echo "em" > m.txt && git add m.txt && git commit -qm "M commit"
echo "en" > n.txt && git add n.txt && git commit -qm "N commit"
echo "em2" > m.txt && git add m.txt
echo "new" > p.txt && git add p.txt
_ST_RUN --amend-into=auto
_ST_EQ "exits 0" "$RC" "0"
_ST_OUT_HAS "names auto-target" 'auto-target'
_ST_EQ "fold landed in M" "$(git show 'HEAD~1:m.txt')" "em2"
_ST_CHECK "new file followed consensus" git cat-file -e 'HEAD~1:p.txt'
