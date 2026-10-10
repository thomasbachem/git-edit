# An agent's run brings the checkout it acted in along as a terminal run's does – a land, a commit,
# a fold, a drop and a replant alike: files nobody touched take what landed, edits merge onto it, a
# conflicting merge writes nothing and names its `git merge-file` whose call it is, staging in a
# path's way and a peer's write during the sync stay, and no `git clean` or restore of a file is
# printed – a partly staged file left named with the carry, for whoever's the staging is
# • What a run leaves to do prints right above the trailer – after a land's landed-commit list, and
#   right above a commit line with one pointer line between it and the trailer
# • Two landings a second apart on one file leave both changes, the second's sync waiting for the
#   first's – read old, it would merge the first's change back out as an uncommitted edit
# • An undo of a land, a drop or an `--exec` rewrite brings the checkout back the same way, one of a
#   fold, a commit or an `--exec` only adding commits leaving what it landed as uncommitted changes
# • The raw undo's index-only step is named, with the carry where `--undo` would bring files back
# • A branch checked out twice: the sync holds the checkout it writes, the carry named for the other
# • Where the sync can't run – its index locked past the wait – one `--carry` is named, which keeps
#   a peer's staging made after the run
_ST_SCENARIO "\e[1;96m[203] every run brings the checkout along, an agent's too\e[0m"
local SY_T SY_F SY_OUT SY_PID SY_B
export GIT_EDIT_ACTOR=sy-agent
# Writes `<dir>/git` standing in for the real one, running <script> where <dir>/arm is there and
# <case pattern> takes the call's arguments – before the call, or with `after` once it returned
_SY_STAND_IN () {
	# Args: <dir> <case pattern> <script> [after]
	mkdir -p "$1"
	{
		print -r -- '#!/bin/sh'
		if [ "$4" = after ]; then
			print -r -- "${(q)commands[git]} \"\$@\"; rc=\$?"
			print -r -- "case \" \$* \" in $2) if [ -e ${(q)1}/arm ]; then $3; fi ;; esac"
			print -r -- 'exit $rc'
		else
			print -r -- "case \" \$* \" in $2) if [ -e ${(q)1}/arm ]; then $3; fi ;; esac"
			print -r -- "exec ${(q)commands[git]} \"\$@\""
		fi
	} > "$1/git"
	chmod +x "$1/git"
}

# A land into a checkout holding an untouched, an edited, a conflicting, a removed and an added file
_ST_PZ_NEW sy1
for SY_F in u e c r; do print -l 1 2 3 4 5 > $SY_F.txt; done
git add -A && git commit -qm "SY base"
SY_T=$(git rev-parse HEAD)
git worktree add -q -b feat "$TMP/sy1-wt" main 2>/dev/null
( cd "$TMP/sy1-wt" && for SY_F in u e c; do sed -i.bak 's/^3$/3 feat/' $SY_F.txt; done && rm -f *.bak && git rm -q r.txt && print new > a.txt && git add -A && git commit -qm "SY feat" )
sed -i.bak 's/^5$/5 mine/' e.txt && sed -i.bak 's/^3$/3 peer/' c.txt && rm -f *.bak
_ST_RUN --land=feat
_ST_EQ "an agent's land lands" "$RC:$(git log -1 --format=%s)" "0:SY feat"
_ST_EQ "the untouched file takes what landed, the added one comes, the removed one goes" \
	"$(sed -n 3p u.txt):$(<a.txt):$([ -e r.txt ] || echo gone)" "3 feat:new:gone"
_ST_EQ "edits beside what landed merge onto it" "$(tr '\n' ' ' < e.txt)" "1 2 3 feat 4 5 mine "
_ST_EQ "a conflicting file is left as it was, as changes to what landed" \
	"$(tr '\n' ' ' < c.txt):$(git show :c.txt | sed -n 3p)" "1 2 3 peer 4 5 :3 feat"
