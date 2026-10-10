# Once a terminal run lands, the files the rewrite changed follow it – one still as before takes
# what landed, edits merge onto it, a conflicting merge writes nothing, as the edits may be a peer
# session's – and whatever stands where a file landed is kept, never overwritten
_ST_SCENARIO "\e[1;96m[124] a terminal run brings the checkout along\e[0m"
local BC_X BC_Y
_ST_PZ_NEW bc1
_ST_PZ_C a.txt $'1\n2\n3\n4\n5' "BC base"
_ST_PZ_C gone.txt gone "BC adds gone"
BC_X=$(git rev-parse HEAD)
_ST_PZ_C a.txt $'1\n2x\n3\n4\n5' "BC edits a"
BC_Y=$(git rev-parse HEAD)
_ST_PZ_C b.txt b "BC tip"
print -r -- $'1\n2x\n3\n4\n5y' > a.txt
print -r -- c > c.txt
_ST_TTY -- -d -y "$BC_X" "$BC_Y"
_ST_EQ "a terminal drop lands" "$RC:$(git log --format=%s | tr '\n' ' ')" "0:BC tip BC base "
_ST_CHECK "the dropped file leaves the checkout" test ! -e gone.txt
_ST_EQ "edits beside a dropped line stay, the line going" "$(tr '\n' ' ' < a.txt)" "1 2 3 4 5y "
_ST_EQ "as unstaged edits, the untracked file as it was" "$(git status --porcelain | tr '\n' '|')" " M a.txt|?? c.txt|"
_ST_OUT_HAS "naming what came along" 'now as they landed: gone.txt'
_ST_OUT_HAS "and the edits merged onto it" 'edits merged onto what landed: a.txt'
_ST_OUT_LACKS "with no hint left to run" 'Reconcile those paths'
# Undone at a terminal, the checkout comes back along the same way – the edits kept on top
_ST_TTY -- --undo
_ST_EQ "an undo brings the checkout back" "$RC:$(<gone.txt):$(tr '\n' ' ' < a.txt)" "0:gone:1 2x 3 4 5y "
_ST_EQ "nothing staged" "$(git diff --cached --name-only | wc -l | tr -d ' ')" "0"
_ST_EQ "and journals the undo as a move of its own" "$(tail -1 .git/git-edit-journal | awk '{print $5}')" "undo"
# A conflict writes nothing – no markers in a file a peer may be editing, no unmerged entry in an
# index it shares – the edits left as changes to what landed, with the merge named
_ST_PZ_NEW bc2
_ST_PZ_C a.txt $'1\n2\n3' "BC2 base"
_ST_PZ_C a.txt $'1\n2x\n3' "BC2 drop"
print -r -- $'1\n2xy\n3' > a.txt
_ST_TTY -- -d -y HEAD
_ST_EQ "edits conflicting with what landed stay as they were, unstaged" "$RC:$(git status --porcelain):$(tr '\n' ' ' < a.txt)" "0: M a.txt:1 2xy 3 "
_ST_OUT_HAS "named as left" 'conflict with what landed – left as they were, as changes to it: a.txt'
_ST_OUT_HAS "with the merge for when it is meant" "git merge-file -- a\.txt \"\$T/base\" \"\$T/landed\"\$"
eval "$(print -r -- "$OUT" | sed -n 's/^  \(T=\$(mktemp -d) && git cat-file --filters .*"\$T\/landed"\)$/\1/p')"
_ST_EQ "which merges them, markers and all" "$(grep -c '^<<<<<<< a.txt$' a.txt):$(local -a G=(a.txt.git-edit-*(N)); print ${#G})" "1:0"
git checkout -q -- a.txt
# What stands where a file lands is kept – an untracked file, an ignored one – as a change to it
_ST_PZ_NEW bc3
print -r -- ign.txt > .gitignore
_ST_PZ_C .gitignore ign.txt "BC3 ignore"
print -r -- landed > n.txt && print -r -- landed > ign.txt && git add -f n.txt ign.txt && git commit -qm "BC3 base"
git rm -q n.txt ign.txt && git commit -qm "BC3 rm"
print -r -- mine > n.txt
print -r -- mine > ign.txt
_ST_TTY -- -d -y HEAD
_ST_EQ "an untracked and an ignored file where the drop lands are kept" "$RC:$(<n.txt):$(<ign.txt)" "0:mine:mine"
_ST_EQ "as changes to what landed" "$(git status --porcelain | tr '\n' '|')" " M ign.txt| M n.txt|"
_ST_OUT_HAS "named with the restore" 'Take what landed with: git restore -- ign.txt n.txt'
# Staged whole, a merge stays staged – staged and unstaged both, it is left
_ST_PZ_NEW bc4
_ST_PZ_C f.txt $'1\n2\n3' "BC4 base"
_ST_PZ_C g.txt $'1\n2\n3' "BC4 g base"
_ST_PZ_C f.txt $'1\n2x\n3' "BC4 f"
BC_X=$(git rev-parse HEAD)
_ST_PZ_C g.txt $'1\n2x\n3' "BC4 g"
BC_Y=$(git rev-parse HEAD)
_ST_PZ_C t.txt t "BC4 tip"
print -r -- $'1\n2x\n3\n4' > f.txt && git add f.txt
print -r -- $'0\n1\n2x\n3' > g.txt && git add g.txt && print -r -- $'0\n1\n2x\n3\n4' > g.txt
_ST_TTY -- -d -y "$BC_X" "$BC_Y"
_ST_EQ "a file staged whole merges, staged" "$RC:$(git show :f.txt | tr '\n' ' '):$(git diff --name-only -- f.txt)" "0:1 2 3 4 :"
_ST_EQ "one staged and edited past that is left" "$(tr '\n' ' ' < g.txt)" "0 1 2x 3 4 "
_ST_OUT_HAS "named as such" 'g.txt – staged and unstaged edits both'
# A rename carries edits to its new path, a removed file's stay untracked, a deleted one stays so
_ST_PZ_NEW bc5
_ST_PZ_C a.txt $'1\n2\n3\n4\n5\n6\n7\n8' "BC5 base"
_ST_PZ_C d.txt $'d1\nd2' "BC5 d"
git mv a.txt z.txt && git commit -qm "BC5 mv"
BC_X=$(git rev-parse HEAD)
_ST_PZ_C e.txt e "BC5 adds e"
BC_Y=$(git rev-parse HEAD)
_ST_PZ_C d.txt $'d1\nd2x' "BC5 d edit"
print -r -- $'1\n2\n3\n4\n5\n6\n7\n8\n9' > z.txt
print -r -- e-mine > e.txt
rm d.txt
_ST_TTY -- -d -y "$BC_X" "$BC_Y"
_ST_EQ "a renamed file's edits go back to its old path" "$RC:$(tail -1 a.txt):$(test -e z.txt && echo z)" "0:9:"
_ST_OUT_HAS "named with both paths" 'z.txt → a.txt'
_ST_EQ "a removed file's edits stay, untracked" "$(<e.txt):$(git status --porcelain -- e.txt)" "e-mine:?? e.txt"
_ST_OUT_HAS "named" 'your edits to them stay, untracked: e.txt'
# Nothing the drop rewrote above d.txt, so it is no path of the move – still deleted
_ST_CHECK "a file deleted beside it stays deleted" test ! -e d.txt
# Halfway through a merge, the checkout is someone's work in progress – left, with the hints
_ST_PZ_NEW bc6
_ST_PZ_C m.txt $'1\n2' "BC6 base"
git checkout -q -b bc6-side && _ST_PZ_C m.txt $'1\n2s' "BC6 side" && git checkout -q main
_ST_PZ_C m.txt $'1\n2m' "BC6 main"
_ST_PZ_C k.txt k "BC6 drop"
git merge -q bc6-side >/dev/null 2>&1
_ST_TTY -- -d -y HEAD
_ST_EQ "a run beside a merge in progress lands, the merge kept" "$RC:$(test -e .git/MERGE_HEAD && echo merging)" "0:merging"
_ST_OUT_HAS "the checkout left as it was" 'halfway through a merge, so it stays as it was'
_ST_CHECK "k.txt still there" test -e k.txt
git merge --abort
cd "$TMP/repo"
