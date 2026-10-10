# The landings guard reads a name ending in CR and a landed mode flip, never offers a restore over
# the caller's own file, markers refuse in every fold, and case clashes fold as the filesystem does
_ST_SCENARIO "\e[1;96m[146] guards read every name, a mode flip, every fold's markers, and case as the filesystem folds it\e[0m"
local GR_T GR_N GR_TREE GR_IDX="$TMP/gr-index"
# A stale copy taking back a peer's edit to a name ending in a CR refuses, as for any other
_ST_PZ_NEW gr1
GR_N=$'notes\r'
print -l l{01..10} > "$GR_N" && cp "$GR_N" plain.txt && git add -A && git commit -qm "GR base" && git commit -q --allow-empty -m "GR target"
OUT=$(GIT_EDIT_ACTOR=gr-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "GR peer" --edits '{"notes\r": [["l02\n", "TWO\n"]], "plain.txt": [["l02\n", "TWO\n"]]}' </dev/null 2>&1)
GR_T=$(git rev-parse HEAD)
git show "HEAD~1:$GR_N" | sed 's/^l09$/NINE/' > "$GR_N"
OUT=$(GIT_EDIT_ACTOR=gr-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "GR stale" -- "$GR_N" </dev/null 2>&1)
RC=$?
_ST_EQ "a stale copy of a name ending in CR refuses" "$RC:$(git rev-parse HEAD)" "1:$GR_T"
_ST_OUT_HAS "naming the landing" "gr-peer's commit run"
git show "HEAD:$GR_N" | sed 's/^l09$/NINE/' > "$GR_N"
OUT=$(GIT_EDIT_ACTOR=gr-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "GR on top" -- "$GR_N" </dev/null 2>&1)
RC=$?
_ST_EQ "while edits on top of the landing land, keeping it" "$RC:$(git show "HEAD:$GR_N" | sed -n 2p)" "0:TWO"
# As does a staged fold of a name holding a newline, which a line per lookup split in two
GR_N=$'two\nlines.txt'
print one > "$GR_N" && git add -- "$GR_N" && git commit -qm "GR newline" && git commit -q --allow-empty -m "GR above"
print two > "$GR_N" && git add -- "$GR_N"
OUT=$(GIT_EDIT_ACTOR=gr-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --amend-into="$(git rev-parse HEAD~1)" -- "$GR_N" </dev/null 2>&1)
RC=$?
_ST_EQ "a staged fold of a name holding a newline lands past another caller's landings" "$RC:$(git show "HEAD~1:$GR_N")" "0:two"
# A file of the caller's own where another caller added one is never pointed at a restore over it
_ST_PZ_NEW gr2
_ST_PZ_C base.txt b "GR2 base" && git commit -q --allow-empty -m "GR2 target"
print -l b1 b2 b3 b4 > "$TMP/gr2-notes"
OUT=$(GIT_EDIT_ACTOR=gr-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "GR2 peer adds" --put notes.txt="$TMP/gr2-notes" </dev/null 2>&1)
GR_T=$(git rev-parse HEAD)
print -l "own 1" "own 2" "own 3" > notes.txt
OUT=$(GIT_EDIT_ACTOR=gr-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "GR2 own" -- notes.txt </dev/null 2>&1)
RC=$?
_ST_EQ "a file of the caller's own over one another caller added refuses" "$RC:$(git rev-parse HEAD)" "1:$GR_T"
_ST_OUT_HAS "pointing at moving it aside or merging by hand" 'Your own notes.txt stands where another caller added one – move yours aside or merge the two by hand'
_ST_OUT_LACKS "never at a restore that overwrites it" 'restore --source=HEAD --worktree'
_ST_EQ "the file left as it was" "$(sed -n 1p notes.txt)" "own 1"
OUT=$(GIT_EDIT_ACTOR=gr-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "GR2 own" --base="$GR_T" -- notes.txt </dev/null 2>&1)
RC=$?
_ST_EQ "and replaces it with --base where that is meant" "$RC:$(git show HEAD:notes.txt | sed -n 1p)" "0:own 1"
# A landing flipping only a file's executable bit is taken back by a file still under the old mode
_ST_PZ_NEW gr3
print -l l{1..6} > f.sh && print y > y.sh && git add -A && git commit -qm "GR3 base" && git commit -q --allow-empty -m "GR3 target"
print l7 >> f.sh
OUT=$(GIT_EDIT_ACTOR=gr-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "GR3 peer chmod" --chmod f.sh=+x </dev/null 2>&1)
GR_T=$(git rev-parse HEAD)
chmod -x f.sh && chmod +x y.sh
OUT=$(GIT_EDIT_ACTOR=gr-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "GR3 self" --allow-mode-change -- f.sh y.sh </dev/null 2>&1)
RC=$?
_ST_EQ "a file taking back another caller's mode flip refuses, --allow-mode-change or not" "$RC:$(git rev-parse HEAD)" "1:$GR_T"
_ST_OUT_HAS "naming the flip" 'f.sh – gr-peer.*which made it executable'
_ST_OUT_HAS "and the chmod taking it" 'chmod -- +x f.sh'
chmod +x f.sh
OUT=$(GIT_EDIT_ACTOR=gr-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "GR3 self" --allow-mode-change -- f.sh y.sh </dev/null 2>&1)
RC=$?
_ST_EQ "while the file under the landed bit lands, its own flip beside it" "$RC:$(git ls-tree HEAD f.sh y.sh | cut -c1-6 | tr '\n' ' ')" "0:100755 100755 "
# As does a flip landed beside an edit, by a file holding that edit under the old mode
print -l g1 g2 g3 > g.sh && git add g.sh && git commit -qm "GR3 g"
OUT=$(GIT_EDIT_ACTOR=gr-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "GR3 peer edit+chmod" --edits '{"g.sh": [["g1\n", "G1\n"]]}' --chmod g.sh=+x </dev/null 2>&1)
GR_T=$(git rev-parse HEAD)
git show HEAD:g.sh > g.sh && print g4 >> g.sh && chmod -x g.sh
OUT=$(GIT_EDIT_ACTOR=gr-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "GR3 self g" --allow-mode-change -- g.sh </dev/null 2>&1)
RC=$?
_ST_EQ "a flip landed beside an edit the file holds refuses under the old mode" "$RC:$(git rev-parse HEAD)" "1:$GR_T"
_ST_OUT_HAS "naming its chmod" 'chmod -- +x g.sh'
cp g.sh "$TMP/gr3-put" && chmod -x "$TMP/gr3-put"
OUT=$(GIT_EDIT_ACTOR=gr-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "GR3 put g" --put g.sh="$TMP/gr3-put" </dev/null 2>&1)
RC=$?
_ST_EQ "while a put keeps the landed bit, as it keeps the tip's mode" "$RC:$(git ls-tree HEAD g.sh | cut -c1-6):$(git show HEAD:g.sh | sed -n 1p)" "0:100755:G1"
# Conflict markers refuse a fold of staged content and of a --tree at the first run, each named
_ST_PZ_NEW gr4
print -l l1 l2 l3 > f.txt && git add f.txt && git commit -qm "GR4 base" && git commit -q --allow-empty -m "GR4 tip"
GR_T=$(git rev-parse HEAD)
print -l l1 '<<<<<<< ours' mine '=======' theirs '>>>>>>> landed' l3 > f.txt && git add f.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" -- f.txt
_ST_EQ "a staged fold carrying conflict markers refuses" "$RC:$(git rev-parse HEAD)" "1:$GR_T"
_ST_OUT_HAS "named as staged" 'Conflict markers in 1 file(s) as staged – nothing landed: f.txt'
git reset -q && git checkout -q -- f.txt
rm -f "$GR_IDX" && GIT_INDEX_FILE=$GR_IDX git read-tree HEAD
GIT_INDEX_FILE=$GR_IDX git update-index --cacheinfo "100644,$(print -l l1 '<<<<<<< ours' a '=======' b '>>>>>>> x' l3 | git hash-object -w --stdin),f.txt"
GR_TREE=$(git commit-tree "$(GIT_INDEX_FILE=$GR_IDX git write-tree)" -p HEAD -m "GR4 composed")
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --tree="$GR_TREE"
_ST_EQ "as does a --tree fold" "$RC:$(git rev-parse HEAD)" "1:$GR_T"
_ST_OUT_HAS "named as the tree's" 'Conflict markers in 1 file(s) of the --tree – nothing landed: f.txt'
print -l l1 '<<<<<<< ours' a '=======' b '>>>>>>> x' l3 > "$TMP/gr4-put"
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --put f.txt="$TMP/gr4-put"
_ST_OUT_HAS "a put's named as the inputs', never as files taken whole" 'Conflict markers in 1 file(s) from the inputs – nothing landed: f.txt'
print -l l1 l2x l3 > f.txt && git add f.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" -- f.txt
_ST_EQ "while a staged fold free of them lands" "$RC:$(git show HEAD~1:f.txt | sed -n 2p)" "0:l2x"
# Where the filesystem ignores case, a non-ASCII name folds as it does, whatever the locale, and a
# patch's new path is checked as a put's is
_ST_PZ_NEW gr5
git config core.ignorecase true
print one > $'\xc3\xa9.txt' && print cs > cs.txt && git add -A && git commit -qm "GR5 base"
GR_T=$(git rev-parse HEAD)
print two > "$TMP/gr5-src"
LC_ALL=C LANG= _ST_RUN --commit --text "GR5 put" --put $'\xc3\x89.txt'="$TMP/gr5-src"
_ST_EQ "a put spelling a non-ASCII tip name in another case refuses" "$RC:$(git rev-parse HEAD)" "1:$GR_T"
_ST_OUT_HAS "naming the tip's spelling" $'\xc3\x89.txt differs from the tip\'s \xc3\xa9.txt only in case'
LC_ALL=C LANG= _ST_RUN --commit --text "GR5 whole" -- $'\xc3\x89.txt'
_ST_EQ "as does a file taken whole under the C locale" "$RC:$(git rev-parse HEAD)" "1:$GR_T"
printf 'diff --git a/CS.txt b/CS.txt\nnew file mode 100644\n--- /dev/null\n+++ b/CS.txt\n@@ -0,0 +1 @@\n+cased\n' > "$TMP/gr5.patch"
_ST_RUN --commit --text "GR5 patch" --patch "$TMP/gr5.patch"
_ST_EQ "and a patch adding a tip name in another case" "$RC:$(git rev-parse HEAD)" "1:$GR_T"
_ST_OUT_HAS "named as the put's is" "CS.txt differs from the tip's cs.txt only in case"
LC_ALL=C LANG= _ST_RUN --commit --text "GR5 new" --put $'\xc3\xbc.txt'="$TMP/gr5-src"
_ST_EQ "while a non-ASCII name no tip name folds to lands" "$RC:$(git ls-tree --name-only HEAD | wc -l | tr -d ' ')" "0:3"
# A case-only rename lands where the run removes the old spelling, the result holding the new alone
print hello > readme.md && git add readme.md && git commit -qm "GR5 readme"
GR_T=$(git rev-parse HEAD)
cp readme.md "$TMP/gr5-readme"
_ST_RUN --commit --text "GR5 cased" --put README.md="$TMP/gr5-readme"
_ST_EQ "a put of the new spelling alone refuses" "$RC:$(git rev-parse HEAD)" "1:$GR_T"
_ST_OUT_HAS "pointing at the removal that renames" 'or rename it by removing readme.md in the same run'
_ST_RUN --commit --text "GR5 rename" --rm readme.md --put README.md="$TMP/gr5-readme"
_ST_EQ "a removal of the old beside a put of the new renames" "$RC:$(git ls-tree --name-only HEAD | grep -ci '^readme.md$'):$(git ls-tree --name-only HEAD | grep -c '^README.md$')" "0:1:1"
git reset -q --hard
mv README.md gr5-t.md && mv gr5-t.md Readme.md
_ST_RUN --commit --text "GR5 whole rename" -- README.md Readme.md
_ST_EQ "as do both spellings taken whole after a mv" "$RC:$(git ls-tree --name-only HEAD | grep -i '^readme.md$')" "0:Readme.md"
_ST_EQ "the checkout left clean" "$(git status --porcelain)" ""
git config core.ignorecase false
# A name holding valid UTF-8 and a byte that is none reaches the tip's entry as itself
_ST_PZ_NEW gr6
git config core.precomposeUnicode true
GR_N=$'caf\xc3\xa9-\xe9.txt'
git update-index --add --cacheinfo "100644,$(print old | git hash-object -w --stdin),$GR_N" && git commit -qm "GR6 base"
_ST_RUN --commit --text "GR6 rm" --rm "$GR_N"
_ST_OUT_LACKS "a name iconv can't read is never mangled into another" 'not at the tip'
_ST_CHECK "reaching the landing – or a filesystem refusing such a name" grep -qE -e '^git-edit: ok|Could not create the worktree' <<<"$OUT"
# A conflicted file whose name ends in a CR is read as itself, its markers found
_ST_PZ_NEW gr7
GR_N=$'notes\r'
print -l a b c > "$GR_N" && git add -A && git commit -qm "GR7 base"
print -l a B c > "$GR_N" && git commit -qam "GR7 later"
print -l a b2 c > "$GR_N" && git add -A
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" -- "$GR_N"
_ST_OUT_HAS "a conflict on a name ending in a CR pauses" 'Conflicted files:'
_ST_OUT_LACKS "its markers read in that file" 'No conflict markers in'
_ST_RUN --abort
git reset -q --hard
# Names reach a replant's refusal and an edit's absorbed files as themselves, never C-quoted
_ST_PZ_NEW gr8
print o > $'\xc3\xa9.txt' && print o > $'c\r' && git add -A && git commit -qm "GR8 base"
git checkout -q -b gr8-up && print u > $'\xc3\xa9.txt' && print u > $'c\r' && git commit -qam "GR8 up"
git checkout -q -b gr8-feature main && _ST_PZ_C f.txt f "GR8 feature"
print mine > $'\xc3\xa9.txt' && print mine > $'c\r'
_ST_RUN --onto=gr8-up
_ST_EQ "a replant over uncommitted work refuses" "$RC" "1"
_ST_OUT_HAS "naming a non-ASCII path as itself" $'^ *\xc3\xa9.txt'
_ST_OUT_HAS "and one ending in a CR in caret notation" '^ *c^M'
git checkout -q -- . && _ST_PZ_C g.txt g "GR8 target" && _ST_PZ_C h.txt h "GR8 later"
_ST_RUN HEAD~1
GR_T=$(_ST_PZ_WT)
print s > "${GR_T:-$ST_NO_WT}/"$'\xc3\xa9-new.txt' && print s > "${GR_T:-$ST_NO_WT}/"$'n\r'
_ST_RUN --continue
_ST_OUT_HAS "an edit names the untracked files it absorbs" 'Absorbing 2 untracked file'
_ST_OUT_HAS "one ending in a CR unquoted" '^ *n^M'
_ST_OUT_HAS "beside a non-ASCII one" $'^ *\xc3\xa9-new.txt'
# A split by path takes a commit whose other name ends in a CR, counted as one
_ST_PZ_C d.txt d "GR8 d base"
print d2 > d.txt && print c2 > $'c\r' && git add -A && git commit -qm "GR8 both"
_ST_RUN --split=HEAD --text "GR8 d alone" -- d.txt
_ST_EQ "a split by path beside a name ending in a CR lands" "$RC:$(git show --name-only --format= HEAD~1)" "0:d.txt"
cd "$TMP/repo"
