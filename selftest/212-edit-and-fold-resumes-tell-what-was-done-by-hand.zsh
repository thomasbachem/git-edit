# An edit's and a fold's resume tell what was done by hand or cut short, each neighbor going on:
# • An edit whose stop only added commits, its landing killed before it cleared the pause, reads as
#   landed to `--abort` and `--continue` alike – no move from the tip onto itself ever journaled
# • A commit the replay drops is named beside commits added at the stop
# • A replay aborted by hand names the reset to the amend and `--continue`, `--status` too
# • A fold's fixup skipped by hand refuses as a fold leaving history unchanged, the staging kept
# • An edit that empties its commit names the abort and the drop, not git's own advice
# • An amend prints no stray commit id, and an abort leaves another repository's checkout at a pause
#   worktree's path alone
# • A refused resume records no verify flag, a dirty submodule never refuses commits made at a stop,
#   and a worktree reset to the old tip stands in for no commits made there
_ST_SCENARIO "\e[1;96m[212] edit and fold resumes tell what was done by hand or cut short\e[0m"
local EP_WT EP_T EP_B EP_A EP_CMD EP_SF

# A `git` stand-in that kills the run calling it right after the edit's landing `update-ref`
mkdir -p "$TMP/ep-kill"
{
	print -r -- '#!/bin/sh'
	print -r -- 'case " $* " in'
	print -r -- "	*\" update-ref -m git edit: edit \"*) ${(q)commands[git]} \"\$@\"; rc=\$?; kill -9 \$PPID; exit \$rc ;;"
	print -r -- 'esac'
	print -r -- "exec ${(q)commands[git]} \"\$@\""
} > "$TMP/ep-kill/git"
chmod +x "$TMP/ep-kill/git"
# Builds A, B, C changing f.txt, D, and pauses an edit of B
_EP_PAUSE_B () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	_ST_PZ_C a.txt a "${(U)1} A" && _ST_PZ_C b.txt b "${(U)1} B" && _ST_PZ_C f.txt 1 "${(U)1} C" && _ST_PZ_C d.txt d "${(U)1} D"
	_ST_RUN HEAD~2
	EP_WT=$(_ST_PZ_WT)
}

# Commits added at the stop, the landing killed – the abort names it landed, taking nothing back
_EP_PAUSE_B ep1
( cd "${EP_WT:-$ST_NO_WT}" && _ST_PZ_C x.txt x "EP1 X" )
PATH="$TMP/ep-kill:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null >/dev/null 2>&1
EP_T=$(git rev-parse HEAD)
_ST_EQ "an edit adding a commit at its stop, killed right after its landing, landed" "$(git log --format=%s | tr '\n' '|')" "EP1 D|EP1 C|EP1 X|EP1 B|EP1 A|"
_ST_RUN --abort
_ST_EQ "its abort takes nothing back and clears the pause" "$RC:$(git rev-parse HEAD):$([ -f .git/git-edit-state ] && echo kept)" "0:$EP_T:"
_ST_OUT_HAS "naming the edit as landed" 'The edit had landed already, before its run cleared the pause'
_ST_OUT_LACKS "never as a branch untouched" 'Branch was never touched'
# A continue after it ends the pause as landed, journaling the move once, so an undo takes it back
_EP_PAUSE_B ep1b
( cd "${EP_WT:-$ST_NO_WT}" && _ST_PZ_C x.txt x "EP1B X" )
PATH="$TMP/ep-kill:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null >/dev/null 2>&1
EP_T=$(git rev-parse HEAD)
_ST_RUN --continue
_ST_EQ "a continue after such a kill lands nothing more" "$RC:$(git rev-parse HEAD):$([ -f .git/git-edit-state ] && echo kept)" "0:$EP_T:"
_ST_OUT_HAS "naming the edit as landed" 'The edit had landed already, its run cut off before clearing the pause'
_ST_EQ "the landing journaled once, never a move from the tip onto itself" "$(awk '$3 == $4' .git/git-edit-journal | wc -l | tr -d ' '):$(grep -c ' edit ' .git/git-edit-journal)" "0:1"
_ST_RUN --undo
_ST_EQ "so an undo takes the edit back" "$RC:$(git log --format=%s | tr '\n' '|')" "0:EP1B D|EP1B C|EP1B B|EP1B A|"
# An amend killed so reads as landed as before
_EP_PAUSE_B ep1c
print -r -- b2 >> "${EP_WT:-$ST_NO_WT}/b.txt"
PATH="$TMP/ep-kill:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue </dev/null >/dev/null 2>&1
EP_T=$(git rev-parse HEAD)
_ST_RUN --abort
_ST_EQ "an amend killed after its landing aborts as landed still" "$RC:$(git rev-parse HEAD):$(git show HEAD~2:b.txt | tr '\n' '|')" "0:$EP_T:b|b2|"
_ST_OUT_HAS "naming it so" 'The edit had landed already, before its run cleared the pause'
# Commits added at a stop whose replay conflicts never landed – its abort says so
_ST_PZ_NEW ep1d
_ST_PZ_C a.txt a "EP1D A" && _ST_PZ_C b.txt b "EP1D B" && _ST_PZ_C f.txt 1 "EP1D C" && _ST_PZ_C d.txt d "EP1D D"
EP_T=$(git rev-parse HEAD)
_ST_RUN HEAD~2
EP_WT=$(_ST_PZ_WT)
( cd "${EP_WT:-$ST_NO_WT}" && _ST_PZ_C f.txt 9 "EP1D X" )
_ST_RUN --continue
_ST_EQ "commits added at a stop whose replay conflicts pause" "$RC" "2"
_ST_RUN --abort
_ST_EQ "and abort as never landed" "$RC:$(git rev-parse HEAD)" "0:$EP_T"
_ST_OUT_HAS "the branch named as untouched" 'Branch was never touched'

