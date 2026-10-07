# The move's span took in the anchor it lands right after, which the rebase replays unchanged,
# and the pushed guard reads the span's oldest commit – so moving a commit to the bottom of the
# unpushed run was refused as rewriting the pushed one below it
_ST_SCENARIO "\e[1;96m[85] a move lands right above the last pushed commit\e[0m"
echo "pa" > pa.txt && git add pa.txt && git commit -qm "PA pushed"
local PA_PUSHED=$(git rev-parse HEAD)
git push -q origin HEAD:refs/heads/pa-pushed 2>/dev/null
local PA
for PA in one two mine; do
	echo "$PA" > "pa_$PA.txt" && git add "pa_$PA.txt" && git commit -qm "PA $PA"
done
_ST_CHECK "the fixture pushed its base" git merge-base --is-ancestor "$PA_PUSHED" origin/pa-pushed
# Each move starts out of position whether or not the one before it landed, so a refusal
# cannot pass as a no-op
_ST_RUN --move="$(git rev-parse ':/PA two')..$(git rev-parse ':/PA mine')" --after="$PA_PUSHED"
_ST_EQ "a run right above it applies" "$RC" "0"
_ST_OUT_LACKS "without calling it pushed" 'already pushed'
_ST_EQ "landing there" "$(git log --format=%s -4 | tr '\n' '|')" "PA one|PA mine|PA two|PA pushed|"
_ST_RUN --move="$(git rev-parse ':/PA mine')" --after="$PA_PUSHED"
_ST_EQ "a single move right above it too" "$RC" "0"
_ST_EQ "landing there too" "$(git log --format=%s -4 | tr '\n' '|')" "PA one|PA two|PA mine|PA pushed|"
_ST_EQ "the pushed commit untouched" "$(git rev-parse HEAD~3)" "$PA_PUSHED"
# Before it, the pushed commit itself moves up, which the guard still refuses
_ST_RUN --move="$(git rev-parse ':/PA mine')" --before="$PA_PUSHED"
_ST_EQ "a move below it still refuses" "$RC" "1"
_ST_OUT_HAS "as rewriting it" 'already pushed'
git push -q origin --delete pa-pushed 2>/dev/null
