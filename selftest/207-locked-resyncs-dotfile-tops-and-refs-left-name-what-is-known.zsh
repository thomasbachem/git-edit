# Printed steps hold where they're run, and a ref left in a rewrite is named by what is known of it
# • A work tree only `GIT_DIR` reaches is told a concrete `.git` file only at a top it knows – the cwd
#   bearing it out, or `core.worktree` – never one in a subdirectory, every tracked file deleted there
# • A locked index's re-sync step – a fold's, another checkout's, a carry's – resets only entries
#   still as the run read them, a peer's staging since kept and listed, even one a textconv hides,
#   and runs as printed in sh, bash and zsh, from the top and from a subdirectory
# • A tag or branch on a commit the run dropped or squashed is named so, a tag takes the exact pair
#   a branch does, and a subject match alone is offered as a guess
_ST_SCENARIO "\e[1;96m[207] locked re-syncs keep a peer's staging, dotfile tops, refs left named by what is known\e[0m"
local RL_P RL_CMD RL_STEP RL_GD RL_WT RL_OLD RL_NEW RL_PEER RL_SO RL_RC RL_B RL_T RL_F
local RL_NAP=$TMP/rl-nap
mkdir -p "$RL_NAP" && print -l '#!/bin/sh' 'exit 0' > "$RL_NAP/sleep" && chmod +x "$RL_NAP/sleep"
# Writes <git dir>'s reference-transaction hook, which takes <lock> once the branch's move commits –
# an index locked past the run's wait, as a peer's long `add` holds one, the wait cut short
_RL_LOCK_HOOK () {
	# Args: <git dir> <lock file>
	mkdir -p "$1/hooks"
	printf '#!/bin/sh\n[ "$1" = committed ] || exit 0\ngrep -q " refs/heads/main$" || exit 0\n: > %s\n' "${(qq)2}" > "$1/hooks/reference-transaction"
	chmod +x "$1/hooks/reference-transaction"
}
# Frees <lock> and takes <git dir>'s hook out
_RL_UNLOCK () {
	# Args: <git dir> <lock file>
	mv -f "$2" "$2.gone" 2>/dev/null
	mv -f "$1/hooks/reference-transaction" "$1/hooks/reference-transaction.off" 2>/dev/null
}
# Runs <step> in <shell> as a person pastes it, leaving its output in `RL_SO` and status in `RL_RC`
_RL_PASTE () {
	# Args: <shell> <step>
	RL_SO=$("$1" -c "$2" 2>&1)
	RL_RC=$?
}
RL_F="sub/it's a \"q\" x.txt"

# A work tree only `GIT_DIR` names, run from a subdirectory with nothing naming its top, is told to
# write the `.git` file at its top, no path given – once, its subdirectory, every file then deleted
RL_P=$TMP/rl1
mkdir -p "$RL_P/wt/sub"
git init -q --bare "$RL_P/repo.git" && git --git-dir="$RL_P/repo.git" config core.bare false
cd "$RL_P/wt"
export GIT_DIR=$RL_P/repo.git
git config user.email p@x.invalid && git config user.name P
print -r -- a > a.txt && print -r -- s > sub/s.txt && git add a.txt sub/s.txt && git commit -qm "RL1 base"
cd sub
_ST_RUN -M --text "RL1 x" HEAD
unset GIT_DIR
_ST_EQ "a GIT_DIR work tree run from a subdirectory refuses" "$RC:$(git --git-dir="$RL_P/repo.git" log -1 --format=%s)" "1:RL1 base"
_ST_OUT_HAS "naming the .git file at its top, no path given" "> '<top of the work tree>/.git'"
_ST_OUT_LACKS "never one in this subdirectory" "$RL_P/wt/sub/\.git"
# From the top, every tracked file there, the step names it and works as printed
cd "$RL_P/wt"
export GIT_DIR=$RL_P/repo.git
_ST_RUN -M --text "RL1 x" HEAD
unset GIT_DIR
_ST_OUT_HAS "run from the top it names the top" "> '*$(pwd -P)/\.git'*\$"
RL_CMD=$(print -r -- "$OUT" | sed -n 's/.*then run git edit without GIT_DIR: //p' | head -1)
eval "$RL_CMD"
cd sub
_ST_EQ "which written, the checkout reads clean from anywhere in it" "$(git status --short):$(git rev-parse --show-toplevel)" ":$(cd "$RL_P/wt" && pwd -P)"
# `core.worktree` names the top – relative to the git dir, taken absolute – from a subdirectory too
RL_P=$TMP/rl1c
mkdir -p "$RL_P/wt/sub"
git init -q --bare "$RL_P/repo.git" && git --git-dir="$RL_P/repo.git" config core.bare false && git --git-dir="$RL_P/repo.git" config core.worktree ../wt
cd "$RL_P/wt/sub"
export GIT_DIR=$RL_P/repo.git
git config user.email p@x.invalid && git config user.name P
print -r -- a > ../a.txt && print -r -- s > s.txt && git add ../a.txt s.txt && git commit -qm "RL1C base"
_ST_RUN -M --text "RL1C x" HEAD
unset GIT_DIR
_ST_EQ "a core.worktree work tree refuses too" "$RC" "1"
_ST_OUT_HAS "naming its top from a subdirectory" "> '*$(cd "$RL_P/wt" && pwd -P)/\.git'*\$"
RL_CMD=$(print -r -- "$OUT" | sed -n 's/.*then run git edit without GIT_DIR: //p' | head -1)
eval "$RL_CMD"
_ST_EQ "which run there leaves it clean, its top the same" "$(git status --short):$(git rev-parse --show-toplevel)" ":$(cd "$RL_P/wt" && pwd -P)"
_ST_RUN -M --text "RL1C x" HEAD
_ST_EQ "and git edit then runs" "$RC:$(git log -1 --format=%s)" "0:RL1C x"

