_ST_SCENARIO "\e[1;96m[47] linking gitignored paths into a pause worktree\e[0m"
git reset -q --hard
printf 'wl one\n' > wl.txt && git add wl.txt && git commit -qm "WL one"
printf 'wl two\n' > wl.txt && git add wl.txt && git commit -qm "WL two"
mkdir -p node_modules/dep && printf 'installed\n' > node_modules/dep/index.js
_ST_RUN HEAD~1
local WL_WT=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
_ST_CHECK "nothing is linked without the config" sh -c "test ! -e '$WL_WT/node_modules'"
_ST_RUN --abort

printf 'node_modules\n' > .gitignore && git add .gitignore && git commit -qm "WL ignore"
git config --add edit.worktreeLink node_modules
# Target `HEAD`, not `HEAD~1:` the worktree checks out the commit being edited,
# so its `.gitignore` is the one that decides whether the link is covered
_ST_RUN HEAD
WL_WT=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
_ST_OUT_HAS "the link is reported" 'Linked into the worktree'
_ST_CHECK "and resolves to the origin's copy" \
	sh -c "test -f '$WL_WT/node_modules/dep/index.js'"
_ST_CHECK "as a symlink, not a copy" sh -c "test -L '$WL_WT/node_modules'"
_ST_OUT_LACKS "an ignored path draws no notice" 'Not linking'
_ST_RUN --abort

# A directory pattern does not match the symlink standing in for it, so the link lands
# untracked where the directory was ignored and the amend stages the worktree wholesale
# Not creating it is the whole remedy, since an ignored link can never be staged
printf 'node_modules/\n' > .gitignore && git add .gitignore && git commit -qm "WL slash"
_ST_RUN HEAD
_ST_OUT_HAS "a trailing-slash pattern is called out" 'Not linking'
_ST_OUT_HAS "with the one-character remedy" 'Drop the trailing slash'
local WL_WT2=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
_ST_CHECK "and no link was created at all" \
	sh -c "test ! -e '$WL_WT2/node_modules'"
printf 'wl edited\n' > "${WL_WT2:-$ST_NO_WT}/wl.txt"
_ST_RUN --continue
_ST_CHECK "so nothing about it reaches the commit" \
	sh -c "! git show HEAD --stat --format= | grep -q node_modules"
_ST_CHECK "while the real edit landed" \
	sh -c "git show HEAD:wl.txt | grep -qx 'wl edited'"
_ST_RUN --undo

# A nested path needs its parent created, or the link silently never happens
git config --unset-all edit.worktreeLink
mkdir -p vendor/deps && printf 'dep\n' > vendor/deps/lib.js
printf 'node_modules\nvendor/deps\n' > .gitignore && git add .gitignore && git commit -qm "WL nested ignore"
git config --add edit.worktreeLink vendor/deps
_ST_RUN HEAD
local WL_WT3=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
_ST_CHECK "a nested path is linked, not silently skipped" \
	sh -c "test -f '$WL_WT3/vendor/deps/lib.js'"
_ST_OUT_LACKS "and reports no failure" 'Could not link'
_ST_RUN --abort

# A value added mid-pause reaches the already-created worktree on resume –
# links are made at worktree setup, so --continue re-ensures them
mkdir -p node_modules/dep && printf 'installed\n' > node_modules/dep/index.js
_ST_RUN HEAD
local WL_WT4=$(echo "$OUT" | sed -n 's/.*paused – edit [^ ]* in \([^;]*\);.*/\1/p')
_ST_CHECK "the later addition is not linked at setup" sh -c "test ! -e '$WL_WT4/node_modules'"
git config --add edit.worktreeLink node_modules
printf 'wl relinked\n' > "${WL_WT4:-$ST_NO_WT}/wl.txt"
_ST_RUN --continue
_ST_OUT_HAS "the mid-pause addition is linked on resume" 'Linked into the worktree: node_modules'
_ST_CHECK "and stays out of the amended commit" \
	sh -c "! git show HEAD --stat --format= | grep -q node_modules"
_ST_CHECK "while the edit landed" sh -c "git show HEAD:wl.txt | grep -qx 'wl relinked'"
_ST_RUN --undo
rm -rf vendor

# The auto-isolated worktree (non-interactive drop/squash/edit) links too –
# proven through a verify command needing the linked path, since the check
# runs in that worktree before anything applies
git config edit.verifyCmd 'test -e node_modules/dep/index.js'
printf 'wl3\n' > wl3.txt && git add wl3.txt && git commit -qm "WL three"
printf 'wl4\n' > wl4.txt && git add wl4.txt && git commit -qm "WL four"
_ST_RUN -d HEAD~1 -y
_ST_EQ "the drop applies with the gate on" "$RC" "0"
_ST_OUT_HAS "after linking into the auto-isolated worktree" 'Linked into the worktree: node_modules'
_ST_OUT_HAS "and verifying there" 'Verified 1 commit'

# The reused --dir branch (reset --hard sync) must link too – one run to
# create the worktree, strip the link, and the next has to restore it
local WL_DIR=$TMP/wl-reuse
# Disposable targets, so neither drop consumes the commit carrying the
# bare ignore pattern the link depends on
printf 'wl5\n' > wl5.txt && git add wl5.txt && git commit -qm "WL five"
printf 'wl6\n' > wl6.txt && git add wl6.txt && git commit -qm "WL six"
_ST_RUN -d HEAD~1 -y --dir="$WL_DIR"
_ST_EQ "an explicit-dir drop applies" "$RC" "0"
rm "$WL_DIR/node_modules"
_ST_RUN -d HEAD~1 -y --dir="$WL_DIR"
_ST_EQ "the reused-worktree drop applies" "$RC" "0"
_ST_OUT_HAS "relinking what was removed on the reuse branch" 'Linked into the worktree: node_modules'
_ST_OUT_HAS "and verifying in the reused worktree" 'Verified 1 commit'
git worktree remove --force "$WL_DIR" 2>/dev/null
git config --unset edit.verifyCmd

git config --unset-all edit.worktreeLink
rm -rf node_modules
git reset -q --hard