# A branch moved by hand onto the result the edit built – the continue refuses, journaling nothing
_EP_PAUSE_B ep2
( cd "${EP_WT:-$ST_NO_WT}" && _ST_PZ_C x.txt x "EP2 X" )
_ST_RUN --continue --verify=false
_ST_EQ "an edit whose gate fails pauses" "$RC" "2"
git update-ref refs/heads/main "$(git -C "${EP_WT:-$ST_NO_WT}" rev-parse HEAD)"
EP_T=$(git rev-parse HEAD)
_ST_RUN --continue --no-verify
_ST_EQ "a continue onto a tip that is its result already refuses, the pause kept" "$RC:$(git rev-parse HEAD):$([ -f .git/git-edit-state ] && echo kept)" "1:$EP_T:kept"
_ST_OUT_HAS "as changing nothing" "The edit's result is main's tip ${EP_T:0:7} itself, so it changes nothing"
_ST_EQ "journaling no move from the tip onto itself" "$(cat .git/git-edit-journal 2>/dev/null | wc -l | tr -d ' ')" "0"
_ST_RUN --abort

# A commit the replay drops is named, commits added at the stop beside it
_ST_PZ_NEW ep3
_ST_PZ_C a.txt a "EP3 A" && _ST_PZ_C b.txt b "EP3 B" && _ST_PZ_C f.txt x "EP3 C adds x" && _ST_PZ_C d.txt d "EP3 D"
_ST_RUN HEAD~2
EP_WT=$(_ST_PZ_WT)
( cd "${EP_WT:-$ST_NO_WT}" && _ST_PZ_C f.txt x "EP3 X adds x" )
_ST_RUN --continue
_ST_EQ "an edit adding at its stop what a later commit adds lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:EP3 D|EP3 X adds x|EP3 B|EP3 A|"
_ST_OUT_HAS "naming the commit the replay dropped" 'dropped: [0-9a-f]* EP3 C adds x$'
_ST_OUT_HAS "beside the one added" 'added: [0-9a-f]* EP3 X adds x$'
# One adding nothing a later commit carries names no drop
_EP_PAUSE_B ep3b
( cd "${EP_WT:-$ST_NO_WT}" && _ST_PZ_C x.txt x "EP3B X" )
_ST_RUN --continue
_ST_EQ "an edit adding a commit of its own at the stop lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:EP3B D|EP3B C|EP3B X|EP3B B|EP3B A|"
_ST_OUT_HAS "naming it added" 'added: [0-9a-f]* EP3B X$'
_ST_OUT_LACKS "and no drop" 'dropped:'
# An amend taking in what a later commit adds names that one dropped as before – and its run prints
# no stray commit id
_ST_PZ_NEW ep3c
_ST_PZ_C a.txt a "EP3C A" && _ST_PZ_C b.txt b "EP3C B" && _ST_PZ_C f.txt x "EP3C C adds x" && _ST_PZ_C d.txt d "EP3C D"
_ST_RUN HEAD~2
EP_WT=$(_ST_PZ_WT)
print -r -- x > "${EP_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
_ST_EQ "an amend taking in a later commit's change lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:EP3C D|EP3C B|EP3C A|"
_ST_OUT_HAS "naming that commit dropped" 'dropped: [0-9a-f]* EP3C C adds x$'
_ST_OUT_HAS "its amend named" 'git commit --amend -> '
_ST_OUT_LACKS "with no stray commit id line" '^[0-9a-f]\{40\}$'