# A staged fold whose re-sync met a locked index prints a step that resets only entries still as
# the fold read them – a peer's staging since kept and listed, run from a subdirectory in sh
_ST_PZ_NEW rl2
mkdir sub
_ST_PZ_C a.txt a "RL2 base" && _ST_PZ_C "$RL_F" one "RL2 f" && _ST_PZ_C g.txt g "RL2 g"
RL_GD=$(git rev-parse --absolute-git-dir)
_RL_LOCK_HOOK "$RL_GD" "$RL_GD/index.lock"
print -r -- two > "$RL_F" && git add -- "$RL_F"
cd sub
PATH="$RL_NAP:$PATH" _ST_RUN --amend-into=HEAD~1
_ST_EQ "the fold lands, its index locked after" "$RC:$(git show "HEAD~1:$RL_F")" "0:two"
_ST_OUT_HAS "naming the entry not re-synced" "Not re-synced, the index was locked: $RL_F"
RL_STEP=$(print -r -- "$OUT" | sed -n 's/.*once it is free, re-sync each still as the fold read it: //p' | head -1)
_ST_OUT_HAS "with a step that resets only what the fold read" "re-sync each still as the fold read it: cd .* && git diff-index --cached --exit-code --name-only [0-9a-f]\{12\} -- .* && git reset -q -- "
_RL_UNLOCK "$RL_GD" "$RL_GD/index.lock"
print -r -- peer > "../$RL_F" && git add -- "../$RL_F"
RL_PEER=$(git rev-parse ":../$RL_F")
_RL_PASTE sh "$RL_STEP"
_ST_EQ "a peer's staging since survives the step, in sh from a subdirectory" "$RL_RC:$(git rev-parse ":../$RL_F")" "1:$RL_PEER"
_ST_EQ "which lists it" "$(print -r -- "$RL_SO" | grep -c 'q')" "1"
# Unchanged since, the entry is re-synced – to a tip a peer's landing moved on meanwhile – in zsh
git reset -q -- "../$RL_F" && print -r -- two > "../$RL_F" && git add -- "../$RL_F"
RL_B=$(print -r -- three | git hash-object -w --stdin)
GIT_INDEX_FILE=$TMP/rl2.idx git -C .. read-tree HEAD
GIT_INDEX_FILE=$TMP/rl2.idx git -C .. update-index --cacheinfo "100644,$RL_B,$RL_F"
RL_T=$(GIT_INDEX_FILE=$TMP/rl2.idx git -C .. write-tree)
git update-ref refs/heads/main "$(git commit-tree -p HEAD -m "RL2 peer landing" "$RL_T")"
_RL_PASTE zsh "$RL_STEP"
_ST_EQ "an entry as the fold read it is re-synced, in zsh" "$RL_RC:$(git rev-parse ":../$RL_F")" "0:$RL_B"

