# A run killed or stopped twice once its branch moved, or stopped as it claimed the pause slot,
# leaves nothing a later run can't see:
# • A SIGKILLed landing's move – in the reflog only – is journaled by the next run, `--status` or
#   `--undo`, its stranded index entries re-synced, so `--undo` takes it back and the whole-file
#   guard refuses taking it back – never while a live run holds the journal's lock, nor twice, nor
#   for a raw undo, which `--undo` still finds already back
# • A second signal once the branch moved re-syncs those entries before the run ends, naming them
# • A signal between the pause slot's claim and the run noting it its own leaves a pause it names
# • A killed run's temp worktree is named by `--status` and swept by a run once 10 min old, one no
#   mark tells of named alone, and a `--commit` losing the race names the mode that ran
_ST_SCENARIO "\e[1;96m[196] a killed run leaves nothing unrecorded, a stop nothing stranded\e[0m"
local KM_P KM_BASE KM_TIP KM_HAND
local -i KM_I
# Writes a `reference-transaction` hook holding the first committed move of `main` once
# `$TMP/<name>-arm` is there, until `$TMP/<name>-go`, then noting it went on
_KM196_HOOK () {
	# Args: <name>
	printf '#!/bin/sh\n[ "$1" = committed ] || exit 0\n[ -e "%s/%s-arm" ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\nrm -f "%s/%s-arm"\n: > "%s/%s-in"\n"%s/st-hold" "%s/%s-go"\n: > "%s/%s-out"\n' \
		"$TMP" "$1" "$TMP" "$1" "$TMP" "$1" "$TMP" "$TMP" "$1" "$TMP" "$1" > .git/hooks/reference-transaction
	chmod +x .git/hooks/reference-transaction
	: > "$TMP/$1-arm"
}
# Waits up to 120 s for <file>, or for <pid> to end first where one is named
_KM196_WAIT () {
	# Args: <file> [<pid>]
	KM_I=0
	until [ -e "$1" ] || { [ -n "$2" ] && ! kill -0 "$2" 2>/dev/null; } || (( ++KM_I > 1200 )); do sleep 0.1; done
}

# A whole-file commit SIGKILLed while a hook runs on its committed move
_ST_PZ_NEW km1
printf 'f1\nf2\n' > F && print -r -- b > B.txt && git add -A && git commit -qm "KM1 base"
KM_BASE=$(git rev-parse HEAD)
print -r -- 'f3 by A' >> F
_KM196_HOOK km1
GIT_EDIT_ACTOR=A GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "KM1 f3" -- F </dev/null >/dev/null 2>&1 &
KM_P=$!
_KM196_WAIT "$TMP/km1-in" $KM_P
kill -9 $KM_P
wait $KM_P
: > "$TMP/km1-go"
_KM196_WAIT "$TMP/km1-out"
rm -f .git/hooks/reference-transaction
KM_TIP=$(git rev-parse HEAD)
_ST_EQ "the killed commit moved the branch, unjournaled, its file staged as before it" \
	"$([ "$KM_TIP" != "$KM_BASE" ] && echo moved):$(cat .git/git-edit-journal 2>/dev/null | grep -c .):$(git diff --cached --name-only)" "moved:0:F"
# Not while a live run holds the journal's lock – pid 1's here – which may be about to record it
KM_HAND=$(<.git/git-edit-journal.lock)
_PID_START 1
print -r -- "1 $REPLY" > .git/git-edit-journal.lock
GIT_EDIT_ACTOR=A _ST_RUN --status
_ST_OUT_LACKS "a live run's journal lock keeps --status from journaling the move" 'journaled from the reflog'
_ST_EQ "the journal and index left as they are" "$(cat .git/git-edit-journal 2>/dev/null | grep -c .):$(git diff --cached --name-only)" "0:F"
# The lock the killed run left put back – what tells its move, made a moment ago, from a live older
# build's not yet journaled
print -r -- "$KM_HAND" > .git/git-edit-journal.lock
GIT_EDIT_ACTOR=A _ST_RUN --status
_ST_OUT_HAS "--status journals the killed run's move from the reflog" "journaled from the reflog: commit by A (${KM_BASE:0:7} → ${KM_TIP:0:7}) – index entries re-synced to it: F"
_ST_EQ "under the run's own label, its entry re-synced" \
	"$(cut -d' ' -f2- .git/git-edit-journal):$(git diff --cached --name-only)" "refs/heads/main $KM_BASE $KM_TIP commit"$'\t'"A:"
