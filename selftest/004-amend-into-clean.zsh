# Fold (--amend-into) clean: a.txt change into C
_ST_SCENARIO "\e[1;96m[4] amend-into (clean)\e[0m"
echo "alpha folded" > a.txt
git add a.txt
_ST_RUN --amend-into="$SHA_C"
_ST_EQ "exits 0" "$RC" "0"
_ST_OUT_HAS "emits ok trailer" '^git-edit: ok – refs/heads/main moved'
_ST_OUT_HAS "prints folded summary" 'Folded'
_ST_OUT_HAS "reports the leftover checkout state" 'Index now empty'
_ST_EQ "change landed in C" "$(git show 'HEAD~2:a.txt')" "alpha folded"
_ST_CHECK "index clean afterwards" git diff --cached --quiet
_ST_CHECK "no fixup commit on branch" test -z "$(git log --format=%s | grep '^fixup!')"