# A peer's staged change a textconv view hides survives too – its guard is plumbing, which runs none –
# the view here a file's first line, which the fold changes and the peer's change keeps
_ST_PZ_NEW rl2t
print -l '#!/bin/sh' 'sed 1q "$1"' > "$TMP/rl-tc" && chmod +x "$TMP/rl-tc"
git config diff.rltc.textconv "$TMP/rl-tc"
print -r -- '*.tc diff=rltc' > .gitattributes && git add .gitattributes && git commit -qm "RL2T base"
print -l a 1 > "x y.tc" && git add -- "x y.tc" && git commit -qm "RL2T f" && _ST_PZ_C g.txt g "RL2T g"
RL_GD=$(git rev-parse --absolute-git-dir)
_RL_LOCK_HOOK "$RL_GD" "$RL_GD/index.lock"
print -l b 1 > "x y.tc" && git add -- "x y.tc"
PATH="$RL_NAP:$PATH" _ST_RUN --amend-into=HEAD~1
RL_STEP=$(print -r -- "$OUT" | sed -n 's/.*once it is free, re-sync each still as the fold read it: //p' | head -1)
_ST_EQ "a fold under a textconv driver prints the step from the top, no cd" "$RC:${RL_STEP%% *}" "0:git"
_RL_UNLOCK "$RL_GD" "$RL_GD/index.lock"
print -l b 2 > "x y.tc" && git add -- "x y.tc"
RL_PEER=$(git rev-parse ":x y.tc")
_RL_PASTE bash "$RL_STEP"
_ST_EQ "a peer's change only textconv hides survives the step, in bash from the top" "$RL_RC:$(git rev-parse ":x y.tc")" "1:$RL_PEER"

# Another checkout of the branch whose index was locked is told a step resetting only entries still on
# the pre-rewrite tip – run in zsh from its subdirectory, a peer's staging there kept
_ST_PZ_NEW rl3
mkdir sub
_ST_PZ_C a.txt a "RL3 base" && _ST_PZ_C "$RL_F" one "RL3 f" && _ST_PZ_C "$RL_F" two "RL3 f two" && _ST_PZ_C g.txt g "RL3 g"
RL_WT=$TMP/rl3-wt
git worktree add -q -f "$RL_WT" main
RL_GD=$(git -C "$RL_WT" rev-parse --absolute-git-dir)
_RL_LOCK_HOOK "$(git rev-parse --git-common-dir)" "$RL_GD/index.lock"
RL_OLD=$(git rev-parse HEAD)
PATH="$RL_NAP:$PATH" _ST_RUN -d -y "$(git rev-parse HEAD~1)"
_ST_EQ "the drop lands, the other checkout's index locked" "$RC:$(git show "HEAD:$RL_F")" "0:one"
_ST_OUT_HAS "naming its entry not re-synced" "Its index entries not re-synced, the index was locked: $RL_F"
RL_STEP=$(print -r -- "$OUT" | sed -n 's/.*Re-sync each still on the pre-rewrite tip once it is free: //p' | head -1)
_ST_OUT_HAS "with a guarded step" "once it is free: cd .* && git diff-index --cached --exit-code --name-only [0-9a-f]\{12\} -- .* && git restore --source=[0-9a-f]\{12\} --staged -- "
_RL_UNLOCK "$(git rev-parse --git-common-dir)" "$RL_GD/index.lock"
print -r -- peer > "$RL_WT/$RL_F" && git -C "$RL_WT" add -- "$RL_F"
RL_PEER=$(git -C "$RL_WT" rev-parse ":$RL_F")
cd "$RL_WT/sub"
_RL_PASTE zsh "$RL_STEP"
_ST_EQ "a peer's staging there since survives, in zsh from a subdirectory" "$RL_RC:$(git rev-parse ":../$RL_F")" "1:$RL_PEER"
# Unchanged since, it is re-synced to the new tip, in sh
git -C "$RL_WT" update-index --cacheinfo "100644,$(git rev-parse "$RL_OLD:$RL_F"),$RL_F"
_RL_PASTE sh "$RL_STEP"
_ST_EQ "an entry still as before is re-synced, in sh" "$RL_RC:$(git rev-parse ":../$RL_F")" "0:$(git rev-parse "main:$RL_F")"

