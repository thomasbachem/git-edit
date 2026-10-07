# Auto-target resolves from a subdirectory
_ST_SCENARIO "\e[1;96m[21] auto-target from subdirectory\e[0m"
mkdir -p subd
echo "sd" > subd/sd.txt && git add subd/sd.txt && git commit -qm "SD commit"
cd subd
echo "sd2" > sd.txt && git add sd.txt
_ST_RUN --amend-into=auto
_ST_EQ "exits 0" "$RC" "0"
_ST_OUT_HAS "names auto-target" 'auto-target'
cd "$TMP/repo"
_ST_EQ "fold landed in SD" "$(git show 'HEAD:subd/sd.txt')" "sd2"
