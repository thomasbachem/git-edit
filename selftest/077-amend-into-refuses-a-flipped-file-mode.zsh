# A fold refuses a flipped file mode – the literal-mode `--cacheinfo` slip
_ST_SCENARIO "\e[1;96m[77] --amend-into refuses a flipped file mode unless --allow-mode-change\e[0m"
printf 'mx1\n' > mx.sh && chmod +x mx.sh && git add mx.sh && git commit -qm "MX base"
local MX_BASE=$(git rev-parse HEAD)
echo "mx-later" > mx2.txt && git add mx2.txt && git commit -qm "MX later"
local MX_TIP=$(git rev-parse HEAD)
# A literal 100644 typed into `--cacheinfo` strips the executable bit along with the edit
git update-index --cacheinfo "100644,$(printf 'mx1\nmx2\n' | git hash-object -w --stdin),mx.sh"
_ST_RUN --amend-into="$MX_BASE" -- mx.sh
_ST_EQ "a flipped mode is refused" "$RC" "1"
_ST_OUT_HAS "names the flip" 'mode change 100755 => 100644 mx\.sh'
_ST_OUT_HAS "names the usual cause and its fix" "ls-tree HEAD"
_ST_OUT_HAS "and the override" 'allow-mode-change to fold'
_ST_EQ "the branch never moved" "$(git rev-parse HEAD)" "$MX_TIP"
_ST_CHECK "the staging is still there" sh -c "git diff --cached --name-only | grep -q '^mx.sh$'"
_ST_RUN --amend-into="$MX_BASE" --allow-mode-change -- mx.sh
_ST_EQ "--allow-mode-change folds it" "$RC" "0"
_ST_OUT_HAS "and the landing still names the mode change" 'mode change 100755 => 100644 mx\.sh'
_ST_EQ "the mode landed as staged" "$(git ls-tree HEAD -- mx.sh | cut -d' ' -f1)" "100644"
# Neighbors: a content-only edit to an executable, and a new executable file, trip nothing
git reset -q --hard
printf 'nx1\n' > nx.sh && chmod +x nx.sh && git add nx.sh && git commit -qm "NX base"
local NX_BASE=$(git rev-parse HEAD)
echo "nx-later" > nx2.txt && git add nx2.txt && git commit -qm "NX later"
printf 'nx1\nnx2\n' > nx.sh && git add nx.sh
printf 'new\n' > nx-new.sh && chmod +x nx-new.sh && git add nx-new.sh
_ST_RUN --amend-into="$NX_BASE" -- nx.sh nx-new.sh
_ST_EQ "a kept mode and a new executable pass" "$RC" "0"
_ST_OUT_LACKS "with no mode notice" 'mode change'
_ST_EQ "the executable bit is kept" "$(git ls-tree HEAD -- nx.sh | cut -d' ' -f1)" "100755"
_ST_EQ "and the new file lands executable" "$(git ls-tree HEAD -- nx-new.sh | cut -d' ' -f1)" "100755"
git reset -q --hard
