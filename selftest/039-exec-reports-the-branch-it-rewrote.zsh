# --exec names the branch it moved, and reaches the reconcile hint
_ST_SCENARIO "\e[1;96m[39] exec reports the branch it rewrote\e[0m"
git reset -q --hard
echo "xa" > xa.txt && git add xa.txt && git commit -qm "XA base"
echo "xb" > xb.txt && git add xb.txt && git commit -qm "XB to reword"
_ST_RUN --exec -- git commit --amend -m "XB reworded by exec"
_ST_EQ "exec exits 0" "$RC" "0"
_ST_EQ "the reword landed" "$(git log -1 --format=%s)" "XB reworded by exec"
# A multi-arg `[ -n ... ]` here leaked the shell's own usage error into the output
_ST_OUT_LACKS "no raw shell error leaks" 'too many arguments'
_ST_OUT_HAS "names the branch it rewrote" 'Branch.*rewritten'
# A detached `HEAD` is the checkout's own, out of reach of a CAS run in the temp worktree
local XD_BR=$(git symbolic-ref --short HEAD) XD_TIP=$(git rev-parse HEAD)
git checkout -q --detach
_ST_RUN --exec -- git commit --allow-empty -qm "XD on a detached HEAD"
_ST_EQ "exec on a detached HEAD refuses, moving nothing" "$RC:$(git rev-parse HEAD)" "1:$XD_TIP"
_ST_OUT_HAS "saying a branch is needed" 'requires being on a branch'
git checkout -q "$XD_BR"
# Only a content-changing exec reaches the per-path hint – and the hint re-syncs the index
# entries the ref move stranded, but only those still equal to the pre-rewrite tip: a peer's
# staging on a changed path (xd) is left alone and named, a removed path (xe) lingers
# untracked and takes a `clean` rather than a restore
echo "xc" > xc.txt && echo "xd" > xd.txt && echo "xe" > xe.txt && echo "xg" > xg.txt && git add xc.txt xd.txt xe.txt xg.txt && git commit -qm "XC to change"
echo "peer" > xd.txt && git add xd.txt && echo "xd" > xd.txt
_ST_RUN --exec -- sh -c 'echo changed > xc.txt && echo changed > xd.txt && git rm -q xe.txt && git mv xg.txt xh.txt && git add xc.txt xd.txt && git commit -q --amend --no-edit'
_ST_EQ "content-changing exec exits 0" "$RC" "0"
_ST_OUT_HAS "re-syncs the stranded entries" 'Index entries re-synced to the new tip: xc\.txt xe\.txt'
# A rename's source would vanish behind `--name-only`'s rename detection, leaving its entry
# stranded as a staged re-add of the old path
_ST_OUT_HAS "re-syncs both sides of a rename" 'Index entries re-synced to the new tip: .*xg\.txt xh\.txt'
_ST_EQ "the rename's old path is gone from the index" "$(git ls-files -- xg.txt)" ""
_ST_CHECK "the rename's new path has its entry" sh -c "git ls-files --error-unmatch -- xh.txt >/dev/null 2>&1"
_ST_CHECK "stranded entry now matches the new tip" sh -c "git diff --cached --quiet -- xc.txt"
_ST_CHECK "removed path is untracked, not a staged re-add" sh -c "test \"\$(git status --porcelain -uall -- xe.txt)\" = '?? xe.txt'"
_ST_OUT_HAS "names the entry it left alone" "left alone.*xd\.txt"
_ST_EQ "peer staging survives" "$(git show :xd.txt)" "peer"
_ST_OUT_HAS "names the paths to reconcile" 'xc\.txt'
_ST_OUT_HAS "prescribes a worktree-only restore" 'restore --source=HEAD --worktree -- .*xc\.txt'
_ST_OUT_HAS "prescribes a clean for the removed path" 'git clean -f -- xe\.txt'
_ST_OUT_LACKS "the restore never names the index" 'restore --source=HEAD --staged'
git reset -q --hard && git clean -qf -- xe.txt
# The route the rules steer every session onto: the change made in the checkout first, then
# landed through exec – the re-sync leaves nothing to reconcile, and the hint says so
echo "xi" > xi.txt && git add xi.txt && git commit -qm "XI to change"
echo "changed" > xi.txt
_ST_RUN --exec -- sh -c 'echo changed > xi.txt && git add xi.txt && git commit -q --amend --no-edit'
_ST_EQ "exec over a checkout already carrying the change exits 0" "$RC" "0"
_ST_OUT_HAS "reports the checkout as current, the branch as rewritten" 'rewritten – index re-synced, your checkout is current'
_ST_OUT_LACKS "and offers no restore" 'Reconcile those paths'
_ST_CHECK "nothing left staged or modified" sh -c "test -z \"\$(git status --porcelain -- xi.txt)\""
# The same change staged first, a rename too – entries already as the new tip has them are in
# sync, never named as differing
echo "xs" > xs.txt && echo "xt" > xt.txt && git add xs.txt xt.txt && git commit -qm "XS to change, XT to move"
echo "changed" > xs.txt && git add xs.txt && git mv xt.txt xu.txt
_ST_RUN --exec -- sh -c 'echo changed > xs.txt && git mv xt.txt xu.txt && git add xs.txt && git commit -q --amend --no-edit'
_ST_EQ "exec over a checkout that staged the change exits 0" "$RC" "0"
_ST_OUT_LACKS "names none of those entries as left alone" 'Index entries left alone'
_ST_OUT_HAS "and reports the checkout as current" 'index re-synced, your checkout is current'
_ST_CHECK "nothing left staged or modified there" sh -c "test -z \"\$(git status --porcelain -- xs.txt xt.txt xu.txt)\""
# A conflicted path is mid-merge – never reset, its stages gone, and never taken for in sync
printf '100644 %s 1\txv.txt\n100644 %s 2\txv.txt\n' "$(echo one | git hash-object -w --stdin)" "$(echo two | git hash-object -w --stdin)" | git update-index --index-info
printf '0 %s\txs.txt\n100644 %s 1\txs.txt\n100644 %s 2\txs.txt\n' "$(git rev-parse HEAD:xs.txt)" "$(echo one | git hash-object -w --stdin)" "$(echo two | git hash-object -w --stdin)" | git update-index --index-info
_ST_RUN --exec -- sh -c 'echo xv > xv.txt && git rm -q xs.txt && git add xv.txt && git commit -q --amend --no-edit'
_ST_EQ "exec over conflicted entries exits 0" "$RC" "0"
_ST_OUT_HAS "names a conflicted path the rewrite added as left alone" 'Index entries left alone.*xv\.txt'
_ST_OUT_HAS "and one it removed" 'Index entries left alone.*xs\.txt'
_ST_EQ "their stages survive" "$(git ls-files -u -- xv.txt xs.txt | wc -l | tr -d ' ')" "4"
git reset -q --hard
# A checkout carrying uncommitted edits in a changed path holds neither tip's content, so
# calling it stale is false and the restore would discard those lines – it is named as left
# alone instead. The everyday shape here: a shared checkout where the file always has WIP
echo "xk" > xk.txt && git add xk.txt && git commit -qm "XK to change"
printf 'xk\nlocal wip\n' > xk.txt
_ST_RUN --exec -- sh -c 'echo changed > xk.txt && git add xk.txt && git commit -q --amend --no-edit'
_ST_EQ "exec over a checkout with its own edits exits 0" "$RC" "0"
_ST_OUT_LACKS "never calls those edits pre-rewrite content" 'still holds the pre-rewrite content'
_ST_OUT_HAS "names the worktree file it left alone" 'Worktree files left alone.*xk\.txt'
_ST_OUT_LACKS "and prescribes no restore that would discard them" 'Reconcile those paths'
_ST_OUT_LACKS "nor claims the checkout is current" 'your checkout is current'
_ST_CHECK "the uncommitted edit survives" sh -c "test \"\$(sed -n 2p xk.txt)\" = 'local wip'"
git reset -q --hard
# Both kinds in one rewrite: the restore has to name the stale path and leave the edited one
# out, or a single reconcile takes work the rewrite never asked about
echo "xm" > xm.txt && echo "xn" > xn.txt && git add xm.txt xn.txt && git commit -qm "XM/XN to change"
printf 'xm\nlocal wip\n' > xm.txt
_ST_RUN --exec -- sh -c 'echo changed > xm.txt && echo changed > xn.txt && git add xm.txt xn.txt && git commit -q --amend --no-edit'
_ST_EQ "exec touching a stale and an edited path exits 0" "$RC" "0"
_ST_OUT_HAS "names the edited path as left alone" 'Worktree files left alone.*xm\.txt'
_ST_OUT_HAS "the restore names the stale path" 'Reconcile those paths.*xn\.txt'
_ST_OUT_LACKS "and never the edited one" 'Reconcile those paths.*xm\.txt'
_ST_CHECK "the edit survives the run" sh -c "test \"\$(sed -n 2p xm.txt)\" = 'local wip'"
git reset -q --hard
# A removed path goes untracked, so its reconcile is a `git clean` – naming one whose worktree
# copy carries work deletes it outright, with no blob anywhere to restore it from
echo "xp" > xp.txt && echo "xq" > xq.txt && echo "xr" > xr.txt
git add xp.txt xq.txt xr.txt && git commit -qm "XP/XQ to remove, XR to keep"
printf 'xq\nlocal wip\n' > xq.txt
_ST_RUN --exec -- sh -c 'git rm -q xp.txt xq.txt && git commit -q --amend --no-edit'
_ST_EQ "exec removing a leftover and a worked-on path exits 0" "$RC" "0"
_ST_OUT_HAS "the clean names the untouched leftover" 'git clean -f -- .*xp\.txt'
_ST_OUT_LACKS "and never the one carrying work" 'git clean -f -- .*xq\.txt'
_ST_OUT_HAS "which is named as left alone instead" 'Worktree files left alone.*xq\.txt'
_ST_CHECK "that work survives the run" sh -c "test \"\$(sed -n 2p xq.txt)\" = 'local wip'"
git reset -q --hard && git clean -qf -- xp.txt xq.txt
# A peer holding the index lock keeps the entries stranded – named as locked, not as differing
echo "xj" > xj.txt && git add xj.txt && git commit -qm "XJ to change"
touch .git/index.lock
_ST_RUN --exec -- sh -c 'echo changed > xj.txt && git add xj.txt && git commit -q --amend --no-edit'
rm -f .git/index.lock
_ST_EQ "exec under a locked index still lands" "$RC" "0"
_ST_OUT_HAS "names the lock" 'Index locked'
_ST_OUT_LACKS "and does not call the entry a differing one" 'Index entries left alone'
_ST_CHECK "the entry is still stranded" sh -c "! git diff --cached --quiet -- xj.txt"
git reset -q --hard
# The lock is taken where the index lives – a hard link from a temp dir on another filesystem,
# as Linux's tmpfs `/tmp` is, failed every re-sync as "locked"
mkdir -p "$TMP/shim-noln"
printf '#!/bin/sh\necho "ln: Cross-device link" >&2\nexit 1\n' > "$TMP/shim-noln/ln"
chmod +x "$TMP/shim-noln/ln"
echo "xln" > xln.txt && git add xln.txt && git commit -qm "XLN to change"
PATH="$TMP/shim-noln:$PATH" _ST_RUN --exec -- sh -c 'echo changed > xln.txt && git add xln.txt && git commit -q --amend --no-edit'
_ST_EQ "an exec lands where no hard link can be made" "$RC:$(git show HEAD:xln.txt)" "0:changed"
_ST_OUT_LACKS "and still re-syncs" 'Index locked'
_ST_CHECK "leaving nothing stranded" git diff --cached --quiet -- xln.txt
git reset -q --hard
# An entry staged apart from both tips stays put, so no headline may call the index re-synced
echo xp > xp.txt && git add xp.txt && git commit -qm "XP base"
echo peer > xp.txt && git add xp.txt && echo new > xp.txt
_ST_RUN --exec -- sh -c 'echo new > xp.txt && git commit -qam "XP lands"'
_ST_OUT_HAS "an entry staged apart from both tips is named" 'left alone.*xp\.txt'
_ST_OUT_LACKS "under no headline calling the index re-synced" 'your checkout is current'
git reset -q -- xp.txt
# A hint's paths run from the checkout's top – pasted in a subdirectory as printed, `xs.txt`
# would name the subdirectory's own file
mkdir -p xsub && echo xs > xs.txt && echo own > xsub/xs.txt && git add xs.txt xsub/xs.txt && git commit -qm "XS base"
cd xsub
_ST_RUN --exec -- sh -c 'echo landed > xs.txt && git commit -qam "XS lands"'
cd "$TMP/repo"
_ST_OUT_HAS "a hint printed in a subdirectory goes to the top first" 'Reconcile those paths.*cd .* && git restore --source=HEAD --worktree -- xs\.txt'
git restore --source=HEAD --worktree -- xs.txt
