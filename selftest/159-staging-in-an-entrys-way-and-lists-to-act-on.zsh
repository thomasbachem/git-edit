# A re-sync keeps staging an entry it writes would replace – files staged under a path a file lands
# at, a file staged where a directory goes – naming the path once, a merged file a peer staged
# meanwhile reads as merged, and a list each of whose names takes its own action names every one
_ST_SCENARIO "\e[1;96m[159] staging in a landed entry's way stays, named once, and lists to act on name every path\e[0m"
local SW_REAL SW_BIN SW_BLOB SW_U SW_I
local -a SW_ARGS
# Files staged under a path a terminal drop puts a file at stay staged, the path left as it was
_ST_PZ_NEW sw1
print a > a.txt && print notes > P && git add -A && git commit -qm "SW1 base"
git rm -q P && git commit -qm "SW1 rm P"
_ST_PZ_C t.txt t "SW1 tip"
mkdir P && print mine1 > P/a.md && print mine2 > P/b.md && git add P
_ST_TTY -- -d -y HEAD~1
_ST_EQ "files staged under a path a terminal drop puts a file at stay staged" "$RC:$(git ls-files P | tr '\n' ' ')" "0:P/a.md P/b.md "
_ST_OUT_HAS "named once, as staged under it" 'reconcile: P – files staged under it where the rewrite put a file$'
# As does a file staged where it puts a directory, in the checkout or gone from it – the latter one
# the two-tree merge took before
_ST_PZ_NEW sw2
print a > a.txt && mkdir d && print x > d/x.txt && git add -A && git commit -qm "SW2 base"
git rm -rq d && git commit -qm "SW2 rm d"
_ST_PZ_C t.txt t "SW2 tip"
print mine > d && git add d
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a file staged where a terminal drop puts a directory stays staged" "$RC:$(git ls-files | tr '\n' ' ')" "0:a.txt d t.txt "
_ST_OUT_HAS "named as staged where its directory goes" 'reconcile: d/x.txt – d staged where its directory goes$'
_ST_PZ_NEW sw3
print a > a.txt && mkdir d && print x > d/x.txt && git add -A && git commit -qm "SW3 base"
git rm -rq d && git commit -qm "SW3 rm d"
_ST_PZ_C t.txt t "SW3 tip"
print mine > d && git add d && mv d "$TMP/sw3-d"
_ST_TTY -- -d -y HEAD~1
_ST_EQ "as does one no longer in the checkout" "$RC:$(git ls-files | tr '\n' ' ')" "0:a.txt d t.txt "
_ST_OUT_HAS "named alike" 'reconcile: d/x.txt – d staged where its directory goes$'
# While the rewrite's own swap of a file for a directory, either way, takes both entries
_ST_PZ_NEW sw4
print a > a.txt && mkdir d && print x > d/x.txt && git add -A && git commit -qm "SW4 base"
git rm -rq d && print file > d && git add d && git commit -qm "SW4 d a file"
_ST_PZ_C t.txt t "SW4 tip"
print mine >> d
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a terminal drop swapping a file edited for a directory takes both entries" "$RC:$(git ls-files | tr '\n' ' '):$(<d)" $'0:a.txt d/x.txt t.txt :file\nmine'
_ST_OUT_HAS "naming the file where its directory goes" 'd/x.txt – your file d stands where its directory goes'
_ST_PZ_NEW sw5
print a > a.txt && print notes > P && git add -A && git commit -qm "SW5 base"
git rm -q P && mkdir P && print y > P/y && git add P && git commit -qm "SW5 P a directory"
_ST_PZ_C t.txt t "SW5 tip"
print mine >> P/y
_ST_TTY -- -d -y HEAD~1
_ST_EQ "as does one swapping a directory edited for a file" "$RC:$(git ls-files | tr '\n' ' ')" "0:P a.txt t.txt "
_ST_OUT_HAS "naming the directory where the file goes" 'P – your directory stands where the rewrite put a file'
# Staging a peer makes under such a path as the sync runs stays too, named once – and a merged file
# a peer staged meanwhile is named once, as merged, its staging noted
_ST_PZ_NEW sw6
print -l 1 2 3 4 5 6 7 8 9 > f.txt && print notes > P && git add -A && git commit -qm "SW6 base"
print -l 1 2 3 4 5 6 7 8 9X > f.txt && git rm -q P && git add f.txt && git commit -qm "SW6 tail, rm P"
_ST_PZ_C t.txt t "SW6 tip"
print -l 1E 2 3 4 5 6 7 8 9X > f.txt
mkdir P && print untracked > P/u.txt
SW_REAL=$(whence -p git)
SW_BLOB=$(print -r -- PEERSTAGED | git hash-object -w --stdin)
SW_U=$(print -r -- peer | git hash-object -w --stdin)
SW_BIN="$TMP/sw6-bin" && mkdir -p "$SW_BIN"
# Stages `P/u.txt` and `f.txt` as a peer once the sync merges its first file
cat > "$SW_BIN/git" <<EOF
#!/bin/sh
if [ "\$1" = merge-file ] && [ ! -e "$PWD/.git/sw6-mark" ]; then
  : > "$PWD/.git/sw6-mark"
  ( unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE; cd "$PWD" && "$SW_REAL" update-index --add --cacheinfo 100644,$SW_U,P/u.txt --cacheinfo 100644,$SW_BLOB,f.txt ) >/dev/null 2>&1
