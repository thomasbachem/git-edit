# A landing's re-sync is marked done, and a pause reads as its resume would:
# • A run SIGKILLed once its move is journaled, before its index re-sync, leaves that re-sync to the
#   next run or `--status`, once – never while the run owing it lives, and never to a revert staged
#   by hand after a landing that finished
# • A `--snapshot` fold stops for a conflicted name holding `\`, `#` or `*?[` as for a plain one
# • A fold pausing over a newline name names the rename alone, no plain-git route
# • `--status` after a hand `git rebase --skip` lost a commit gives the resume's refusal
# • An unlabeled caller blocked by a labeled caller's pause is told it may take it up
# • A step going to the top before "run this again" names where to run it again from
_ST_SCENARIO "\e[1;96m[200] a killed landing's re-sync is owed until done, pauses read as resumes do\e[0m"
local M2_P M2_BASE M2_TIP M2_MARK M2_N M2_T M2_WT M2_STEP M2_DIR M2_HERE M2_GITFN
local -i M2_I
# Runs `git edit <arg>...` as caller <label>
_P200_AS () {
	# Args: <label> <arg>...
	export GIT_EDIT_ACTOR=$1
	shift
	_ST_RUN "$@"
	export GIT_EDIT_ACTOR=
}

# A whole-file commit SIGKILLed at its first git call once the journal holds its move
_ST_PZ_NEW m200a
printf 'f1\nf2\n' > F && print -r -- b > B.txt && git add -A && git commit -qm "M200 base"
M2_BASE=$(git rev-parse HEAD)
print -r -- 'f3 by A' >> F
mkdir -p "$TMP/m200-bin"
{
	print -r -- '#!/bin/sh'
	print -r -- "if [ -e ${(q)TMP}/m200-arm ] && [ -s ${(q)PWD}/.git/git-edit-journal ]; then"
	print -r -- "	rm -f ${(q)TMP}/m200-arm; : > ${(q)TMP}/m200-in; ${(q)TMP}/st-hold ${(q)TMP}/m200-go"
	print -r -- "	${(q)commands[git]} \"\$@\"; rc=\$?; : > ${(q)TMP}/m200-out; exit \$rc"
	print -r -- 'fi'
	print -r -- "exec ${(q)commands[git]} \"\$@\""
} > "$TMP/m200-bin/git"
chmod +x "$TMP/m200-bin/git"
: > "$TMP/m200-arm"
PATH="$TMP/m200-bin:$PATH" GIT_EDIT_ACTOR=A GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "M200 f3" -- F </dev/null >/dev/null 2>&1 &
M2_P=$!
M2_I=0; until [ -e "$TMP/m200-in" ] || ! kill -0 $M2_P 2>/dev/null || (( ++M2_I > 1200 )); do sleep 0.1; done
kill -9 $M2_P
wait $M2_P
: > "$TMP/m200-go"
M2_I=0; until [ -e "$TMP/m200-out" ] || (( ++M2_I > 1200 )); do sleep 0.1; done
M2_TIP=$(git rev-parse HEAD)
_ST_EQ "a commit killed once its move is journaled leaves its file staged as before it" \
	"$([ "$M2_TIP" != "$M2_BASE" ] && echo moved):$(grep -c . .git/git-edit-journal):$(git diff --cached --name-only)" "moved:1:F"
# Not while the run owing it lives – pid 1 here
M2_MARK=$(cat .git/git-edit-resynced 2>/dev/null)
_PID_START 1
print -r -- "refs/heads/main $M2_BASE $M2_TIP 1 $REPLY" > .git/git-edit-resynced
_P200_AS B --status
_ST_OUT_LACKS "a live run owing the re-sync keeps --status from taking it on" 'stopped before re-syncing'
_ST_EQ "its entry left as it is" "$RC:$(git diff --cached --name-only)" "0:F"
print -r -- "$M2_MARK" > .git/git-edit-resynced
_P200_AS B --status
_ST_OUT_HAS "--status re-syncs what the killed run's journaled move stranded" \
	"stopped before re-syncing the index: commit by A (${M2_BASE:0:7} → ${M2_TIP:0:7}) – index entries re-synced to it: F\$"
