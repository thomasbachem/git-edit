# A fold composes from the caller's own changes as a new commit does, and puts and removals rest
# on the commit the caller names, a landing on their path since refusing rather than reverted
_ST_SCENARIO "\e[1;96m[137] a fold composes the caller's own changes, puts and removals resting on --base\e[0m"
local FI_T FI_B FI_F FI_L
_ST_PZ_NEW fi1
printf 'a\nb\nc\nd\ne\n' > app.js && chmod +x app.js && print -r -- x > other.txt
git add -A && git commit -qm "FI base"
_ST_PZ_C later.txt l "FI later"
FI_B=$(git rev-parse HEAD~1)
# The peer's WIP line and staging on the very file being folded
printf 'a\nb\nc\nDELTA\nPEER-WIP\n' > app.js
print -r -- "peer staged" > other.txt && git add other.txt
_ST_RUN --amend-into="$FI_B" --edits '{"app.js": [["d\n", "DELTA\n"]]}'
FI_F=$(git rev-parse HEAD~1)
_ST_EQ "a fold lands the edit in its target" "${RC}:$(git show "${FI_F}:app.js" | sed -n 4p)" "0:DELTA"
_ST_EQ "the tip inherits it, its mode kept" "$(git show HEAD:app.js | sed -n 4p):$(git ls-tree HEAD app.js | cut -c1-6)" "DELTA:100755"
_ST_EQ "the peer's staging and WIP line stay" "$(git show :other.txt):$(git diff HEAD -- app.js | grep -c '^+PEER-WIP')" "peer staged:1"
FI_T=$(git rev-parse HEAD)
_ST_RUN --amend-into="$FI_F" --edits '{"app.js": [["DELTA", "DELTA"]]}'
_ST_EQ "a fold changing nothing refuses" "${RC}:$(git rev-parse HEAD)" "1:$FI_T"
_ST_OUT_HAS "saying so" 'Nothing to fold'
_ST_RUN --amend-into="$FI_F" --edits '{"app.js": [["a", "b"]]}' -- app.js
_ST_OUT_HAS "paths beside the inputs refuse" 'the inputs name their own paths'
_ST_RUN --amend-into="$FI_F" --edits '{"app.js": [["a", "b"]]}' --whole -- app.js
_ST_OUT_HAS "as does a path taken whole and edited" 'app.js: named after -- to take whole, and by --edits too'
_ST_RUN --amend-into="$FI_F" --edits '{"app.js": [["a", "b"]]}' --tree=HEAD
_ST_OUT_HAS "and --tree" 'no --tree beside them'
# A fold rewording its target, adding an executable and removing a file, and a chmod in a fold
print -r -- '#!/bin/sh' > "$TMP/fi-tool.sh" && chmod +x "$TMP/fi-tool.sh"
_ST_RUN --amend-into="$FI_F" --text "FI base, reworded" --put tool.sh="$TMP/fi-tool.sh" --rm other.txt --base="$FI_T"
FI_F=$(git rev-parse HEAD~1)
_ST_EQ "a fold rewords, adds an executable and removes" \
	"${RC}:$(git log -1 --format=%s "$FI_F"):$(git ls-tree "$FI_F" tool.sh | cut -c1-6):$(git cat-file -e "${FI_F}:other.txt" 2>/dev/null && echo kept)" \
	"0:FI base, reworded:100755:"
