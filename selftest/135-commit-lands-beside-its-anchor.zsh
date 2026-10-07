# A new commit lands beside the one it belongs with in the same run – built on the tip, then
# replayed into place, so the branch never holds it at the tip and no second run moves it
_ST_SCENARIO "\e[1;96m[135] a commit lands beside its anchor in one run, never at the tip first\e[0m"
local PL_A PL_T PL_WT PL_N
_ST_PZ_NEW pl1
_ST_PZ_C a.txt a "PL a" && _ST_PZ_C b.txt b "PL b" && _ST_PZ_C c.txt c "PL c"
PL_A=$(git rev-parse HEAD~2)
PL_T=$(git rev-parse HEAD)
PL_N=$(git reflog main | wc -l)
print -r -- n > n.txt
_ST_RUN --commit --text "PL n" --after="$PL_A" -- n.txt
_ST_EQ "--after lands the commit right above its anchor" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:PL c|PL b|PL n|PL a|"
_ST_EQ "in one move of the branch, named for the placement" \
	"$(( $(git reflog main | wc -l) - PL_N )):$(git reflog -1 --format=%gs main)" "1:git edit: commit after ${PL_A:0:7}"
_ST_EQ "the tip as a commit there would have left it" "$(git diff --name-only "$PL_T" HEAD)" "n.txt"
_ST_OUT_HAS "naming the commit where it landed" "committed after ${PL_A:0:7}: [0-9a-f]* PL n"
_ST_EQ "the checkout current" "$(git status --porcelain)" ""
print -r -- m > m.txt
PL_T=$(git rev-parse HEAD)
_ST_RUN --commit --text "PL m" --before=HEAD -- m.txt
_ST_EQ "--before lands it right below its anchor" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:PL c|PL m|PL b|PL n|PL a|"
_ST_EQ "named for the placement's own word" "$(git reflog -1 --format=%gs main)" "git edit: commit before ${PL_T:0:7}"
print -r -- t > t.txt
_ST_RUN --commit --text "PL t" --after=HEAD -- t.txt
_ST_EQ "after the tip, it lands as a plain commit does" "${RC}:$(git log -1 --format=%s):$(git reflog -1 --format=%gs main)" "0:PL t:git edit: commit"
# What an `--exec` command adds on top goes the same way, one that rewrote history refusing
_ST_RUN --exec --after="$PL_A" -- sh -c 'echo e > e.txt && git add e.txt && git commit -qm "PL e"'
_ST_EQ "--exec places the commits its command added" "${RC}:$(git log --reverse --format=%s | sed -n 2p)" "0:PL e"
_ST_OUT_HAS "naming them" '^Placed after'
# What the command leaves uncommitted beside its commit never lands, nor stops the placement
_ST_RUN --exec --after="$PL_A" -- sh -c 'echo d > d.txt && git add d.txt && git commit -qm "PL d" && echo left >> a.txt && echo junk > junk.txt'
_ST_EQ "a command's leftovers are dropped rather than read as a conflict" "$RC:$(git log --reverse --format=%s | sed -n 2p):$(git show HEAD:a.txt)" "0:PL d:a"
_ST_OUT_HAS "and named" 'Dropped what the command left uncommitted, which never lands: a.txt, junk.txt'
PL_T=$(git rev-parse HEAD)
_ST_RUN --exec --after="$PL_A" -- git commit --amend -qm "PL amended"
_ST_EQ "a command that rewrote history instead refuses" "${RC}:$(git rev-parse HEAD)" "1:$PL_T"
_ST_OUT_HAS "saying why" 'the command rewrote history instead'
_ST_RUN -d --after="$PL_A" HEAD
_ST_EQ "--after refuses on a mode it does not apply to" "$RC" "1"
_ST_OUT_HAS "naming the ones it does" 'only apply to --move, --commit and --exec'
print -r -- x > x.txt
_ST_RUN --commit --text "PL x" --after="$PL_A" --before=HEAD -- x.txt
_ST_EQ "and refuses both at once" "${RC}:$(git rev-parse HEAD)" "1:$PL_T"
# A pushed commit above the anchor refuses before anything is built
git init -q --bare "$TMP/pl-origin.git" && git remote add origin "$TMP/pl-origin.git" && git push -q origin main 2>/dev/null
_ST_RUN --commit --text "PL x" --after=HEAD~1 -- x.txt
_ST_EQ "placing below a pushed commit refuses, nothing landed" "${RC}:$(git rev-parse HEAD):$(git status --porcelain -- x.txt)" "1:$PL_T:?? x.txt"
_ST_OUT_HAS "naming it" 'already pushed'
# A conflict placing it pauses as a move does, with nothing landed – the tip it read is what the
# resume lands against, and what was built on it what a clean replay reproduces
_ST_PZ_NEW pl2
_ST_PZ_C f.txt $'1\n2\n3\n4' "PL2 A"
_ST_PZ_C f.txt $'1\n2b\n3\n4' "PL2 B"
PL_A=$(git rev-parse HEAD~1)
PL_T=$(git rev-parse HEAD)
print -r -- $'1\n2b\n3c\n4' > f.txt
_ST_RUN --commit --text "PL2 N" --after="$PL_A" -- f.txt
_ST_EQ "a placement that conflicts pauses with nothing landed" "${RC}:$(git rev-parse HEAD)" "2:$PL_T"
_ST_OUT_HAS "saying so" 'nothing landed'
_ST_RUN --abort
_ST_EQ "an abort leaves the branch and the checkout's edit as they were" "${RC}:$(git rev-parse HEAD):$(git diff --name-only)" "0:$PL_T:f.txt"
_ST_RUN --commit --text "PL2 N" --after="$PL_A" -- f.txt
PL_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$PL_WT" f.txt $'1\n2\n3c\n4'
_ST_RUN --continue
_ST_EQ "a resolved placement lands once, the tip's own commit above it" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:PL2 B|PL2 N|PL2 A|"
_ST_EQ "the tip as it was built, the placed commit carrying its own change" \
	"$(git show HEAD:f.txt | tr '\n' ' '):$(git show HEAD~1:f.txt | tr '\n' ' ')" "1 2b 3c 4 :1 2 3c 4 "