_ST_EQ "the journal as it was, nothing staged" "$(grep -c . .git/git-edit-journal):$(git diff --cached --name-only)" "1:"
_P200_AS B --status
_ST_OUT_LACKS "a second --status re-syncs nothing more" 'stopped before re-syncing'
print -r -- c > C.txt && git add C.txt && git commit -qm "M200 plain"
_ST_EQ "so a peer's plain commit takes nothing back" "$(git diff-tree --no-commit-id --name-only -r HEAD):$(git show HEAD:F | tail -1)" "C.txt:f3 by A"
# A landing that finished leaves a revert staged by hand after it alone
print -r -- f4 >> F
_P200_AS B --commit --text "M200 f4" -- F
git show HEAD~1:F > F && git add F
_P200_AS B --status
print -r -- b2 >> B.txt
_P200_AS B --commit --text "M200 b2" -- B.txt
_ST_EQ "a revert staged by hand after a finished landing stays staged" "$RC:$(git diff --cached --name-only):$(git show HEAD:F | tail -1)" "0:F:f4"
_ST_OUT_LACKS "named by no run" 'stopped before re-syncing'

# A snapshot fold stops for a name zsh would read as a pattern, as for a plain one
if _ST_MERGE_BASE_OK; then
	for M2_N in 'back\slash.txt' '#hash.txt' 'st*r?[x].txt' plain.txt; do
		_ST_PZ_NEW m200b
		printf 'l1\nl2\nl3\n' > "$M2_N" && git add -A && git commit -qm "M200 base"
		M2_T=$(git rev-parse HEAD)
		printf 'l1\nl2 later\nl3\n' > "$M2_N" && git commit -qam "M200 later"
		print -r -- o > o && git add o && git commit -qm "M200 o"
		printf 'l1\nl2 folded\nl3\n' > "$M2_N" && git add -A
		_ST_RUN --amend-into="$M2_T" --snapshot
		_ST_EQ "a snapshot fold over $M2_N stops for its resolution" "$RC:$(_ST_PZ_WT | grep -c .)" "2:1"
		_ST_OUT_LACKS "never as a conflict not over content ($M2_N)" 'not over its content'
		M2_WT=$(_ST_PZ_WT)
		printf 'l1\nl2 folded\nl3\n' > "${M2_WT:-$ST_NO_WT}/$M2_N" && git -C "${M2_WT:-$ST_NO_WT}" add -A
		_ST_RUN --continue
		_ST_EQ "and lands once resolved ($M2_N)" "$RC:$(git show "HEAD:$M2_N" | sed -n 2p):$(git diff --cached --name-only)" "0:l2 folded:"
	done
fi

# A fold pausing over a newline name, a peer's unstaged edit beside it
_ST_PZ_NEW m200c
M2_N=$'new\nline.txt'
printf 'l1\nl2\nl3\n' > "$M2_N" && print -r -- b > b.txt && git add -A && git commit -qm "M200 base"
M2_T=$(git rev-parse HEAD)
printf 'l1\nl2 later\nl3\n' > "$M2_N" && git commit -qam "M200 later"
print -r -- 'peer wip' >> b.txt
printf 'l1\nl2 x\nl3\n' > "$M2_N" && git add -- "$M2_N"
M2_TIP=$(git rev-parse HEAD)
_ST_RUN --amend-into="$M2_T"
_ST_OUT_HAS "a fold pausing over a newline name names the rename alone" 'untouched – rename the file\.$'
_ST_OUT_LACKS "never a fixup and autosquash, which refuse a shared checkout's unstaged edits" 'git commit --fixup'
_ST_EQ "nothing landed, the staging kept" "$RC:$(git rev-parse HEAD):$(git diff --cached --name-only -z | tr '\0' '|')" "1:$M2_TIP:$M2_N|"

