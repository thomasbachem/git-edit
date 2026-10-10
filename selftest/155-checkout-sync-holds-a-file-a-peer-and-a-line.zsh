# A checkout sync keeps a file of the caller's standing where a landed path's directory goes, writes
# its index entries in one guarded step keeping a peer's late staging, and prints each list on its
# line – while a drop that can't bring the checkout along, an agent's here, names what it leaves, a
# case-only rename undone onto edits read as taking the rewrite back
_ST_SCENARIO "\e[1;96m[155] a checkout sync keeps a file where a directory lands, a peer's late staging, and its lists whole and on one line\e[0m"
local SY_BIN SY_REAL SY_BLOB SY_OLD SY_N SY_CI=""
# A file of the caller's where a terminal drop lands a directory stays, named, unrestored
_ST_PZ_NEW sy1
_ST_PZ_C a.txt a "SY1 base"
mkdir d && _ST_PZ_C d/x landed "SY1 add d/x"
git rm -rq d && git commit -qm "SY1 rm d"
_ST_PZ_C z.txt z "SY1 tip"
print -r -- precious > d
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a file of the caller's where a terminal drop lands a directory stays" "$RC:$(test -f d && cat d)" "0:precious"
_ST_OUT_HAS "named as standing where its directory goes" 'd/x – your file d stands where its directory goes'
_ST_OUT_LACKS "with no restore offered" 'git restore \(--source\|--worktree\|-- \)'
# While a directory of the caller's there takes the landed file beside its own
_ST_PZ_NEW sy1b
_ST_PZ_C a.txt a "SY1b base"
mkdir d && _ST_PZ_C d/x landed "SY1b add d/x"
git rm -rq d && git commit -qm "SY1b rm d"
_ST_PZ_C z.txt z "SY1b tip"
mkdir d && print -r -- mine > d/mine.txt
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a directory of the caller's there takes the landed file" "$RC:$(<d/x):$(<d/mine.txt)" "0:landed:mine"
# As does an agent's drop name it, offering no discard, and say nothing of a path removed under it
_ST_PZ_NEW sy2
_ST_PZ_C a.txt a "SY2 base"
mkdir d && _ST_PZ_C d/x landed "SY2 add d/x"
git rm -rq d && git commit -qm "SY2 rm d"
_ST_PZ_C z.txt z "SY2 tip"
print -r -- precious > d
_ST_RUN_UNSYNCED -d -y HEAD~1
_ST_OUT_HAS "an agent's drop names the file standing where a directory lands" 'Worktree paths left alone where a file of yours stands in place of their directory.*d/x'
_ST_OUT_LACKS "offering it no discard" 'discard it with'
_ST_EQ "and keeps it" "$(test -f d && cat d)" "precious"
_ST_PZ_NEW sy2b
_ST_PZ_C a.txt a "SY2b base"
mkdir d && _ST_PZ_C d/x landed "SY2b add d"
_ST_PZ_C z.txt z "SY2b tip"
git rm -rq d && print -r -- mine > d
_ST_RUN -d -y HEAD~1
_ST_OUT_HAS "a path a drop removes under the caller's file is no worry of the run" '^  dropped: '
_ST_OUT_LACKS "so goes unnamed" 'd/x'
_ST_PZ_NEW sy2c
_ST_PZ_C a.txt a "SY2c base"
mkdir d && _ST_PZ_C d/x landed "SY2c add d/x"
git rm -rq d && git commit -qm "SY2c rm d"
_ST_PZ_C z.txt z "SY2c tip"
print -r -- target > t.txt && ln -s t.txt d
_ST_RUN_UNSYNCED -d -y HEAD~1
_ST_OUT_HAS "a symlink to a file there still reads as a link" 'Worktree paths left alone under a symlink of yours.*d/x'
_ST_CHECK "the link kept" test -L d
# A peer staging a path while the terminal sync merges keeps its staging – every entry written in
# one locked step, which re-reads each
_ST_PZ_NEW sy3
print -l 1 2 3 4 5 6 7 8 9 > a.txt && cp a.txt b.txt && cp a.txt c.txt && git add -A && git commit -qm "SY3 base"
print -l 1 2 3 4 5 6 7 8 9X > a.txt && cp a.txt b.txt && cp a.txt c.txt && git commit -qam "SY3 tail"
_ST_PZ_C z.txt z "SY3 tip"
print -l 1E 2 3 4 5 6 7 8 9X > a.txt && cp a.txt b.txt && cp a.txt c.txt
SY_REAL=$(whence -p git)
SY_BLOB=$(print -r -- PEERSTAGED | git hash-object -w --stdin)
SY_BIN="$TMP/sy3-bin" && mkdir -p "$SY_BIN"
# Logs each index write, and stages `b.txt` as a peer once the sync merges its first file
cat > "$SY_BIN/git" <<EOF
#!/bin/sh
case " \$* " in *" update-index "*) printf '%s\n' "\${GIT_INDEX_FILE:-real} \$*" >> "$PWD/.git/sy3-log" ;; esac
if [ "\$1" = merge-file ] && [ ! -e "$PWD/.git/sy3-mark" ]; then
  : > "$PWD/.git/sy3-mark"
  ( unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE; cd "$PWD" && "$SY_REAL" update-index --cacheinfo 100644,$SY_BLOB,b.txt ) >/dev/null 2>&1