_ST_EQ "under the placement's name" "$(git reflog -1 --format=%gs main)" "git edit: commit after ${PL_A:0:7}"
_ST_OUT_HAS "its tree what was built" 'Tip tree identical'
_ST_EQ "the checkout current" "$(git status --porcelain)" ""
# At a terminal a placement's conflict is a prompt like any pause's, Enter landing it once resolved
_ST_PZ_NEW pl5
_ST_PZ_C f.txt $'1\n2\n3\n4' "PL5 A"
_ST_PZ_C f.txt $'1\n2b\n3\n4' "PL5 B"
print -r -- $'1\n2b\n3t\n4' > f.txt
_ST_TTY_START -- --commit --text "PL5 T" --after=HEAD~1 -- f.txt
if _ST_TTY_AT 'Resolve the conflicts in'; then
	_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'1\n2\n3t\n4'
	zpty -wn ST_TTY $'\r'
fi
_ST_TTY_END
_ST_EQ "a placement resolved at a terminal's prompt lands beside its anchor" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:f.txt | tr '\n' ' ')" "0:PL5 B|PL5 T|PL5 A|:1 2b 3t 4 "
cd "$TMP/pz-pl2"
# A replay aborted by hand there lands nothing, not even the commit at the tip
PL_T=$(git rev-parse HEAD)
print -r -- $'1\n2b\n3c\n4d' > f.txt
_ST_RUN --commit --text "PL2 M" --after="$PL_A" -- f.txt
PL_WT=$(_ST_PZ_WT)
git -C "${PL_WT:-$ST_NO_WT}" rebase --abort >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a placement aborted by hand in its worktree lands nothing" "${RC}:$(git rev-parse HEAD)" "1:$PL_T"
_ST_OUT_HAS "saying it was aborted" 'aborted by hand'
_ST_RUN --abort
git checkout -q -- f.txt
# The gate checks the commit where it lands, not only the tip, which still carries what it needs
_ST_PZ_NEW pl3
_ST_PZ_C a.txt a "PL3 a"
_ST_PZ_C need.txt need "PL3 need"
PL_A=$(git rev-parse HEAD~1)
PL_T=$(git rev-parse HEAD)
# A check naming no path of the repo, which the gate would skip a commit lacking
print -r -- '[ ! -e use.txt ] || [ -e need.txt ]' > "$TMP/pl3-check" && chmod +x "$TMP/pl3-check"
git config edit.verifyCmd "$TMP/pl3-check"
print -r -- use > use.txt
_ST_RUN --commit --text "PL3 use" --after="$PL_A" -- use.txt
_ST_EQ "a placed commit failing the check there lands nothing" "${RC}:$(git rev-parse HEAD)" "1:$PL_T"
_ST_OUT_HAS "the check run where it landed" 'PL3 use'
_ST_RUN --commit --text "PL3 use" -- use.txt
_ST_EQ "where at the tip it passes" "${RC}:$(git log -1 --format=%s)" "0:PL3 use"
git config --unset edit.verifyCmd
# A move whose resolution brings content in re-syncs the checkout's index, as any rewrite does,
# rather than leave the new path reading as a staged removal
_ST_PZ_NEW pl4
_ST_PZ_C f.txt $'1\n2\n3\n4' "PL4 A"
_ST_PZ_C f.txt $'1\n2b\n3\n4' "PL4 B"
_ST_PZ_C f.txt $'1\n2b\n3c\n4' "PL4 C"
_ST_RUN --move=HEAD --before=HEAD~1
PL_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$PL_WT" f.txt $'1\n2\n3c\n4'
print -r -- g > "${PL_WT:-$ST_NO_WT}/g.txt" && git -C "${PL_WT:-$ST_NO_WT}" add g.txt
_ST_RUN --continue
_ST_RESOLVE "$PL_WT" f.txt $'1\n2b\n3c\n4'
_ST_RUN --continue
_ST_EQ "a move whose resolution added a file lands it" "${RC}:$(git show HEAD:g.txt 2>/dev/null)" "0:g"
_ST_EQ "the checkout's index re-synced, the file named as missing there" "$(git status --porcelain -- g.txt)" " D g.txt"
cd "$TMP/repo"
