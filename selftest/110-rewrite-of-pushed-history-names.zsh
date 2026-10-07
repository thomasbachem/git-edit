# A rewrite of pushed history names the push that publishes it
# Its lease pinned to the upstream as the rewrite found it – a background fetch would move the
# remote-tracking ref under a bare --force-with-lease
_ST_SCENARIO "\e[1;96m[110] a rewrite of pushed history names its pinned force push\e[0m"
local LP_BRANCH=$(git symbolic-ref --short HEAD)
git init -q --bare "$TMP/lp-remote.git"
echo l > lp.txt && git add lp.txt && git commit -qm "LP pushed"
git remote add lp "$TMP/lp-remote.git" && git push -q lp "HEAD:refs/heads/$LP_BRANCH" && git fetch -q lp
git branch -q --set-upstream-to="lp/$LP_BRANCH"
local LP_UP=$(git rev-parse HEAD)
_ST_RUN -M --text="LP reworded" --allow-pushed "$LP_UP"
_ST_OUT_HAS "the landing names the push" "git push --force-with-lease=$LP_BRANCH:$LP_UP lp $LP_BRANCH"
git push -q --force-with-lease="$LP_BRANCH:$LP_UP" lp "$LP_BRANCH"
_ST_EQ "which publishes it" "$(git ls-remote lp "refs/heads/$LP_BRANCH" | cut -f1)" "$(git rev-parse HEAD)"
git fetch -q lp
echo m > lp2.txt && git add lp2.txt && git commit -qm "LP unpushed"
_ST_RUN -M --text="LP unpushed reworded" "$(git rev-parse HEAD)"
_ST_EQ "a rewrite above the upstream lands" "$RC" "0"
_ST_OUT_LACKS "naming no push" 'force-with-lease'
git branch -q --unset-upstream && git remote remove lp
