# The one-git-log rebuild walk preserves empty-message and merge commits

# The walk packs each commit's fields into one NUL-separated `git log`, so an
# empty message (a trailing empty field) and a merge (a multi-value parents
# field) are the two shapes a format/index drift would corrupt silently
_ST_SCENARIO "\e[1;96m[57] rebuild-walk field edges (empty message, merge parents)\e[0m"
cd "$TMP/repo"
local WE_BELOW=$(git rev-parse HEAD)
echo we1 > we1.txt && git add we1.txt && git commit -qm "Walk edge base"
git commit -q --allow-empty --allow-empty-message -m ""
git checkout -q -b we-side; echo wes > wes.txt && git add wes.txt && git commit -qm "Walk edge side"
git checkout -q main; echo wem > wem.txt && git add wem.txt
GIT_AUTHOR_DATE='@1600009999 +0000' git -c user.name='Edge Main Author' -c user.email='edgemain@x' commit -qm "Walk edge main"
local WE_AUTHOR=$(git log -1 --format='%an|%ae|%aI' :/Walk\ edge\ main)
git merge -q --no-ff we-side -m "Walk edge merge" >/dev/null 2>&1
local WE_TREE=$(git rev-parse 'HEAD^{tree}')
# Reword the base below both – the walk climbs through the empty-message
# commit and the merge, rebuilding each from its packed fields
_ST_RUN -M --text="Walk edge base reworded" "$(git rev-parse :/Walk\ edge\ base)"
_ST_EQ "walk-through reword exits 0" "$RC" "0"
_ST_EQ "base was reworded" "$(git log --format='%s' "$WE_BELOW..HEAD" | grep -c '^Walk edge base reworded$')" "1"
_ST_EQ "empty-message commit kept its empty message" "$(git log --format='%s' "$WE_BELOW..HEAD" | grep -c '^$')" "1"
_ST_EQ "merge kept its two parents" "$(git rev-list --min-parents=2 --count "$WE_BELOW..HEAD")" "1"
_ST_EQ "tip tree preserved (content unchanged)" "$(git rev-parse 'HEAD^{tree}')" "$WE_TREE"
_ST_EQ "rebuilt descendant preserves its author (name, email, date)" "$(git log -1 --format='%an|%ae|%aI' :/Walk\ edge\ main)" "$WE_AUTHOR"
git checkout -q main 2>/dev/null
cd "$TMP/repo"
