# State an older build left resumes as this one's would, and a refusal names whose pause it is:
# • A split's continue reads an edit made in its index's own second, at the same size
# • A pause an older build wrote with no stops recorded has its stop recorded at the resume, so
#   the absorption guard runs, and a clean resolution still lands
# • A pause from before labels is never waited for, and refuses naming its continue and abort
# • Another caller's pause is left to that caller or waited for, never offered to continue
# • `--undo` takes a caller's own run journaled under its mapped label as its own
# • A journal lock naming a pid alone is broken once older than the 60 s wait
_ST_SCENARIO "\e[1;96m[197] older builds' state resumes guarded, refusals name whose pause it is\e[0m"
local SO_WT SO_SF SO_T SO_S SO_IDX SO_LINE
local -i SO_AT
zmodload zsh/datetime
# Runs `git edit <arg>...` as caller <label>, outside the suite's no-wait pin
_S197_RUN () {
	# Args: <label> <arg>...
	OUT=$(env -u GIT_EDIT_SELFTEST_DEPTH GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR="$1" "$SELF" "${@:2}" </dev/null 2>&1)
	RC=$?
}
# Drops the lines of the pause's state file whose key matches <pattern>, as an older build wrote it
_S197_STRIP () {
	# Args: <extended pattern of keys>
	local SF="$(git rev-parse --git-common-dir)/git-edit-state"
	LC_ALL=C grep -v -E "^($1)=" "$SF" > "$SF.s197" && mv -f "$SF.s197" "$SF"
}

# A split's edit made in the second its worktree was checked out, the file's size unchanged, reads
# as made – a copy of the index taking a fresh mtime read it as clean, the first commit then
# keeping what the edit took out – the second pinned on the file and the index alike
_ST_PZ_NEW so1
git config core.checkStat minimal
print -l one two three > f.txt; print -l uno dos tres > g.txt; git add .; git commit -qm "SO1 A"
print -l ONE two THREE > f.txt; print -l UNO dos TRES > g.txt; git add .; git commit -qm "SO1 B"
_ST_RUN --split=HEAD
SO_WT=$(_ST_PZ_WT)
print -l ONE two three > "${SO_WT:-$ST_NO_WT}/f.txt"
print -l UNO dos tres > "${SO_WT:-$ST_NO_WT}/g.txt"
SO_T=$(git -C "${SO_WT:-$ST_NO_WT}" ls-files --debug -- f.txt 2>/dev/null | sed -n 's/^ *mtime: \([0-9]*\):.*/\1/p')
SO_IDX=$(git -C "${SO_WT:-$ST_NO_WT}" rev-parse --path-format=absolute --git-path index 2>/dev/null)
strftime -s SO_S '%Y%m%d%H%M.%S' "${SO_T:-0}"
touch -t "$SO_S" "${SO_WT:-$ST_NO_WT}/f.txt" "${SO_IDX:-$ST_NO_WT}"
# The continue in a later second, as one a moment after the edit runs
SO_AT=0
until (( EPOCHSECONDS > ${SO_T:-0} )) || (( ++SO_AT > 30 )); do sleep 0.1; done
_ST_RUN --continue --text "SO1 B first"
_ST_EQ "a split's continue reads an edit made in its index's second" "$RC:$(git show HEAD~1:f.txt 2>&1 | tr '\n' ' ')" "0:ONE two three "
_ST_EQ "beside one made later" "$(git show HEAD~1:g.txt 2>&1 | tr '\n' ' ')|$(git show HEAD:f.txt 2>&1 | tr '\n' ' ')" "UNO dos tres |ONE two THREE "

