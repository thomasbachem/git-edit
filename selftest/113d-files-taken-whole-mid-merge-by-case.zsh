# Mid-merge, or on a file still unmerged, files taken whole refuse as git commit's partial one does
_ST_SCENARIO "\e[1;96m[113d] files taken whole mid-merge, by case, past landings that moved lines\e[0m"
export GIT_EDIT_ACTOR=wc-self
local WC_BR=$(git symbolic-ref --short HEAD) WC_ICASE=$(git config core.ignorecase)
git checkout -q -b wc-mside && echo S > wc-mg.txt && git add wc-mg.txt && git commit -qm "WC merge side" && git checkout -q "$WC_BR"
echo M > wc-mg.txt && git add wc-mg.txt && git commit -qm "WC merge main"
git merge -q wc-mside >/dev/null 2>&1
_ST_RUN --commit --text "x" -- wc-mg.txt
_ST_OUT_HAS "a commit mid-merge refuses" 'A merge is in progress'
git merge --abort && git branch -q -D wc-mside
echo u > wc-um.txt
local WC_UB=$(git hash-object -w wc-um.txt)
printf '100644 %s 1\twc-um.txt\n100644 %s 2\twc-um.txt\n' "$WC_UB" "$WC_UB" | git update-index --index-info
_ST_RUN --commit --text "x" -- wc-um.txt
_ST_OUT_HAS "as does one on a file still unmerged" 'wc-um.txt is unmerged'
git rm -q --cached wc-um.txt && rm -f wc-um.txt
# A branch named as the state file is none in progress
git update-ref refs/heads/CHERRY_PICK_HEAD HEAD
echo cp > wc-cp.txt
_ST_RUN --commit --text "WC beside a branch named CHERRY_PICK_HEAD" -- wc-cp.txt
_ST_EQ "a branch named as a cherry-pick's state file blocks nothing" "$RC" "0"
git update-ref -d refs/heads/CHERRY_PICK_HEAD
# Where case tells no names apart: a spelling the tip holds exactly passes beside another, and
# two new names whose directories differ only in case refuse
git config core.ignorecase true
local WC_EA=$(echo a | git hash-object -w --stdin)
printf '100644 %s\twc-CS/a.txt\n100644 %s\twc-cs/b.txt\n' "$WC_EA" "$WC_EA" | git update-index --index-info
git commit -qm "WC both spellings"
mkdir -p wc-CS && echo n > wc-CS/new.txt
_ST_RUN --commit --text "WC new beside both" -- wc-CS/new.txt
_ST_EQ "a spelling the tip holds exactly passes beside another" "$RC" "0"
mkdir -p wc-q && echo x > wc-q/X.txt && mkdir -p WC-Q && echo y > WC-Q/y.txt
_ST_RUN --commit --text "x" -- wc-q/X.txt WC-Q/y.txt
_ST_OUT_HAS "two new names whose directories differ only in case refuse" 'WC-Q and wc-q differ only in case'
rm -rf wc-q WC-Q
git rm -q --cached wc-CS/a.txt wc-cs/b.txt wc-CS/new.txt && git commit -qm "WC drop both spellings" && rm -rf wc-CS
git config core.ignorecase "${WC_ICASE:-false}"
export GIT_EDIT_ACTOR=wc-self
# A landing undoing an earlier one counts too – a copy read between them takes it back
printf 'r%s\n' {1..12} > wc-rv.txt
_ST_RUN --commit --text "WC revert base" -- wc-rv.txt
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN --exec -- sh -c "sed 's/^r3\$/A3/' wc-rv.txt > t && mv t wc-rv.txt && git commit -qam 'WC rv A'"
git show HEAD:wc-rv.txt > "$TMP/wc-rv-stale"
export GIT_EDIT_ACTOR=wc-other
_ST_RUN --exec -- sh -c "sed 's/^A3\$/r3/' wc-rv.txt > t && mv t wc-rv.txt && git commit -qam 'WC rv B'"
export GIT_EDIT_ACTOR=wc-self
sed 's/^r10$/C10/' "$TMP/wc-rv-stale" > wc-rv.txt
local WC_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- wc-rv.txt
_ST_EQ "a copy lacking a landing that undid an earlier one refuses" "$RC:$(git rev-parse HEAD)" "1:$WC_TIP"
_ST_OUT_HAS "naming that landing" "wc-rv.txt – wc-other's exec run"
git checkout -q -- wc-rv.txt
# A stale copy edited beside a landed line lacks it, an edit there on the landed content doesn't
printf 'j%s\n' {1..9} > wc-aj.txt
_ST_RUN --commit --text "WC adjacent-line base" -- wc-aj.txt
cp wc-aj.txt "$TMP/wc-aj-stale"
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN --exec -- sh -c "sed 's/^j5\$/P5/' wc-aj.txt > t && mv t wc-aj.txt && git commit -qam 'WC aj land'"
export GIT_EDIT_ACTOR=wc-self
sed 's/^j6$/C6/' "$TMP/wc-aj-stale" > wc-aj.txt
WC_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- wc-aj.txt
_ST_EQ "a stale copy edited beside a landed line refuses" "$RC:$(git rev-parse HEAD)" "1:$WC_TIP"
git show HEAD:wc-aj.txt | sed 's/^j6$/C6/' > wc-aj.txt
_ST_RUN --commit --text "WC beside the landed line" -- wc-aj.txt
_ST_EQ "while one edited beside it on the landed content lands" "$RC:$(git show HEAD:wc-aj.txt | sed -n '5p;6p' | tr '\n' ' ')" "0:P5 C6 "
# Edits overlap a landing by where they sit, not by what they say – a blank line both remove
# elsewhere shares no position, and a line the landing inserted, edited since, shares its own
printf 'a\nb\n\nc\n\nd\n' > wc-bl.txt
_ST_RUN --commit --text "WC blank base" -- wc-bl.txt
cp wc-bl.txt "$TMP/wc-bl-stale"
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN --exec -- sh -c "printf 'a\nB\nc\n\nd\n' > wc-bl.txt && git commit -qam 'WC bl land'"
export GIT_EDIT_ACTOR=wc-self
printf 'a\nb\n\nC\nd\n' > wc-bl.txt
WC_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- wc-bl.txt
_ST_EQ "a stale copy removing a blank line elsewhere still refuses" "$RC:$(git rev-parse HEAD)" "1:$WC_TIP"
git checkout -q -- wc-bl.txt
printf 'one\ntwo\nthree\n' > wc-in.txt
_ST_RUN --commit --text "WC insert base" -- wc-in.txt
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN --exec -- sh -c "printf 'one\nimport foo\ntwo\nthree\n' > wc-in.txt && git commit -qam 'WC in land'"
export GIT_EDIT_ACTOR=wc-self
printf 'one\nimport foo, bar\ntwo\nthree\n' > wc-in.txt
_ST_RUN --commit --text "WC extends the inserted line" -- wc-in.txt
_ST_EQ "while an edit since on a line the landing inserted lands" "$RC:$(git show HEAD:wc-in.txt | sed -n 2p)" "0:import foo, bar"
# A merge by ID that aborts, as git 2.53's does in a linked worktree, merges from files instead
mkdir -p "$TMP/shim-mfabort"
printf '#!/bin/zsh\n[[ "$1" == merge-file && "$2" == --object-id ]] && exit 134\nexec %s "$@"\n' "$(whence -p git)" > "$TMP/shim-mfabort/git"
chmod +x "$TMP/shim-mfabort/git"
printf 'k%s\n' {1..9} > wc-ab.txt
_ST_RUN --commit --text "WC abort base" -- wc-ab.txt
cp wc-ab.txt "$TMP/wc-ab-stale"
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN --exec -- sh -c "sed 's/^k2\$/P2/' wc-ab.txt > t && mv t wc-ab.txt && git commit -qam 'WC ab land'"
export GIT_EDIT_ACTOR=wc-self
sed 's/^k8$/C8/' "$TMP/wc-ab-stale" > wc-ab.txt
WC_TIP=$(git rev-parse HEAD)
PATH="$TMP/shim-mfabort:$PATH" _ST_RUN --commit --text "x" -- wc-ab.txt
_ST_EQ "a stale copy still refuses where git's merge by ID aborts" "$RC:$(git rev-parse HEAD)" "1:$WC_TIP"
git checkout -q -- wc-ab.txt
# A file this commit renames, read before a landing on its old name, takes that landing back
printf 'n%s\n' {1..8} > wc-rnm.txt
_ST_RUN --commit --text "WC own rename base" -- wc-rnm.txt
cp wc-rnm.txt "$TMP/wc-rnm-stale"
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN --exec -- sh -c "sed 's/^n3\$/P3/' wc-rnm.txt > t && mv t wc-rnm.txt && git commit -qam 'WC rnm land'"
export GIT_EDIT_ACTOR=wc-self
sed 's/^n7$/C7/' "$TMP/wc-rnm-stale" > wc-rnm2.txt && rm -f wc-rnm.txt
WC_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- wc-rnm.txt wc-rnm2.txt
_ST_EQ "a rename made on stale content refuses" "$RC:$(git rev-parse HEAD)" "1:$WC_TIP"
_ST_OUT_HAS "naming both names" 'wc-rnm.txt – wc-peer.*which this commit renames to wc-rnm2.txt'
_ST_OUT_HAS "and the merge bringing what landed into the new one" "git merge-file -- wc-rnm2\.txt \"\$T/base\" \"\$T/landed\"\$"
# Run as printed, by a plain `sh`
sh -c "$(print -r -- "$OUT" | sed -n "s/.*Merge what landed into the new name with: //p")"
_ST_EQ "which merges it in" "$(sed -n '3p;7p' wc-rnm2.txt | tr '\n' ' '):$(local -a G=(wc-rnm2.txt.git-edit-*(N)); print ${#G})" "P3 C7 :0"
_ST_RUN --commit --text "WC own rename" -- wc-rnm.txt wc-rnm2.txt
_ST_EQ "while one made on the landed content lands" "$RC:$(git show HEAD:wc-rnm2.txt | sed -n '3p;7p' | tr '\n' ' ')" "0:P3 C7 "
# What a peer stages of a file while it is taken whole or folded keeps its staging – only the entry
# the file had when read is the run's to re-sync
printf 'ps1\n' > wc-pst.txt
_ST_RUN --commit --text "WC peer staging base" -- wc-pst.txt
local WC_PB=$(printf 'peer staged\n' | git hash-object -w --stdin)
git config edit.verifyCmd "git -C '$TMP/repo' update-index --cacheinfo 100644,$WC_PB,wc-pst.txt"
printf 'ps2\n' > wc-pst.txt
_ST_RUN --commit --text "WC past a peer's staging" -- wc-pst.txt
_ST_EQ "a peer's staging made meanwhile stays staged" "$RC:$(git ls-files -s -- wc-pst.txt | awk '{print $2}')" "0:$WC_PB"
_ST_OUT_HAS "named as left alone" 'Left as they were.*wc-pst.txt'
git restore --staged -- wc-pst.txt
printf 'ps3\n' > wc-pst.txt && git add wc-pst.txt
_ST_RUN --amend-into="$(git rev-parse HEAD)" -- wc-pst.txt
git config --unset edit.verifyCmd
_ST_EQ "as does one staged while a fold runs" "$RC:$(git ls-files -s -- wc-pst.txt | awk '{print $2}')" "0:$WC_PB"
_ST_OUT_HAS "named there too" 'Left staged, changed since the fold read it: wc-pst.txt'
git restore --staged --worktree -- wc-pst.txt
# A pause elsewhere blocks neither `--commit` nor `--exec` – one on their
# own branch does, saying whose call it is
git checkout -q -b wc-paused
printf '1\n2\n3\n' > wc-pz.txt
_ST_RUN --commit --text "WC pz base" -- wc-pz.txt
local WC_PZ=$(git rev-parse HEAD)
printf '1\nL\n3\n' > wc-pz.txt
_ST_RUN --commit --text "WC pz later" -- wc-pz.txt
printf '1\nS\n3\n' > wc-pz.txt && git add wc-pz.txt
_ST_RUN --amend-into="$WC_PZ" -- wc-pz.txt
_ST_OUT_HAS "a fold pauses on its branch" '^git-edit: conflict'
git restore --staged --worktree -- wc-pz.txt
git checkout -q "$WC_BR"
echo pz > wc-pz-main.txt
_ST_RUN --commit --text "WC commit beside a pause elsewhere" -- wc-pz-main.txt
_ST_EQ "--commit lands on another branch" "$RC:$(git log -1 --format=%s)" "0:WC commit beside a pause elsewhere"
_ST_RUN --exec -- git commit -q --allow-empty -m "WC exec beside a pause elsewhere"
_ST_EQ "as --exec does" "$RC:$(git log -1 --format=%s)" "0:WC exec beside a pause elsewhere"
_ST_RUN --undo
_ST_EQ "and --undo takes such a landing back" "$RC:$(git log -1 --format=%s)" "0:WC commit beside a pause elsewhere"
_ST_RUN -M --text "x" HEAD
_ST_OUT_HAS "while other modes still refuse" 'operation is in flight on wc-paused'
git checkout -q wc-paused
echo pz2 > wc-pz2.txt
_ST_RUN --commit --text "x" -- wc-pz2.txt
_ST_OUT_HAS "and --commit on the paused branch refuses" 'operation is in flight on wc-paused'
_ST_OUT_HAS "saying whose call it is" "if another session's, wait for it"
rm -f wc-pz2.txt
_ST_RUN --abort
git checkout -q "$WC_BR"
git branch -q -D wc-paused
# Bare --carry with no mark, as an older build leaves the checkout, takes the last rewrite past a
# --commit since, which took the checkout's own files
printf 'c1\nc2\nc3\n' > wc-bc.txt
_ST_RUN --commit --text "WC carry base" -- wc-bc.txt
_ST_RUN --exec -- sh -c "printf 'C1\nc2\nc3\n' > wc-bc.txt && git commit -qam 'WC carry rewrite'"
printf 'c1\nc2\nc3\nmine\n' > wc-bc.txt
echo x > wc-bc-other.txt
_ST_RUN --commit --text "WC commit after the rewrite" -- wc-bc-other.txt
rm -f "$(git rev-parse --path-format=absolute --git-path git-edit-brought)"
_ST_RUN --carry
_ST_EQ "bare --carry carries across the last rewrite, past a --commit" "$RC:$(tr '\n' ' ' < wc-bc.txt)" "0:C1 c2 c3 mine "
git checkout -q -- wc-bc.txt
echo cl > wc-cl.txt
_ST_RUN --commit --text "WC commit line" -- wc-cl.txt
_ST_EQ "--commit's commit line sits within tail -3" "$(print -r -- "$OUT" | tail -3 | grep -c 'committed: [0-9a-f]* WC commit line')" "1"
export GIT_EDIT_ACTOR=
