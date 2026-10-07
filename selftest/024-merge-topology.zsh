# Merge topology: plumbing rebuilds preserve it, rebase modes refuse
_ST_SCENARIO "\e[1;96m[24] merge topology\e[0m"
echo "l1" > l1.txt && git add l1.txt && git commit -qm "Low one"
local LOW1=$(git rev-parse HEAD)
echo "l2" > l2.txt && git add l2.txt && git commit -qm "Low two"
local LOW2=$(git rev-parse HEAD)
echo "db" > db.txt && git add db.txt && git commit -qm "Diamond base"
local DBASE=$(git rev-parse HEAD)
git checkout -q -b d-side
echo "ds" > ds.txt && git add ds.txt && git commit -qm "Diamond side"
local DSIDE=$(git rev-parse HEAD)
git checkout -q main
echo "dm" > dm.txt && git add dm.txt && git commit -qm "Diamond main"
local DMAIN=$(git rev-parse HEAD)
git merge -q --no-ff -m "Diamond merge" d-side >/dev/null 2>&1
echo "dt" > dt.txt && git add dt.txt && git commit -qm "Diamond tip"
# Mid-leg reword: the side leg does not descend from it, so it must
# survive byte-identical while the merge is rebuilt with the new parent
_ST_RUN -M --text="Diamond main reworded" "$DMAIN"
_ST_EQ "reword below a merge exits 0" "$RC" "0"
_ST_EQ "merge topology preserved" "$(git rev-list --merges --count HEAD)" "1"
_ST_CHECK "untouched side leg kept as-is" git merge-base --is-ancestor "$DSIDE" HEAD
echo "dbx" >> db.txt && git add db.txt
_ST_RUN --amend-into="$DBASE"
_ST_EQ "--amend-into refuses across a merge" "$RC" "1"
_ST_OUT_HAS "names the flatten hazard" 'flatten'
git reset -q && git checkout -q -- db.txt
_ST_RUN -d -y "$DBASE"
_ST_EQ "drop refuses across a merge" "$RC" "1"
# A merge-free range below the merge routes to plumbing and stays legal
_ST_RUN -s -y --text="Lows combined" "$LOW1" "$LOW2"
_ST_EQ "squash below the merge auto-routes to plumbing" "$RC" "0"
_ST_EQ "merge survived the squash" "$(git rev-list --merges --count HEAD)" "1"
git branch -q -D d-side
