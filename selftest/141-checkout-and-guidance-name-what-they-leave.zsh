# What a run leaves in the shared checkout is named and never lost – a locked index, a second
# checkout of the branch, a case-only rename – its environment refused where it points elsewhere,
# and a pause's guidance gives the exact answer wherever there is one
_ST_SCENARIO "\e[1;96m[141] a run names what it leaves in the checkout, and a pause the exact answer\e[0m"
local CG_T CG_WT CG_PRE
# An object directory naming another store refuses, one naming the repo's own is dropped
_ST_PZ_NEW cg1
_ST_PZ_C a.txt a "CG A" && _ST_PZ_C b.txt b "CG B" && _ST_PZ_C c.txt c "CG C"
CG_T=$(git rev-parse HEAD)
mkdir -p "$TMP/cg-objects"
OUT=$(GIT_OBJECT_DIRECTORY="$TMP/cg-objects" GIT_ALTERNATE_OBJECT_DIRECTORIES="$PWD/.git/objects" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text "CG B reworded" HEAD~1 </dev/null 2>&1)
RC=$?
_ST_EQ "an object directory elsewhere refuses, nothing landed" "${RC}:$(git rev-parse HEAD)" "1:$CG_T"
OUT=$(GIT_OBJECT_DIRECTORY="$PWD/.git/objects" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text "CG B reworded" HEAD~1 </dev/null 2>&1)
RC=$?
_ST_EQ "while the repo's own is dropped and the run lands" "${RC}:$(git log -1 --format=%s HEAD~1):$(git fsck --connectivity-only >/dev/null 2>&1 && echo whole)" "0:CG B reworded:whole"
OUT=$(GIT_OBJECT_DIRECTORY= GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text "CG empty" HEAD~1 </dev/null 2>&1)
RC=$?
_ST_OUT_HAS "an empty object directory variable refuses, naming it" 'GIT_INDEX_FILE or an object directory names'
OUT=$(GIT_ALTERNATE_OBJECT_DIRECTORIES="$TMP/cg-objects" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text "CG alt" HEAD~1 </dev/null 2>&1)
RC=$?
_ST_EQ "an alternate object store elsewhere refuses too" "$RC" "1"
# A repo path holding `=` takes the checkout's config adopted all the same
_ST_PZ_NEW 'cg=eq'
_ST_PZ_C a.txt a "CG2 A" && _ST_PZ_C b.txt b "CG2 B" && _ST_PZ_C c.txt c "CG2 C"
printf '[user]\n\temail = onbranch@x.invalid\n' > "$TMP/cg-onbranch.inc"
git config includeIf.onbranch:main.path "$TMP/cg-onbranch.inc"
_ST_RUN -d -y HEAD~1
_ST_EQ "a repo under a path holding = drops with its adopted identity" "${RC}:$(git log -1 --format=%ce)" "0:onbranch@x.invalid"
# The branch checked out a second time has its stranded entries re-synced and named
_ST_PZ_NEW cg3
_ST_PZ_C f.txt f "CG3 base" && _ST_PZ_C g.txt g "CG3 adds g" && _ST_PZ_C t.txt t "CG3 tip"
rm -rf "${TMP:?}/cg3-twice" && git worktree add -q -f "$TMP/cg3-twice" main
_ST_RUN -d -y HEAD~1
_ST_EQ "the other checkout's stranded entry is re-synced, its file left" "$(git -C "$TMP/cg3-twice" status --porcelain)" "?? g.txt"
_ST_OUT_HAS "and named" 'Also checked out at .*/cg3-twice'
print -r -- 'f fixed' > f.txt && git add f.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" -- f.txt
_ST_EQ "a fold re-syncs the other checkout as well" "${RC}:$(git -C "$TMP/cg3-twice" status --porcelain -- f.txt)" "0: M f.txt"
git worktree remove --force "$TMP/cg3-twice" 2>/dev/null
# Assume-unchanged and skip-worktree flags survive a re-sync and a terminal sync alike
_ST_PZ_NEW cg3b
_ST_PZ_C f.txt $'1\n2\n3' "CG3b base" && _ST_PZ_C f.txt $'1\n2x\n3' "CG3b change" && _ST_PZ_C t.txt t "CG3b tip"
git update-index --assume-unchanged f.txt && print -r -- $'1\n2x\n3\nmine' > f.txt
_ST_RUN -d -y HEAD~1
_ST_EQ "an agent's re-sync keeps assume-unchanged" "${RC}:$(git ls-files -v f.txt | cut -c1)" "0:h"
git update-index --no-assume-unchanged f.txt && git checkout -q -- f.txt
_ST_PZ_C f.txt $'1\n2y\n3' "CG3b change 2" && _ST_PZ_C t.txt t2 "CG3b tip 2"
git update-index --skip-worktree f.txt && print -r -- $'1\n2y\n3\nmine' > f.txt
_ST_TTY -- -d -y HEAD~1
_ST_EQ "and a terminal sync keeps skip-worktree" "${RC}:$(git ls-files -v f.txt | cut -c1)" "0:S"
# A terminal run's sync under a held index lock names what it could not re-sync
_ST_PZ_NEW cg4
_ST_PZ_C base.txt b "CG4 base" && _ST_PZ_C gone.txt g "CG4 adds gone" && _ST_PZ_C t.txt t "CG4 tip"
print -r -- mine >> gone.txt
: > .git/index.lock
_ST_TTY -- -d -y HEAD~1
rm -f .git/index.lock
_ST_EQ "a terminal drop under a held lock still lands" "${RC}:$(git log -1 --format=%s HEAD~1)" "0:CG4 base"
_ST_OUT_HAS "leaving the checkout to the agent's hints, the locked entry named" 'Index locked – entries still on the pre-rewrite tip.*gone.txt'
# A lock let go within the wait is waited out, the sync bringing the checkout along
_ST_PZ_NEW cg4b
_ST_PZ_C base.txt b "CG4b base" && _ST_PZ_C gone.txt g "CG4b adds gone" && _ST_PZ_C t.txt t "CG4b tip"
print -r -- mine >> gone.txt
: > .git/index.lock
( sleep 1; rm -f .git/index.lock ) &!
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a lock let go meanwhile is waited out, the edited file kept untracked" "${RC}:$(git status --porcelain | tr '\n' '|')" "0:?? gone.txt|"
# A case-only rename taken back carries the edits on a filesystem that ignores case
if [ "$(git config --type=bool core.ignorecase)" = true ]; then
	_ST_PZ_NEW cg5
	_ST_PZ_C README.md $'r1\nr2\nr3\nr4\nr5' "CG5 base"
	git mv README.md cg5.tmp && git mv cg5.tmp readme.md && git commit -qm "CG5 lowercase"
	_ST_PZ_C t.txt t "CG5 tip"
	print -r -- $'r1\nr2\nr3\nr4\nr5 mine' > readme.md
	_ST_TTY -- -d -y HEAD~1
	_ST_EQ "a case-only rename taken back keeps the edits" "${RC}:$(tail -1 readme.md):$(git status --porcelain | tr '\n' '|')" "0:r5 mine: M README.md|"
	_ST_OUT_HAS "as carried onto the new name" 'merged onto what landed: readme.md → README.md'