# A replay aborted by hand names the reset to the amend and the continue, which then resume it
_ST_PZ_NEW ep4
_ST_PZ_C a.txt a "EP4 A" && _ST_PZ_C f.txt 1 "EP4 B" && _ST_PZ_C f.txt 2 "EP4 C" && _ST_PZ_C d.txt d "EP4 D"
_ST_RUN HEAD~2
EP_WT=$(_ST_PZ_WT)
print -r -- 9 > "${EP_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
_ST_EQ "an edit whose replay conflicts pauses" "$RC" "2"
EP_A=$(sed -n 's/^amended=//p' .git/git-edit-state)
git -C "${EP_WT:-$ST_NO_WT}" rebase --abort
_ST_RUN --continue
_ST_EQ "a continue after the replay was aborted by hand refuses" "$RC:$([ -f .git/git-edit-state ] && echo kept)" "1:kept"
_ST_OUT_HAS "naming the hand abort" 'was aborted by hand – nothing was applied'
_ST_OUT_HAS "and the reset to the amend, then the continue" "reset --hard ${EP_A:0:12}'), then 'git edit --continue'"
EP_CMD=$(print -r -- "$OUT" | sed -n "s/.*Reset it there ('\(.*\)'), then 'git edit --continue'.*/\1/p")
_ST_RUN --status
_ST_OUT_HAS "--status names it too" "The replay was aborted by hand, nothing applied – reset the worktree to the amend: .* reset --hard ${EP_A:0:12}"
_ST_OUT_LACKS "never as a result built past the amend" 'Past the amend'
eval "$EP_CMD" >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "the printed reset, then a continue, replays again to its conflict" "$RC:$(git -C "${EP_WT:-$ST_NO_WT}" ls-files -u | wc -l | tr -d ' ')" "2:3"
_ST_RESOLVE "${EP_WT:-$ST_NO_WT}" f.txt 9
_ST_RUN --continue
_ST_EQ "which lands once resolved" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:f.txt)" "0:EP4 D|EP4 B|EP4 A|:9"
# A worktree reset elsewhere gets no hand-abort verdict
_ST_PZ_NEW ep4b
_ST_PZ_C a.txt a "EP4B A" && _ST_PZ_C f.txt 1 "EP4B B" && _ST_PZ_C d.txt d "EP4B D"
_ST_RUN HEAD~1
EP_WT=$(_ST_PZ_WT)
git -C "${EP_WT:-$ST_NO_WT}" reset -q --hard HEAD^
_ST_RUN --continue
_ST_EQ "a worktree reset to the paused commit's parent refuses" "$RC:$([ -f .git/git-edit-state ] && echo kept)" "1:kept"
_ST_OUT_HAS "as no longer building on the commit" "The edit's worktree no longer builds on"
_ST_OUT_LACKS "never as a hand abort" 'aborted by hand'
_ST_RUN --abort