_ST_RUN --amend-into="$FI_F" --chmod tool.sh=-x
_ST_EQ "a fold flips a mode through --chmod" "${RC}:$(git ls-tree HEAD~1 tool.sh | cut -c1-6):$(git ls-tree HEAD tool.sh | cut -c1-6)" "0:100644:100644"
_ST_OUT_HAS "and says it landed" 'Mode changes landed'
chmod -x app.js && git diff -- app.js > "$TMP/fi-mode.patch"; chmod +x app.js
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --patch "$TMP/fi-mode.patch"
_ST_OUT_HAS "a patch's flip in a fold refuses unless --chmod names it" 'mode change outside --chmod rides along: app.js'
# --base on a put: a landing on its path since refuses, one elsewhere passes, a removed path too
git checkout -q -- app.js 2>/dev/null; git restore -q --staged other.txt 2>/dev/null; rm -f other.txt
_ST_PZ_NEW fi2
_ST_PZ_C notes.txt notes "FI2 notes"
_ST_PZ_C keep.txt keep "FI2 keep"
FI_B=$(git rev-parse HEAD)
print -r -- $'notes\nput' > "$TMP/fi-notes.txt"
_ST_PZ_C elsewhere.txt e "FI2 elsewhere"
_ST_RUN --commit --text "FI2 put" --put notes.txt="$TMP/fi-notes.txt" --base="$FI_B"
_ST_EQ "a landing on another path since --base lets a put through" "${RC}:$(git show HEAD:notes.txt | tr '\n' ' ')" "0:notes put "
FI_B=$(git rev-parse HEAD)
_ST_PZ_C notes.txt $'notes\nput\npeer' "FI2 peer on notes"
FI_T=$(git rev-parse HEAD)
print -r -- $'notes\nput\nmine' > "$TMP/fi-notes2.txt"
_ST_RUN --commit --text "FI2 stale put" --put notes.txt="$TMP/fi-notes2.txt" --base="$FI_B"
_ST_EQ "a put rebuilt before a landing on its path refuses" "${RC}:$(git rev-parse HEAD)" "1:$FI_T"
_ST_OUT_HAS "naming the change between" 'notes.txt: changed between --base'
_ST_RUN --amend-into="$FI_T" --put notes.txt="$TMP/fi-notes2.txt" --base="$FI_B"
_ST_EQ "and in a fold" "${RC}:$(git rev-parse HEAD)" "1:$FI_T"
git rm -q keep.txt && git commit -qm "FI2 removes keep"
FI_T=$(git rev-parse HEAD)
_ST_RUN --commit --text "FI2 recreate" --put keep.txt="$TMP/fi-notes2.txt" --base="$FI_B"
_ST_EQ "a put recreating a path removed since --base refuses" "${RC}:$(git rev-parse HEAD)" "1:$FI_T"
# --base on a removal, as a rename's old path
_ST_PZ_C mod.txt mod "FI2 mod"
FI_B=$(git rev-parse HEAD)
_ST_PZ_C mod.txt $'mod\npeer' "FI2 peer on mod"
FI_T=$(git rev-parse HEAD)
print -r -- mod > "$TMP/fi-moved.txt"
_ST_RUN --commit --text "FI2 rename" --put moved.txt="$TMP/fi-moved.txt" --rm mod.txt --base="$FI_B"
_ST_EQ "a rename past a landing on its old path refuses" "${RC}:$(git rev-parse HEAD)" "1:$FI_T"
_ST_OUT_HAS "pointing at the removal" 'remove it with the tip as --base'
print -r -- $'mod\npeer' > "$TMP/fi-moved.txt"
_ST_RUN --commit --text "FI2 rename" --put moved.txt="$TMP/fi-moved.txt" --rm mod.txt --base="$FI_T"
_ST_EQ "a rename resting on the tip lands" "${RC}:$(git show HEAD:moved.txt | tr '\n' ' '):$(git cat-file -e HEAD:mod.txt 2>/dev/null && echo kept)" "0:mod peer :"
# Without --base a put or removal is checked against other callers' landings, as whole files are
_ST_PZ_NEW fi4
_ST_PZ_C notes.txt notes "FI4 notes"
_ST_PZ_C old.txt old "FI4 old"
print -r -- $'notes\nmine' > "$TMP/fi4-put.txt"
_ST_RUN --commit --text "FI4 put" --put notes.txt="$TMP/fi4-put.txt" --rm old.txt
_ST_EQ "with no other caller's landing on its path a put needs no --base, nor a removal" \
	"$RC:$(git show HEAD:notes.txt | tr '\n' ' '):$(git cat-file -e HEAD:old.txt 2>/dev/null && echo kept)" "0:notes mine :"