_ST_OUT_HAS "and reports it as the last completed run" "Last completed: commit (${KM_BASE:0:7} → ${KM_TIP:0:7})"
_ST_OUT_HAS "naming the temp worktree the killed run left" 'Temp worktrees a killed run left registered, which no pause names – a run sweeps them once 10 min old, or remove them now: git worktree remove --force .*/git-edit-exec\.'
GIT_EDIT_ACTOR=A _ST_RUN --status
_ST_OUT_LACKS "a second --status journals nothing more" 'journaled from the reflog'
_ST_EQ "one line still" "$(grep -c . .git/git-edit-journal)" "1"
GIT_EDIT_ACTOR=A _ST_RUN --undo
_ST_EQ "--undo takes the killed run's move back" "$RC:$(git rev-parse HEAD):$(git diff --cached --name-only)" "0:$KM_BASE:"
# A temp worktree no mark tells of is named alone, and the killed run's swept by a run once it is
# 10 min old, never before
KM_HAND="$TMPDIR/git-edit-hand.km1abc"
git worktree add -q --detach "$KM_HAND" HEAD
_ST_RUN --status
_ST_OUT_HAS "one no mark tells of is named as maybe in flight" "whose run nothing tells gone – an older git-edit's, or one still in flight – once no git-edit run is live in this repository, remove them with: git worktree remove --force .*git-edit-hand.km1abc"
_ST_RUN -M --text "KM1 base reworded" HEAD
_ST_EQ "a run leaves a killed run's temp worktree made under 10 min ago" "$RC:$(git worktree list --porcelain | grep -c '^worktree ')" "0:3"
_ST_OUT_LACKS "sweeping nothing" 'Swept'
touch -t 202001010000 "$(git -C "$(git worktree list --porcelain | sed -n 's/^worktree \(.*\/git-edit-exec\..*\)/\1/p')" rev-parse --absolute-git-dir)/git-edit-owner"
_ST_RUN -M --text "KM1 base reworded again" HEAD
_ST_OUT_HAS "while one made earlier is swept" 'Swept 1 temp worktree(s) a killed run left registered'
_ST_EQ "leaving the unmarked one registered" "$(git worktree list --porcelain | grep -c '^worktree '):$([ -d "$KM_HAND" ] && echo kept)" "2:kept"
git worktree remove --force "$KM_HAND"

# A drop killed so leaves a peer's whole-file commit refused, as it would have been after a drop
# that finished
_ST_PZ_NEW km2
printf 'l1\nl2\nl3\n' > F && git add F && git commit -qm "KM2 base"
printf 'l1\nl2\nl3\nx2 by A\n' > F
GIT_EDIT_ACTOR=A _ST_RUN --commit --text "KM2 x2" -- F
_KM196_HOOK km2
GIT_EDIT_ACTOR=A GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -d -y HEAD </dev/null >/dev/null 2>&1 &
KM_P=$!
_KM196_WAIT "$TMP/km2-in" $KM_P
kill -9 $KM_P
wait $KM_P
: > "$TMP/km2-go"
_KM196_WAIT "$TMP/km2-out"
rm -f .git/hooks/reference-transaction
print -r -- 'b by B' >> F
GIT_EDIT_ACTOR=B _ST_RUN --commit --text "KM2 b" -- F
_ST_EQ "a peer's whole-file commit after a killed drop refuses" "$RC:$(git show HEAD:F | tr '\n' ' ')" "1:l1 l2 l3 "
_ST_OUT_HAS "as taking back what the drop landed" 'would take back what another caller landed: F'
_ST_OUT_HAS "having journaled the drop first" 'journaled from the reflog: drop .* by A'
# A raw undo – a `git edit: undo` move by hand – is no run's to journal, `--undo` finding it back
KM_TIP=$(git rev-parse HEAD)
git checkout -q -- F
print -r -- 'l4' >> F
_ST_RUN --commit --text "KM2 l4" -- F
KM_BASE=$KM_TIP KM_TIP=$(git rev-parse HEAD)
git update-ref -m "git edit: undo commit" refs/heads/main "$KM_BASE" "$KM_TIP"
_ST_RUN --undo
_ST_OUT_LACKS "a raw undo is not journaled as a run" 'journaled from the reflog'
_ST_OUT_HAS "--undo finding the branch already back" 'already sat at'

