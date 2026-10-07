_ST_SCENARIO "\e[1;96m[50] SHA-keyed metadata across a plumbing rewrite\e[0m"
git reset -q --hard
git config notes.rewriteRef 'refs/notes/*'
printf 'nt one\n' > nt.txt && git add nt.txt && git commit -qm "NT one"
printf 'nt two\n' > nt.txt && git add nt.txt && git commit -qm "NT two"
printf 'nt three\n' > nt.txt && git add nt.txt && git commit -qm "NT three"
git notes --ref=ge-test add -m "meta on the target" HEAD~2
git notes --ref=ge-test add -m "meta on a descendant" HEAD
local NT_REACH='git log --format=%H | while read s; do git notes --ref=ge-test show $s 2>/dev/null; done | grep -c .'
_ST_EQ "both notes reachable to begin with" "$(eval $NT_REACH)" "2"
# `commit-tree` runs none of the machinery a rebase does, so these modes used
# to orphan notes silently while `-d` and `--move` carried them
_ST_RUN -M --text='NT one reworded' HEAD~2
_ST_EQ "a plumbing reword carries them to the rebuilt commits" "$(eval $NT_REACH)" "2"
_ST_RUN -S HEAD~1 HEAD
_ST_EQ "a plumbing squash carries them too" "$(eval $NT_REACH)" "2"

# The hook git fires for its own rewrites, with the same old->new map
printf 'nt four\n' > nt.txt && git add nt.txt && git commit -qm "NT four"
printf 'nt five\n' > nt.txt && git add nt.txt && git commit -qm "NT five"
local NT_LOG=$(git rev-parse --git-path ge-rewrite.log)
local NT_HOOK=$(git rev-parse --git-path hooks/post-rewrite)
print -r -- '#!/bin/sh' > "$NT_HOOK"
print -r -- "printf '%s\\n' \"\$1\" > '$NT_LOG'; cat >> '$NT_LOG'" >> "$NT_HOOK"
chmod +x "$NT_HOOK"
rm -f "$NT_LOG"
_ST_RUN -M --text='NT three reworded' HEAD~2
_ST_EQ "the hook is told which command rewrote" "$(head -1 "$NT_LOG" 2>/dev/null)" "rebase"
_ST_EQ "and gets one old->new pair per rebuilt commit" \
	"$(tail -n +2 "$NT_LOG" 2>/dev/null | grep -c '^[0-9a-f]\{40,64\} [0-9a-f]\{40,64\}$')" "3"
rm -f "$NT_HOOK" "$NT_LOG"

# A fold that also rewords is two rewrites back to back, and the first one's
# map names commits the second rebuilds – held to the CAS it would copy onto
# intermediates nothing can reach, stranding the note it was meant to carry
printf 'nt six\n' > nt.txt && git add nt.txt && git commit -qm "NT six"
printf 'nt seven\n' > nt.txt && git add nt.txt && git commit -qm "NT seven"
git notes --ref=ge-fold add -m "meta on the fold target" HEAD~1
printf 'nt staged\n' > nt2.txt && git add nt2.txt
_ST_RUN --amend-into=HEAD~1 --text='NT six, folded and reworded'
_ST_EQ "the fold settles" "$RC" "0"
_ST_EQ "a fold that also rewords keeps its note on live history" \
	"$(git log --format=%H | while read s; do git notes --ref=ge-fold show $s 2>/dev/null; done | grep -c .)" "1"

# A repo that configures none of this must be unaffected
git config --unset notes.rewriteRef
_ST_RUN -M --text='NT five reworded' HEAD
_ST_EQ "unconfigured repos still succeed" "$RC" "0"
git reset -q --hard

# "Color follows the same rule and also honors `NO_COLOR` and `TERM=dumb`" – a captured run
# proves the pipe case, the other two only structurally, since no TTY is available here
# The cleanup below enumerates worktrees for the temp ones outside `$TMP`, so assert the path
_ST_CHECK "the cleanup can enumerate the scratch repo's worktrees" \
	sh -c "test \$(git -C '$TMP/repo' worktree list --porcelain 2>/dev/null | grep -c '^worktree ') -ge 1"