OUT=$(GIT_EDIT_ACTOR=fi-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --exec -- sh -c "printf 'notes\nmine\npeer\n' > notes.txt && echo n > added.txt && git add added.txt && git commit -qam 'FI4 peer'" </dev/null 2>&1)
FI_T=$(git rev-parse HEAD)
# Rebuilt before that landing, changing another line
print -r -- $'NOTES\nmine' > "$TMP/fi4-put2.txt"
_ST_RUN --commit --text "FI4 stale put" --put notes.txt="$TMP/fi4-put2.txt"
_ST_EQ "a put lacking another caller's landing on its path refuses" "$RC:$(git rev-parse HEAD)" "1:$FI_T"
_ST_OUT_HAS "naming the remedy" 'rebuild it from the tip, or replay your change with --edits'
_ST_RUN --commit --text "FI4 rm" --rm added.txt
_ST_EQ "as does the removal of a file another caller added" "$RC:$(git rev-parse HEAD)" "1:$FI_T"
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --put notes.txt="$TMP/fi4-put2.txt"
_ST_EQ "and a fold putting it" "$RC:$(git rev-parse HEAD)" "1:$FI_T"
_ST_RUN --commit --text "FI4 edit" --edits '{"notes.txt": [["peer", "peer, then mine"]]}'
_ST_EQ "while edits replay onto the tip, the landing kept" "$RC:$(git show HEAD:notes.txt | tr '\n' ' ')" "0:notes mine peer, then mine "
# An auto target is the commit that last touched the lines the inputs change, named as folded
_ST_PZ_C a.txt $'1\n2\n3' "FI4 a" && _ST_PZ_C b.txt b "FI4 b"
_ST_RUN --amend-into=auto --edits '{"a.txt": [["2\n", "2x\n"]]}'
_ST_EQ "--amend-into=auto finds the commit the edit's lines came from" "$RC:$(git log -1 --format=%s HEAD~1):$(git show HEAD~1:a.txt | tr '\n' ' ')" "0:FI4 a:1 2x 3 "
_ST_OUT_HAS "naming the lines folded, not staged" 'auto-target: commit that last touched the folded lines'
# Names git would read as a pattern, as magic, or as two words are each taken as themselves
_ST_PZ_NEW fi3
print -r -- x > x.txt && print -r -- br > '[x].txt' && print -r -- c > ':c.txt' && print -r -- spaced > 'a b.txt'
git add -A && git commit -qm "FI3 names"
FI_B=$(git rev-parse HEAD)
_ST_RUN --commit --text "FI3 rm" --rm '[x].txt' --base="$FI_B"
_ST_EQ "a removal of a name like a pattern takes it alone" "${RC}:$(git ls-tree --name-only HEAD | tr '\n' '|')" "0::c.txt|a b.txt|x.txt|"
_ST_RUN --commit --text "FI3 colon" --edits '{":c.txt": [["c", "C"]]}'
_ST_EQ "an edit of a name led by a colon lands" "${RC}:$(git show 'HEAD::c.txt')" "0:C"
_ST_RUN --amend-into="$(git rev-parse HEAD)" --edits '{":c.txt": [["C", "C, folded"]]}'
_ST_EQ "as does a fold of it" "${RC}:$(git show 'HEAD::c.txt')" "0:C, folded"
print -r -- "spaced, patched" > 'a b.txt' && git diff -- 'a b.txt' > "$TMP/fi-space.patch" && git checkout -q -- 'a b.txt'
_ST_RUN --commit --text "FI3 space" --patch "$TMP/fi-space.patch"
_ST_EQ "a patch on a name with a space lands" "${RC}:$(git show 'HEAD:a b.txt')" "0:spaced, patched"
# The gate checks what the inputs compose, --no-verify reaching both paths
git config edit.verifyCmd '! grep -q REJECTED gate.txt'
print -r -- ok > gate.txt && git add gate.txt && git commit -qm "FI3 gate"
FI_T=$(git rev-parse HEAD)
_ST_RUN --commit --text "FI3 rejected" --edits '{"gate.txt": [["ok", "REJECTED"]]}'
_ST_EQ "a commit the repo's check rejects never reaches the branch" "${RC}:$(git rev-parse HEAD)" "1:$FI_T"
_ST_RUN --commit --no-verify --text "FI3 rejected anyway" --edits '{"gate.txt": [["ok", "REJECTED"]]}'
_ST_EQ "--no-verify lands it" "${RC}:$(git show HEAD:gate.txt)" "0:REJECTED"
_ST_RUN --amend-into="$(git rev-parse HEAD)" --no-verify --edits '{"gate.txt": [["REJECTED", "REJECTED, folded"]]}'
_ST_EQ "and lands a fold" "${RC}:$(git show HEAD:gate.txt)" "0:REJECTED, folded"
git config --unset edit.verifyCmd
# A fold into a pushed commit takes --allow-pushed, and --snapshot carries through
git init -q --bare "$TMP/fi-origin.git" && git remote add origin "$TMP/fi-origin.git" && git push -q origin main 2>/dev/null
FI_T=$(git rev-parse HEAD)
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --edits '{"x.txt": [["x", "x, pushed"]]}'
_ST_EQ "a fold into a pushed commit refuses" "${RC}:$(git rev-parse HEAD)" "1:$FI_T"
_ST_OUT_HAS "naming it" 'already pushed'
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --allow-pushed --edits '{"x.txt": [["x", "x, pushed"]]}'
_ST_EQ "--allow-pushed lands it" "${RC}:$(git show HEAD~1:x.txt)" "0:x, pushed"
_ST_PZ_C y.txt y "FI3 y"
# `--snapshot` needs git 2.40's `merge-tree --merge-base`
if _ST_MERGE_BASE_OK; then
	_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --allow-pushed --snapshot --edits '{"x.txt": [["x, pushed", "x, snap"]]}'
	_ST_EQ "--snapshot merges the fold into the commits above" "${RC}:$(git show HEAD~1:x.txt):$(git show HEAD:x.txt)" "0:x, snap:x, snap"