_ST_EQ "nothing else differs from the tip" "$(git status --short | LC_ALL=C sort | tr '\n' '|')" " M c.txt| M e.txt|"
_ST_OUT_HAS "naming what came along" 'Your checkout came along – now as they landed: a.txt, r.txt, u.txt'
_ST_OUT_HAS "and what it took out, with the way back" 'Taken out of your checkout with the landing: r.txt – back with git edit --undo while that is the last run'
_ST_OUT_HAS "an agent's conflict says whose call the merge is" '^If those edits are yours, merge them, markers and all.* – if another session.s, leave them'
_ST_OUT_LACKS "never the caller's own edits" 'Your uncommitted edits conflict'
_ST_EQ "the merge prints after the landed-commit list, then the trailer" \
	"$(print -r -- "$OUT" | tail -5 | cut -c1-12 | tr '\n' '|')" "Landed 1 of |  ${$(git rev-parse HEAD):0:7} SY|If those edi|  T=\$(mktemp|git-edit: ok|"
_ST_OUT_LACKS "no restore of a file or clean is printed" 'git restore \(--source\|--worktree\|-- \)\|git clean'
# Undone, the land takes the checkout back the same way, the edits kept on top
_ST_RUN --undo
_ST_EQ "an undone land brings the checkout back" \
	"$RC:$(sed -n 3p u.txt):$(tr '\n' ' ' < r.txt):$([ -e a.txt ] || echo gone):$(tr '\n' ' ' < e.txt)" "0:3:1 2 3 4 5 :gone:1 2 3 4 5 mine "
_ST_EQ "the conflict still left as it was, nothing staged" "$(git status --short | LC_ALL=C sort | tr '\n' '|')" " M c.txt| M e.txt|"
git checkout -q -- c.txt e.txt

# A commit composed from the caller's edits takes the file's entry alone where the merge leaves
# the file as it is – a peer's line beside them kept, the file never written – and a conflict's
# merge prints right above the commit line, one pointer line between it and the trailer
_ST_PZ_NEW sy2
print -l 1 2 3 4 5 > f.txt && print -l 1 2 3 > g.txt && git add -A && git commit -qm "SY2 base"
print -l 1 2 3 4 5 peer > f.txt && sed -i.bak 's/^2$/2 mine/' f.txt && rm -f f.txt.bak
print -l 1 2peer 3 > g.txt
SY_F=$(command ls -i f.txt | awk '{print $1}')
_ST_RUN --commit --text "SY2 commit" --edits '{"f.txt": [["2\n", "2 mine\n"]], "g.txt": [["2\n", "2 own\n"]]}'
_ST_EQ "an agent's composed commit lands" "$RC:$(git show HEAD:f.txt | tr '\n' ' ')" "0:1 2 mine 3 4 5 "
_ST_EQ "the file holding the edit stays as it was, never written" \
	"$(tr '\n' ' ' < f.txt):$(command ls -i f.txt | awk '{print $1}'):$(git diff --name-only HEAD -- f.txt)" "1 2 mine 3 4 5 peer :$SY_F:f.txt"
_ST_EQ "its entry takes what landed, the peer's line unstaged" "$(git diff --cached --name-only)" ""
_ST_EQ "the conflicting one left as it was" "$(tr '\n' ' ' < g.txt):$(git show :g.txt | tr '\n' ' ')" "1 2peer 3 :1 2 own 3 "
_ST_EQ "its merge right above the commit line, a pointer above the trailer" \
	"$(print -r -- "$OUT" | tail -4 | cut -c1-12 | tr '\n' '|')" "  T=\$(mktemp|  committed:|Still to do,|git-edit: ok|"
_ST_OUT_HAS "the pointer names the merge" '^Still to do, as named above: the merge of g.txt, if those edits are yours$'
# Undone, a commit keeps what it landed as uncommitted changes, as it may have come from the checkout
git checkout -q -- g.txt
_ST_RUN --undo
_ST_EQ "an undone commit keeps its content in the checkout" "$RC:$(tr '\n' ' ' < f.txt):$(git diff --cached --name-only)" "0:1 2 mine 3 4 5 peer :"
_ST_OUT_HAS "naming it as uncommitted changes" 'what the undone run landed stays in your checkout, as uncommitted changes: f.txt'

