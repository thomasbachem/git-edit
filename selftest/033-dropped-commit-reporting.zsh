# A reorder step resolved to empty must not vanish under an `ok`
_ST_SCENARIO "\e[1;96m[33] dropped-commit reporting\e[0m"
git reset -q --hard
printf 'd1\nd2\nd3\n' > dr.txt && git add dr.txt && git commit -qm "DR base"
printf 'd1\nDX\nd3\n' > dr.txt && git add dr.txt && git commit -qm "DR one"
printf 'd1\nDY\nd3\n' > dr.txt && git add dr.txt && git commit -qm "DR two"
local DR_TIP=$(git rev-parse HEAD)
_ST_RUN --reorder "$DR_TIP" "$(git rev-parse HEAD~1)"
_ST_EQ "reordering abutting edits conflicts" "$RC" "2"
local DR_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
printf 'd1\nDY\nd3\n' > "${DR_WT:-$ST_NO_WT}/dr.txt" && git -C "$DR_WT" add dr.txt
# The final step restores the pre-op blobs by itself, which leaves the
# replayed commit empty and the rebase drops it
_ST_RUN --continue
_ST_EQ "resolution completes in one continue" "$RC" "0"
_ST_OUT_HAS "continue path prints the new order too" 'new order (oldest-first)'
_ST_OUT_HAS "reports the dropped commit" 'resolved to empty and were dropped'
_ST_OUT_HAS "and names it" 'dropped: .*DR one'
_ST_CHECK "state cleared" sh -c "! git edit --status 2>&1 | grep -q 'In-flight'"
git reset -q --hard

# The dissolution workflow rests on the same drop staying silent at the
# rebase: an edit that reproduces a later commit's change empties the husk,
# the replay drops it without a pause, and the summary names it
printf 'h1\n' > hk.txt && git add hk.txt && git commit -qm "HK origin"
printf 'h1\nh2\n' > hk.txt && git add hk.txt && git commit -qm "HK husk"
local HK_COUNT=$(git rev-list --count HEAD)
_ST_RUN "$(git rev-parse HEAD~1)"
local HK_WT=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
printf 'h1\nh2\n' > "${HK_WT:-$ST_NO_WT}/hk.txt"
_ST_RUN --continue
_ST_EQ "the dissolution applies without a pause" "$RC" "0"
_ST_OUT_HAS "the emptied husk is counted" 'resolved to empty and were dropped'
_ST_OUT_HAS "and named" 'dropped: .*HK husk'
_ST_OUT_HAS "with the tip tree proven untouched" 'Tip tree identical'
_ST_EQ "the husk is gone from history" "$(git rev-list --count HEAD)" "$((HK_COUNT - 1))"
_ST_EQ "and the identity line stays within a 'tail -3'" \
	"$(echo "$OUT" | tail -3 | grep -c 'edited: ')" "1"
git reset -q --hard

# Duplicate subjects cancel by count, so the husk is named and its twin is not
printf 'p1\n' > dp.txt && git add dp.txt && git commit -qm "DP origin"
printf 'p1\np2\n' > dp.txt && git add dp.txt && git commit -qm "DP twin"
printf 'p1\np2\np3\n' > dp.txt && git add dp.txt && git commit -qm "DP twin"
local DP_HUSK=$(git rev-parse --short HEAD~1)
_ST_RUN "$(git rev-parse HEAD~2)"
local DP_WT=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
printf 'p1\np2\n' > "${DP_WT:-$ST_NO_WT}/dp.txt"
_ST_RUN --continue
_ST_EQ "the twin-subject dissolution applies" "$RC" "0"
_ST_EQ "exactly one commit is named" "$(print -r -- "$OUT" | grep -c 'dropped: ')" "1"
_ST_OUT_HAS "and it is the husk, not its surviving twin" "dropped: $DP_HUSK"
_ST_EQ "the surviving twin kept its content" "$(git show HEAD:dp.txt | tail -1)" "p3"
git reset -q --hard

# A reword in the same run leaves a subject with no counterpart – that is no
# drop, so the naming stands down while the count stays
printf 'r1\n' > rw.txt && git add rw.txt && git commit -qm "RW origin"
printf 'r1\nr2\n' > rw.txt && git add rw.txt && git commit -qm "RW husk"
_ST_RUN "$(git rev-parse HEAD~1)"
local RW_WT=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
printf 'r1\nr2\n' > "${RW_WT:-$ST_NO_WT}/rw.txt"
_ST_RUN --continue --text "RW origin reworded"
_ST_EQ "the reworded dissolution applies" "$RC" "0"
_ST_OUT_HAS "the drop is still counted" 'resolved to empty and were dropped'
_ST_OUT_LACKS "but nothing is named on ambiguous subjects" 'dropped: '
git reset -q --hard

# Subjects are shell text, and this repo's own are full of backticks – an
# arithmetic subscript would execute them while counting
printf 'b1\n' > bt.txt && git add bt.txt && git commit -qm 'BT origin'
printf 'b1\nb2\n' > bt.txt && git add bt.txt && git commit -qm 'BT `rules` husk $(echo PWNED)'
_ST_RUN "$(git rev-parse HEAD~1)"
local BT_WT=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
printf 'b1\nb2\n' > "${BT_WT:-$ST_NO_WT}/bt.txt"
_ST_RUN --continue
_ST_EQ "a backticked subject dissolves cleanly" "$RC" "0"
_ST_OUT_HAS "and is named verbatim" 'dropped: .*BT `rules` husk'
_ST_OUT_HAS "with its substitution text intact, not executed" '(echo PWNED)'
git reset -q --hard