fi
# A peer's staging on a path the inputs change stays staged, through a pause's resume too
_ST_PZ_NEW fi5
_ST_PZ_C f.txt $'a\nb\nc\nx\ny\nz' "FI5 A"
_ST_PZ_C f.txt $'a\nB2\nc\nx\ny\nz' "FI5 B"
print -r -- $'a\nB2\nc\nx\ny\nPEER' > f.txt && git add f.txt
_ST_RUN --amend-into="$(git rev-parse HEAD)" --edits '{"f.txt": [["a\n", "A\n"]]}'
_ST_EQ "a peer's staging on a path a fold changes stays staged" "${RC}:$(git show HEAD:f.txt | head -1):$(git show :f.txt | tail -1)" "0:A:PEER"
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --edits '{"f.txt": [["B2\n", "B3\n"]]}'
_ST_EQ "a fold into the older commit pauses on its replay" "$RC" "2"
# Each stop resolved to what its own commit holds – the fold's B3 on the older commit, then the
# later one's A on top – as taking the later A in early is an absorption the replay refuses
local FI_N
for FI_N in $'a\nB3\nc\nx\ny\nz' $'A\nB3\nc\nx\ny\nz'; do
	[ "$RC" = 2 ] || break
	_ST_RESOLVE "$(_ST_PZ_WT)" f.txt "$FI_N"
	_ST_RUN --continue
done
_ST_EQ "and through a resume" "${RC}:$(git show HEAD:f.txt | sed -n 2p):$(git show :f.txt | tail -1)" "0:B3:PEER"
cd "$TMP/repo"
