# Fold conflict -> resolve -> continue (with cascade)
_ST_SCENARIO "\e[1;96m[6] amend-into conflict + continue\e[0m" # needs 5
_ST_RUN --amend-into="$SHA_C2"
_ST_EQ "pauses with exit 2" "$RC" "2"
local ROUNDS=0
while [ "$RC" = "2" ] && [ $ROUNDS -lt 4 ]; do
	ROUNDS=$((ROUNDS+1))
	local CONFLICT_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	if [ -z "$CONFLICT_WT" ] || [ ! -d "$CONFLICT_WT" ]; then
		break
	fi
	if [ $ROUNDS -eq 1 ]; then
		echo "line1-resolved" > "${CONFLICT_WT:-$ST_NO_WT}/c.txt"
	else
		echo "line2" > "${CONFLICT_WT:-$ST_NO_WT}/c.txt"
	fi
	git -C "$CONFLICT_WT" add c.txt
	_ST_RUN --continue
done
_ST_EQ "continue completes" "$RC" "0"
_ST_OUT_HAS "emits ok trailer" '^git-edit: ok – refs/heads/main moved'
_ST_EQ "resolution in C" "$(git show 'HEAD~2:c.txt')" "line1-resolved"
_ST_EQ "tip keeps D's content" "$(git show 'HEAD:c.txt')" "line2"
_ST_CHECK "index clean afterwards" git diff --cached --quiet
_ST_CHECK "state cleared" test ! -f "$(git rev-parse --git-common-dir)/git-edit-state"
