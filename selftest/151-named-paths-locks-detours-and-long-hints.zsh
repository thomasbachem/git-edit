# A bracketed name staged for removal or given in a `--tree` is that path, a `-C` lock is let go
# only by its holder, a detour back to the start tip builds nothing, a hint over many paths
# stays runnable, and a terminal resume checks what was pushed while it waited
_ST_SCENARIO "\e[1;96m[151] removals and trees name their paths, -C locks hold, detours land, long hints run\e[0m"
local NP_T NP_C NP_I NP_WT NP_LOCK NP_GD NP_H NP_TIP NP_DEAD
# A fold named `app/[id].tsx`, staged as a removal, takes that removal alone – a peer's staged
# `app/i.tsx` left staged
_ST_PZ_NEW np1
mkdir app && print 1 > 'app/[id].tsx' && print 1 > app/i.tsx
git add app && git commit -qm "NP1 app" && _ST_PZ_C t.txt t "NP1 tip"
git rm -q -- ':(literal)app/[id].tsx' && print peer >> app/i.tsx && git add app/i.tsx
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" -- 'app/[id].tsx'
_ST_EQ "a bracketed name staged as a removal folds that removal alone" "${RC}:$(git show --name-only --format= HEAD~1 | tr '\n' ' ')" "0:app/i.tsx "
_ST_EQ "the peer's file left staged, out of the target" "$(git diff --cached --name-only):$(git show HEAD~1:app/i.tsx)" "app/i.tsx:1"
# A `--tree` adding `app/[n].tsx`, which the index lacks, folds it alone – not its `app/n.tsx` too
git reset -q && print 1 > app/n.tsx && git add app/n.tsx && git commit -qm "NP1 n" && _ST_PZ_C t2.txt t2 "NP1 tip 2"
rm -f "$TMP/np1-index"
GIT_INDEX_FILE=$TMP/np1-index git read-tree HEAD
GIT_INDEX_FILE=$TMP/np1-index git update-index --add --cacheinfo "100644,$(print new | git hash-object -w --stdin),app/[n].tsx"
GIT_INDEX_FILE=$TMP/np1-index git update-index --add --cacheinfo "100644,$(print changed | git hash-object -w --stdin),app/n.tsx"
NP_T=$(git commit-tree "$(GIT_INDEX_FILE=$TMP/np1-index git write-tree)" -p HEAD -m "NP1 composed")
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --tree="$NP_T" -- 'app/[n].tsx'
_ST_EQ "a bracketed name the --tree adds folds that path alone" "${RC}:$(git show HEAD~1:'app/[n].tsx'):$(git show HEAD~1:app/n.tsx)" "0:new:1"
# A split by a bracketed name a commit deletes takes that deletion alone
_ST_PZ_NEW np2
mkdir app && print 1 > 'app/[id].tsx' && print 1 > app/i.tsx && git add app && git commit -qm "NP2 base"
git rm -q -- ':(literal)app/[id].tsx' && print 2 > app/i.tsx && git add app/i.tsx && git commit -qm "NP2 both"
_ST_RUN --split=HEAD --text "NP2 removal alone" -- 'app/[id].tsx'
_ST_EQ "a split by a bracketed name the commit deletes takes that deletion alone" "${RC}:$(git show --name-status --format= HEAD~1 | tr '\t\n' ' |')" "0:D app/[id].tsx|"
# A `-C` run lets go of the lock at its end only where it still names this run – one another run
# took as stale is that run's
_ST_PZ_NEW np3
for NP_I in 1 2 3; do _ST_PZ_C "f$NP_I.txt" "$NP_I" "NP3 c$NP_I"; done
git config edit.verifyCmd "$TMP/st-hold $TMP/np3.go"
rm -f "$TMP/np3.go"
( GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -d -y HEAD~1 -C </dev/null > "$TMP/np3.out" 2>&1 ) &
NP_I=0; until grep -q verify "$TMP/np3.out" 2>/dev/null || (( ++NP_I > 200 )); do sleep 0.1; done
NP_GD=$(git -C "$(git rev-parse --show-toplevel).git-edit" rev-parse --absolute-git-dir 2>/dev/null)
NP_LOCK="$NP_GD/git-edit-run.lock"
print -r -- $$ > "$NP_LOCK"
: > "$TMP/np3.go"
wait
OUT=$(<"$TMP/np3.out")
_ST_EQ "a run whose -C lock another took lands" "$(git log --format=%s | tr '\n' '|')" "NP3 c3|NP3 c1|"
_ST_EQ "and leaves that lock to its holder" "$(cat "$NP_LOCK" 2>/dev/null)" "$$"
# A lock naming no pid yet is taken as stale only once it is old – a run writing it is mid-take
: > "$NP_LOCK"
_ST_RUN -d -y HEAD~1 -C --no-verify
_ST_EQ "a fresh lock naming no pid refuses" "${RC}:$(git log -1 --format=%s)" "1:NP3 c3"
_ST_OUT_HAS "as in use" 'is in use by another run'
touch -t 200001010000 "$NP_LOCK"
_ST_RUN -d -y HEAD~1 -C --no-verify
_ST_EQ "an old one is taken" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:NP3 c3|"
# As is one naming a pid that is gone
_ST_PZ_C f4.txt 4 "NP3 c4"
sh -c 'exit 0' & NP_DEAD=$!
wait $NP_DEAD
print -r -- "$NP_DEAD" > "$NP_LOCK"
_ST_RUN -d -y HEAD~1 -C --no-verify
_ST_EQ "a lock whose pid is gone is taken" "${RC}:$(git log --format=%s | tr '\n' '|'):$([ -e "$NP_LOCK" ] || echo released)" "0:NP3 c4|:released"
git config --unset edit.verifyCmd
# An `--exec` that visits an older commit and comes back builds on the start tip – it lands
_ST_PZ_NEW np4
_ST_PZ_C a.txt a "NP4 a" && _ST_PZ_C b.txt b "NP4 b" && _ST_PZ_C c.txt c "NP4 c"
_ST_RUN --exec -- sh -c 'git checkout -q HEAD~2 && git checkout -q - && git commit -q --amend -m "NP4 c amended"'
_ST_EQ "a detour back to the start tip, then an amend, lands" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:NP4 c amended|NP4 b|NP4 a|"
NP_TIP=$(git rev-parse HEAD)
_ST_RUN --exec -- sh -c 'git checkout -q HEAD~2 && git checkout -q - && git reset -q --hard HEAD~1 && git commit -q --allow-empty -m "NP4 x"'
_ST_EQ "while one going below it after the detour still refuses" "${RC}:$(git rev-parse HEAD)" "1:$NP_TIP"
_ST_OUT_HAS "naming where HEAD went" 'below the tip this run started on'
# A hint over more than 10 paths reads them from a file it names, a bracketed one marked literal,
# so it runs at any count – and over a few, lists them – the raw undo's re-sync step where a drop
# can't bring the checkout along, which brings it along otherwise
_ST_PZ_NEW np5
mkdir d && for NP_I in {1..12}; do print 1 > "d/f$NP_I.txt"; done
print 1 > 'd/[x].txt' && print 1 > d/x.txt && print 1 > d/y.txt && print 1 > d/z.txt
git add -A && git commit -qm "NP5 base"
for NP_I in {1..12}; do print 2 > "d/f$NP_I.txt"; done
print 2 > 'd/[x].txt'
git add -A && git commit -qm "NP5 change" && _ST_PZ_C t.txt t "NP5 tip"
print mine > d/x.txt
_ST_RUN -d -y HEAD~1
_ST_EQ "a drop over 13 paths lands, the checkout with it, the edited file kept" \
	"${RC}:$(git log --format=%s | tr '\n' '|'):$(git status --porcelain | tr '\n' '|')" "0:NP5 tip|NP5 base|: M d/x.txt|"
