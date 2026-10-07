# Stopped past its `update-ref`, a run stranded what the move still owed – journal entry,
# rewrite delivery, index re-sync – and stopped inside it, it named no move at all
_ST_SCENARIO "\e[1;96m[94] a signal once the branch moves lets the run finish\e[0m"
local VL
for VL in base one two; do
	echo "$VL" > "vl_$VL.txt" && git add "vl_$VL.txt" && git commit -qm "VL $VL"
done
local VL_REF=$(git symbolic-ref HEAD) VL_HOOKS=$(git rev-parse --path-format=absolute --git-path hooks)
local VL_WORKTREES=$(git worktree list | wc -l | tr -d ' ')
local VL_TIP=$(git rev-parse HEAD) VL_PID
# Holds the move open, so the signal lands inside it every time
print -r -- "#!/bin/sh
[ \"\$1\" = committed ] || exit 0
while read -r old new ref; do [ \"\$ref\" = $VL_REF ] && { : > '$TMP/vl-moving'; '$TMP/st-hold' '$TMP/vl-release'; }; done
exit 0" > "$VL_HOOKS/reference-transaction"
chmod +x "$VL_HOOKS/reference-transaction"
rm -f "$TMP/vl-moving" "$TMP/vl-release"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --exec -- sh -c 'echo changed > vl_two.txt && git commit -qam "VL changed"' </dev/null >"$TMP/vl-out" 2>&1 &
VL_PID=$!
until [ -f "$TMP/vl-moving" ] || ! kill -0 $VL_PID 2>/dev/null; do
	sleep 0.05
done
kill -TERM $VL_PID 2>/dev/null
: > "$TMP/vl-release"
wait $VL_PID
RC=$?
OUT=$(<"$TMP/vl-out")
_ST_EQ "a TERM while the branch moves lets the run finish" "$RC" "0"
_ST_OUT_HAS "naming the signal above the trailer" '^SIGTERM arrived once the branch had moved'
_ST_OUT_HAS "whose trailer reports the move" "^git-edit: ok – $VL_REF moved $VL_TIP → "
_ST_EQ "with the index re-synced to the new tip" "$(git diff --cached --name-only)" ""
_ST_EQ "and no worktree" "$(git worktree list | wc -l | tr -d ' ')" "$VL_WORKTREES"
_ST_RUN --status
_ST_OUT_HAS "and its journal entry written for --undo" "Last completed: exec (${VL_TIP:0:7} → "
git checkout -q -- vl_two.txt
# A second signal stops it after all, here while the `post-rewrite` delivery holds the run
print -r -- "#!/bin/sh
: > '$TMP/vl-delivering'; cat >/dev/null; '$TMP/st-hold' '$TMP/vl-release2'" > "$VL_HOOKS/post-rewrite"
chmod +x "$VL_HOOKS/post-rewrite"
VL_TIP=$(git rev-parse HEAD)
rm -f "$TMP/vl-moving" "$TMP/vl-delivering" "$TMP/vl-release" "$TMP/vl-release2"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --move="$(git rev-parse ':/VL one')" --after="$(git rev-parse ':/VL two')" </dev/null >"$TMP/vl-out" 2>&1 &
VL_PID=$!
until [ -f "$TMP/vl-moving" ] || ! kill -0 $VL_PID 2>/dev/null; do
	sleep 0.05
done
kill -TERM $VL_PID 2>/dev/null
: > "$TMP/vl-release"
until [ -f "$TMP/vl-delivering" ] || ! kill -0 $VL_PID 2>/dev/null; do
	sleep 0.05
done
kill -TERM $VL_PID 2>/dev/null
: > "$TMP/vl-release2"
wait $VL_PID
RC=$?
OUT=$(<"$TMP/vl-out")
rm -f "$VL_HOOKS/reference-transaction" "$VL_HOOKS/post-rewrite"
_ST_EQ "a second signal stops the run" "$RC" "143"
_ST_OUT_HAS "naming the move in its trailer" "^git-edit: error – stopped by SIGTERM after $VL_REF moved $VL_TIP → [0-9a-f]\{40,64\}\$"
_ST_EQ "the move it names is the branch's" "$(git rev-parse HEAD)" "${${OUT##* → }%%$'\n'*}"
_ST_EQ "and no worktree" "$(git worktree list | wc -l | tr -d ' ')" "$VL_WORKTREES"