# A carry whose index was locked prints a step guarded the same way – run in bash from a subdirectory
_ST_PZ_NEW rl4
mkdir sub
print -l 1 2 3 4 5 > "$RL_F" && git add -- "$RL_F" && git commit -qm "RL4 base"
print -l 1 2 3 4 5 6 > "$RL_F" && git commit -qam "RL4 add 6"
RL_OLD=$(git rev-parse HEAD)
RL_B=$(print -l 1 2 3 4 5 six | git hash-object -w --stdin)
GIT_INDEX_FILE=$TMP/rl4.idx git read-tree HEAD~1
GIT_INDEX_FILE=$TMP/rl4.idx git update-index --cacheinfo "100644,$RL_B,$RL_F"
RL_T=$(GIT_INDEX_FILE=$TMP/rl4.idx git write-tree)
RL_NEW=$(git commit-tree -p HEAD~1 -m "RL4 add 6 alt" "$RL_T")
git update-ref refs/heads/main "$RL_NEW" "$RL_OLD"
print -l one 2 3 4 5 6 > "$RL_F"
RL_GD=$(git rev-parse --absolute-git-dir)
: > "$RL_GD/index.lock"
cd sub
PATH="$RL_NAP:$PATH" _ST_RUN --carry="$RL_OLD"
_ST_EQ "the carry writes the file, its entry left by the lock" "$RC:$(<"../$RL_F")" "1:$(print -l one 2 3 4 5 six)"
RL_STEP=$(print -r -- "$OUT" | sed -n 's/^Index entries left on the pre-rewrite content.*the files left as they are: //p' | head -1)
_ST_OUT_HAS "with a guarded step" "the files left as they are: cd .* && git diff-index --cached --exit-code --name-only ${RL_OLD:0:12} -- .* && git restore --source=HEAD --staged -- "
_RL_UNLOCK "$RL_GD" "$RL_GD/index.lock"
print -r -- peer > "$TMP/rl4.peer" && RL_PEER=$(git hash-object -w "$TMP/rl4.peer")
git -C .. update-index --cacheinfo "100644,$RL_PEER,$RL_F"
_RL_PASTE bash "$RL_STEP"
_ST_EQ "a peer's staging since survives, in bash from a subdirectory" "$RL_RC:$(git rev-parse ":../$RL_F")" "1:$RL_PEER"
git -C .. update-index --cacheinfo "100644,$(git rev-parse "$RL_OLD:$RL_F"),$RL_F"
_RL_PASTE sh "$RL_STEP"
_ST_EQ "an entry still on the pre-rewrite content is re-synced, in sh" "$RL_RC:$(git rev-parse ":../$RL_F")" "0:$RL_B"

# A tag and a branch on a commit a drop took out are named as dropped – never re-pointed to a later
# commit sharing its subject
_ST_PZ_NEW rl5
_ST_PZ_C a.txt a "RL5 base" && _ST_PZ_C b.txt b "RL5 fix typo" && _ST_PZ_C c.txt c "RL5 feature" && _ST_PZ_C d.txt d "RL5 fix typo"
git tag rl5-tag HEAD~2 && git branch rl5-side HEAD~2
_ST_RUN -d -y "$(git rev-parse HEAD~2)"
_ST_EQ "the drop lands" "$RC:$(git log -1 --format=%s HEAD~1)" "0:RL5 feature"
_ST_OUT_HAS "a tag on the dropped commit is named so" '^Tag rl5-tag points at a commit this run dropped, with no counterpart in the new span'
_ST_OUT_HAS "as is a branch" '^Branch rl5-side points at a commit this run dropped, with no counterpart in the new span'
_ST_OUT_LACKS "neither re-pointed to the commit sharing its subject" "git \(tag\|branch\) -f rl5-"