# A fold paused by an older build – its stop's tip kept, but no stops or replay, or none of it –
# resumed with a resolution taking in a later commit's change refuses, as one this build paused
for SO_S in 'stops|replay|todo_left' 'stop_head|stops|replay|todo_left|actor|actor_id'; do
	_ST_PZ_NEW so2
	print -l base l2 > f.txt; print -l g1 g2 g3 g4 > g.txt; git add .; git commit -qm "SO2 A"
	print -l bee l2 > f.txt; git commit -qam "SO2 B"
	print -l g1 'g2 C' 'g3 C' 'g4 C' > g.txt; print h > h.txt; git add .; git commit -qm "SO2 C"
	print -l fold l2 > f.txt; git add f.txt
	_ST_RUN --amend-into=HEAD~2 -- f.txt
	SO_WT=$(_ST_PZ_WT)
	_S197_STRIP "$SO_S"
	_ST_RESOLVE "${SO_WT:-$ST_NO_WT}" f.txt "$(print -l base l2)"
	_ST_RESOLVE "${SO_WT:-$ST_NO_WT}" g.txt "$(print -l g1 'g2 C' 'g3 C' 'g4 C')"
	_ST_RUN --continue
	_ST_EQ "an older pause (no ${SO_S%%|*}) resolved to take in a later change refuses" "$RC:$(git show --format= --name-only HEAD | tr '\n' ' ')" "1:g.txt h.txt "
	_ST_OUT_HAS "naming it" 'A resolution took in what a later commit changes'
	_ST_RUN --abort
done
# While one resolved as the fold asks resumes, its next stop pausing, and lands
_ST_PZ_NEW so3
print -l base l2 > f.txt; print -l g1 g2 g3 g4 > g.txt; git add .; git commit -qm "SO3 A"
print -l bee l2 > f.txt; git commit -qam "SO3 B"
print -l g1 'g2 C' 'g3 C' 'g4 C' > g.txt; print h > h.txt; git add .; git commit -qm "SO3 C"
print -l fold l2 > f.txt; git add f.txt
_ST_RUN --amend-into=HEAD~2 -- f.txt
SO_WT=$(_ST_PZ_WT)
_S197_STRIP 'stop_head|stops|replay|todo_left|actor|actor_id'
_ST_RESOLVE "${SO_WT:-$ST_NO_WT}" f.txt "$(print -l fold l2)"
_ST_RUN --continue
_ST_EQ "an older pause resolved as the fold asks resumes to its next stop" "$RC" "2"
_ST_RESOLVE "${SO_WT:-$ST_NO_WT}" f.txt "$(print -l bee l2)"
_ST_RUN --continue
_ST_EQ "and lands from there" "$RC:$(git show HEAD~2:f.txt | tr '\n' ' ')|$(git show --format= --name-only HEAD | tr '\n' ' ')" "0:fold l2 |g.txt h.txt "

# A pause from before labels – no actor line – is anyone's to resume, so a labeled caller never
# waits for it, refusing at once with its continue and abort named
_ST_PZ_NEW so4
_ST_PZ_C a.txt a "SO4 A" && _ST_PZ_C b.txt b "SO4 B" && _ST_PZ_C c.txt c "SO4 C"
export GIT_EDIT_ACTOR=so-peer
_ST_RUN HEAD~1
export GIT_EDIT_ACTOR=
cp "$(git rev-parse --git-common-dir)/git-edit-state" "$TMP/so4-state"
_S197_STRIP 'actor|actor_id'
SO_AT=$EPOCHSECONDS
_S197_RUN so-self -M --text "SO4 C reworded" --wait=30 HEAD
_ST_EQ "a labeled caller never waits for a pause from before labels" "$RC:$(( EPOCHSECONDS - SO_AT < 15 ))" "1:1"
_ST_OUT_LACKS "never waiting" 'Waiting up to'
_ST_OUT_HAS "naming its continue and abort" "If it is yours, 'git edit --continue' or 'git edit --abort' it"
# While one naming another label is waited for, up to the bound
cp "$TMP/so4-state" "$(git rev-parse --git-common-dir)/git-edit-state"
_S197_RUN so-self -M --text "SO4 C reworded" --wait=1 HEAD
_ST_EQ "while one naming another label is waited for" "$RC" "1"
_ST_OUT_HAS "up to the bound" 'Waiting up to 1s for so-peer'"'"'s paused edit'

