# A replant, a land and an edit's replay refuse a rebase failing with nothing to resolve – a hook's
# veto, a failed signature – in git's and the hook's words: a first run pauses nothing, a resume
# keeps its pause for a retry
# Commits made at an edit's stop on top of the paused commit are named as added after it, which
# stays as it was – an amend beside them named as the edit – and untracked files beside them are
# refused with the step that fits an edit
_ST_SCENARIO "\e[1;96m[206] replants, lands and edits refuse git's own failures and name commits added at a stop\e[0m"
local FR_T FR_WT FR_B FR_H FR_Y FR_GPG=$TMP/fr-gpg
# Answers whether the repo holds no pause and no worktree but its own
_FR_CLEAN () {
	[ ! -f "$(git rev-parse --git-common-dir)/git-edit-state" ] && [ "$(git worktree list | wc -l | tr -d ' ')" = 1 ]
}
# Arms a `pre-rebase` hook that refuses with a line of its own
_FR_VETO () {
	mkdir -p .git/hooks && print -l '#!/bin/sh' 'echo "fr hook: no rebasing here" >&2' 'exit 1' > .git/hooks/pre-rebase
	chmod +x .git/hooks/pre-rebase
}
# A gpg stand-in that signs anything, so a rebase begun signing fails only once it is swapped out –
# its status line after a newline, where git 2.31 looks for it
print -l '#!/bin/sh' 'cat >/dev/null' 'echo >&2' 'echo "[GNUPG:] SIG_CREATED D 1 8 00 1 X" >&2' \
	"printf -- '-----BEGIN PGP SIGNATURE-----\\n\\nfr\\n-----END PGP SIGNATURE-----\\n'" > "$FR_GPG"
chmod +x "$FR_GPG"

# A land a hook vetoes refuses with the hook's words, nothing paused, so the next run goes ahead
_ST_PZ_NEW fr1
_ST_PZ_C a.txt a "FR1 base"
git checkout -q -b feat && _ST_PZ_C f.txt f "FR1 F" && git checkout -q main && _ST_PZ_C m.txt m "FR1 M"
FR_T=$(git rev-parse HEAD)
_FR_VETO
_ST_RUN --land=feat
_ST_EQ "a land whose rebase a hook vetoes refuses" "$RC:$(git rev-parse HEAD)" "1:$FR_T"
_ST_OUT_HAS "in git's own words" 'git rebase failed without a conflict to resolve: The pre-rebase hook refused to rebase'
_ST_OUT_HAS "the hook's own line too" 'fr hook: no rebasing here'
_ST_OUT_HAS "and that nothing paused" 'Nothing was applied and nothing paused – fix what git names, then run it again'
_ST_OUT_LACKS "never a conflict" 'Conflict while landing'
_ST_CHECK "leaving no pause or worktree" _FR_CLEAN
_ST_RUN -M --text "FR1 M reworded" HEAD
_ST_EQ "the next run is not blocked" "$RC:$(git log -1 --format=%s)" "0:FR1 M reworded"
rm -f .git/hooks/pre-rebase
_ST_RUN --land=feat
_ST_EQ "with the hook gone the land lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:FR1 F|FR1 M reworded|FR1 base|"
# A replant the same
_ST_PZ_NEW fr1b
_ST_PZ_C a.txt a "FR1B base"
git checkout -q -b feat && _ST_PZ_C f.txt f "FR1B F" && git checkout -q main && _ST_PZ_C m.txt m "FR1B M"
git checkout -q feat
FR_T=$(git rev-parse HEAD)
_FR_VETO
_ST_RUN --onto=main
_ST_EQ "a replant whose rebase a hook vetoes refuses" "$RC:$(git rev-parse HEAD)" "1:$FR_T"
_ST_OUT_HAS "in the hook's words" 'fr hook: no rebasing here'
_ST_OUT_LACKS "never a conflict" 'Conflict while replanting'
_ST_CHECK "leaving no pause or worktree" _FR_CLEAN
# As does one whose commit cannot be signed, its rebase stopped midway
_ST_PZ_NEW fr1c
_ST_PZ_C a.txt a "FR1B base"
git checkout -q -b feat && _ST_PZ_C f.txt f "FR1B F" && git checkout -q main && _ST_PZ_C m.txt m "FR1B M"
git checkout -q feat
FR_T=$(git rev-parse HEAD)
git config commit.gpgSign true && git config gpg.program false
_ST_RUN --onto=main
_ST_EQ "a replant whose commit cannot be signed refuses" "$RC:$(git rev-parse HEAD)" "1:$FR_T"
_ST_OUT_HAS "naming the signature" 'without a conflict to resolve: gpg failed to sign the data'
_ST_CHECK "nothing paused" _FR_CLEAN
git config --unset commit.gpgSign && git config --unset gpg.program
_ST_RUN --onto=main
_ST_EQ "while one signing nothing replants" "$RC:$(git log --format=%s | tr '\n' '|')" "0:FR1B F|FR1B M|FR1B base|"

