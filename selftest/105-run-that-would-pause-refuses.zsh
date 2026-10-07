_ST_SCENARIO "\e[1;96m[105] a run that would pause refuses where a parallel run's pause took the slot\e[0m"
local PSN PS_FIRST PS_LAST PS_WORKTREES
local PS_SF="$(git rev-parse --path-format=absolute --git-common-dir)/git-edit-state"
for PSN in 1 2 3; do echo "ps $PSN" > "ps$PSN.txt" && git add "ps$PSN.txt" && git commit -qm "PS $PSN" -- "ps$PSN.txt"; done
PS_FIRST=$(git rev-parse HEAD~2)
PS_LAST=$(git rev-parse HEAD)
PS_WORKTREES=$(git worktree list | wc -l | tr -d ' ')
# The failing check records a parallel run's pause first, with that run's check output – once,
# as the failure's diagnosis reruns it
printf '#!/bin/sh\n[ -f "%s" ] || printf "operation=edit\\nworktree=/nonexistent/peer\\n" > "%s"\n[ -f "%s-verify" ] || echo "peer log" > "%s-verify"\nexit 1\n' \
	"$PS_SF" "$PS_SF" "$PS_SF" "$PS_SF" > "$TMP/ps-pause.sh" && chmod +x "$TMP/ps-pause.sh"
_ST_RUN --move="$PS_LAST" --before="$PS_FIRST" --verify="$TMP/ps-pause.sh"
_ST_EQ "a failed check refuses rather than pause" "$RC" "1"
_ST_OUT_HAS "as an operation in flight, which drivers wait out" 'Another git-edit operation is in flight'
_ST_EQ "leaving no worktree" "$(git worktree list | wc -l | tr -d ' ')" "$PS_WORKTREES"
_ST_EQ "and the branch where it was" "$(git rev-parse HEAD)" "$PS_LAST"
_ST_EQ "the parallel run's pause stands" "$(sed -n 2p "$PS_SF")" "worktree=/nonexistent/peer"
_ST_EQ "and so does its check output" "$(cat "$PS_SF-verify")" "peer log"
rm -f "$PS_SF" "$PS_SF-verify"
# An edit pause records itself as soon as its worktree exists – a hook on that checkout
# records the parallel run's pause first
mkdir -p "$TMP/ps-hooks"
printf '#!/bin/sh\nprintf "operation=edit\\nworktree=/nonexistent/peer\\n" > "%s"\n' "$PS_SF" > "$TMP/ps-hooks/post-checkout"
chmod +x "$TMP/ps-hooks/post-checkout"
git config core.hooksPath "$TMP/ps-hooks"
PS_WORKTREES=$(git worktree list | wc -l | tr -d ' ')
_ST_RUN "$PS_FIRST"
_ST_EQ "an edit pause refuses the same way" "$RC" "1"
_ST_OUT_HAS "as an operation in flight" 'Another git-edit operation is in flight'
_ST_EQ "and its worktree goes too" "$(git worktree list | wc -l | tr -d ' ')" "$PS_WORKTREES"
rm -f "$PS_SF"
PS_WORKTREES=$(git worktree list | wc -l | tr -d ' ')
_ST_RUN --split="$PS_FIRST"
_ST_EQ "so does a content split's pause" "$RC" "1"
_ST_EQ "its worktree gone as well" "$(git worktree list | wc -l | tr -d ' ')" "$PS_WORKTREES"
rm -f "$PS_SF"
# A conflict pause, from two commits rewriting one line swapped
echo "pc base" > pc.txt && git add pc.txt && git commit -qm "PC base" -- pc.txt
echo "pc one" > pc.txt && git commit -qm "PC one" -- pc.txt
echo "pc two" > pc.txt && git commit -qm "PC two" -- pc.txt
PS_WORKTREES=$(git worktree list | wc -l | tr -d ' ')
_ST_RUN --move="$(git rev-parse HEAD)" --before="$(git rev-parse HEAD~1)"
_ST_EQ "a conflict pause refuses the same way" "$RC" "1"
_ST_OUT_HAS "as an operation in flight, mid-rebase" 'Another git-edit operation is in flight'
_ST_EQ "its worktree gone, rebase and all" "$(git worktree list | wc -l | tr -d ' ')" "$PS_WORKTREES"
rm -f "$PS_SF"
# A worktree named with -C is the caller's, which git-edit reuses from run to run
_ST_RUN -d "$(git rev-parse HEAD~1)" -C="$TMP/ps-own"
git config --unset core.hooksPath
_ST_EQ "a drop's conflict pause in a -C worktree refuses too" "$RC" "1"
_ST_CHECK "and leaves that worktree in place" test -e "$TMP/ps-own/.git"
rm -f "$PS_SF"
git worktree remove --force "$TMP/ps-own"
# Where the filesystem has no hard links, an exclusive create claims the slot instead
mkdir -p "$TMP/ps-noln"
printf '#!/bin/sh\n[ "$1" = -sfn ] && exec /bin/ln "$@"\nexit 1\n' > "$TMP/ps-noln/ln" && chmod +x "$TMP/ps-noln/ln"
local PS_PATH=$PATH
PATH="$TMP/ps-noln:$PATH"
_ST_RUN --move="$PS_LAST" --before="$PS_FIRST" --verify=false
_ST_EQ "without hard links a free slot still pauses" "$RC" "2"
_ST_EQ "recording this run's pause" "$(sed -n 's/^operation=//p' "$PS_SF")" "reorder"
_ST_RUN --abort
_ST_RUN --move="$PS_LAST" --before="$PS_FIRST" --verify="$TMP/ps-pause.sh"
PATH=$PS_PATH
_ST_EQ "and a taken one still refuses" "$RC" "1"
_ST_EQ "leaving its pause alone" "$(sed -n 2p "$PS_SF")" "worktree=/nonexistent/peer"
rm -f "$PS_SF" "$PS_SF-verify"