# Another caller's pause is left to that caller or waited for – its continue and abort are not this
# one's to run – the caller's own, and one from before labels, still named so
_S197_RUN so-self -M --text "SO4 C reworded" --wait=0 HEAD
_ST_EQ "another caller's pause refuses at once" "$RC:$(git log -1 --format=%s)" "1:SO4 C"
_ST_OUT_HAS "left to that caller, or waited for" "Leave it to that caller, or wait for it to clear: run this again with --wait=<secs> ('git edit --status' shows it)"
_ST_OUT_LACKS "never offered to continue" 'If it is yours'
_ST_RUN -M --text "SO4 C reworded" HEAD
_ST_OUT_HAS "while an unlabeled caller, which may resume it, is named its continue and abort" "If it is yours, 'git edit --continue' or 'git edit --abort' it"
_S197_RUN so-peer -M --text "SO4 C reworded" --wait=0 HEAD
_ST_OUT_HAS "while the caller's own names its continue and abort" "If it is yours, 'git edit --continue' or 'git edit --abort' it"
_S197_STRIP 'actor|actor_id'
_S197_RUN so-self -M --text "SO4 C reworded" --wait=0 HEAD
_ST_OUT_HAS "as does one from before labels" "If it is yours, 'git edit --continue' or 'git edit --abort' it"
_ST_RUN --abort

# A run journaled under the caller's mapped label alone, as before labels were kept as given, is
# the caller's own to take back – one under another label mapping alike is not
_ST_PZ_NEW so5
_ST_PZ_C a.txt a "SO5 A" && _ST_PZ_C b.txt b "SO5 B"
_S197_RUN "so agent" -M --text "SO5 B reworded" HEAD
SO_LINE=$(tail -1 .git/git-edit-journal)
print -r -- "${SO_LINE%%$'\t'*}"$'\tso_agent' > .git/git-edit-journal
_S197_RUN "so agent" --undo
_ST_EQ "--undo takes a run journaled under the caller's mapped label back" "$RC:$(git log -1 --format=%s)" "0:SO5 B"
_S197_RUN "so agent" -M --text "SO5 B reworded" HEAD
SO_LINE=$(tail -1 .git/git-edit-journal)
print -r -- "${SO_LINE%%$'\t'*}"$'\t$\'so:agent\'' > .git/git-edit-journal
_S197_RUN "so agent" --undo
_ST_EQ "never one under another label mapping alike" "$RC:$(git log -1 --format=%s)" "1:SO5 B reworded"
_ST_OUT_HAS "named as another caller's" "is another caller's – refusing to take it back"
# And past another caller's run, its own under the mapped label is named as the caller's
print -r -- "${SO_LINE%%$'\t'*}"$'\tso_agent' > .git/git-edit-journal
_ST_PZ_C c.txt c "SO5 C"
print -r -- "$EPOCHSECONDS refs/heads/main $(git rev-parse HEAD~1) $(git rev-parse HEAD) commit"$'\tso-peer' >> .git/git-edit-journal
_S197_RUN "so agent" --undo
_ST_OUT_HAS "past another caller's run, its own is named" 'Your own last run (reword '

# A journal lock naming a pid alone, as an older build wrote it, held by a live process past the
# 60 s wait is broken – one younger still counts as live, as a pause worktree's lock shows at once
# – pid 1 lives, and is no run's parent the lock check walks up to
_ST_PZ_NEW so6
_ST_PZ_C a.txt a "SO6 A" && _ST_PZ_C b.txt b "SO6 B"
print -r -- 1 > .git/git-edit-journal.lock
strftime -s SO_S '%Y%m%d%H%M.%S' $(( EPOCHSECONDS - 120 ))
touch -t "$SO_S" .git/git-edit-journal.lock
SO_AT=$EPOCHSECONDS
_ST_RUN -M --text "SO6 B reworded" HEAD
_ST_EQ "a journal lock naming a live pid alone past the wait is broken" "$RC:$(git log -1 --format=%s):$(( EPOCHSECONDS - SO_AT < 30 ))" "0:SO6 B reworded:1"
rm -f .git/git-edit-journal.lock
_ST_RUN HEAD~1
SO_WT=$(_ST_PZ_WT)
print -r -- 1 > "$(git -C "${SO_WT:-$ST_NO_WT}" rev-parse --absolute-git-dir)/git-edit-run.lock"
_ST_RUN --continue
_ST_EQ "while a younger one naming a live pid alone holds" "$RC:$([ -f .git/git-edit-state ] && echo kept)" "1:kept"
_ST_OUT_HAS "naming that run" 'is in use by a run in flight'
rm -f "$(git -C "${SO_WT:-$ST_NO_WT}" rev-parse --absolute-git-dir)/git-edit-run.lock"
_ST_RUN --abort
cd "$TMP/repo"
