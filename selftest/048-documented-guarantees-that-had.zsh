_ST_SCENARIO "\e[1;96m[48] documented guarantees that had no assertion\e[0m"
git reset -q --hard
printf 'dg one\n' > dg.txt && git add dg.txt && git commit -qm "DG one"
printf 'dg two\n' > dg.txt && git add dg.txt && git commit -qm "DG two"
printf 'dg three\n' > dg.txt && git add dg.txt && git commit -qm "DG three"

# "no checkout, no stash, no rebase – the working tree is physically
# untouched (file inodes and mtimes preserved)"
local -a STATFMT
if stat -f '%i' . >/dev/null 2>&1; then
	STATFMT=(-f '%i %m')
else
	STATFMT=(-c '%i %Y')
fi
local DG_BEFORE=$(stat "${STATFMT[@]}" dg.txt 2>/dev/null)
_ST_RUN -M --text='DG two reworded' HEAD~1
_ST_EQ "reword leaves the file's inode and mtime alone" \
	"$(stat "${STATFMT[@]}" dg.txt 2>/dev/null)" "$DG_BEFORE"

# "Every completed operation is attributed in the ref's own reflog"
_ST_CHECK "the ref's reflog attributes the operation" \
	sh -c "git reflog -1 --format=%gs | grep -q '^git edit: reword '"

# "Set `GIT_EDIT_NO_RESOLVE=1` to disable resolution entirely and have every unreachable
# commit refused" – the sha has to be captured before the rewrite that orphans it, since
# taken after it is simply current
printf 'st one\n' > st.txt && git add st.txt && git commit -qm "ST one"
printf 'st two\n' > st.txt && git add st.txt && git commit -qm "ST two"
local ST_TARGET=$(git rev-parse HEAD)
printf 'st three\n' > st.txt && git add st.txt && git commit -qm "ST three"
_ST_RUN -M --text='ST two reworded' "$ST_TARGET"
_ST_CHECK "the sha really is orphaned now" \
	sh -c "! git merge-base --is-ancestor $ST_TARGET HEAD 2>/dev/null"
_ST_RUN -M --text='ST two v3' "$ST_TARGET"
_ST_OUT_HAS "a stale sha resolves by default" 'was rewritten'
_ST_RUN --undo
OUT=$(GIT_EDIT_NO_RESOLVE=1 GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text='ST two v3' "$ST_TARGET" </dev/null 2>&1)
RC=$?
_ST_EQ "GIT_EDIT_NO_RESOLVE refuses it instead" "$RC" "1"
_ST_OUT_LACKS "and resolves nothing" 'using its current identity'

# "`-C` is enabled automatically for the modes that would otherwise touch the main working
# tree", and the plumbing modes are left alone – one file per commit, so a drop has
# nothing to conflict over and cannot pause
printf 'ai1\n' > ai1.txt && git add ai1.txt && git commit -qm "AI one"
printf 'ai2\n' > ai2.txt && git add ai2.txt && git commit -qm "AI two"
printf 'ai3\n' > ai3.txt && git add ai3.txt && git commit -qm "AI three"
_ST_RUN -d -y HEAD~1
_ST_EQ "the drop succeeds" "$RC" "0"
_ST_OUT_HAS "a drop runs in a worktree of its own" 'git worktree add --detach .*git-edit-auto-iso'
_ST_RUN --undo
_ST_RUN -M --text='AI three reworded' HEAD
_ST_EQ "a reword lands" "$RC" "0"
_ST_OUT_LACKS "in no worktree, being plumbing" 'git worktree add'
_ST_RUN --undo
_ST_CHECK "and left nothing in flight" \
	sh -c "! test -f \"\$(git rev-parse --git-common-dir)/git-edit-state\""

# "The guard is span-scoped, not repo-scoped: operating above the merge
# stays legal"
local MG_BASE=$(git rev-parse HEAD)
git checkout -q -b dg-side HEAD~1
printf 'dg side\n' > dg-side.txt && git add dg-side.txt && git commit -qm "DG side"
git checkout -q main
git merge -q --no-ff -m "DG merge" dg-side 2>/dev/null
printf 'dg a\n' > dg-a.txt && git add dg-a.txt && git commit -qm "DG above one"
printf 'dg b\n' > dg-b.txt && git add dg-b.txt && git commit -qm "DG above two"
_ST_RUN -d -y HEAD~1
_ST_EQ "a span above a merge stays legal" "$RC" "0"
_ST_RUN --undo
_ST_RUN -d -y "$MG_BASE"
_ST_OUT_HAS "a span containing one is refused" 'contains a merge commit'
git branch -q -D dg-side 2>/dev/null
git reset -q --hard