_ST_OUT_HAS "naming ten and how many more" 'now as they landed: .* … and 3 more$'
for NP_I in {1..12}; do print 4 > "d/f$NP_I.txt"; done
print 4 > 'd/[x].txt'
git add -- d/f*.txt ':(literal)d/[x].txt' && git commit -qm "NP5 change 2" && _ST_PZ_C t3.txt t3 "NP5 tip 3"
_ST_RUN_UNSYNCED -d -y HEAD~1
NP_H=${(M)${(f)OUT}:#After the raw undo, re-sync them back*}
NP_H=${NP_H#*listing those: }
_ST_EQ "its hint feeds them from a file the run names" "${NP_H%%< *}" "xargs -0 git diff-index --cached --exit-code --name-only $(git rev-parse HEAD | cut -c1-12) -- "
_ST_EQ "its name giving the count" "${${${NP_H%% && *}##*/}%%.*}" "git-edit-13-paths"
_ST_CHECK "which runs" sh -c "${NP_H:-false}"
git checkout -q -- d
for NP_I in y z; do print 3 > "d/$NP_I.txt"; done
git add d/y.txt d/z.txt && git commit -qm "NP5 yz" && _ST_PZ_C t2.txt t2 "NP5 tip 2"
_ST_RUN_UNSYNCED -d -y HEAD~1
_ST_OUT_HAS "a hint over two paths lists them" 'listing those: git diff-index --cached --exit-code --name-only [0-9a-f]* -- d/y\.txt d/z\.txt && git restore --staged -- d/y\.txt d/z\.txt$'
git checkout -q -- d
# Enter at a terminal edit's prompt resumes as `--continue`, refusing what was pushed meanwhile
_ST_PZ_NEW np6
git init -q --bare "$TMP/np6-remote.git" && git remote add origin "$TMP/np6-remote.git"
_ST_PZ_C a.txt a "NP6 a" && _ST_PZ_C b.txt b "NP6 b" && _ST_PZ_C c.txt c "NP6 c"
NP_TIP=$(git rev-parse HEAD)
_ST_TTY_START -- HEAD~1
if _ST_TTY_AT 'Make your changes in'; then
	NP_WT=$(_ST_PZ_WT)
	print -r -- b2 > "${NP_WT:-$ST_NO_WT}/b.txt"
	git push -q origin main
	zpty -wn ST_TTY $'\r'
	_ST_TTY_AT 'to leave it paused' 2 && zpty -wn ST_TTY q
fi
_ST_TTY_END
_ST_EQ "Enter at an edit's prompt lands nothing pushed while it waited" "$(git rev-parse HEAD)" "$NP_TIP"
_ST_OUT_HAS "naming the push" 'pushed while this paused'
_ST_RUN --abort
cd "$TMP/repo"