# A fold's fixup skipped by hand refuses, the pause and the staging kept
_ST_PZ_NEW ep5
_ST_PZ_C a.txt a "EP5 A" && _ST_PZ_C f.txt 1 "EP5 F1" && _ST_PZ_C f.txt 2 "EP5 F2"
EP_T=$(git rev-parse HEAD)
print -r -- 3 > f.txt && git add f.txt
_ST_RUN --amend-into=HEAD~1
_ST_EQ "a fold conflicting at its fixup pauses" "$RC" "2"
EP_WT=$(_ST_PZ_WT)
git -C "${EP_WT:-$ST_NO_WT}" rebase --skip >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a continue after its fixup was skipped by hand refuses" "$RC:$(git rev-parse HEAD):$([ -f .git/git-edit-state ] && echo kept):$(git diff --cached --name-only)" "1:$EP_T:kept:f.txt"
_ST_OUT_HAS "as a fold leaving history unchanged" 'The fold left history unchanged – its fixup was skipped in the worktree'
_ST_OUT_LACKS "never as finished" 'Rebase finished with nothing to apply'
_ST_RUN --abort
_ST_EQ "its abort keeps the staging" "$RC:$(git diff --cached --name-only)" "0:f.txt"
# One finished by hand with each stop resolved lands
_ST_RUN --amend-into=HEAD~1
EP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${EP_WT:-$ST_NO_WT}" f.txt 3
GIT_EDITOR=true git -C "${EP_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RESOLVE "${EP_WT:-$ST_NO_WT}" f.txt 3
GIT_EDITOR=true git -C "${EP_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "while one finished by hand lands" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:f.txt)" "0:EP5 F1|EP5 A|:3"
_ST_OUT_HAS "as completed in the worktree" 'Rebase already completed in worktree'

# An edit that empties its commit names the abort and the drop, which work as printed
_ST_PZ_NEW ep6
_ST_PZ_C a.txt a "EP6 A" && _ST_PZ_C b.txt b "EP6 B" && _ST_PZ_C d.txt d "EP6 D"
EP_B=$(git rev-parse HEAD~1)
_ST_RUN HEAD~1
EP_WT=$(_ST_PZ_WT)
git -C "${EP_WT:-$ST_NO_WT}" rm -q b.txt
_ST_RUN --continue
_ST_EQ "an edit that empties its commit refuses, the pause kept" "$RC:$([ -f .git/git-edit-state ] && echo kept)" "1:kept"
_ST_OUT_HAS "saying so" "The edit empties ${EP_B:0:7}"
_ST_OUT_HAS "naming the abort, then the drop" "'git edit --abort', then 'git edit -d ${EP_B:0:12}'"
_ST_OUT_LACKS "never git's own advice" 'allow-empty'
_ST_RUN --abort
_ST_RUN -d "${EP_B:0:12}"
_ST_EQ "the printed steps drop it" "$RC:$(git log --format=%s | tr '\n' '|')" "0:EP6 D|EP6 A|"
# An empty commit paused for its message still takes one
_ST_PZ_NEW ep6b
_ST_PZ_C a.txt a "EP6B A" && git commit -q --allow-empty -m "EP6B empty" && _ST_PZ_C d.txt d "EP6B D"
_ST_RUN HEAD~1
_ST_RUN --continue --text "EP6B empty reworded"
_ST_EQ "while an empty commit paused for its message is reworded" "$RC:$(git log --format=%s | tr '\n' '|')" "0:EP6B D|EP6B empty reworded|EP6B A|"

# An abort leaves another repository's checkout standing at a pause worktree's path alone
_EP_PAUSE_B ep7
mv "${EP_WT:-$ST_NO_WT}" "${EP_WT:-$ST_NO_WT}.moved"
git init -q "${EP_WT:-$ST_NO_WT}" && ( cd "${EP_WT:-$ST_NO_WT}" && _ST_PZ_C o.txt o "EP7 other" )
_ST_RUN --abort
_ST_EQ "an abort with another repository's checkout at the pause's path clears the pause" "$RC:$([ -f .git/git-edit-state ] && echo kept)" "0:"
_ST_EQ "leaving that checkout as it was" "$(git -C "${EP_WT:-$ST_NO_WT}" log -1 --format=%s 2>/dev/null)" "EP7 other"
_ST_OUT_HAS "naming it" "is no longer a checkout of this repository – left as it is"
# One still this repository's worktree goes
_EP_PAUSE_B ep7b
_ST_RUN --abort
_ST_EQ "while a pause worktree of this repository is removed" "$RC:$([ -e "${EP_WT:-$ST_NO_WT}" ] && echo kept)" "0:"

