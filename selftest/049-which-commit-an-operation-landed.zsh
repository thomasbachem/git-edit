_ST_SCENARIO "\e[1;96m[49] which commit an operation landed in survives a short tail\e[0m"
git reset -q --hard
printf 'id base\n' > id.txt && git add id.txt && git commit -qm "ID base"
# A target wide enough that its own stat block would bury a line printed
# above it – the shape that hid which commit a fold had landed in
local IDF
for IDF in {1..14}; do printf 'id %s\n' "$IDF" > "id$IDF.txt"; done
git add -A && git commit -qm "ID wide target"
printf 'id staged\n' > id-staged.txt && git add id-staged.txt
_ST_RUN --amend-into=HEAD
_ST_EQ "the wide fold succeeds" "$RC" "0"
_ST_OUT_HAS "names the commit folded into" 'amended: .*ID wide target'
_ST_EQ "and names it within a 'tail -3'" \
	"$(echo "$OUT" | tail -3 | grep -c 'amended: ')" "1"

printf 'id s1\n' > id-s1.txt && git add id-s1.txt && git commit -qm "ID squash one"
printf 'id s2\n' > id-s2.txt && git add id-s2.txt && git commit -qm "ID squash two"
_ST_RUN -s -y HEAD~1 HEAD
_ST_EQ "the squash succeeds" "$RC" "0"
_ST_OUT_HAS "and proves its tree-preserving invariant" 'Tip tree identical'
_ST_EQ "its own summary lands within a 'tail -3' too" \
	"$(echo "$OUT" | tail -3 | grep -c 'squashed: ')" "1"

# These lines are the mis-target signal, so a subject has to reach them
# verbatim – routed through an `echo -e` a `\d` collapses to `d` and a `\n`
# breaks the line, leaving a name that reads as a different commit
printf 'id esc\n' > id-esc.txt && git add id-esc.txt
git commit -qm 'ID esc \d and \n intact'
printf 'id esc2\n' > id-esc2.txt && git add id-esc2.txt
_ST_RUN --amend-into=HEAD
_ST_EQ "a subject's backslash escapes reach the identity line intact" \
	"$(echo "$OUT" | grep -cF 'amended: ')" "1"
# `print -r`, not `echo` – zsh's `echo` would interpret the escapes here in
# the harness and report a mangling that never happened
_ST_EQ "and are not interpreted on the way" \
	"$(print -r -- "$OUT" | grep -F 'amended: ' | grep -cF 'ID esc \d and \n intact')" "1"
# The preamble names the same subject through a different path, so it needs
# its own guard – `PRINT_ACTION` embeds it in a string `ECHO_E` interprets
_ST_EQ "the preamble keeps them too" \
	"$(print -r -- "$OUT" | grep -F 'Amending staged changes' | grep -cF 'ID esc \d and \n intact')" "1"

# A non-contiguous selection falls back to the rebase path, which has no
# plumbing commit of its own to name – it names the destination instead
printf 'id f1\n' > id-f1.txt && git add -A && git commit -qm 'ID fallback \d target'
printf 'id f2\n' > id-f2.txt && git add -A && git commit -qm "ID fallback skipped"
printf 'id f3\n' > id-f3.txt && git add -A && git commit -qm "ID fallback folded"
_ST_RUN -s -y HEAD~2 HEAD
_ST_EQ "the non-contiguous squash succeeds" "$RC" "0"
_ST_EQ "it names its destination within a 'tail -3'" \
	"$(print -r -- "$OUT" | tail -3 | grep -c 'squashed into: ')" "1"
_ST_EQ "with that subject's escapes intact" \
	"$(print -r -- "$OUT" | grep -F 'squashed into: ' | grep -cF 'ID fallback \d target')" "1"

# A split's two halves keep their stats paired under their own subjects, so
# it names the commit it split rather than moving those
printf 'id p\n' > id-p.txt && printf 'id q\n' > id-q.txt
git add -A && git commit -qm "ID split source"
_ST_RUN --split HEAD --text='ID extracted' -- id-p.txt
_ST_EQ "the split succeeds" "$RC" "0"
_ST_OUT_HAS "it names the commit it split" 'split: .*ID split source'
_ST_EQ "and does so within a 'tail -3'" \
	"$(echo "$OUT" | tail -3 | grep -c 'split: ')" "1"

# A drop's hint lists every restored path, so the commit's own name has to
# follow that list – it is the only mode whose tail named no commit at all
printf 'id d1\n' > id-d1.txt && git add -A && git commit -qm 'ID drop \d target'
_ST_RUN -d -y HEAD
_ST_EQ "the drop succeeds" "$RC" "0"
_ST_EQ "it names what it dropped within a 'tail -3'" \
	"$(print -r -- "$OUT" | tail -3 | grep -c 'dropped: ')" "1"
_ST_EQ "with that subject's escapes intact" \
	"$(print -r -- "$OUT" | grep -F 'dropped: ' | grep -cF 'ID drop \d target')" "1"

# An edit resumes in a later run, where the paused trailer's name is gone
printf 'id e1\n' > id-e1.txt && git add -A && git commit -qm "ID edit target"
_ST_RUN HEAD
_ST_EQ "the edit pauses" "$RC" "2"
local ID_WT=$(print -r -- "$OUT" | sed -n 's/^git-edit: paused – edit [^ ]* in \([^;]*\);.*/\1/p' | head -1)
_ST_CHECK "it opened a worktree" test -d "$ID_WT"
printf 'id e1 edited\n' > "${ID_WT:-$ST_NO_WT}/id-e1.txt"
git -C "$ID_WT" add id-e1.txt
_ST_RUN --continue
_ST_EQ "the edit settles" "$RC" "0"
_ST_EQ "and names what it edited within a 'tail -3'" \
	"$(print -r -- "$OUT" | tail -3 | grep -c 'edited: ')" "1"
git reset -q --hard