# A fold brings the checkout along, a drop too – the dropped content leaving it, with the way back –
# and an undo of each does what its kind does
_ST_PZ_NEW sy3
print -l 1 2 3 > f.txt && print -l a b > d.txt && git add -A && git commit -qm "SY3 base"
SY_B=$(git rev-parse HEAD)
print -l 1 2 3 4 > f.txt && git commit -qam "SY3 grow"
print -l a b c > d.txt && print gone > x.txt && git add -A && git commit -qm "SY3 drop me"
print top > t.txt && git add t.txt && git commit -qm "SY3 top"
_ST_RUN --amend-into="$SY_B" --edits '{"f.txt": [["2\n", "2 fold\n"]]}'
_ST_EQ "an agent's fold brings the file along" "$RC:$(tr '\n' ' ' < f.txt):$(git status --short)" "0:1 2 fold 3 4 :"
_ST_RUN --undo
_ST_EQ "an undone fold keeps what it landed as uncommitted changes" "$RC:$(tr '\n' ' ' < f.txt):$(git status --short)" "0:1 2 fold 3 4 : M f.txt"
git checkout -q -- f.txt
_ST_RUN -d -y HEAD~1
_ST_EQ "an agent's drop takes the dropped content out of the checkout" "$RC:$(tr '\n' ' ' < d.txt):$([ -e x.txt ] || echo gone):$(git status --short)" "0:a b :gone:"
_ST_OUT_HAS "naming it with the way back" "Taken out of your checkout with the rewrite: .*x\.txt – back with git edit --undo while that is the last run, else git show [0-9a-f]\{12\}:<path>"
_ST_OUT_LACKS "never a restore or clean" 'git restore \(--source\|--worktree\|-- \)\|git clean\|Keep it, or discard'
_ST_RUN --undo
_ST_EQ "an undone drop brings it back" "$RC:$(tr '\n' ' ' < d.txt):$(<x.txt):$(git status --short)" "0:a b c :gone:"

# A replant brings a linked worktree's checkout along – the read-tree that refused the lot is gone
_ST_PZ_NEW sy4
print -l 1 2 3 > f.txt && print o > o.txt && git add -A && git commit -qm "SY4 base"
git worktree add -q -b topic "$TMP/sy4-wt" main 2>/dev/null
( cd "$TMP/sy4-wt" && print t > t.txt && git add t.txt && git commit -qm "SY4 topic" && print own >> o.txt )
print -l 1 2 3 4 > f.txt && git commit -qam "SY4 main"
cd "$TMP/sy4-wt"
_ST_RUN --onto=main
_ST_EQ "an agent's replant brings its checkout along" "$RC:$(tr '\n' ' ' < f.txt):$(git status --short)" "0:1 2 3 4 : M o.txt"
_ST_OUT_LACKS "naming no read-tree" 'read-tree'
cd "$TMP/pz-sy4"
git worktree remove --force "$TMP/sy4-wt"

