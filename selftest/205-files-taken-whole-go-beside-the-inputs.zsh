# Files taken whole go beside the inputs, each as `-- <paths>` alone takes it – the named-path checks,
# conflict markers, other callers' landings or `--base`, a removal where the checkout lacks the file,
# the index re-sync – where rebuilding them as inputs skipped the landings guard
# An edit losing its one match to an earlier edit of the same list names that edit, not a peer
_ST_SCENARIO "\e[1;96m[205] files taken whole go beside the inputs, guarded as alone, and an overlapping edit is named\e[0m"
local MX_T MX_O
_ST_PZ_NEW mx1
printf '1\n2\n3\n4\n5\n6\n7\n8\n' > a.txt && print -r -- w > w.txt && print -r -- gone > g.txt
printf '#!/bin/sh\n' > x.sh && chmod +x x.sh
git add -A && git commit -qm "MX base"
# A commit of edits, a file taken whole and one the checkout lost, a peer's line in the edited file
printf '1\nMINE\n3\n4\n5\n6\n7\nPEER\n' > a.txt
print -r -- "w, mine" > w.txt && git add w.txt
mv g.txt "$TMP/mx-g.txt"
_ST_RUN --commit --text "MX mixed" --edits '{"a.txt": [["1\n2\n", "1\nMINE\n"]]}' -- w.txt g.txt
_ST_EQ "edits and files taken whole land as one commit" "$RC:$(git show HEAD:a.txt | tr '\n' ' '):$(git show HEAD:w.txt)" "0:1 MINE 3 4 5 6 7 8 :w, mine"
_ST_EQ "a file the checkout lacks removed" "$(git cat-file -e HEAD:g.txt 2>/dev/null && echo kept)" ""
_ST_OUT_HAS "the run names the files taken whole" 'Committing 3 file(s), 2 of them whole, on'
_ST_EQ "the peer's line stays in the checkout" "$(git diff HEAD -- a.txt | grep -c '^+PEER')" "1"
_ST_EQ "the whole file's staging re-synced, as alone" "$(git diff --cached --name-only -- w.txt g.txt)" ""
# The same mix folds, `--whole` saying the paths are files and not staged changes
_ST_PZ_C t.txt t1 "MX target"
MX_T=$(git rev-parse HEAD)
_ST_PZ_C u.txt u1 "MX above"
print -r -- "w, folded" > w.txt
_ST_RUN --amend-into="$MX_T" --whole --edits '{"a.txt": [["3\n", "THREE\n"]]}' -- w.txt
_ST_EQ "a fold takes them beside the inputs" "$RC:$(git show HEAD~1:w.txt):$(git show HEAD~1:a.txt | sed -n 3p):$(git log -1 --format=%s HEAD~1)" "0:w, folded:THREE:MX target"
_ST_OUT_HAS "naming the files taken whole" 'Amending 2 file(s), 1 of them whole, into'
MX_T=$(git rev-parse HEAD)
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --edits '{"a.txt": [["4\n", "FOUR\n"]]}' -- w.txt
_ST_EQ "without --whole, paths beside the inputs still refuse" "$RC:$(git rev-parse HEAD)" "1:$MX_T"
_ST_OUT_HAS "naming --whole" 'files folded whole beside them take --whole'
# One left stale by another caller's landing refuses as taken alone, nothing landing
_ST_PZ_C s.txt $'s1\ns2\ns3\ns4\ns5\ns6' "MX s base"
GIT_EDIT_ACTOR=mx-peer _ST_RUN --exec -- sh -c "printf 's1\nPEER\ns3\ns4\ns5\ns6\n' > s.txt && git commit -qam 'MX peer lands'"
MX_T=$(git rev-parse HEAD)
printf 's1\ns2\ns3\ns4\ns5\nMINE\n' > s.txt
GIT_EDIT_ACTOR=mx-self _ST_RUN --commit --text "MX stale" --edits '{"a.txt": [["4\n", "FOUR\n"]]}' -- s.txt
_ST_EQ "a stale file taken whole beside the inputs refuses" "$RC:$(git rev-parse HEAD)" "1:$MX_T"
_ST_OUT_HAS "as the landings guard refuses it alone" 'Committed whole, 1 file(s) would take back what another caller landed: s.txt'
_ST_OUT_HAS "naming the carry" "--carry=$(git rev-parse --short=12 HEAD~1)"
GIT_EDIT_ACTOR=mx-self _ST_RUN --commit --text "MX stale base" --base="$(git rev-parse HEAD~1)" --edits '{"a.txt": [["4\n", "FOUR\n"]]}' -- s.txt
_ST_EQ "against a --base it refuses as alone too" "$RC:$(git rev-parse HEAD)" "1:$MX_T"
_ST_OUT_HAS "a path changed since named" 'so committed whole they would take that back: s.txt'
GIT_EDIT_ACTOR=mx-self _ST_RUN --commit --text "MX stale tip" --base="$MX_T" --edits '{"a.txt": [["4\n", "FOUR\n"]]}' -- s.txt
_ST_EQ "and the tip as --base takes the landing back on purpose" "$RC:$(git show HEAD:s.txt | tr '\n' ' '):$(git show HEAD:a.txt | sed -n 4p)" "0:s1 s2 s3 s4 s5 MINE :FOUR"
# Conflict markers, a mode change, a path named both ways and a --tree beside paths refuse
MX_T=$(git rev-parse HEAD)
printf 'm1\n<<<<<<< ours\nx\n=======\ny\n>>>>>>> theirs\n' > m.txt
_ST_RUN --commit --text "MX markers" --edits '{"a.txt": [["5\n", "FIVE\n"]]}' -- m.txt
_ST_EQ "conflict markers in a file taken whole refuse" "$RC:$(git rev-parse HEAD)" "1:$MX_T"
_ST_OUT_HAS "named as taken whole" 'Conflict markers in 1 file(s) taken whole – nothing landed: m.txt'
mv m.txt "$TMP/mx-m.txt"
chmod -x x.sh && print -r -- 'echo x' >> x.sh
_ST_RUN --commit --text "MX flip" --edits '{"a.txt": [["5\n", "FIVE\n"]]}' -- x.sh
_ST_EQ "a mode change on a file taken whole refuses" "$RC:$(git rev-parse HEAD)" "1:$MX_T"
_ST_OUT_HAS "with the whole file's remedy" 'A file-mode change rides along on a file taken whole'
chmod +x x.sh
_ST_RUN --commit --text "MX both" --edits '{"a.txt": [["5\n", "FIVE\n"]]}' -- a.txt
_ST_OUT_HAS "a path taken whole and edited refuses, naming both" 'a.txt: named after -- to take whole, and by --edits too'
_ST_RUN --commit --text "MX both rm" --rm x.sh -- x.sh
_ST_OUT_HAS "as does one removed" 'x.sh: named after -- to take whole, and by --rm too'
git diff HEAD -- a.txt > "$TMP/mx.patch"
_ST_RUN --commit --text "MX both patch" --patch "$TMP/mx.patch" -- a.txt
_ST_OUT_HAS "or patched" 'a.txt: named after -- to take whole, and by --patch too'
MX_O=$(_ST_COMPOSE w.txt "composed")
_ST_RUN --commit --text "MX tree" --tree="$MX_O" -- w.txt
_ST_OUT_HAS "--tree beside paths still refuses" '--commit --tree commits that tree alone – no paths beside it'
_ST_EQ "none of them moving the branch" "$(git rev-parse HEAD)" "$MX_T"
_ST_RUN --commit --text "MX whole x" --edits '{"a.txt": [["5\n", "FIVE\n"]]}' -- x.sh
_ST_EQ "a file taken whole beside an edit lands, the checkout's bit kept" "$RC:$(git ls-tree HEAD x.sh | cut -c1-6):$(git show HEAD:x.sh | tail -1)" "0:100755:echo x"
# Edits replay in order – one whose old text an earlier edit rewrote names that edit
_ST_PZ_NEW mx2
_ST_PZ_C o.txt $'A\nB\nC\nD' "MX2 base"
MX_T=$(git rev-parse HEAD)
_ST_RUN --commit --text "MX2 overlap" --edits '{"o.txt": [["B\n", "b\n"], ["B\nC\n", "B\nc\n"]]}'
_ST_EQ "an edit overlapping an earlier one refuses" "$RC:$(git rev-parse HEAD)" "1:$MX_T"
_ST_OUT_HAS "naming that edit, its old text on one line" "o.txt: edit 2 (.'B.nC.n') overlaps edit 1"
_ST_OUT_HAS "and the merge that fixes it" 'merge edits 1 and 2 into one edit'
_ST_OUT_LACKS "never a peer's line" "a peer's line sits inside it"
_ST_RUN --commit --text "MX2 middle" --edits '{"o.txt": [["A\n", "a\n"], ["C\n", "c\n"], ["B\nC", "x"]]}'
_ST_OUT_HAS "the one it overlaps among several" "edit 3 (.*B.*) overlaps edit 2"
_ST_RUN --commit --text "MX2 repeat" --edits '{"o.txt": [["A\n", "A\nD\n"], ["D", "d"]]}'
_ST_OUT_HAS "as is one an earlier edit's new text repeats" "edit 2 (D) overlaps edit 1"
_ST_RUN --commit --text "MX2 missing" --edits '{"o.txt": [["A\n", "a\n"], ["Z\n", "z\n"]]}'
_ST_OUT_HAS "an old text the tip lacks keeps today's message" "no match for edit 2 (.*Z.*) – a peer's line sits inside it"
_ST_EQ "none of them landing" "$(git rev-parse HEAD)" "$MX_T"
cd "$TMP/repo"
