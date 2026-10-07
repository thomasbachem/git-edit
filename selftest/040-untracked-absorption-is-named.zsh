# A continue names the untracked files it absorbs
_ST_SCENARIO "\e[1;96m[40] untracked absorption is named\e[0m"
git reset -q --hard
echo "ua" > ua.txt && git add ua.txt && git commit -qm "UA base"
echo "ub" > ub.txt && git add ub.txt && git commit -qm "UB target"
local UA_TGT=$(git rev-parse HEAD)
echo "uc" > uc.txt && git add uc.txt && git commit -qm "UC later"
_ST_RUN "$UA_TGT"
local UA_WT=$(echo "$OUT" | sed $'s/\e\\[[0-9;]*m//g' | grep -oE '/[^ ]*git-edit-edit\.[A-Za-z0-9]+' | head -1)
echo "edited" >> "${UA_WT:-$ST_NO_WT}/ub.txt"
echo "scratch" > "${UA_WT:-$ST_NO_WT}/ua-stray.txt"
_ST_RUN --continue
_ST_EQ "continue exits 0" "$RC" "0"
_ST_OUT_HAS "names untracked files it absorbs" 'Absorbing.*untracked file'
_ST_OUT_HAS "names the stray itself" 'ua-stray\.txt'
_ST_CHECK "the stray really did land in the commit" \
	sh -c "git show --stat --format= HEAD~1 | grep -q ua-stray"
git reset -q --hard
# An edit touching only tracked files must not cry wolf
echo "ud" > ud.txt && git add ud.txt && git commit -qm "UD target"
_ST_RUN "$(git rev-parse HEAD)"
local UA_WT2=$(echo "$OUT" | sed $'s/\e\\[[0-9;]*m//g' | grep -oE '/[^ ]*git-edit-edit\.[A-Za-z0-9]+' | head -1)
echo "edited" >> "${UA_WT2:-$ST_NO_WT}/ud.txt"
_ST_RUN --continue
_ST_EQ "clean continue exits 0" "$RC" "0"
_ST_OUT_LACKS "silent when nothing untracked is absorbed" 'Absorbing'
git reset -q --hard