# A peer writing a file between the sync's read and its write keeps what it wrote, named; staging
# in a path's way stays
_ST_PZ_NEW sy5
print -l 1 2 3 4 5 > e.txt && git add -A && git commit -qm "SY5 base"
git worktree add -q -b feat "$TMP/sy5-wt" main 2>/dev/null
( cd "$TMP/sy5-wt" && sed -i.bak 's/^3$/3 feat/' e.txt && rm -f e.txt.bak && mkdir d && print n > d/n.txt && git add -A && git commit -qm "SY5 feat" )
sed -i.bak 's/^5$/5 mine/' e.txt && rm -f e.txt.bak
print staged > d && git add d
_SY_STAND_IN "$TMP/sy5-git" '*" merge-file -p "*' "echo 'peer wrote this' > ${(q)PWD}/e.txt; rm -f ${(q)TMP}/sy5-git/arm" after
: > "$TMP/sy5-git/arm"
OUT=$(PATH="$TMP/sy5-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --land=feat </dev/null 2>&1)
RC=$?
_ST_EQ "a peer's write during the sync is kept as written" "$RC:$(<e.txt)" "0:peer wrote this"
_ST_OUT_HAS "named as changed while it ran" 'e.txt – changed while it ran'
_ST_EQ "staging in a path's way stays, the path not written" "$(git show :d):$([ -e d/n.txt ] || echo absent)" "staged:absent"
_ST_OUT_HAS "named with what is in its way" 'd/n.txt – '
git worktree remove --force "$TMP/sy5-wt"

# Two landings a second apart on one file: the second waits for the first's sync, which a stand-in
# holds between its read and its write, and the file ends with both changes and nothing uncommitted
_ST_PZ_NEW sy6
print -l 1 2 3 4 5 6 > f.txt && git add -A && git commit -qm "SY6 base"
git worktree add -q -b one "$TMP/sy6-one" main 2>/dev/null
git worktree add -q -b two "$TMP/sy6-two" main 2>/dev/null
( cd "$TMP/sy6-one" && sed -i.bak 's/^2$/2 one/' f.txt && rm -f f.txt.bak && git commit -qam "SY6 one" )
( cd "$TMP/sy6-two" && sed -i.bak 's/^5$/5 two/' f.txt && rm -f f.txt.bak && git commit -qam "SY6 two" )
_SY_STAND_IN "$TMP/sy6-git" '*" ls-files -v -z "*' "rm -f ${(q)TMP}/sy6-git/arm; : > ${(q)TMP}/sy6-in; ${(q)TMP}/st-hold ${(q)TMP}/sy6-go"
: > "$TMP/sy6-git/arm"
( PATH="$TMP/sy6-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --land=one </dev/null > "$TMP/sy6.1" 2>&1 ) &
SY_PID=$!
local -i SY_I=0
until [ -e "$TMP/sy6-in" ] || ! kill -0 $SY_PID 2>/dev/null || (( ++SY_I > 600 )); do sleep 0.1; done
( GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --land=two </dev/null > "$TMP/sy6.2" 2>&1 ) &
# Its move reached, it gets 3 s to sync – done meanwhile only where nothing holds it back
SY_I=0
until grep -q 'update-ref' "$TMP/sy6.2" 2>/dev/null || (( ++SY_I > 600 )); do sleep 0.1; done
SY_I=0
until grep -q '^git-edit:' "$TMP/sy6.2" 2>/dev/null || (( ++SY_I > 30 )); do sleep 0.1; done
: > "$TMP/sy6-go"
wait
_ST_EQ "both landings land" "$(git log --format=%s | tr '\n' '|')" "SY6 two|SY6 one|SY6 base|"
_ST_EQ "the file ends with both changes, nothing uncommitted" "$(tr '\n' ' ' < f.txt):$(git status --short)" "1 2 one 3 4 5 two 6 :"
_ST_EQ "and no hold left behind" "$(command ls .git | grep -c 'git-edit-sync')" "0"
git worktree remove --force "$TMP/sy6-one"; git worktree remove --force "$TMP/sy6-two"

# The steps printed name `git edit`, run as printed through a link on `PATH`
mkdir -p "$TMP/sy-bin" && ln -sf "$SELF" "$TMP/sy-bin/git-edit"

# Its index locked past the wait, the checkout is left with one carry to run, never a restore – and
# run once a peer staged one of the paths since, it keeps that staging
_ST_PZ_NEW sy7
print -l 1 2 3 > f.txt && print -l 1 2 3 > g.txt && git add -A && git commit -qm "SY7 base"
git worktree add -q -b feat "$TMP/sy7-wt" main 2>/dev/null
( cd "$TMP/sy7-wt" && print -l 1 2 3 f > f.txt && print -l 1 2 3 g > g.txt && git commit -qam "SY7 feat" )
: > .git/index.lock
_ST_RUN --land=feat
rm -f .git/index.lock
_ST_EQ "a land with the index locked lands" "$RC:$(git log -1 --format=%s):$(tr '\n' ' ' < f.txt)" "0:SY7 feat:1 2 3 "
_ST_OUT_HAS "naming why the checkout was not brought along" 'Your checkout was not brought along – its index was locked by another run past the wait\.'
_ST_OUT_HAS "and the carry, right above the trailer" "^Once that is done, bring your checkout along – files to what landed, edits merged onto it: git edit --carry=${$(git rev-parse HEAD~1):0:12}$"
_ST_OUT_LACKS "no restore of a file or clean is printed" 'git restore \(--source\|--worktree\|-- \)\|git clean'
print -l 1 2 peer > g.txt && git add g.txt
PATH="$TMP/sy-bin:$PATH" eval "$(print -r -- "$OUT" | sed -n 's/^Once that is done, bring your checkout along[^:]*: //p')"
_ST_EQ "the carry brings the rest along, a peer's staging since kept" \
	"$(tr '\n' ' ' < f.txt):$(git show :f.txt | tr '\n' ' '):$(git show :g.txt | tr '\n' ' ')" "1 2 3 f :1 2 3 f :1 2 peer "
git worktree remove --force "$TMP/sy7-wt"

# An undone `--exec` rewrite brings the checkout back as any rewrite's undo does – kept as it is,
# the checkout would hold an unstaged revert of what the undo brought back – while an undone
# `--exec` that only added commits keeps what it landed, as a commit's undo does
_ST_PZ_NEW sy8
print -l 1 2 3 > f.txt && print g > g.txt && git add -A && git commit -qm "SY8 base"
print -l 1 2 3 4 > f.txt && git commit -qam "SY8 C1"
SY_T=$(git rev-parse HEAD)
_ST_RUN --exec --base="$SY_T" -- git reset -q --hard HEAD~1
_ST_EQ "an --exec dropping a commit brings the checkout along" "$RC:$(tr '\n' ' ' < f.txt)" "0:1 2 3 "
_ST_RUN --undo
_ST_EQ "its undo brings the checkout back" "$RC:$(git log -1 --format=%s):$(tr '\n' ' ' < f.txt):$(git status --porcelain)" "0:SY8 C1:1 2 3 4 :"
_ST_OUT_LACKS "never keeping a revert as what the run landed" 'stays in your checkout'
_ST_RUN --exec -- sh -c 'printf "1\n2\n3\n4\n5\n" > f.txt && git commit -qam "SY8 C2"'
_ST_RUN --undo
_ST_EQ "while one only adding a commit keeps what it landed" "$RC:$(tr '\n' ' ' < f.txt):$(git status --porcelain)" "0:1 2 3 4 5 : M f.txt"
_ST_OUT_HAS "as uncommitted changes" 'what the undone run landed stays in your checkout, as uncommitted changes: f.txt'
git checkout -q -- f.txt

# A file staged and edited both, left as it was, is named with the carry, worded for whoever owns
# the staging – never as the caller's to reconcile
_ST_PZ_NEW sy9
print -l 1 2 3 4 5 6 7 8 9 > f.txt && print o > o.txt && git add -A && git commit -qm "SY9 base"
print -l 1 2 3 4 5 6 7 8 9 DROPME > f.txt && git commit -qam "SY9 C1"
print o2 > o.txt && git commit -qam "SY9 C2"
SY_T=$(git rev-parse HEAD)
print -l 1-staged 2 3 4 5 6 7 8 9 DROPME > f.txt && git add f.txt
print -l 1-staged 2 3 4 5-unstaged 6 7 8 9 DROPME > f.txt
_ST_RUN -d -y HEAD~1
_ST_EQ "a partly staged file stays as it was" "$RC:$(git show :f.txt | tail -1):$(tail -1 f.txt)" "0:DROPME:DROPME"
_ST_OUT_HAS "named with the carry for whoever staged it" "^Whoever staged f.txt – a peer's staging, or the caller's own – brings what landed into the file with git edit --carry=${SY_T:0:12}, then stages their part again$"
_ST_OUT_LACKS "never as the caller's to reconcile" 'for you to reconcile'
_ST_RUN --carry="$SY_T"
_ST_EQ "which brings what landed into the file, the staging left to its owner" "$(tr '\n' ' ' < f.txt):$(git show :f.txt | head -1)" "1-staged 2 3 4 5-unstaged 6 7 8 9 :1-staged"
git reset -q -- f.txt && git checkout -q -- f.txt

# A branch checked out twice: a run from the second brings the second along, holding the sync of
# the checkout it writes, and names the carry for the first, which follows it as printed
_ST_PZ_NEW sy10
print -l 1 2 3 > f.txt && print o > o.txt && git add -A && git commit -qm "SY10 base"
print -l 1 2 3 4 > f.txt && git commit -qam "SY10 C1" && print o2 > o.txt && git commit -qam "SY10 C2"
git worktree add -q -f "$TMP/sy10-wt" main 2>/dev/null
_SY_STAND_IN "$TMP/sy10-git" '*" ls-files -v -z "*' "ls ${(q)TMP}/pz-sy10/.git/git-edit-sync.lock ${(q)TMP}/pz-sy10/.git/worktrees/*/git-edit-sync.lock > ${(q)TMP}/sy10-held 2>/dev/null; rm -f ${(q)TMP}/sy10-git/arm" after
: > "$TMP/sy10-git/arm"
cd "$TMP/sy10-wt"
OUT=$(PATH="$TMP/sy10-git:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -d -y HEAD~1 </dev/null 2>&1)
RC=$?
_ST_EQ "a run from the second checkout brings that one along" "$RC:$(tr '\n' ' ' < f.txt):$(git status --porcelain)" "0:1 2 3 :"
_ST_EQ "holding the sync of the checkout it writes" "$(sed 's|.*/\.git/||' "$TMP/sy10-held" 2>/dev/null)" "worktrees/sy10-wt/git-edit-sync.lock"
_ST_OUT_HAS "naming the carry for the other" "^The branch's other checkout, .*/pz-sy10, stays as it was – bring it along with git -C .*/pz-sy10 edit --carry="
PATH="$TMP/sy-bin:$PATH" eval "$(print -r -- "$OUT" | sed -n "s/^The branch's other checkout, [^–]*– bring it along with //p")"
cd "$TMP/pz-sy10"
_ST_EQ "which brings the first along as printed" "$(tr '\n' ' ' < f.txt):$(git status --porcelain)" "1 2 3 :"
git worktree remove --force "$TMP/sy10-wt"

# Where the sync ran, the raw undo's index-only step is named still, with the carry that brings the
# files back as `--undo` would – after a commit, which `--undo` keeps, the step alone
_ST_PZ_NEW sy11
print -l 1 2 3 > f.txt && print o > o.txt && git add -A && git commit -qm "SY11 base"
print -l 1 2 3 4 > f.txt && git commit -qam "SY11 C1" && print o2 > o.txt && git commit -qam "SY11 C2"
print peer > p.txt && git add p.txt
_ST_RUN -d -y HEAD~1
SY_OUT=$OUT
_ST_OUT_HAS "a drop names the raw undo's index-only step" '^After the raw undo, re-sync them back – [^:]*: git diff-index --cached --exit-code --name-only [0-9a-f]* -- f.txt && git restore --staged -- f.txt$'
_ST_OUT_HAS "and the carry that brings the files back" "^Then bring the checkout back with it, as git edit --undo would: git edit --carry=${$(git rev-parse HEAD):0:12}$"
eval "$(print -r -- "$SY_OUT" | sed -n 's/^Undo: git edit --undo  (or, the ref alone: \(.*\))$/\1/p')"
eval "$(print -r -- "$SY_OUT" | sed -n 's/^After the raw undo, re-sync them back – [^:]*: //p')"
PATH="$TMP/sy-bin:$PATH" eval "$(print -r -- "$SY_OUT" | sed -n 's/^Then bring the checkout back with it, as git edit --undo would: //p')" >/dev/null 2>&1
_ST_EQ "followed as printed, the checkout is back, the peer's staging kept" \
	"$(git log -1 --format=%s HEAD~1):$(tr '\n' ' ' < f.txt):$(git status --porcelain | tr '\n' '|')" "SY11 C1:1 2 3 4 :A  p.txt|"
print x > n.txt
_ST_RUN --commit --text "SY11 n" -- n.txt
_ST_OUT_HAS "a commit names the step" '^After the raw undo, re-sync them back – [^:]*: git diff-index --cached --exit-code --name-only [0-9a-f]* -- n.txt && git restore --staged -- n.txt$'
_ST_OUT_LACKS "with no carry, its undo keeping what it landed" '^Then bring the checkout back'

# Every file that can vanish between a check and its read is read with the shell's own errors
# silenced – a held sync let go of meanwhile printed `no such file or directory` into a run's output
_ST_EQ "no file read silences only its own redirection" "$(grep -c '\$(<"[^)]*2>/dev/null)' "$SELF")" "0"
cd "$TMP/repo"
