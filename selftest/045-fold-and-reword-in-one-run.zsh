_ST_SCENARIO "\e[1;96m[45] fold and reword in one run\e[0m"
git reset -q --hard
printf 'at one\n' > at.txt && git add at.txt && git commit -qm "AT base"
printf 'at two\n' > at.txt && git add at.txt && git commit -qm "AT target"
local AT_TARGET=$(git rev-parse HEAD)
printf 'at three\n' > at-other.txt && git add at-other.txt && git commit -qm "AT descendant"
printf 'at folded\n' > at.txt && git add at.txt
_ST_RUN --amend-into="$AT_TARGET" --text='AT reworded by the fold'
_ST_EQ "the run succeeds" "$RC" "0"
_ST_OUT_HAS "names the subject it replaced" 'replaced:.*AT target'
# The capture is a pipe, so this doubles as the check that color is gated
_ST_OUT_LACKS "captured output carries no color" $'\e\\['
_ST_CHECK "the message landed" sh -c "git log --format=%s | grep -qx 'AT reworded by the fold'"
_ST_CHECK "and replaced the old one" sh -c "! git log --format=%s | grep -qx 'AT target'"
_ST_CHECK "the fold landed in that same commit" \
	sh -c "git show HEAD~1:at.txt | grep -qx 'at folded'"
_ST_CHECK "the descendant survives" sh -c "git log --format=%s | grep -qx 'AT descendant'"
_ST_CHECK "nothing is left staged" sh -c "git diff --cached --quiet"
# Without a message the fold must leave the subject exactly as it was
git reset -q --hard
printf 'at plain\n' > at.txt && git add at.txt
_ST_RUN --amend-into=HEAD~1
_ST_CHECK "a fold without --text keeps the subject" \
	sh -c "git log --format=%s | grep -qx 'AT reworded by the fold'"
_ST_OUT_LACKS "and claims no replacement" 'replaced:'
git reset -q --hard

# A message is part of the fold's definition – the replay already carries
# it, so one arriving at --continue has to be refused rather than dropped
printf 'atc base\n' > atc.txt && git add atc.txt && git commit -qm "ATC base"
printf 'atc mid\n' > atc.txt && git add atc.txt && git commit -qm "ATC target"
local ATC_TARGET=$(git rev-parse HEAD)
printf 'atc top\n' > atc.txt && git add atc.txt && git commit -qm "ATC top"
printf 'atc folded\n' > atc.txt && git add atc.txt
_ST_RUN --amend-into="$ATC_TARGET"
_ST_EQ "a conflicting fold pauses" "$RC" "2"
_ST_RUN --continue --text='too late'
_ST_OUT_HAS "--text on --continue is refused, not ignored" 'takes --text up front'
_ST_RUN --abort
_ST_CHECK "abort leaves the branch intact" sh -c "git log --format=%s | grep -qx 'ATC top'"
git reset -q --hard

# A resolution that empties the replayed commit shortens the chain, so an
# offset from the new tip names a commit the fold never touched
printf 'ae base\n' > ae.txt && git add ae.txt && git commit -qm "AE base"
printf 'ae mid\n' > ae.txt && git add ae.txt && git commit -qm "AE target"
local AE_TARGET=$(git rev-parse HEAD)
printf 'ae top\n' > ae.txt && git add ae.txt && git commit -qm "AE top"
printf 'ae folded\n' > ae.txt && git add ae.txt
_ST_RUN --amend-into="$AE_TARGET"
local AE_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
local AE_ROUNDS=0
while [ -n "$AE_WT" ] && [ -d "$AE_WT" ] && [ $AE_ROUNDS -lt 5 ]; do
	AE_ROUNDS=$((AE_ROUNDS+1))
	printf 'ae folded\n' > "${AE_WT:-$ST_NO_WT}/ae.txt"
	git -C "$AE_WT" add ae.txt
	_ST_RUN --continue
	AE_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
done
_ST_EQ "the fold settles" "$RC" "0"
_ST_CHECK "a commit really was dropped as empty" \
	sh -c "! git log --format=%s | grep -qx 'AE top'"
_ST_OUT_HAS "the summary names the commit folded into" 'amended: .*AE target'
_ST_OUT_LACKS "not the one below it" 'amended: .*AE base'
git reset -q --hard
