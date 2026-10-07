_ST_SCENARIO "\e[1;96m[104] a refused landing removes its worktree though a parallel run's pause is recorded\e[0m"
local PPN PP_FIRST PP_LAST PP_PEER PP_BRANCH PP_WORKTREES
local PP_SF="$(git rev-parse --path-format=absolute --git-common-dir)/git-edit-state"
for PPN in 1 2 3; do echo "pp $PPN" > "pp$PPN.txt" && git add "pp$PPN.txt" && git commit -qm "PP $PPN" -- "pp$PPN.txt"; done
PP_FIRST=$(git rev-parse HEAD~2)
PP_LAST=$(git rev-parse HEAD)
PP_BRANCH=$(git symbolic-ref --short HEAD)
PP_PEER=$(git commit-tree -p "$PP_LAST" -m "PP peer" "$PP_LAST^{tree}")
PP_WORKTREES=$(git worktree list | wc -l | tr -d ' ')
# The check stands in for a parallel session, landing on the branch and recording its own pause
printf '#!/bin/sh\ngit update-ref refs/heads/%s %s\nprintf "operation=edit\\nworktree=/nonexistent/peer\\n" > "%s"\n' \
	"$PP_BRANCH" "$PP_PEER" "$PP_SF" > "$TMP/pp-land.sh" && chmod +x "$TMP/pp-land.sh"
_ST_RUN --move="$PP_LAST" --before="$PP_FIRST" --verify="$TMP/pp-land.sh"
_ST_EQ "the landing is refused" "$RC" "1"
_ST_OUT_HAS "as the branch moved" 'moved during reorder'
_ST_EQ "and its worktree goes" "$(git worktree list | wc -l | tr -d ' ')" "$PP_WORKTREES"
_ST_EQ "the parallel run's pause stands" "$(sed -n 2p "$PP_SF")" "worktree=/nonexistent/peer"
rm -f "$PP_SF"
git update-ref "refs/heads/$PP_BRANCH" "$PP_LAST"
