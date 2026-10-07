# Scoped fold: a pathspec keeps the rest of the index out
_ST_SCENARIO "\e[1;96m[32] scoped --amend-into\e[0m"
git reset -q --hard
echo "sc1" > sc.txt && echo "other" > sc-other.txt && git add sc.txt sc-other.txt && git commit -qm "SC base"
local SC_TARGET=$(git rev-parse HEAD)
echo "sc-later" > sc-later.txt && git add sc-later.txt && git commit -qm "SC later"
echo "sc1-folded" > sc.txt && git add sc.txt
echo "sc-other-parallel" > sc-other.txt && git add sc-other.txt   # a parallel session's staging
_ST_RUN --amend-into="$SC_TARGET" -- sc.txt
_ST_EQ "scoped fold exits 0" "$RC" "0"
_ST_OUT_HAS "reports what stayed staged" 'outside the pathspec'
# A count can't say whose leftovers these are, so the caller has to guess
_ST_OUT_HAS "names the leftover path" 'outside the pathspec.*sc-other\.txt'
# Agents overwhelmingly read this through `| tail -N`, so the summary has
# to survive the truncation rather than be padded out of reach
_ST_EQ "non-TTY output carries no blank lines" "$(echo "$OUT" | grep -c '^$')" "0"
_ST_EQ "summary survives a tail -5" "$(echo "$OUT" | tail -5 | grep -c 'outside the pathspec')" "1"
local SC_NEW=$(git log --format='%H %s' | grep 'SC base' | cut -d' ' -f1)
_ST_EQ "pathspec change folded" "$(git show "${SC_NEW}:sc.txt")" "sc1-folded"
_ST_EQ "out-of-pathspec change NOT folded" "$(git show "${SC_NEW}:sc-other.txt")" "other"
_ST_CHECK "out-of-pathspec change still staged" sh -c "git diff --cached --name-only | grep -q sc-other.txt"
_ST_CHECK "history never saw it" sh -c "! git log -p --all | grep -q sc-other-parallel"
_ST_RUN --amend-into="$SC_NEW" -- nosuch.txt
_ST_EQ "empty pathspec match refused" "$RC" "1"
_ST_OUT_HAS "names the empty match" 'No staged changes under'
git reset -q --hard