fi
exec "$SY_REAL" "\$@"
EOF
chmod +x "$SY_BIN/git"
_ST_TTY PATH="$SY_BIN:$PATH" -- -d -y HEAD~1
_ST_EQ "a peer's staging during the sync's merges stays staged" "$RC:$(git show :b.txt)" "0:PEERSTAGED"
_ST_OUT_HAS "named once, among the merged, its staging noted" 'b.txt (its staging left as a peer staged it)'
_ST_EQ "while the others take what landed, their edits merged" "$(git diff --cached --name-only | tr '\n' ' '):$(head -1 a.txt):$(head -1 c.txt)" "b.txt :1E:1E"
_ST_EQ "the sync's entries written in one step under the lock, none apart" \
	"$(grep -c '/index\.git-edit\.[0-9]* .*update-index -z --index-info' .git/sy3-log):$(grep -c '^real ' .git/sy3-log)" "1:0"
# An agent's case-only rename undone onto edits made on the rewrite takes it back committed whole,
# as a plain path does – and the carry it offers lands them on the new name
_ST_PZ_NEW sy4
print -r -- probe > sy-probe && [ -e SY-PROBE ] && SY_CI=1
rm -f sy-probe
if [ -n "$SY_CI" ]; then
	printf 'l1\nl2\nl3\nl4\nl5\n' > Case.txt && git add -A && git commit -qm "SY4 base"
	git mv Case.txt case.txt && printf 'L1\nl2\nl3\nl4\nl5\n' > case.txt && git add -A && git commit -qm "SY4 rename + L1"
	_ST_PZ_C x x "SY4 tip"
	printf 'L1\nl2\nl3\nl4\nl5-mine\n' > case.txt
	SY_OLD=$(git rev-parse HEAD)
	_ST_RUN_UNSYNCED -d -y HEAD~1
	_ST_OUT_HAS "a case-only rename undone onto edits made on the rewrite reads as taking it back" 'on the pre-rewrite content.*: Case.txt$'
	_ST_RUN --carry="$SY_OLD"
	_ST_EQ "whose carry lands the edits on the new name" "$RC:$(ls | grep -ix case.txt):$(head -1 Case.txt):$(tail -1 Case.txt)" "0:Case.txt:l1:l5-mine"
	_ST_PZ_NEW sy4b
	printf 'l1\nl2\nl3\nl4\nl5\n' > Case.txt && git add -A && git commit -qm "SY4b base"
	git mv Case.txt case.txt && printf 'L1\nl2\nl3\nl4\nl5\n' > case.txt && git add -A && git commit -qm "SY4b rename + L1"
	_ST_PZ_C x x "SY4b tip"
	printf 'l1\nl2\nl3\nl4\nl5-mine\n' > case.txt
	_ST_RUN_UNSYNCED -d -y HEAD~1
	_ST_OUT_HAS "while edits on the new content read as edits there" 'uncommitted edits there, not the pre-rewrite content.*: Case.txt$'
	_ST_OUT_LACKS "never as taking it back" 'on the pre-rewrite content –'
