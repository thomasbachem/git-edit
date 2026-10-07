# A -C path registered but gone is reclaimed alone, never by a prune
# A prune would drop every vanished worktree's records, a parallel session's reflog with them
_ST_SCENARIO "\e[1;96m[107] a vanished -C worktree is reclaimed alone, other records kept\e[0m"
echo p > pr.txt && git add pr.txt && git commit -qm "PR base"
echo q > pr2.txt && git add pr2.txt && git commit -qm "PR dropped"
git worktree add -q --detach "$TMP/pr-peer" HEAD && rm -rf "$TMP/pr-peer"
git worktree add -q --detach "$TMP/pr-own" HEAD && rm -rf "$TMP/pr-own"
_ST_RUN -d "$(git rev-parse HEAD)" -C="$TMP/pr-own"
_ST_EQ "a run whose -C path vanished still lands" "$RC:$(git log -1 --format=%s)" "0:PR base"
_ST_OUT_HAS "reclaiming that path" 'reclaiming its path'
_ST_CHECK "and leaves a parallel worktree's records alone" test -d "$(git rev-parse --git-common-dir)/worktrees/pr-peer"
git reset -q --hard
git worktree remove --force "$TMP/pr-own"
git worktree prune
