# As most modes name their target – a run that only added commits on top stays bare
_ST_SCENARIO "\e[1;96m[96] exec's reflog entry names the oldest commit it replaced\e[0m"
local EL
for EL in base one two; do
	echo "$EL" > "el_$EL.txt" && git add "el_$EL.txt" && git commit -qm "EL $EL"
done
local EL_ONE=$(git rev-parse ':/EL one') EL_REF=$(git symbolic-ref HEAD)
# A squash by hand goes below the tip it started on, so `--base` names the tip it saw
_ST_RUN --exec --base="$(git rev-parse HEAD)" -- sh -c 'git reset -q --soft HEAD~2 && git commit -qm "EL one and two"'
_ST_EQ "a rewrite exits 0" "$RC" "0"
_ST_EQ "and names the oldest commit it replaced" "$(git reflog show -1 --format=%gs "$EL_REF")" "git edit: exec ${EL_ONE:0:7}"
_ST_RUN --undo
_ST_EQ "its undo names it too" "$(git reflog show -1 --format=%gs "$EL_REF")" "git edit: undo exec ${EL_ONE:0:7}"
_ST_RUN --exec -- git commit -q --allow-empty -m "EL on top"
_ST_EQ "a run adding on top exits 0" "$RC" "0"
_ST_EQ "and stays bare" "$(git reflog show -1 --format=%gs "$EL_REF")" "git edit: exec"
local EL_TOP=$(git rev-parse HEAD)
_ST_RUN --exec --base="$EL_TOP" -- git reset -q --hard HEAD~1
_ST_EQ "a rewind exits 0" "$RC" "0"
_ST_EQ "and names the commit it dropped" "$(git reflog show -1 --format=%gs "$EL_REF")" "git edit: exec ${EL_TOP:0:7}"