# A drop's conflict pause, finished there by a hand `git rebase --skip` that lost a commit
_ST_PZ_NEW m200d
git config rerere.enabled false
_ST_PZ_C f.txt 1 "M200 one" && _ST_PZ_C f.txt 2 "M200 two" && _ST_PZ_C f.txt 3 "M200 three" && _ST_PZ_C f.txt 4 "M200 four"
_P200_AS m-a -d HEAD~1
_P200_AS m-a --status
_ST_OUT_HAS "a paused drop's status sends the caller to resolve it" '^Resolve there, then git edit --continue'
M2_WT=$(_ST_PZ_WT)
git -C "${M2_WT:-$ST_NO_WT}" rebase --skip >/dev/null 2>&1
_P200_AS m-a --status
_ST_EQ "skipped by hand there, losing a commit, its status refuses" "$RC" "1"
_ST_OUT_HAS "naming the lost commit, as the resume does" 'lost 1 of its commit(s), their changes missing from what it builds'
_ST_OUT_HAS "and the abort that clears it" "Cancel with 'git edit --abort'"
_ST_OUT_LACKS "never to resolve and continue" 'Resolve there'
_P200_AS m-a --continue
_ST_OUT_HAS "as its resume refuses" 'lost 1 of its commit(s)'
_P200_AS m-a --abort
_ST_EQ "which the abort clears" "$RC:$(git log -1 --format=%s)" "0:M200 four"

# A labeled caller's pause, met by an unlabeled caller and by another label
_ST_PZ_NEW m200e
_ST_PZ_C a.txt a "M200 a" && _ST_PZ_C b.txt b "M200 b" && _ST_PZ_C c.txt c "M200 c"
_P200_AS agentA HEAD~1
_ST_RUN -M --text "M200 c2" HEAD --wait=0
_ST_OUT_HAS "an unlabeled caller blocked by a labeled caller's pause may take it up" "If it is yours, 'git edit --continue' or 'git edit --abort' it"
_ST_OUT_LACKS "never told to leave it to that caller" 'Leave it to that caller'
_P200_AS agentB -M --text "M200 c2" HEAD --wait=0
_ST_OUT_HAS "while another label is" 'Leave it to that caller, or wait for it to clear'
_ST_RUN --abort
_ST_EQ "and the unlabeled caller's abort clears it" "$RC:$([ -f .git/git-edit-state ] && echo paused)" "0:"

# A file moved by hand onto the name another caller renamed it to, committed whole from a
# subdirectory – the step goes to the top, and the run again comes from where the caller stood
_ST_PZ_NEW m200f
mkdir sub && print -l {1..20} > sub/f && print -r -- o > other && git add -A && git commit -qm "M200 base"
print -r -- x >> other && git commit -qam "M200 other"
cd sub
M2_HERE=$PWD
_ST_UNSYNCED _P200_AS m-a --exec -- sh -c 'git mv f g && { echo ONE; sed 1d g; } > g.new && mv g.new g && git commit -qam "M200 rename f to g"'
{ print -l {1..19}; print TWENTY; } > f
mv f g
_P200_AS m-b --commit --text "M200 B" -- g
_ST_OUT_HAS "a step going to the top says where to run this again from" ' – then run this again from .*sub.*\.$'
M2_STEP=$(sed -n 's/.* with: \(cd .*\) – then run this again from .*/\1/p' <<<"$OUT")
M2_DIR=$(sed -n 's/.* – then run this again from \(.*\)\.$/\1/p' <<<"$OUT")
M2_GITFN="git () { if [ \"\$1\" = edit ]; then shift; GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=m-b ${(qq)SELF} \"\$@\"; else command git \"\$@\"; fi; }"
sh -c "$M2_GITFN; ${M2_STEP:-false}" </dev/null >/dev/null 2>&1
_ST_EQ "naming the caller's directory" "${${(Q)M2_DIR}:A}" "${M2_HERE:A}"
cd "${(Q)M2_DIR:-$ST_NO_WT}"
_P200_AS m-b --commit --text "M200 B" -- g
_ST_EQ "and run again from there as told, it lands" "$RC:$(git show HEAD:sub/g | sed -n '1p;20p' | tr '\n' '|'):$(git log -1 --format=%s)" "0:ONE|TWENTY|:M200 B"
cd "$TMP/repo"
