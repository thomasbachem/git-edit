# A fold that lands nothing, or less than was staged, says so

# The fold's correct tip is knowable up front, the pre-op tip plus the staged changes, so
# a run falling short of it must not read as ok – nothing landed is refused with staging
# intact, a dissolved hunk lands with a note, and an emptied replay gets its drop counted
_ST_SCENARIO "\e[1;96m[54] fold landing guards\e[0m"
local R54="$TMP/fold54"
git init -q -b main "$R54"
git -C "$R54" config user.email selftest@git-edit
git -C "$R54" config user.name "git-edit selftest"
cd "$R54"
printf 'a1\n' > fa.txt
printf 'x1\n' > fb.txt
git add fa.txt fb.txt && git commit -qm "F base"
printf 'x2\n' > fb.txt && git commit -qam "F advance"
local F_BASE=$(git rev-parse HEAD~1)
local F_TIP=$(git rev-parse HEAD)

# Total dissolve: stage a revert of the later commit and fold it into base –
# base already carries that content, so the fixup neutralizes cleanly
printf 'x1\n' > fb.txt && git add fb.txt
_ST_RUN --amend-into="$F_BASE"
_ST_EQ "a fold landing nothing is refused" "$RC" "1"
_ST_OUT_HAS "and names the cause" 'left history unchanged'
_ST_OUT_HAS "with an error trailer" '^git-edit: error'
_ST_EQ "branch untouched" "$(git rev-parse HEAD)" "$F_TIP"
_ST_CHECK "staged change still staged" sh -c "git diff --cached --name-only | grep -q fb.txt"

# Partial dissolve: one real hunk beside the same revert – the real hunk
# lands, and the summary notes the tip fell short of what was staged
printf 'a2\n' > fa.txt
git add fa.txt fb.txt
_ST_RUN --amend-into="$F_BASE"
_ST_EQ "a partial fold still exits 0" "$RC" "0"
_ST_OUT_HAS "emits ok trailer" '^git-edit: ok'
_ST_OUT_HAS "notes the dissolved hunk" 'tip tree differs from the staged result'
# The note grows the block above the identity line, which must still land
# where a `tail -3` reader looks for it
_ST_EQ "and the identity line still lands within a 'tail -3'" \
	"$(echo "$OUT" | tail -3 | grep -c 'amended: ')" "1"
_ST_EQ "the real hunk landed in base" "$(git show HEAD~1:fa.txt)" "a2"
_ST_EQ "the later commit's content survives" "$(git show HEAD:fb.txt)" "x2"
git reset -q --hard

# A resolution keeping the fold's content over the next commit's change leaves that pick empty –
# blind continues then drop it, and the summary must count the loss (resolving to the next commit's
# content instead takes its change in early, which the absorption guard refuses)
printf 'v1\n' > fc.txt && git add fc.txt && git commit -qm "F pick a"
printf 'v2\n' > fc.txt && git commit -qam "F pick b"
local F_COUNT=$(git rev-list --count HEAD)
printf 'v9\n' > fc.txt && git add fc.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~1)"
_ST_EQ "same-line fold pauses" "$RC" "2"
local ROUNDS54=0
while [ "$RC" = "2" ] && [ $ROUNDS54 -lt 4 ]; do
	ROUNDS54=$((ROUNDS54+1))
	if grep -q 'current step became empty' <<<"$OUT"; then
		# The pause an emptied pick surfaces as – continue drives through it
		_ST_RUN --continue
		continue
	fi
	local WT54=$(print -r -- "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ (;]*\).*/\1/p' | head -1)
	if [ -z "$WT54" ] || [ ! -d "$WT54" ]; then
		break
	fi
	printf 'v9\n' > "$WT54/fc.txt"
	git -C "$WT54" add fc.txt
	_ST_RUN --continue
done
_ST_EQ "blind resolution completes" "$RC" "0"
_ST_OUT_HAS "and the dropped commit is counted" 'resolved to empty and were dropped'
_ST_EQ "history is one commit shorter" "$(git rev-list --count HEAD)" "$((F_COUNT-1))"

# And an ordinary clean fold must trip neither guard (the partial fold
# above rewrote F_BASE, so re-derive the target from the root)
printf 'a3\n' > fa.txt && git add fa.txt
_ST_RUN --amend-into="$(git rev-list --max-parents=0 HEAD)"
_ST_EQ "clean fold exits 0" "$RC" "0"
_ST_OUT_LACKS "no tree note on a faithful fold" 'tip tree differs'
_ST_OUT_LACKS "no drop count on a faithful fold" 'resolved to empty'
cd "$TMP/repo"