# A reword's exact pair names the counterpart of an annotated tag as of a branch, and the tag's
# command re-points it there, annotated still
_ST_PZ_NEW rl6
_ST_PZ_C a.txt a "RL6 base" && _ST_PZ_C b.txt b "RL6 b" && _ST_PZ_C c.txt c "RL6 c"
git tag -a -m "RL6 notes" rl6-tag HEAD~1 && git branch rl6-side HEAD~1
_ST_RUN -M --text "RL6 b reworded" HEAD~1
_ST_EQ "the reword lands" "$RC:$(git log -1 --format=%s HEAD~1)" "0:RL6 b reworded"
_ST_OUT_HAS "the tag is offered its exact counterpart" '^Tag rl6-tag points into the rewritten span – re-point it to its counterpart, the same change: RL6 b$'
_ST_OUT_HAS "with the command naming it" "git tag -f -a -F - rl6-tag $(git rev-parse --short=12 HEAD~1)\$"
_ST_OUT_HAS "as the branch is" "git branch -f rl6-side $(git rev-parse --short=12 HEAD~1)\$"
eval "$(print -r -- "$OUT" | sed -n 's/^  \(git for-each-ref .*git tag -f -a -F - rl6-tag [0-9a-f]*\)$/\1/p')"
_ST_EQ "which run re-points the annotated tag there" "$(git rev-parse "rl6-tag^{commit}"):$(git cat-file -t rl6-tag):$(git for-each-ref --format='%(contents:subject)' refs/tags/rl6-tag)" "$(git rev-parse HEAD~1):tag:RL6 notes"

# A squash's member is named as squashed into the commit it went into – by a rebase and by plumbing
_ST_PZ_NEW rl7
_ST_PZ_C a.txt a "RL7 base" && _ST_PZ_C b.txt b "RL7 b" && _ST_PZ_C c.txt c "RL7 c" && _ST_PZ_C d.txt d "RL7 d"
git tag rl7-tag HEAD && git branch rl7-side HEAD
_ST_RUN -s="$(git rev-parse HEAD~2)" -y "$(git rev-parse HEAD)"
_ST_EQ "the squash lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:RL7 c|RL7 b|RL7 base|"
_ST_OUT_HAS "a tag on a squashed member names the commit it went into" "^Tag rl7-tag points at a commit this run squashed into $(git rev-parse --short=12 HEAD~1) – "
_ST_OUT_HAS "with the command re-pointing it there" "^  git tag -f rl7-tag $(git rev-parse --short=12 HEAD~1)\$"
_ST_OUT_HAS "as a branch does" "^Branch rl7-side points at a commit this run squashed into $(git rev-parse --short=12 HEAD~1) – "
_ST_PZ_NEW rl7p
_ST_PZ_C a.txt a "RL7P base" && _ST_PZ_C b.txt b "RL7P b" && _ST_PZ_C c.txt c "RL7P c" && _ST_PZ_C d.txt d "RL7P d"
git tag rl7p-tag HEAD~1
_ST_RUN -S -y "$(git rev-parse HEAD~2)" "$(git rev-parse HEAD~1)"
_ST_OUT_HAS "a plumbing squash names its member the same way" "^Tag rl7p-tag points at a commit this run squashed into $(git rev-parse --short=12 HEAD~1) – "

# Where no pair is known, a commit sharing the subject is offered as a guess to check, never as the
# counterpart – a drop's replay changing the context of the tagged commit's diff
_ST_PZ_NEW rl8
print -l 1 2 3 4 5 6 7 8 > f.txt && git add f.txt && git commit -qm "RL8 base"
print -l 1 two 3 4 5 6 7 8 > f.txt && git commit -qam "RL8 two"
print -l 1 two 3 4 five 6 7 8 > f.txt && git commit -qam "RL8 five"
git tag rl8-tag HEAD
_ST_RUN -d -y "$(git rev-parse HEAD~1)"
_ST_EQ "the drop lands, the later change replayed" "$RC:$(git show HEAD:f.txt | tr '\n' ' ')" "0:1 2 3 4 five 6 7 8 "
_ST_OUT_HAS "the tag is offered a guess by subject, to check" "^Tag rl8-tag points into the rewritten span – a guess at its counterpart, by its subject alone, to check is the same change before re-pointing it: RL8 five\$"
_ST_OUT_HAS "its command naming that commit" "^  git tag -f rl8-tag $(git rev-parse --short=12 HEAD)\$"
_ST_OUT_LACKS "never called its counterpart" "^Tag rl8-tag .*re-point it to its counterpart"