# A resume refused leaves the pause's gate as it was, one accepted records its flag
_ST_PZ_NEW ep8
_ST_PZ_C a.txt a "EP8 A" && _ST_PZ_C f.txt 1 "EP8 B" && _ST_PZ_C f.txt 2 "EP8 C" && _ST_PZ_C d.txt d "EP8 D"
_ST_RUN -d HEAD~2
_ST_EQ "a drop conflicting pauses" "$RC" "2"
EP_WT=$(_ST_PZ_WT)
_ST_RUN --continue --verify=false --text=x
_ST_EQ "a resume refused over --text" "$RC" "1"
_ST_EQ "records no verify command in the pause" "$(grep -c '^verify_cmd=' .git/git-edit-state)" "0"
_ST_RESOLVE "${EP_WT:-$ST_NO_WT}" f.txt 2
_ST_RUN --continue --verify=false
_ST_EQ "while one accepted, its gate failing, pauses with it recorded" "$RC:$(sed -n 's/^verify_cmd=//p' .git/git-edit-state)" "2:false"
_ST_RUN --abort

# A submodule's own edits never refuse commits made at a stop – a tracked change beside them does
_ST_PZ_NEW ep9s
_ST_PZ_C s.txt s "EP9 S"
_ST_PZ_NEW ep9
_ST_PZ_C a.txt a "EP9 A"
git -c protocol.file.allow=always submodule -q add "$TMP/pz-ep9s" sub >/dev/null 2>&1 && git commit -qm "EP9 sub"
_ST_PZ_C b.txt b "EP9 B" && _ST_PZ_C d.txt d "EP9 D"
_ST_RUN HEAD~1
EP_WT=$(_ST_PZ_WT)
git -C "${EP_WT:-$ST_NO_WT}" -c protocol.file.allow=always submodule -q update --init >/dev/null 2>&1
print -r -- dirty >> "${EP_WT:-$ST_NO_WT}/sub/s.txt"
( cd "${EP_WT:-$ST_NO_WT}" && _ST_PZ_C x.txt x "EP9 X" )
print -r -- b2 >> "${EP_WT:-$ST_NO_WT}/b.txt"
_ST_RUN --continue
_ST_EQ "commits made at a stop beside a tracked change refuse" "$RC:$([ -f .git/git-edit-state ] && echo kept)" "1:kept"
_ST_OUT_HAS "naming it" 'with changes beside them still uncommitted'
git -C "${EP_WT:-$ST_NO_WT}" checkout -q -- b.txt
_ST_EQ "the submodule dirty in the worktree" "$(git -C "${EP_WT:-$ST_NO_WT}" status --porcelain --untracked-files=no)" " M sub"
_ST_RUN --continue
_ST_EQ "while beside only a dirty submodule they land" "$RC:$(git log --format=%s | tr '\n' '|')" "0:EP9 D|EP9 X|EP9 B|EP9 sub|EP9 A|"

# A worktree reset to the old tip stands in for no commits made at the stop
_EP_PAUSE_B ep10
EP_T=$(git rev-parse HEAD)
git -C "${EP_WT:-$ST_NO_WT}" reset -q --hard "$EP_T"
_ST_RUN --continue
_ST_EQ "a worktree reset to the old tip refuses, nothing journaled" "$RC:$(git rev-parse HEAD):$(cat .git/git-edit-journal 2>/dev/null | wc -l | tr -d ' ')" "1:$EP_T:0"
_ST_OUT_HAS "as holding the commits that followed, none made at the stop" "worktree was reset to ${EP_T:0:7}, which holds commits that followed [0-9a-f]* on the branch, none made at its stop"
_ST_OUT_LACKS "never naming its commits as added" 'added:'
_ST_RUN --abort