fi
# A reorder's step that last touches a file names its exact answer, every step its commit's
# subject – abutting edits, each stop resolved to its own commit's change alone
_ST_PZ_NEW cg6
_ST_PZ_C run.sh $'#!/bin/sh\necho run\necho end' "CG6 base" && _ST_PZ_C notes.txt n "CG6 notes"
_ST_PZ_C run.sh $'#!/bin/sh\necho run X\necho end' "CG6 X" && _ST_PZ_C notes.txt $'n\nline 2' "CG6 notes 2"
_ST_PZ_C run.sh $'#!/bin/sh\necho run X\necho end Y' "CG6 Y"
CG_PRE=$(git rev-parse HEAD)
_ST_RUN --move=HEAD --before=HEAD~2
_ST_RESOLVE "$(_ST_PZ_WT)" run.sh $'#!/bin/sh\necho run\necho end Y'
_ST_RUN --continue
_ST_OUT_HAS "a step no later one touches names the pre-op content as its answer" "No later step touches run.sh"
_ST_OUT_HAS "each remaining step with its subject" 'pick [0-9a-f]* # CG6 notes 2'
# A resolution there that changes what the tip holds lands nothing – a reorder only moves commits
_ST_RESOLVE "$(_ST_PZ_WT)" run.sh $'#!/bin/sh\necho run X\necho end Y X'
_ST_RUN --continue
_ST_EQ "a reorder whose resolution changed the tree refuses, nothing landed" "${RC}:$(git rev-parse HEAD)" "1:$CG_PRE"
_ST_OUT_HAS "naming the file it changed" 'no longer ends on the tree it began with – a resolution changed run.sh'
_ST_RUN --abort
# A later step renaming the conflicted file away touches it, so no exact answer is claimed for it
_ST_PZ_NEW cg6b
_ST_PZ_C f.txt $'old 1\nold 2\nold 3\nold 4' "CG6b A" && _ST_PZ_C z.txt z "CG6b Z"
git mv f.txt g.txt && git commit -qm "CG6b rename f to g"
_ST_PZ_C f.txt $'new 1\nnew 2' "CG6b new f"
_ST_RUN --reorder HEAD HEAD~1
_ST_OUT_HAS "a step renaming the file counts as touching it" 'rebuilds a state that never existed for f.txt'
_ST_OUT_LACKS "and no exact answer is offered" 'No later step touches f.txt'
_ST_RUN --abort
# An undo refused after a peer's landing names a rewrite, not a compare-and-swap that must fail
_ST_PZ_NEW cg7
_ST_PZ_C a.txt a "CG7 A"
GIT_EDIT_ACTOR=cg-me _ST_RUN -M --text "CG7 A reworded" HEAD
print -r -- p > p.txt
GIT_EDIT_ACTOR=cg-peer _ST_RUN --commit --text "CG7 peer" -- p.txt
GIT_EDIT_ACTOR=cg-me _ST_RUN --undo
_ST_OUT_HAS "an undo past a peer's landing names a rewrite to take it back" 'take it back with a rewrite of its own'
# A zero-padded id picks the scenario its file spells
OUT=$("$SELF" --selftest=022 </dev/null 2>&1)
_ST_TRAILER_LAST
_ST_OUT_HAS "a zero-padded --selftest id picks its scenario" 'git-edit: ok – selftest [0-9/]* passed – scenario 22 (1 of'
cd "$TMP/repo"
