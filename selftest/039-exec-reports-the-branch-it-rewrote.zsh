# --exec names the branch it moved, and brings the checkout along
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
# A content-changing exec brings the checkout along path by path: a file still as before takes what
# landed, file and entry, a removed one goes, a rename moves, and a peer's staging on a changed
# path (xd) is left as it is and named
echo "xc" > xc.txt && echo "xd" > xd.txt && echo "xe" > xe.txt && echo "xg" > xg.txt && git add xc.txt xd.txt xe.txt xg.txt && git commit -qm "XC to change"
echo "peer" > xd.txt && git add xd.txt && echo "xd" > xd.txt
_ST_RUN --exec -- sh -c 'echo changed > xc.txt && echo changed > xd.txt && git rm -q xe.txt && git mv xg.txt xh.txt && git add xc.txt xd.txt && git commit -q --amend --no-edit'
_ST_EQ "content-changing exec exits 0" "$RC" "0"
_ST_OUT_HAS "brings the changed files along" 'Your checkout came along – now as they landed: .*xc\.txt'
_ST_EQ "they take what landed" "$(<xc.txt):$(<xh.txt):$([ -e xe.txt ] || echo gone):$([ -e xg.txt ] || echo gone)" "changed:xg:gone:gone"
_ST_EQ "the rename's old path is gone from the index" "$(git ls-files -- xg.txt)" ""
_ST_CHECK "the rename's new path has its entry" sh -c "git ls-files --error-unmatch -- xh.txt >/dev/null 2>&1"
_ST_CHECK "stranded entry now matches the new tip" sh -c "git diff --cached --quiet -- xc.txt"
_ST_EQ "removed path is gone, not a staged re-add" "$(git status --porcelain -uall -- xe.txt)" ""
_ST_OUT_HAS "names the path it left as it was" "Left as they were.*xd\.txt"
_ST_EQ "peer staging survives" "$(git show :xd.txt)" "peer"
_ST_OUT_LACKS "prescribes no restore or clean" 'git restore \(--source\|--worktree\|-- \)\|git clean'
git reset -q --hard
# The route the rules steer every session onto: the change made in the checkout first, then
# landed through exec – nothing is left to bring along
echo "xi" > xi.txt && git add xi.txt && git commit -qm "XI to change"
echo "changed" > xi.txt
_ST_RUN --exec -- sh -c 'echo changed > xi.txt && git add xi.txt && git commit -q --amend --no-edit'
_ST_EQ "exec over a checkout already carrying the change exits 0" "$RC" "0"
_ST_OUT_HAS "reports the branch as rewritten" 'Branch .* rewritten\.$'
_ST_OUT_LACKS "and names no file" 'came along\|Left as they were'
_ST_CHECK "nothing left staged or modified" sh -c "test -z \"\$(git status --porcelain -- xi.txt)\""
# The same change staged first, a rename too – entries already as the new tip has them are in
# sync, never named as differing
echo "xs" > xs.txt && echo "xt" > xt.txt && git add xs.txt xt.txt && git commit -qm "XS to change, XT to move"
echo "changed" > xs.txt && git add xs.txt && git mv xt.txt xu.txt
_ST_RUN --exec -- sh -c 'echo changed > xs.txt && git mv xt.txt xu.txt && git add xs.txt && git commit -q --amend --no-edit'
_ST_EQ "exec over a checkout that staged the change exits 0" "$RC" "0"
_ST_OUT_LACKS "names none of those entries as left alone" 'Left as they were'
_ST_CHECK "nothing left staged or modified there" sh -c "test -z \"\$(git status --porcelain -- xs.txt xt.txt xu.txt)\""
# A conflicted path is mid-merge – the checkout not brought along, its stages kept, and the
# entries re-synced none but those still as before
printf '100644 %s 1\txv.txt\n100644 %s 2\txv.txt\n' "$(echo one | git hash-object -w --stdin)" "$(echo two | git hash-object -w --stdin)" | git update-index --index-info
printf '0 %s\txs.txt\n100644 %s 1\txs.txt\n100644 %s 2\txs.txt\n' "$(git rev-parse HEAD:xs.txt)" "$(echo one | git hash-object -w --stdin)" "$(echo two | git hash-object -w --stdin)" | git update-index --index-info
_ST_RUN --exec -- sh -c 'echo xv > xv.txt && git rm -q xs.txt && git add xv.txt && git commit -q --amend --no-edit'
_ST_EQ "exec over conflicted entries exits 0" "$RC" "0"
_ST_OUT_HAS "names a conflicted path the rewrite added as left alone" 'Index entries left alone.*xv\.txt'
_ST_OUT_HAS "and one it removed" 'Index entries left alone.*xs\.txt'
_ST_EQ "their stages survive" "$(git ls-files -u -- xv.txt xs.txt | wc -l | tr -d ' ')" "4"
_ST_OUT_HAS "naming why the checkout was not brought along" 'Your checkout was not brought along – it is halfway through a conflict'
git reset -q --hard
# A checkout carrying uncommitted edits in a changed path keeps them, merged onto what landed or,
# where they conflict, left as they were – the everyday shape of a shared checkout
echo "xk" > xk.txt && git add xk.txt && git commit -qm "XK to change"
printf 'xk\nlocal wip\n' > xk.txt
_ST_RUN --exec -- sh -c 'echo changed > xk.txt && git add xk.txt && git commit -q --amend --no-edit'
_ST_EQ "exec over a checkout with its own edits exits 0" "$RC" "0"
_ST_OUT_HAS "names the file with its edits" 'Uncommitted edits \(merged onto\|conflict with\) what landed.*xk\.txt'
_ST_OUT_LACKS "and prescribes no restore that would discard them" 'git restore \(--source\|--worktree\|-- \)'
_ST_CHECK "the uncommitted edit survives" sh -c "test \"\$(sed -n 2p xk.txt)\" = 'local wip'"
git reset -q --hard
# Both kinds in one rewrite: the stale path comes along, the edited one keeps its edits
echo "xm" > xm.txt && echo "xn" > xn.txt && git add xm.txt xn.txt && git commit -qm "XM/XN to change"
printf 'xm\nlocal wip\n' > xm.txt
_ST_RUN --exec -- sh -c 'echo changed > xm.txt && echo changed > xn.txt && git add xm.txt xn.txt && git commit -q --amend --no-edit'
_ST_EQ "exec touching a stale and an edited path exits 0" "$RC" "0"
_ST_EQ "the stale path came along" "$(<xn.txt)" "changed"
_ST_OUT_LACKS "never as come along the edited one" 'came along.*xm\.txt'
_ST_CHECK "the edit survives the run" sh -c "test \"\$(sed -n 2p xm.txt)\" = 'local wip'"
git reset -q --hard
# A removed path still as before goes, one whose copy carries work stays untracked
echo "xp" > xp.txt && echo "xq" > xq.txt && echo "xr" > xr.txt
git add xp.txt xq.txt xr.txt && git commit -qm "XP/XQ to remove, XR to keep"
printf 'xq\nlocal wip\n' > xq.txt
_ST_RUN --exec -- sh -c 'git rm -q xp.txt xq.txt && git commit -q --amend --no-edit'
_ST_EQ "exec removing a leftover and a worked-on path exits 0" "$RC" "0"
_ST_EQ "the untouched leftover goes" "$([ -e xp.txt ] || echo gone)" "gone"
_ST_OUT_HAS "named as taken out" 'Taken out of your checkout with the rewrite: xp\.txt'
_ST_OUT_HAS "the one carrying work is named as kept" 'your edits to them stay, untracked: xq\.txt'
_ST_CHECK "that work survives the run" sh -c "test \"\$(sed -n 2p xq.txt)\" = 'local wip'"
git reset -q --hard && git clean -qf -- xp.txt xq.txt
# A peer holding the index lock keeps the entries stranded – named as locked, not as differing
echo "xj" > xj.txt && git add xj.txt && git commit -qm "XJ to change"
touch .git/index.lock
_ST_RUN --exec -- sh -c 'echo changed > xj.txt && git add xj.txt && git commit -q --amend --no-edit'
rm -f .git/index.lock
_ST_EQ "exec under a locked index still lands" "$RC" "0"
_ST_OUT_HAS "names the lock" 'Index locked'
_ST_OUT_HAS "and the carry for once it is free" '^Once that is done, bring your checkout along.*git edit --carry='
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
_ST_OUT_HAS "an entry staged apart from both tips is named" 'Left as they were.*xp\.txt'
_ST_EQ "and stays staged" "$(git show :xp.txt)" "peer"
git reset -q -- xp.txt
# Run in a subdirectory, the checkout's top comes along, the subdirectory's own file left as it is
mkdir -p xsub && echo xs > xs.txt && echo own > xsub/xs.txt && git add xs.txt xsub/xs.txt && git commit -qm "XS base"
cd xsub
_ST_RUN --exec -- sh -c 'echo landed > ../xs.txt && git commit -qam "XS lands"'
cd "$TMP/repo"
_ST_EQ "a run in a subdirectory brings the top along" "$(<xs.txt):$(<xsub/xs.txt)" "landed:own"