fi
# A name holding a newline lists on its line, as its quoted form – merged, conflicting or deleted at
# a terminal, edited at an agent's
_ST_PZ_NEW sy5
for SY_N in $'nl\nname' $'nl2\nx' $'nl3\ny'; do printf 'l1\nl2\nl3\nl4\nl5\n' > "$SY_N"; done
git add -A && git commit -qm "SY5 base"
for SY_N in $'nl\nname' $'nl2\nx' $'nl3\ny'; do printf 'L1\nl2\nl3\nl4\nl5\n' > "$SY_N"; done
git add -A && git commit -qm "SY5 L1"
_ST_PZ_C z.txt z "SY5 tip"
printf 'L1-mine\nl2\nl3\nl4\nl5\n' > $'nl\nname' && printf 'L1\nl2\nl3\nl4\nl5-mine\n' > $'nl2\nx' && rm -f $'nl3\ny'
_ST_TTY -- -d -y HEAD~1
_ST_OUT_HAS "a merged name holding a newline at a terminal" "merged onto what landed: \$'nl2\\\\nx'\$"
_ST_OUT_HAS "a conflicting one" "conflict with what landed.*: \$'nl\\\\nname'\$"
_ST_OUT_HAS "a deleted one" "stay deleted: \$'nl3\\\\ny'\$"
_ST_EQ "none splitting its line" "$(print -r -- "$OUT" | grep -cE '^(name|x|y)($|,| )')" "0"
_ST_PZ_NEW sy5b
printf 'l1\nl2\nl3\nl4\nl5\n' > $'nl\nname' && git add -A && git commit -qm "SY5b base"
printf 'L1\nl2\nl3\nl4\nl5\n' > $'nl\nname' && git add -A && git commit -qm "SY5b L1"
_ST_PZ_C z.txt z "SY5b tip"
printf 'l1\nl2\nl3\nl4\nl5-mine\n' > $'nl\nname'
_ST_RUN_UNSYNCED -d -y HEAD~1
_ST_OUT_HAS "as does an agent's list" "uncommitted edits there, not the pre-rewrite content.*: \$'nl\\\\nname'\$"
# As do the carry's lists, carried and left alike
_ST_PZ_NEW sy5c
for SY_N in $'nl\nc' $'nl2\nd'; do printf 'l1\nl2\nl3\nl4\nl5\n' > "$SY_N"; done
git add -A && git commit -qm "SY5c base"
for SY_N in $'nl\nc' $'nl2\nd'; do printf 'L1\nl2\nl3\nl4\nl5\n' > "$SY_N"; done
git add -A && git commit -qm "SY5c L1"
_ST_PZ_C z.txt z "SY5c tip"
printf 'L1\nl2\nl3\nl4\nl5-mine\n' > $'nl\nc' && printf 'L1-mine\nl2\nl3\nl4\nl5\n' > $'nl2\nd'
SY_OLD=$(git rev-parse HEAD)
_ST_RUN_UNSYNCED -d -y HEAD~1
_ST_RUN --carry="$SY_OLD"
_ST_OUT_HAS "a carried name holding a newline lists on its line" "Carried onto the new content: \$'nl\\\\nc'\$"
_ST_OUT_HAS "as does one the carry leaves" "to merge by hand: \$'nl2\\\\nd' – 1 conflict(s)\$"
# A list no printed command covers names every path, as each needs its own action
_ST_PZ_NEW sy6
for SY_N in {01..12}; do printf 'l1\nl2\nl3\nl4\nl5\n' > "f$SY_N"; done
git add -A && git commit -qm "SY6 base"
for SY_N in {01..12}; do printf 'L1\nl2\nl3\nl4\nl5\n' > "f$SY_N"; done
git add -A && git commit -qm "SY6 L1"
_ST_PZ_C z.txt z "SY6 tip"
for SY_N in {01..12}; do printf 'l1\nl2\nl3\nl4\nl5-mine\n' > "f$SY_N"; done
_ST_RUN_UNSYNCED -d -y HEAD~1
_ST_OUT_HAS "an agent's edited files are named, every one" 'uncommitted edits there, not the pre-rewrite content.*: f01 .* f12$'
_ST_OUT_LACKS "none cut short" 'uncommitted edits there,.*and 2 more'
git reset -q --hard
_ST_PZ_NEW sy6b
for SY_N in {01..12}; do printf 'l1\nl2\nl3\nl4\nl5\n' > "f$SY_N"; done
git add -A && git commit -qm "SY6b base"
for SY_N in {01..12}; do printf 'L1\nl2\nl3\nl4\nl5\n' > "f$SY_N"; done
git add -A && git commit -qm "SY6b L1"
_ST_PZ_C z.txt z "SY6b tip"
for SY_N in {01..12}; do printf 'L1-mine\nl2\nl3\nl4\nl5\n' > "f$SY_N"; done
_ST_TTY -- -d -y HEAD~1
_ST_OUT_HAS "as are a terminal's conflicting ones" 'conflict with what landed.*: f01, .*, f12$'
_ST_OUT_LACKS "none cut short there either" 'conflict with what landed.*and 2 more'
git reset -q --hard
cd "$TMP/repo"
