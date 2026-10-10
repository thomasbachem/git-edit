# A landing the checkout never got, as a rewrite lands one, makes a whole file a revert – on
# the file as 113 leaves it, committed here where a run starts without 113
_ST_SCENARIO "\e[1;96m[113b] a whole file lacking another caller's landing refuses\e[0m"
export GIT_EDIT_ACTOR=wc-self
local WC_BR=$(git symbolic-ref --short HEAD) WC_HOOK=$(git rev-parse --git-path hooks/pre-commit)
printf 'a\nb\nc\nd\ne\nf\ng\nh\ni\nj\n' > wc.txt && git add wc.txt
git diff --cached --quiet -- wc.txt || git commit -qm "WC guard base"
local WC_BEFORE=$(git rev-parse HEAD)
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN --exec -- sh -c "printf 'a\nB\nc\nd\ne\nf\ng\nh\ni\nj\n' > wc.txt && git commit -qam 'WC peer lands'"
export GIT_EDIT_ACTOR=wc-self
printf 'a\nb\nc\nd\ne\nf\nG-mine\nh\ni\nj\n' > wc.txt
local WC_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- wc.txt
_ST_OUT_HAS "a whole file lacking another caller's landing refuses, naming the run" "wc.txt – wc-peer's exec run"
_ST_OUT_LACKS "under a lead-in printed once" 'on them: Committed whole'
_ST_OUT_HAS "and the carry that merges the edits onto it" "--carry=${WC_BEFORE:0:12}"
_ST_RUN --amend-into="$WC_TIP" --whole -- wc.txt
_ST_OUT_HAS "a whole-file fold refuses the same" 'would take back'
_ST_RUN --commit --text "x" --base="$WC_BEFORE" -- wc.txt
_ST_OUT_HAS "as does a --base the file changed since" 'Changed between --base'
_ST_EQ "none of them moved the branch" "$(git rev-parse HEAD)" "$WC_TIP"
_ST_RUN --carry="$WC_BEFORE"
_ST_RUN --commit --text "WC mine on the peer's" -- wc.txt
_ST_EQ "once carried it lands with both" "$RC:$(git show HEAD:wc.txt | sed -n '2p;7p' | tr '\n' ' ')" "0:B G-mine "
printf 'a\nb\nc\nd\ne\nf\nG-mine\nh\ni\nj\n' > wc.txt
_ST_RUN --commit --text "WC take it back on purpose" --base="$(git rev-parse HEAD)" -- wc.txt
_ST_EQ "the tip's SHA as --base takes a landing back on purpose" "$RC:$(git show HEAD:wc.txt | sed -n 2p)" "0:b"
_ST_RUN --exec -- sh -c "printf 'a\nb\nC\nd\ne\nf\nG-mine\nh\ni\nj\n' > wc.txt && git commit -qam 'WC my own landing'"
printf 'a\nb\nc\nd\ne\nf\nG-mine\nH\ni\nj\n' > wc.txt
_ST_RUN --commit --text "WC past my own landing" -- wc.txt
_ST_EQ "this caller's own landing does not count" "$RC" "0"
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN --exec -- sh -c "printf 'a\nb\nc\nD\ne\nf\nG-mine\nH\ni\nj\n' > wc.txt && git commit -qam 'WC peer lands D'"
export GIT_EDIT_ACTOR=wc-other
_ST_RUN --exec -- sh -c "printf 'a\nb\nc\nd\ne\nf\nG-mine\nH\ni\nj\n' > wc.txt && git commit -qam 'WC another takes it back'"
export GIT_EDIT_ACTOR=wc-self
printf 'A\nb\nc\nd\ne\nf\nG-mine\nH\ni\nj\n' > wc.txt
_ST_RUN --commit --text "WC past a landing taken back" -- wc.txt
_ST_EQ "a landing the tip no longer carries does not count" "$RC" "0"
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN --exec -- sh -c "printf 'A\nb\nc\nD-peer\ne\nf\nG-mine\nH\ni\nj\n' > wc.txt && git commit -qam 'WC peer lands a line'"
export GIT_EDIT_ACTOR=wc-self
printf 'A\nb\nc\nD-reworked\ne\nf\nG-mine\nH\ni\nj\n' > wc.txt
_ST_RUN --commit --text "WC rework the peer's line" -- wc.txt
_ST_EQ "edits on a landed line, made after it, do not count" "$RC:$(git show HEAD:wc.txt | sed -n 4p)" "0:D-reworked"
export GIT_EDIT_ACTOR=
_ST_RUN --exec -- sh -c "printf 'A\nb\nc\nD-reworked\ne\nF\nG-mine\nH\ni\nj\n' > wc.txt && git commit -qam 'WC unlabeled lands'"
export GIT_EDIT_ACTOR=wc-self
printf 'A\nb\nc\nD-reworked\ne\nf\nG-mine\nH\nI\nj\n' > wc.txt
_ST_RUN --commit --text "x" -- wc.txt
_ST_OUT_HAS "an unlabeled landing counts" "wc.txt – an unlabeled caller's exec run"
local WC_JF="$(git rev-parse --git-common-dir)/git-edit-journal"
local WC_LAST=$(tail -1 "$WC_JF")
{ sed '$d' "$WC_JF"; print -r -- "$(( ${WC_LAST%% *} - 8 * 86400 )) ${WC_LAST#* }"; } > "$WC_JF.tmp" && mv "$WC_JF.tmp" "$WC_JF"
_ST_RUN --commit --text "WC past a landing 8 days old" -- wc.txt
_ST_EQ "one older than 7 days does not" "$RC:$(git show HEAD:wc.txt | sed -n 6p)" "0:f"
# An unlabeled caller's own runs are every unlabeled one, which nothing tells apart
export GIT_EDIT_ACTOR=
_ST_RUN --exec -- sh -c "printf 'A\nb\nc\nD-reworked\ne\nf\nG-mine\nH\nI\nJ\n' > wc.txt && git commit -qam 'WC unlabeled lands J'"
printf 'A\nb\nc\nD-reworked\nE\nf\nG-mine\nH\nI\nj\n' > wc.txt
_ST_RUN --commit --text "WC unlabeled past an unlabeled landing" -- wc.txt
_ST_EQ "an unlabeled caller counts no unlabeled run" "$RC:$(git show HEAD:wc.txt | sed -n '5p;10p' | tr '\n' ' ')" "0:E j "
export GIT_EDIT_ACTOR=wc-self
echo x > wc-gone.txt
_ST_RUN --commit --text "WC add a file a peer removes" -- wc-gone.txt
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN --exec -- sh -c "git rm -q wc-gone.txt && git commit -qm 'WC peer removes it'"
export GIT_EDIT_ACTOR=wc-self
printf 'x\nmine\n' > wc-gone.txt
_ST_RUN --commit --text "x" -- wc-gone.txt
_ST_OUT_HAS "a file another caller's landing removed refuses to come back" 'which removed it'
rm -f wc-gone.txt
# A name git would read as a pattern is taken as itself – committed, re-synced, guarded, hinted
printf 'g\n' > 'wc-[g].txt' && printf 'g\n' > wc-g.txt && printf 'c\nx\ny\nz\n' > ':wc-colon.txt'
_ST_RUN --commit --text "WC odd names" -- 'wc-[g].txt' wc-g.txt ':wc-colon.txt'
printf 'g\nmine\n' > 'wc-[g].txt' && printf 'g\nwip\n' > wc-g.txt && printf 'c\nx\ny\nz\nmine\n' > ':wc-colon.txt'
_ST_RUN --commit --text "WC odd names again" -- 'wc-[g].txt' ':wc-colon.txt'
_ST_EQ "a name like a pattern commits as itself" "$RC:$(git show --name-only --format= HEAD | LC_ALL=C sort | tr '\n' ' ')" "0::wc-colon.txt wc-[g].txt "
_ST_EQ "and re-syncs as itself, the file it would match keeping its WIP" "$(git status --porcelain -- ':(literal)wc-[g].txt' ':(literal):wc-colon.txt' wc-g.txt)" " M wc-g.txt"
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN --exec -- sh -c "printf 'C\nx\ny\nz\nmine\n' > ./:wc-colon.txt && git commit -qam 'WC peer on an odd name'"
export GIT_EDIT_ACTOR=wc-self
printf 'c\nx\ny\nz\nmine\nmore\n' > ':wc-colon.txt'
_ST_RUN --commit --text "x" -- ':wc-colon.txt'
_ST_OUT_HAS "the guard reads such a name too" ':wc-colon.txt – wc-peer'
rm -f ':wc-colon.txt'
_ST_RUN --commit --text "WC remove an odd name" -- ':wc-colon.txt'
_ST_OUT_HAS "removing such a name the peer just edited refuses, as for any file" ':wc-colon.txt – wc-peer.*which edited it'
WC_T=$(git rev-parse HEAD)
_ST_RUN --commit --text "WC remove an odd name" --base="$WC_T" -- ':wc-colon.txt'
_ST_EQ "and with --base a removal finds it at the tip" "$RC:$(git cat-file -e 'HEAD::wc-colon.txt' 2>/dev/null && echo kept || echo gone)" "0:gone"
_ST_RUN --exec -- sh -c "printf 'g\nmine\nlanded\n' > 'wc-[g].txt' && git commit -qam 'WC land beside the checkout'"
_ST_OUT_HAS "a restore hint marks such a name literal" "restore --source=HEAD --worktree -- ':(literal)wc-\[g\]\.txt'"
git checkout -q -- ':(literal)wc-[g].txt' && printf 'g\nmine\nlanded\nfolded\n' > 'wc-[g].txt' && echo f > ':wc-fold.txt'
_ST_RUN --amend-into="$(git rev-parse HEAD)" --whole -- 'wc-[g].txt' ':wc-fold.txt'
_ST_EQ "--whole folds such names as themselves" "$RC:$(git show 'HEAD:wc-[g].txt' | tail -1):$(git show 'HEAD::wc-fold.txt'):$(git show HEAD:wc-g.txt | tail -1)" "0:folded:f:g"
# A tip moving while the files are read refuses – a clean filter landing a commit stands in for
# the peer, running between the read of the tip and the landing
git config filter.wcmove.clean "sh -c '[ -e \"$TMP/wc-moved\" ] || { touch \"$TMP/wc-moved\" && git update-ref HEAD \"\$(git commit-tree HEAD^{tree} -p HEAD -m \"WC peer lands mid-run\")\"; }; cat'"
echo '*.wcmove filter=wcmove' >> .git/info/attributes && echo race > wc.wcmove
WC_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- wc.wcmove
_ST_EQ "a tip moving while the files are read refuses, the landing kept" "$RC:$(git log -1 --format=%s):$(git rev-parse HEAD~1)" "1:WC peer lands mid-run:$WC_TIP"
_ST_OUT_HAS "saying so" 'while the commit was composed'
git config --unset filter.wcmove.clean && rm -f wc.wcmove
# A peer staging the file while it is read keeps that staging – its entry is taken before the read
local WC_PEERBLOB=$(print -r -- "peer staged" | git hash-object -w --stdin)
git config filter.wcpeer.clean "sh -c '[ -e \"$TMP/wc-stage-now\" ] && rm \"$TMP/wc-stage-now\" && env -u GIT_INDEX_FILE git update-index --cacheinfo 100644,$WC_PEERBLOB,wc.wcpeer; cat'"
echo '*.wcpeer filter=wcpeer' >> .git/info/attributes && echo base > wc.wcpeer
_ST_RUN --commit --text "WC peer-staged base" -- wc.wcpeer
echo mine > wc.wcpeer && touch "$TMP/wc-stage-now"
_ST_RUN --commit --text "WC mine over a peer's staging" -- wc.wcpeer
_ST_EQ "a peer staging the file mid-read keeps its staging" "$RC:$(git ls-files -s wc.wcpeer | cut -d' ' -f2)" "0:$WC_PEERBLOB"
git config --unset filter.wcpeer.clean && git reset -q -- wc.wcpeer
# A hook landing a commit stands in for a peer landing while the commit is made
printf '#!/bin/sh\n[ -e "%s" ] && exit 0\ntouch "%s"\ngit update-ref "refs/heads/%s" "$(git commit-tree HEAD^{tree} -p HEAD -m "WC peer lands mid-commit")"\n' \
	"$TMP/wc-hooked" "$TMP/wc-hooked" "$WC_BR" > "$WC_HOOK" && chmod +x "$WC_HOOK"
echo race > wc-race.txt
WC_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- wc-race.txt
_ST_EQ "a tip moving while the commit is made refuses, the landing kept" "$RC:$(git log -1 --format=%s):$(git rev-parse HEAD~1)" "1:WC peer lands mid-commit:$WC_TIP"
_ST_OUT_HAS "asking for a rerun rather than offering the stale commit" 'Nothing landed – run it again'
rm -f "$WC_HOOK" wc-race.txt
# The repo's gate runs on it, and a path names it from anywhere
git config edit.verifyCmd "! grep -q REJECT wc-gate.txt"
echo REJECT > wc-gate.txt
WC_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- wc-gate.txt
_ST_EQ "a commit the repo's gate rejects never lands" "$RC:$(git rev-parse HEAD)" "1:$WC_TIP"
_ST_RUN --commit --text "WC past the gate" --no-verify -- "$TMP/repo/wc-gate.txt"
git config --unset edit.verifyCmd
_ST_EQ "--no-verify lands it, named by its absolute path" "$RC:$(git show HEAD:wc-gate.txt)" "0:REJECT"
