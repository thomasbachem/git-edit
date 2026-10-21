# Flagged files a landing changes go in one two-tree merge where git finds them up to date, those
# with hidden edits path by path as before, which merge them – every flag kept either way:
# • Assume-unchanged and skip-worktree alike, a file touched since with its content as committed
#   goes in that merge too, brought along like any other
# • A clean flagged rename's new path goes along in that merge, one with hidden edits keeps its own
_ST_SCENARIO "\e[1;96m[236] flagged files without hidden edits land in one merge\e[0m"
local FU_I FU_N=40 FU_TR="$TMP/fu-trace" FU_SIX=$'1\n2\n3\n4\n5\n6' FU_WANT=""
_ST_PZ_NEW fu
for FU_I in {1..$FU_N}; do print -r -- "$FU_SIX" > "f$FU_I.txt"; done
print -l -- one two three four five six seven > r1.txt
print -l -- uno dos tres cuatro cinco seis siete > r2.txt
git add -A && git commit -qm "FU base"
for FU_I in {1..$FU_N}; do print -r -- $'1\n2\nb\n4\n5\n6' > "f$FU_I.txt"; done
git mv r1.txt n1.txt && git mv r2.txt n2.txt
print -l -- one two three four five six seven eight > n1.txt
print -l -- uno dos tres cuatro cinco seis siete ocho > n2.txt
git add -A && git commit -qm "FU change all"
_ST_PZ_C t.txt t "FU tip"
# Every entry flagged, the first ten skip-worktree, the rest assume-unchanged – hidden edits in
# five of the files, two touched alone, one of each flag, one renamed file edited
git ls-files -z | git update-index -z --assume-unchanged --stdin
git update-index --no-assume-unchanged -- f{1..10}.txt && git update-index --skip-worktree -- f{1..10}.txt
for FU_I in 3 9 17 28 40; do print -r -- mine >> "f$FU_I.txt"; FU_WANT+="1 2 3 4 5 6 mine "; done
touch -t 202001010000 f6.txt f22.txt
print -r -- mine >> n2.txt
GIT_TRACE=$FU_TR _ST_RUN -d -y HEAD~1
_ST_EQ "an agent's drop over flagged files lands" "${RC}:$(git log -1 --format=%s HEAD~1)" "0:FU base"
_ST_EQ "each hidden edit merged onto what landed" "$(for FU_I in 3 9 17 28 40; do tr '\n' ' ' < "f$FU_I.txt"; done)" "$FU_WANT"
_ST_EQ "the rest brought along, a clean rename's file too" "$(cat f1.txt):$(cat f39.txt):$(tr '\n' ' ' < r1.txt)" \
	"$FU_SIX:$FU_SIX:one two three four five six seven "
_ST_EQ "the touched files brought along, their flags kept" \
	"$(cat f6.txt):$(cat f22.txt):$(git ls-files -v -- f6.txt f22.txt | tr '\n' ' ')" "${FU_SIX}:${FU_SIX}:h f22.txt S f6.txt "
_ST_EQ "their entries what landed" "$(git rev-parse :f6.txt :f22.txt)" "$(git rev-parse HEAD:f6.txt HEAD:f22.txt)"
_ST_OUT_LACKS "neither named as not brought along" 'Not brought along'
_ST_OUT_HAS "the edited rename's left to merge by hand" 'left as they were, as changes to it: n2\.txt → r2\.txt$'
_ST_EQ "every flag kept, a renamed file's new path unflagged as before" "$(git ls-files -v | cut -c1 | LC_ALL=C sort | uniq -c | awk '{ printf "%s%s ", $1, $2 }')" "2H 10S 31h "
_ST_EQ "one merge for the files git finds up to date, one each for the six it refuses" \
	"$(grep -c 'read-tree -m -u' "$FU_TR")" "7"
# A lone flagged file touched since, which takes a merge of its own, is brought along all the same
_ST_PZ_NEW fu1
_ST_PZ_C f.txt $'1\n2\n3' "FU1 base" && _ST_PZ_C f.txt $'1\n2x\n3' "FU1 change" && _ST_PZ_C t.txt t "FU1 tip"
git update-index --assume-unchanged f.txt && touch -t 202001010000 f.txt
_ST_RUN -d -y HEAD~1
_ST_EQ "a lone touched file brought along, its flag kept" "${RC}:$(tr '\n' ' ' < f.txt):$(git ls-files -v f.txt)" "0:1 2 3 :h f.txt"
_ST_OUT_LACKS "and not named as not brought along" 'Not brought along'