# An edit's replay a hook vetoes refuses too, its pause kept for a retry, which then lands
_ST_PZ_NEW fr2
_ST_PZ_C a.txt a "FR2 A" && _ST_PZ_C b.txt b "FR2 B" && _ST_PZ_C c.txt c "FR2 C"
FR_T=$(git rev-parse HEAD)
_ST_RUN HEAD~1
FR_WT=$(_ST_PZ_WT)
print -r -- b2 > "${FR_WT:-$ST_NO_WT}/b.txt"
_FR_VETO
_ST_RUN --continue --text "FR2 B edited"
_ST_EQ "an edit's replay a hook vetoes refuses" "$RC:$(git rev-parse HEAD)" "1:$FR_T"
_ST_OUT_HAS "in the hook's words" 'fr hook: no rebasing here'
_ST_OUT_HAS "keeping the pause for a retry" 'Nothing was applied – fix what git names, then git edit --continue, or abort the operation: git edit --abort'
_ST_OUT_LACKS "never a conflict" 'Conflict while replaying descendants'
_ST_CHECK "the pause kept" test -f .git/git-edit-state
rm -f .git/hooks/pre-rebase
_ST_RUN --continue
_ST_EQ "the retry lands the edit" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:b.txt)" "0:FR2 C|FR2 B edited|FR2 A|:b2"

# A replant's resume whose commit cannot be signed keeps its pause, with the retry's words
_ST_PZ_NEW fr3
_ST_PZ_C f.txt a "FR3 base"
git checkout -q -b feat && _ST_PZ_C f.txt feat "FR3 F" && _ST_PZ_C g.txt g "FR3 G"
git checkout -q main && _ST_PZ_C f.txt main "FR3 M" && git checkout -q feat
FR_T=$(git rev-parse HEAD)
git config commit.gpgSign true && git config gpg.program "$FR_GPG"
_ST_RUN --onto=main
_ST_EQ "a real conflict still pauses" "$RC" "2"
FR_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${FR_WT:-$ST_NO_WT}" f.txt resolved
git config gpg.program false
_ST_RUN --continue
_ST_EQ "a resume whose commit cannot be signed refuses" "$RC:$(git rev-parse HEAD)" "1:$FR_T"
_ST_OUT_HAS "naming the signature" 'without a conflict to resolve: gpg failed to sign the data'
_ST_OUT_HAS "keeping the pause for a retry" 'Nothing was applied – fix what git names, then git edit --continue'
_ST_OUT_LACKS "never a conflict to resolve" 'Conflict continues'
_ST_CHECK "the pause kept" test -f .git/git-edit-state
git config gpg.program "$FR_GPG"
_ST_RUN --continue
_ST_EQ "once signing works the retry lands" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:f.txt)" "0:FR3 G|FR3 F|FR3 M|FR3 base|:resolved"
git config --unset commit.gpgSign && git config --unset gpg.program
# An edit's replay resumed at a conflict the same
_ST_PZ_NEW fr4
_ST_PZ_C f.txt a "FR4 A" && _ST_PZ_C g.txt b "FR4 B" && _ST_PZ_C f.txt c "FR4 C"
FR_T=$(git rev-parse HEAD)
git config commit.gpgSign true && git config gpg.program "$FR_GPG"
_ST_RUN HEAD~1
FR_WT=$(_ST_PZ_WT)
print -r -- b > "${FR_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
_ST_EQ "an edit whose replay conflicts pauses" "$RC" "2"
_ST_RESOLVE "${FR_WT:-$ST_NO_WT}" f.txt c
git config gpg.program false
_ST_RUN --continue
_ST_EQ "its resume whose commit cannot be signed refuses" "$RC:$(git rev-parse HEAD)" "1:$FR_T"
_ST_OUT_HAS "naming the signature, the pause kept for a retry" 'Nothing was applied – fix what git names, then git edit --continue'
_ST_CHECK "the pause kept" test -f .git/git-edit-state
git config gpg.program "$FR_GPG"
_ST_RUN --continue
_ST_EQ "once signing works the retry lands" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:f.txt)" "0:FR4 C|FR4 B|FR4 A|:b"
git config --unset commit.gpgSign && git config --unset gpg.program

