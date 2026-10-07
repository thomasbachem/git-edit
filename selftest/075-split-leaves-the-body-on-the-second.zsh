# A split leaves the message, body included, on the second commit

# `--text` names the extracted commit alone and the remainder keeps the original whole – a
# caller reading the pause as "--text is the first commit's subject" rewords the remainder
# next with `-M --text` and cuts the body, so the pause names it, and `--status` again
_ST_SCENARIO "\e[1;96m[75] a split leaves the body on the second commit, and says so\e[0m"
printf 'first\nsecond\n' > sp.txt && git add sp.txt && git commit -qm "SP base"
printf 'FIRST\nsecond\nthird\n' > sp.txt && echo "sp-side" > sp2.txt && git add sp.txt sp2.txt
git commit -q -F - <<-'SPMSG'
	SP mixed commit

	• first body line
	• second body line
SPMSG
local SP_TARGET=$(git rev-parse HEAD)
local SP_MSG=$(git log -1 --format=%B "$SP_TARGET")
echo "sp-later" > sp3.txt && git add sp3.txt && git commit -qm "SP later"
# The pathspec form
_ST_RUN --split="$SP_TARGET" --text="SP extracted by path" -- sp2.txt
_ST_EQ "a pathspec split applies" "$RC" "0"
local SP_KEPT=$(git log --format='%H %s' | grep 'SP mixed commit' | cut -d' ' -f1)
_ST_EQ "the extracted commit carries --text alone" "$(git log -1 --format=%B "$SP_KEPT^")" "SP extracted by path"
_ST_EQ "the remainder keeps the message, body included" "$(git log -1 --format=%B "$SP_KEPT")" "$SP_MSG"
# The content form, on the remainder, which still carries the body
_ST_RUN --split="$SP_KEPT"
_ST_EQ "a content split pauses" "$RC" "2"
_ST_OUT_HAS "and names the body the second commit keeps" "keeps ${SP_KEPT:0:7}'s message, its 2-line body included"
_ST_OUT_HAS "with the reword's own trap" 'restating the body lines that still hold'
local SP_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – split [0-9a-f]* in \(.*\); then.*/\1/p')
_ST_RUN --status
_ST_OUT_HAS "as does --status" 'its 2-line body included'
printf 'FIRST\nsecond\n' > "${SP_WT:-$ST_NO_WT}/sp.txt"
_ST_RUN --continue --text "SP extracted by content"
_ST_EQ "the continue completes the split" "$RC" "0"
SP_KEPT=$(git log --format='%H %s' | grep 'SP mixed commit' | cut -d' ' -f1)
_ST_EQ "the extracted commit carries --text alone" "$(git log -1 --format=%B "$SP_KEPT^")" "SP extracted by content"
_ST_EQ "the remainder keeps the message, body included" "$(git log -1 --format=%B "$SP_KEPT")" "$SP_MSG"
# Negative: a subject-only target has no body to name
printf 'sp-a\nsp-b\n' > sp4.txt && git add sp4.txt && git commit -qm "SP plain base"
printf 'SP-A\nsp-b\nsp-c\n' > sp4.txt && git add sp4.txt && git commit -qm "SP plain"
_ST_RUN --split="$(git rev-parse HEAD)"
_ST_EQ "a content split of a subject-only commit pauses" "$RC" "2"
_ST_OUT_HAS "naming the message it keeps" "keeps $(git rev-parse --short=7 HEAD)'s message – reword"
_ST_OUT_LACKS "and no body" 'body included'
_ST_RUN --abort
git reset -q --hard
