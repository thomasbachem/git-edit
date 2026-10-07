# An exec result whose messages gained trailing blank lines refuses
# `%B` fed raw to `commit-tree` adds a blank line to each message a loop rebuilds, one more
# per pass, and `git log` and `git range-diff` both hide it – so the landing counts bytes
_ST_SCENARIO "\e[1;96m[91] exec refuses messages that gained trailing blank lines\e[0m"
git commit -q --allow-empty -m "BL one"
local BL_BASE=$(git rev-parse HEAD)
# One message already ends in a blank line, which a loop carrying it as is must not trip on
git reset -q --hard "$(printf 'BL two\n\nbody\n\n' | git commit-tree "$(git rev-parse HEAD^{tree})" -p HEAD)"
git commit -q --allow-empty -m "BL three"
cat > "$TMP/bl-loop.sh" <<'EOF'
# Rebuilds `$1..HEAD`, each tree kept, the message read raw by `%B`, byte-exact, or trimmed
N=$1
for C in $(git rev-list --reverse "$1..HEAD"); do
case $2 in
	raw) N=$(git log -1 --format=%B "$C" | git commit-tree "$C^{tree}" -p "$N") ;;
	exact) N=$(git cat-file commit "$C" | sed '1,/^$/d' | git commit-tree "$C^{tree}" -p "$N") ;;
	trim) N=$(git commit-tree "$C^{tree}" -p "$N" -m "$(git log -1 --format=%B "$C")") ;;
esac
done
git reset -q --hard "$N"
EOF
local BL_TIP=$(git rev-parse HEAD)
_ST_RUN --exec --base="$BL_TIP" -- sh "$TMP/bl-loop.sh" "$BL_BASE" raw
_ST_EQ "a loop feeding %B raw refuses" "$RC" "1"
_ST_OUT_HAS "counting both messages" '2 message(s) it brings in end in more blank lines'
_ST_OUT_HAS "naming one already ending in a blank line" '^    [0-9a-f]\{7,\} BL two$'
_ST_OUT_HAS "and one that did not" '^    [0-9a-f]\{7,\} BL three$'
_ST_OUT_HAS "and the fix" 'Take each message from git cat-file commit'
_ST_EQ "moving nothing" "$(git rev-parse HEAD)" "$BL_TIP"
_ST_RUN --exec --dry-run --base="$BL_TIP" -- sh "$TMP/bl-loop.sh" "$BL_BASE" raw
_ST_EQ "its dry run refuses too" "$RC" "1"
_ST_OUT_LACKS "printing no landing" 'Land it:'
_ST_RUN --exec --base="$BL_TIP" -- sh "$TMP/bl-loop.sh" "$BL_BASE" exact
_ST_EQ "a byte-exact loop lands" "$RC" "0"
_ST_EQ "carrying the old blank line as is" "$(git cat-file commit HEAD~1 | sed '1,/^$/d' | wc -l | tr -d ' ')" "4"
_ST_RUN --exec --base="$(git rev-parse HEAD)" -- sh "$TMP/bl-loop.sh" "$BL_BASE" trim
_ST_EQ "a trimming loop lands" "$RC" "0"
_ST_EQ "ending it in a single newline" "$(git cat-file commit HEAD~1 | sed '1,/^$/d' | wc -l | tr -d ' ')" "3"
# A reword keeps the author and author date, which still match it to the commit it replaces
_ST_RUN --exec --base="$(git rev-parse HEAD)" -- sh -c 'GIT_AUTHOR_DATE="$(git log -1 --format=%ad --date=raw HEAD)" && export GIT_AUTHOR_DATE && git reset -q --hard "$(printf "BL reworded\n\n" | git commit-tree HEAD^{tree} -p HEAD^)"'
_ST_EQ "a reword ending in a blank line refuses" "$RC" "1"
_ST_OUT_HAS "naming it" '^    [0-9a-f]\{7,\} BL reworded$'
# A commit made elsewhere and brought in replaces nothing, so it lands with its message as it was
local BL_SIDE=$(printf 'BL side\n\n' | git commit-tree "$(git rev-parse HEAD^{tree})" -p HEAD)
_ST_RUN --exec -- git merge -q --ff-only "$BL_SIDE"
_ST_EQ "a branch brought in lands as it is" "$RC" "0"
_ST_EQ "its message untouched" "$(git cat-file commit HEAD | sed '1,/^$/d' | wc -l | tr -d ' ')" "2"
# A plain commit on top trims its own message, as git commit always does
printf 'BL on top\n\n\n' > "$TMP/bl-msg"
_ST_RUN --exec -- git commit -q --allow-empty -F "$TMP/bl-msg"
_ST_EQ "a git commit in the run lands" "$RC" "0"
_ST_EQ "as the new tip" "$(git log --format=%s -1)" "BL on top"
git reset -q --hard
