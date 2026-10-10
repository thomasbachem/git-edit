# What an agent reads names a step that works for it – a printed command runs as printed from
# where it is pasted, every mode refuses outside a repository or a cwd that is gone, `--status`
# names whose a damaged or orphaned pause is and what clears it, owners are told apart by the
# label as given, and a new `-C` path a late refusal stops is taken back out
_ST_SCENARIO "\e[1;96m[175] the agent surface names a step that works, owners by their label as given\e[0m"
local AS_TOP AS_WT AS_CMD AS_SF AS_D AS_REAL AS_ARG
local -i AS_RC

# An `--onto` refusal over uncommitted work names the commit from the top – `--commit` reads its
# paths from where it runs, so from a subdirectory it once committed another session's file
_ST_PZ_NEW as2
mkdir -p sub/sub
_ST_PZ_C sub/x.txt x0 "AS2 base"
git branch up
_ST_PZ_C f.txt f "AS2 feat"
git checkout -q up
_ST_PZ_C sub/x.txt x1 "AS2 up"
git checkout -q main
print -r -- xLOCAL > sub/x.txt
print -r -- peer > sub/sub/x.txt
AS_TOP=$PWD
cd sub
_ST_RUN --onto=up
_ST_EQ "an --onto over uncommitted work from a subdirectory refuses" "$RC" "1"
_ST_OUT_HAS "its commit command going to the top first" "yours: cd .* && git edit --commit --text '<subject>' -- sub/x.txt"
AS_CMD=$(print -r -- "$OUT" | sed -n 's/.*– yours: \(.*\); another session.*/\1/p' | head -1)
AS_CMD=${AS_CMD//<subject>/AS2 local}
AS_CMD=${AS_CMD/git edit/${(q)SELF}}
( export GIT_EDIT_NO_AUTO_OPEN=1; eval "$AS_CMD" ) </dev/null >/dev/null 2>&1
_ST_EQ "which, run there as printed, commits the blocking file and nothing else" "$(git log -1 --format=%s):$(git diff-tree --no-commit-id --name-only -r HEAD)" "AS2 local:sub/x.txt"
cd "$AS_TOP"

# Outside a repository every mode refuses, saying so, where each answered as for an empty one
mkdir -p "$TMP/as3-outside"
cd "$TMP/as3-outside"
for AS_ARG in --status --undo --continue; do
	GIT_CEILING_DIRECTORIES=$TMP _ST_RUN $AS_ARG
	_ST_EQ "$AS_ARG outside a repository refuses, saying so" "$RC:${${(M)OUT:#*Not inside a git repository*}:+named}" "1:named"
done
GIT_CEILING_DIRECTORIES=$TMP _ST_RUN --version
_ST_EQ "while --version still answers there" "$RC" "0"
# And so does a run from a cwd that is gone – a pause worktree its own resume cleared
_ST_PZ_NEW as3
_ST_PZ_C f.txt $'a\nb\nc' "AS3 A" && _ST_PZ_C f.txt $'a\nB\nc' "AS3 B" && _ST_PZ_C f.txt $'a\nB2\nc' "AS3 C" && _ST_PZ_C g.txt g "AS3 G"
AS_TOP=$PWD
_ST_RUN -d -y HEAD~2
AS_WT=$(_ST_PZ_WT)
cd "${AS_WT:-$ST_NO_WT}"
_ST_RESOLVE . f.txt $'a\nB2\nc'
_ST_RUN --continue
_ST_EQ "a resume run inside its pause worktree lands" "$RC" "0"
_ST_RUN --undo
_ST_EQ "an undo from that cwd, gone with the worktree, refuses saying so" "$RC:${${(M)OUT:#*current directory is gone*}:+named}" "1:named"
cd "$AS_TOP"
_ST_RUN --undo
_ST_EQ "while one from the checkout takes the run back" "$RC:$(git log -1 --format=%s)" "0:AS3 G"

# A state file cut short, naming neither caller nor operation, is reported as the guards treat it
_ST_PZ_NEW as4
_ST_PZ_C f.txt $'a\nb\nc' "AS4 A" && _ST_PZ_C f.txt $'a\nB\nc' "AS4 B" && _ST_PZ_C f.txt $'a\nB2\nc' "AS4 C"
_ST_RUN -d -y HEAD~1
AS_SF=$PWD/.git/git-edit-state
grep '^worktree=' "$AS_SF" > "$AS_SF.cut" && mv "$AS_SF.cut" "$AS_SF"
GIT_EDIT_ACTOR=bot _ST_RUN --status
_ST_OUT_HAS "--status tells a labeled caller a pause cut short is not its own" "^git-edit: paused – a pause with no operation on record is an unknown caller's, not yours"
_ST_OUT_LACKS "never to resolve and continue it" 'Resolve there'
_ST_RUN --status
_ST_EQ "an unlabeled caller hearing that nothing resumes it" "$RC:${${(M)OUT:#*nothing can resume it*}:+named}" "1:named"
_ST_OUT_HAS "and that --abort clears it" "Clear it with 'git edit --abort'"
_ST_RUN --continue
_ST_OUT_HAS "as a resume of it says" "^git-edit: error – The pause records no operation this version knows"
GIT_EDIT_ACTOR=bot _ST_RUN --abort
_ST_OUT_HAS "a labeled abort it refuses names the override that clears it" "git edit --abort --allow-other-actor"
_ST_OUT_LACKS "not a status that shows no branch" 'shows the branch'
GIT_EDIT_ACTOR=bot _ST_RUN --abort --allow-other-actor
_ST_EQ "which clears it" "$RC:$([ -f "$AS_SF" ] && echo kept)" "0:"

# Labels mapping alike stay two callers – ownership goes by the label as given
_ST_PZ_NEW as5
_ST_PZ_C f.txt a "AS5 A" && _ST_PZ_C g.txt g "AS5 G"
GIT_EDIT_ACTOR='ci:job/1' _ST_RUN -M --text="AS5 G reworded" HEAD
GIT_EDIT_ACTOR='ci.job.1' _ST_RUN --undo
_ST_EQ "an undo under a label mapping alike refuses the other's run" "$RC:$(git log -1 --format=%s)" "1:AS5 G reworded"
_ST_OUT_HAS "naming both as given" "It ran as \$'ci:job/1', this undo as \$'ci.job.1'"
GIT_EDIT_ACTOR='ci:job/1' _ST_RUN --undo
_ST_EQ "while the label itself takes it back" "$RC:$(git log -1 --format=%s)" "0:AS5 G"
_ST_PZ_C f.txt $'a\nb\nc' "AS5 B" && _ST_PZ_C f.txt $'a\nB\nc' "AS5 C" && _ST_PZ_C f.txt $'a\nB2\nc' "AS5 D"
AS_SF=$PWD/.git/git-edit-state
GIT_EDIT_ACTOR='ci:job/1' _ST_RUN -d -y HEAD~1
GIT_EDIT_ACTOR='ci.job.1' _ST_RUN --abort
_ST_EQ "an abort of a pause under a label mapping alike refuses" "$RC:$([ -f "$AS_SF" ] && echo kept)" "1:kept"
GIT_EDIT_ACTOR='ci.job.1' _ST_RUN --status
_ST_OUT_HAS "--status telling it the pause is not its own" "is \$'ci:job/1''s, not yours"
GIT_EDIT_ACTOR='ci:job/1' _ST_RUN --status
_ST_OUT_HAS "and the label itself to resolve it" 'Resolve there'
# A state file from before the label as given was kept holds the mapped one alone
grep -v '^actor_id=' "$AS_SF" > "$AS_SF.old" && mv "$AS_SF.old" "$AS_SF"
GIT_EDIT_ACTOR='ci:job/1' _ST_RUN --abort
_ST_EQ "one from before, holding the mapped label alone, still aborts under it" "$RC:$([ -f "$AS_SF" ] && echo kept)" "0:"

# A verify pause's inspect command quotes its worktree, a `-C` path with a space in it
_ST_PZ_NEW as6
_ST_PZ_C a.txt a "AS6 A" && _ST_PZ_C b.txt b "AS6 B" && _ST_PZ_C bad bad "AS6 C"
git rm -q bad && git commit -qm "AS6 D"
_ST_PZ_C e.txt e "AS6 E"
AS_D="$TMP/as6 wt dir"
_ST_RUN -C="$AS_D" --verify='test ! -f bad' --verify-span -d -y HEAD~3
AS_CMD=$(print -r -- "$OUT" | sed -n 's/^Inspect the failing state: //p' | head -1)
_ST_OUT_HAS "a verify pause names the commit to inspect" '^Inspect the failing state: '
( eval "$AS_CMD" ) </dev/null >/dev/null 2>&1
AS_RC=$?
_ST_EQ "its command running as printed, the -C path holding a space" "$AS_RC:$(git -C "$AS_D" log -1 --format=%s 2>/dev/null)" "0:AS6 C"
_ST_RUN --abort

# A pause whose worktree is gone is named with its owner, each caller told the step that works
_ST_PZ_NEW as7
_ST_PZ_C f.txt $'a\nb\nc' "AS7 A" && _ST_PZ_C f.txt $'a\nB\nc' "AS7 B" && _ST_PZ_C f.txt $'a\nB2\nc' "AS7 C"
GIT_EDIT_ACTOR=agentA _ST_RUN -d -y HEAD~1
AS_WT=$(_ST_PZ_WT)
mv "${AS_WT:-$ST_NO_WT}" "${AS_WT:-$ST_NO_WT}.away"
GIT_EDIT_ACTOR=agentB _ST_RUN --status
_ST_OUT_HAS "--status on a pause whose worktree is gone names its owner to another label" "is agentA's, not yours"
_ST_OUT_HAS "and the override that clears it" 'git edit --abort --allow-other-actor'
GIT_EDIT_ACTOR=agentA _ST_RUN --status
_ST_OUT_HAS "while the owner is told to abort it" "agentA's – run 'git edit --abort' to clear"
GIT_EDIT_ACTOR=agentA _ST_RUN --abort
_ST_EQ "which clears it" "$RC:$([ -f .git/git-edit-state ] && echo kept)" "0:"

# Messages name what they mean – a bare run's missing commit, a drop as a drop, a `-C` to give
_ST_PZ_NEW as9
_ST_PZ_C f.txt $'a\nb\nc' "AS9 A" && _ST_PZ_C f.txt $'a\nB\nc' "AS9 B" && _ST_PZ_C f.txt $'a\nB2\nc' "AS9 C"
_ST_RUN
_ST_OUT_HAS "a bare git edit names what is missing" '^git-edit: error – Missing <commit> or mode'
_ST_RUN -d -y HEAD~1
_ST_RUN --status
_ST_OUT_HAS "--status names a paused drop as one" '^In-flight operation: drop '
_ST_RUN --skip
_ST_OUT_HAS "as --skip's refusal does" "'drop' has no commit to step over"
_ST_RUN --abort
mkdir -p "$TMP/as9-empty"
_ST_RUN -C="$TMP/as9-empty" -d -y HEAD~1
_ST_OUT_HAS "-C on an existing directory that is no worktree names a path to give instead" 'Name a path that does not exist yet'

# A new `-C` path the late in-flight checks refuse is taken back out – kept only where a pause in it
# holds work, a peer's that took the path while this run waited
_ST_PZ_NEW asc
_ST_PZ_C a.txt a "ASC A" && _ST_PZ_C b.txt b "ASC B" && _ST_PZ_C c.txt c "ASC C"
AS_SF=$PWD/.git/git-edit-state
AS_REAL=${commands[git]}
mkdir -p "$TMP/asc-git"
{
	print -r -- '#!/bin/sh'
	print -r -- "case \" \$* \" in *' worktree add '*) ;; *) exec ${(q)AS_REAL} \"\$@\" ;; esac"
	print -r -- "${(q)AS_REAL} \"\$@\"; rc=\$?"
	print -r -- '[ -e "$ASC_ARM" ] || exit $rc'
	print -r -- 'mv "$ASC_ARM" "$ASC_ARM.done"'
	print -r -- 'printf "actor=\noperation=rebase\nbranch=refs/heads/main\nworktree=%s\n" "$ASC_WT" > "$ASC_SF"'
	print -r -- '[ -z "$ASC_WORK" ] || echo work > "$ASC_WT/peer.txt"'
	print -r -- 'exit $rc'
} > "$TMP/asc-git/git"
chmod +x "$TMP/asc-git/git"
: > "$TMP/asc-arm1"
PATH="$TMP/asc-git:$PATH" ASC_ARM=$TMP/asc-arm1 ASC_SF=$AS_SF ASC_WT=/nonexistent/asc ASC_WORK= _ST_RUN -C="$TMP/asc-new1" -d -y HEAD~1
_ST_EQ "a new -C path refused for a pause recorded elsewhere meanwhile is removed again" "$RC:$([ -e "$TMP/asc-new1" ] && echo kept):$(git worktree list --porcelain | grep -c asc-new1)" "1::0"
mv "$AS_SF" "$TMP/asc-state1"
: > "$TMP/asc-arm2"
PATH="$TMP/asc-git:$PATH" ASC_ARM=$TMP/asc-arm2 ASC_SF=$AS_SF ASC_WT=$TMP/asc-new2 ASC_WORK=1 _ST_RUN -C="$TMP/asc-new2" -d -y HEAD~1
_ST_EQ "while one a peer's pause holds work in is kept" "$RC:$([ -e "$TMP/asc-new2/peer.txt" ] && echo kept)" "1:kept"
mv "$AS_SF" "$TMP/asc-state2"
: > "$TMP/asc-arm3"
PATH="$TMP/asc-git:$PATH" ASC_ARM=$TMP/asc-arm3 ASC_SF=$AS_SF ASC_WT=$TMP/asc-new3 ASC_WORK= _ST_RUN -C="$TMP/asc-new3" -d -y HEAD~1
_ST_EQ "and one a pause names but holding nothing goes" "$RC:$([ -e "$TMP/asc-new3" ] && echo kept)" "1:"
mv "$AS_SF" "$TMP/asc-state3"
_ST_RUN -C="$TMP/asc-new4" -d -y HEAD~1
_ST_EQ "a new -C path nothing refuses lands and stays" "$RC:$([ -d "$TMP/asc-new4" ] && echo kept)" "0:kept"

# A stranded branch opening on a dash is moved by its full ref,
# as `git branch` reads it as an option
_ST_PZ_NEW asb
_ST_PZ_C a.txt a "ASB A" && _ST_PZ_C b.txt b "ASB B" && _ST_PZ_C c.txt c "ASB C"
git update-ref refs/heads/-side HEAD~1
_ST_RUN -M --text="ASB B reworded" HEAD~1
_ST_OUT_HAS "a stranded branch opening on a dash is moved through update-ref" "git update-ref refs/heads/-side $(git rev-parse --short=12 HEAD~1)$"
_ST_OUT_LACKS "never through git branch" 'git branch -f -side'

# A caller reading every pathspec literally gets names unmarked, which a mark would turn into others
_ST_PZ_NEW asl
_ST_PZ_C 'f*.txt' $'a\nb\nc' "ASL A" && _ST_PZ_C 'f*.txt' $'a\nB\nc' "ASL B" && _ST_PZ_C 'f*.txt' $'a\nB2\nc' "ASL C"
_ST_RUN -d -y HEAD~1
AS_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${AS_WT:-$ST_NO_WT}" 'f*.txt' $'a\nB2\nc'
print -r -- $'a\nB2\nc\nmore' > "${AS_WT:-$ST_NO_WT}/f*.txt"
GIT_LITERAL_PATHSPECS=1 _ST_RUN --status
AS_CMD=$(print -r -- "$OUT" | grep -m1 ' add -- ')
_ST_OUT_HAS "a pause with a change left unstaged names its add" ' add -- '
_ST_OUT_LACKS "unmarked for a caller under GIT_LITERAL_PATHSPECS" ':(literal)'
( export GIT_LITERAL_PATHSPECS=1; eval "$AS_CMD" ) </dev/null >/dev/null 2>&1
AS_RC=$?
_ST_EQ "so it runs there as printed" "$AS_RC:$(git -C "${AS_WT:-$ST_NO_WT}" diff --name-only)" "0:"
print -r -- $'a\nB2\nc\nmore2' > "${AS_WT:-$ST_NO_WT}/f*.txt"
_ST_RUN --status
_ST_OUT_HAS "while any other caller's still marks the name" ":(literal)f\*\.txt"
_ST_RUN --abort
cd "$TMP/repo"
