# Batch reword rewrites many messages in one pass from stdin records
_ST_SCENARIO "\e[1;96m[56] batch reword (-M --text - records)\e[0m"
cd "$TMP/repo"
# Self-contained commits so an earlier fixture can't collide
local _bw
for _bw in bw1 bw2 bw3 bw4; do echo "$_bw" > "$_bw.txt"; git add "$_bw.txt"; git commit -qm "Batch $_bw"; done
local BW_TIP0=$(git rev-parse HEAD)
local BW_TREE0=$(git rev-parse 'HEAD^{tree}')
local BW_COUNT0=$(git rev-list --count HEAD)
local BW1=$(git rev-parse --short :/Batch\ bw1)
local BW3=$(git rev-parse --short :/Batch\ bw3)
# Dump the run's shape, edit two bodies, feed it straight back
_ST_RUN_IN "$(printf -- '--- %s\nBatch bw1 reworded\n--- %s\nBatch bw3 reworded\n\nWith a body\n' "$BW1" "$BW3")" -M --text -
_ST_EQ "batch reword exits 0" "$RC" "0"
_ST_OUT_HAS "emits ok trailer" '^git-edit: ok'
_ST_OUT_HAS "reports the count" 'Reworded 2 commits'
_ST_OUT_HAS "asserts the tree invariant" 'Trees unchanged'
_ST_EQ "first target's message applied" "$(git log --format=%s | grep -c '^Batch bw1 reworded$')" "1"
_ST_EQ "second target's message applied" "$(git log --format=%s | grep -c '^Batch bw3 reworded$')" "1"
_ST_EQ "second target's body applied" "$(git log -1 --format=%b :/'Batch bw3 reworded' | grep -c 'With a body')" "1"
# Two-dash headers read as records to their author and as nothing to the detector – every
# session that wrote them got the bare missing-commit refusal, so name the shape
_ST_RUN_IN "$(printf -- '-- %s\nTwo dashes\n' "$BW1")" -M --text -
_ST_EQ "two-dash records refuse" "$RC" "1"
_ST_OUT_HAS "and name the three-dash shape" "Records start with '--- <commit>'"
_ST_OUT_LACKS "instead of the bare missing-commit refusal" 'Missing <commit>'
_ST_EQ "untouched neighbour intact" "$(git log --format=%s | grep -c '^Batch bw2$')" "1"
_ST_EQ "tip tree preserved (content unchanged)" "$(git rev-parse 'HEAD^{tree}')" "$BW_TREE0"
_ST_EQ "commit count unchanged" "$(git rev-list --count HEAD)" "$BW_COUNT0"
# The reflog top is the single CAS – not two, not one per commit
_ST_EQ "exactly one ref update" "$(git reflog show main | head -1 | grep -c 'git edit: reword 2 commits')" "1"
# Undo reverses the whole batch in one step
_ST_RUN --undo
_ST_EQ "undo restores the pre-batch tip" "$(git rev-parse HEAD)" "$BW_TIP0"

# Re-apply, then exercise every rejection path against a stable tip
_ST_RUN_IN "$(printf -- '--- %s\nBatch bw1 reworded\n' "$BW1")" -M --text -
local BW_AFTER=$(git rev-parse HEAD)
_ST_RUN_IN "$(printf -- '--- %s\nX\n--- %s\nY\n' "$(git rev-parse --short HEAD)" "$(git rev-parse --short HEAD)")" -M --text -
_ST_EQ "duplicate target refused" "$RC" "1"
_ST_OUT_HAS "names the duplicate" 'named by two records'
_ST_EQ "duplicate left the tip untouched" "$(git rev-parse HEAD)" "$BW_AFTER"
_ST_RUN_IN "$(printf -- '--- %s\n\n' "$(git rev-parse --short HEAD)")" -M --text -
_ST_EQ "empty message refused" "$RC" "1"
_ST_OUT_HAS "names the empty record" 'empty message'
_ST_RUN_IN "$(printf -- '--- %s\nok\n--- deadbeefdeadbeef\nno\n' "$(git rev-parse --short HEAD)")" -M --text -
_ST_EQ "unknown header refused" "$RC" "1"
_ST_EQ "unknown header left the tip untouched" "$(git rev-parse HEAD)" "$BW_AFTER"
# Every record already matches -> nothing to do, no ref move
local BW_NOW=$(git rev-parse HEAD)
_ST_RUN_IN "$(git log -1 --format='--- %h%n%B' HEAD)" -M --text -
_ST_EQ "all-no-op exits 0" "$RC" "0"
_ST_OUT_HAS "reports nothing to do" 'nothing to do'
_ST_EQ "all-no-op moved no ref" "$(git rev-parse HEAD)" "$BW_NOW"
# A stale SHA in a record resolves to its rewritten identity
local BW_S1=$(git rev-parse HEAD)
_ST_RUN -M --text="staled once" "$BW_S1"
_ST_RUN_IN "$(printf -- '--- %s\nrecovered via stale sha\n' "${BW_S1:0:9}")" -M --text -
_ST_EQ "stale sha resolved and applied" "$RC" "0"
_ST_EQ "stale target's new message present" "$(git log --format=%s | grep -c '^recovered via stale sha$')" "1"
# A target whose own message carries a `--- ` line is refused, that line being the record
# separator, so its dump would mis-split – the single form has none to collide with
printf 'Body with a separator\n\n--- probe\n' | git commit -q --allow-empty -F -
local BW_MARK=$(git rev-parse HEAD)
_ST_RUN_IN "$(printf -- '--- %s\nReworded marker body\n' "$(git rev-parse --short HEAD)")" -M --text -
_ST_EQ "marker-body target refused" "$RC" "1"
_ST_OUT_HAS "names the reserved separator" "reserves"
_ST_EQ "marker refusal moved no ref" "$(git rev-parse HEAD)" "$BW_MARK"
# A pushed target is refused via the bulk unpushed-set check, which falls back to
# `_GUARD_UNPUSHED` for the message, and `origin/main` is pushed history
local BW_TIP=$(git rev-parse HEAD)
_ST_RUN_IN "$(printf -- '--- %s\nRewrite pushed history\n' "$(git rev-parse origin/main)")" -M --text -
_ST_EQ "pushed target refused" "$RC" "1"
_ST_OUT_HAS "names it as pushed" "already pushed"
_ST_EQ "pushed refusal moved no ref" "$(git rev-parse HEAD)" "$BW_TIP"
cd "$TMP/repo"