fi
exec "$SW_REAL" "\$@"
EOF
chmod +x "$SW_BIN/git"
_ST_TTY PATH="$SW_BIN:$PATH" -- -d -y HEAD~1
_ST_EQ "a peer's staging under a path a file lands at, made as the sync runs, stays" "$RC:$(git ls-files P | tr '\n' ' ')" "0:P/u.txt "
_ST_OUT_HAS "the path named once, as staged under it" 'reconcile: P – files staged under it where the rewrite put a file$'
_ST_OUT_LACKS "never as the directory alone" 'your directory stands where'
_ST_EQ "a merged file's staging a peer made meanwhile stays" "$(git show :f.txt):$(head -1 f.txt)" "PEERSTAGED:1E"
_ST_OUT_HAS "named once, among the merged, its staging noted" 'merged onto what landed: f.txt (its staging left as a peer staged it)$'
_ST_OUT_LACKS "never as left as it was" 'f.txt – staged meanwhile'
# An agent's drop keeps staging in its re-sync's way alike, naming it left alone
_ST_PZ_NEW sw7
print a > a.txt && print notes > P && git add -A && git commit -qm "SW7 base"
git rm -q P && git commit -qm "SW7 rm P"
_ST_PZ_C t.txt t "SW7 tip"
mkdir P && print mine1 > P/a.md && print mine2 > P/b.md && git add P
_ST_RUN_UNSYNCED -d -y HEAD~1
_ST_EQ "an agent's drop keeps files staged under a path it puts a file at" "$RC:$(git ls-files P | tr '\n' ' ')" "0:P/a.md P/b.md "
_ST_OUT_HAS "naming them left alone" '^Index entries left alone .*: P$'
_ST_PZ_NEW sw8
print a > a.txt && mkdir d && print x > d/x.txt && git add -A && git commit -qm "SW8 base"
git rm -rq d && git commit -qm "SW8 rm d"
_ST_PZ_C t.txt t "SW8 tip"
print mine > d && git add d
_ST_RUN_UNSYNCED -d -y HEAD~1
_ST_EQ "as it does a file staged where it puts a directory" "$RC:$(git ls-files | tr '\n' ' ')" "0:a.txt d t.txt "
_ST_OUT_HAS "naming that file left alone" '^Index entries left alone .*: d$'
_ST_PZ_NEW sw8b
print a > a.txt && mkdir d && print x > d/x.txt && git add -A && git commit -qm "SW8b base"
git rm -rq d && print file > d && git add d && git commit -qm "SW8b d a file"
_ST_PZ_C t.txt t "SW8b tip"
_ST_RUN -d -y HEAD~1
_ST_EQ "while its re-sync of a swap takes both entries" "$RC:$(git ls-files | tr '\n' ' ')" "0:a.txt d/x.txt t.txt "
# A replant refused over 12 dirty paths the upstream changed – halfway through a sequence – names
# each, as each takes its own step
_ST_PZ_NEW sw9
print base > base.txt && git add -A && git commit -qm "SW9 base" && git branch sw9-up
git checkout -q sw9-up
for SW_I in {01..12}; do print u$SW_I > f$SW_I.txt; done
print u > u.txt && git add -A && git commit -qm "SW9 up" && git checkout -q main
for SW_I in {01..12}; do print a$SW_I > f$SW_I.txt; done
git add -A && git commit -qm "SW9 twelve"
for SW_I in {01..12}; do print b$SW_I >> f$SW_I.txt; done
_ST_RUN_UNSYNCED --onto=sw9-up
_ST_EQ "a replant refused over 12 dirty paths names every one" "$RC:$(print -r -- "$OUT" | grep -cE '^  f[0-9]+\.txt \(modified\) – ')" "1:12"
# While a report no action follows still names ten
git checkout -q -- .
_ST_RUN -d -y HEAD
_ST_OUT_HAS "while a report names ten and how many more" 'now as they landed: .* … and 2 more$'
# A commit taking back 12 removals names each to leave out
_ST_PZ_NEW sw10
for SW_I in {01..12}; do print -l a$SW_I b$SW_I > f$SW_I.txt; done
git add -A && git commit -qm "SW10 base" && git commit -q --allow-empty -m "SW10 two"
SW_ARGS=()
for SW_I in {01..12}; do SW_ARGS+=(--rm "f$SW_I.txt"); done
OUT=$(GIT_EDIT_ACTOR=sw-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "SW10 peer rm" "${SW_ARGS[@]}" </dev/null 2>&1)
for SW_I in {01..12}; do print x >> f$SW_I.txt; done
OUT=$(GIT_EDIT_ACTOR=sw-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "SW10 self" -- f{01..12}.txt </dev/null 2>&1)
RC=$?
_ST_EQ "a commit taking back 12 removals refuses" "$RC" "1"
_ST_OUT_HAS "naming every one to leave out" 'Leave out what was removed: f01.txt .*f12.txt$'
_ST_OUT_LACKS "none cut short" 'removed: .*and 2 more'
# A reorder stop rebuilding 12 files names each to author
_ST_PZ_NEW sw11
for SW_I in {01..12}; do print -l x$SW_I y z > f$SW_I.txt; done
git add -A && git commit -qm "SW11 base"
for SW_I in {01..12}; do print -l a$SW_I y z > f$SW_I.txt; done
git commit -qam "SW11 A"
for SW_I in {01..12}; do print -l b$SW_I y z > f$SW_I.txt; done
git commit -qam "SW11 B"
for SW_I in {01..12}; do print -l b$SW_I y c > f$SW_I.txt; done
git commit -qam "SW11 C"
_ST_RUN --reorder HEAD~1 HEAD~2 HEAD
_ST_OUT_HAS "a reorder stop rebuilding 12 files names every one to author" 'never existed for f01.txt, .*, f12.txt – author'
_ST_OUT_LACKS "none cut short" 'never existed for .*and 2 more'
_ST_RUN --abort
cd "$TMP/repo"