# A commit made on top of the paused commit leaves it as it was – no replaced message, no body
# named lost and no reword offered for the hand commit
_ST_PZ_NEW fr5
_ST_PZ_C a.txt a "FR5 A"
print -r -- b > b.txt && git add b.txt && git commit -qm "FR5 B" -m "FR5 B body that stays on B"
FR_B=$(git rev-parse HEAD)
_ST_PZ_C c.txt c "FR5 C"
_ST_RUN HEAD~1
FR_WT=$(_ST_PZ_WT)
print -r -- x > "${FR_WT:-$ST_NO_WT}/x.txt" && git -C "${FR_WT:-$ST_NO_WT}" add x.txt && git -C "${FR_WT:-$ST_NO_WT}" commit -qm "FR5 X by hand"
FR_H=$(git -C "${FR_WT:-$ST_NO_WT}" rev-parse --short HEAD)
_ST_RUN --continue
_ST_EQ "a commit on top of the paused one lands after it" "$RC:$(git log --format=%s | tr '\n' '|'):$(git rev-parse HEAD~2)" "0:FR5 C|FR5 X by hand|FR5 B|FR5 A|:$FR_B"
_ST_OUT_HAS "named as added after it, which stays as it was" "^${FR_B:0:7} stays as it was – the commit(s) made at the stop were added after it:\$"
_ST_OUT_HAS "the added commit named" "^  added: $FR_H FR5 X by hand\$"
_ST_OUT_LACKS "never as replacing it" '^  replaced: '
_ST_OUT_LACKS "nor its body as dropped" 'carried a 1-line body'
_ST_OUT_LACKS "nor a reword putting it on the hand commit" 'To put the body back'
# An amend with a commit added on top keeps the edit's report, and names the added one too
_ST_RUN HEAD~2
FR_WT=$(_ST_PZ_WT)
print -r -- b2 > "${FR_WT:-$ST_NO_WT}/b.txt" && git -C "${FR_WT:-$ST_NO_WT}" commit -qa --amend -m "FR5 B amended"
FR_B=$(git -C "${FR_WT:-$ST_NO_WT}" rev-parse --short HEAD)
print -r -- y > "${FR_WT:-$ST_NO_WT}/y.txt" && git -C "${FR_WT:-$ST_NO_WT}" add y.txt && git -C "${FR_WT:-$ST_NO_WT}" commit -qm "FR5 Y by hand"
FR_Y=$(git -C "${FR_WT:-$ST_NO_WT}" rev-parse --short HEAD)
_ST_RUN --continue
_ST_EQ "an amend with a commit on top lands both" "$RC:$(git log --format=%s | tr '\n' '|')" "0:FR5 C|FR5 X by hand|FR5 Y by hand|FR5 B amended|FR5 A|"
_ST_OUT_HAS "the amend named as the edit" "^  edited: $FR_B FR5 B amended\$"
_ST_OUT_HAS "the subject it replaced" '^  replaced: FR5 B$'
_ST_OUT_HAS "the body it dropped" 'The replaced message carried a 1-line body'
_ST_OUT_HAS "and the commit added after it" "^  added: $FR_Y FR5 Y by hand\$"

# Untracked files beside commits made at the stop, a check configured, are refused with an edit's
# step, never a resolution's
_ST_PZ_NEW fr6
_ST_PZ_C a.txt a "FR6 A" && _ST_PZ_C b.txt b "FR6 B" && _ST_PZ_C c.txt c "FR6 C"
git config edit.verifyCmd true
_ST_RUN HEAD~1
FR_WT=$(_ST_PZ_WT)
print -r -- x > "${FR_WT:-$ST_NO_WT}/x.txt" && git -C "${FR_WT:-$ST_NO_WT}" add x.txt && git -C "${FR_WT:-$ST_NO_WT}" commit -qm "FR6 X by hand"
print -r -- u > "${FR_WT:-$ST_NO_WT}/u.txt"
_ST_RUN --continue
_ST_EQ "untracked files beside commits made at the stop refuse" "$RC" "1"
_ST_OUT_HAS "naming the edit's step" 'Commit the ones the edit needs beside the commits made at the stop and remove the rest'
_ST_OUT_LACKS "never a resolution's" 'Stage the ones the resolution needs'
rm -f "${FR_WT:-$ST_NO_WT}/u.txt"
_ST_RUN --continue
_ST_EQ "and once gone the edit lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:FR6 C|FR6 X by hand|FR6 B|FR6 A|"
git config --unset edit.verifyCmd
