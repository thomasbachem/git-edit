# Comment stripping exists to drop the instructions git seeds an editor template with,
# and nothing seeds `--text`, so a `#` line there is the caller's content – an issue
# reference, a Markdown heading, a shell snippet – silently rewritten on every route
_ST_SCENARIO "\e[1;96m[53] --text keeps the caller's own '#' lines\e[0m"
git reset -q --hard
local HM_BODY

HM_BODY=$(printf 'HM reworded\n\nSee also:\n#123 route-reword')
echo "hm1" > hm.txt && git add hm.txt && git commit -qm "HM base"
_ST_RUN -M --text="$HM_BODY" HEAD
_ST_EQ "a reword keeps them" "$(git log --format=%B | grep -c '^#123 route-reword$')" "1"

HM_BODY=$(printf 'HM folded\n\nSee also:\n#123 route-plumbing')
echo "hm2" > hm2.txt && git add hm2.txt && git commit -qm "HM one"
echo "hm3" > hm3.txt && git add hm3.txt && git commit -qm "HM two"
_ST_RUN -s="$(git rev-parse HEAD~1)" -y --text="$HM_BODY" "$(git rev-parse HEAD)"
_ST_EQ "a plumbing fold keeps them" "$(git log --format=%B | grep -c '^#123 route-plumbing$')" "1"

# Non-adjacent, so it falls to the rebase path where the message reaches the commit through
# an editor – which route a fold takes turns on adjacency, not on anything the caller
# said, so the two must not disagree here
HM_BODY=$(printf 'HM gapped\n\nSee also:\n#123 route-rebase')
echo "hm4" > hm4.txt && git add hm4.txt && git commit -qm "HM gap a"
echo "hm5" > hm5.txt && git add hm5.txt && git commit -qm "HM gap b"
echo "hm6" > hm6.txt && git add hm6.txt && git commit -qm "HM gap c"
_ST_RUN -s="$(git rev-parse HEAD~2)" -y --text="$HM_BODY" "$(git rev-parse HEAD)"
_ST_EQ "a rebase-path fold keeps them too" \
	"$(git log --format=%B | grep -c '^#123 route-rebase$')" "1"
_ST_CHECK "and no template boilerplate rode along" \
	sh -c "! git log --format=%B | grep -qE 'This is a combination of|rebase in progress|^# Conflicts:'"

# Whitespace-only input still has nothing to commit, so the guard stays live
_ST_RUN -M --text='   ' HEAD
_ST_EQ "a blank message is still refused" "$RC" "1"
_ST_OUT_HAS "and says why" 'empty message'
git reset -q --hard

_ST_CHECK "the color gate covers NO_COLOR and TERM=dumb" \
	sh -c "command grep -q '^if \\[ ! -t 1 \\] || \\[ -n \"\\\$NO_COLOR\" \\] || \\[ \"\\\$TERM\" = \"dumb\" \\]; then' \"\$1\"" _ "$SELF"