# Stopped twice once the branch moved, a commit re-syncs the entry it stranded first
_ST_PZ_NEW km3
printf 'f1\nf2\n' > F && print -r -- b > B.txt && git add -A && git commit -qm "KM3 base"
print -r -- 'f3 by A' >> F
_KM196_HOOK km3
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "KM3 f3" -- F </dev/null >"$TMP/km3.out" 2>&1 &
KM_P=$!
_KM196_WAIT "$TMP/km3-in" $KM_P
kill -TERM $KM_P
sleep 0.3
kill -TERM $KM_P
: > "$TMP/km3-go"
wait $KM_P
RC=$?
OUT=$(<"$TMP/km3.out")
rm -f .git/hooks/reference-transaction
_ST_EQ "a second signal past the move stops the commit, journaled" "$RC:$(grep -c ' commit' .git/git-edit-journal)" "143:1"
_ST_OUT_HAS "its trailer naming the entry it re-synced" "^git-edit: error – stopped by SIGTERM after refs/heads/main moved .* – index entries re-synced to it: F\$"
print -r -- b2 >> B.txt && git add B.txt && git commit -qm "KM3 plain"
_ST_EQ "so a peer's plain commit takes nothing back" "$(git diff-tree --no-commit-id --name-only -r HEAD):$(git show HEAD:F | tail -1)" "B.txt:f3 by A"

# A signal as the pause slot is claimed – after the link, before the run notes the pause its own –
# leaves the pause whole, worktree and all, and says so
_ST_PZ_NEW km4
git config rerere.enabled false
printf 'x1\nx2\n' > F && git add F && git commit -qm "KM4 c1"
printf 'x1\nx2a\n' > F && git commit -qam "KM4 c2"
printf 'x1\nx2b\n' > F && git commit -qam "KM4 c3"
mkdir -p "$TMP/km4-bin"
{
	print -r -- '#!/bin/sh'
	print -r -- 'for a; do prev=$last; last=$a; done'
	print -r -- "case \"\$last\" in */git-edit-state) if [ -e ${(q)TMP}/km4-arm ]; then rm -f ${(q)TMP}/km4-arm; ${(q)commands[ln]} \"\$prev\" \"\$last\" || exit 1; : > ${(q)TMP}/km4-in; ${(q)TMP}/st-hold ${(q)TMP}/km4-go; exit 0; fi ;; esac"
	print -r -- "exec ${(q)commands[ln]} \"\$@\""
} > "$TMP/km4-bin/ln"
chmod +x "$TMP/km4-bin/ln"
: > "$TMP/km4-arm"
PATH="$TMP/km4-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --move=HEAD --before=HEAD~1 </dev/null >"$TMP/km4.out" 2>&1 &
KM_P=$!
_KM196_WAIT "$TMP/km4-in" $KM_P
kill -TERM $KM_P
: > "$TMP/km4-go"
wait $KM_P
RC=$?
OUT=$(<"$TMP/km4.out")
_ST_EQ "a signal at the slot's claim stops the run, its pause and worktree kept" \
	"$RC:$([ -f .git/git-edit-state ] && echo state):$([ -d "$(_ST_PZ_WT)" ] && echo wt)" "143:state:wt"
_ST_OUT_HAS "saying the pause stays" "^git-edit: error – stopped by SIGTERM – its pause stays, 'git edit --status' shows it\$"
_ST_RUN --status
_ST_OUT_HAS "which --status shows" 'In-flight operation: reorder'
_ST_OUT_LACKS "its worktree not named as left behind" 'Temp worktrees'
_ST_RUN --abort
_ST_EQ "and --abort ends" "$RC:$([ -f .git/git-edit-state ] && echo state):$(git worktree list | wc -l | tr -d ' ')" "0::1"

# A `--commit` losing the race names the mode that ran, an `--exec` its own
_ST_PZ_NEW km5
_ST_PZ_C a a "KM5 a" && _ST_PZ_C b b "KM5 b"
KM_TIP=$(git rev-parse HEAD)
mkdir -p "$TMP/km5-bin"
{
	print -r -- '#!/bin/sh'
	print -r -- "if [ -e ${(q)TMP}/km5-arm ] && [ \"\$1\" = update-ref ]; then"
	print -r -- "	rm -f ${(q)TMP}/km5-arm; ${(q)commands[git]} update-ref refs/heads/main refs/heads/main~1"
	print -r -- 'fi'
	print -r -- "exec ${(q)commands[git]} \"\$@\""
} > "$TMP/km5-bin/git"
chmod +x "$TMP/km5-bin/git"
print -r -- c > c
: > "$TMP/km5-arm"
PATH="$TMP/km5-bin:$PATH" _ST_RUN --commit --text "KM5 c" -- c
_ST_OUT_HAS "a --commit losing the race says it moved during the commit" "Ref 'refs/heads/main' moved during commit – refusing to overwrite"
git reset -q --hard "$KM_TIP"
: > "$TMP/km5-arm"
PATH="$TMP/km5-bin:$PATH" _ST_RUN --exec -- sh -c 'echo d > d && git add d && git commit -qm "KM5 d"'
_ST_OUT_HAS "an --exec still says during exec" "Ref 'refs/heads/main' moved during exec – refusing to overwrite"
cd "$TMP/repo"
