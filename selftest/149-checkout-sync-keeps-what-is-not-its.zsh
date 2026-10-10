# A terminal run's checkout sync takes an entry the run superseded as the agent re-sync does, keeps
# a directory, a symlink of the caller's and a peer's fresh staging as they are, and merges a
# case-only rename's conflict with the landed side – while `--status` leaves another label's
# pause to its owner
_ST_SCENARIO "\e[1;96m[149] a checkout sync keeps what is not its own, and --status leaves another's pause\e[0m"
local CS_X CS_BIN CS_REAL CS_BLOB CS_EXT CS_CI=""
# Committed whole at a terminal, an intent-to-add file and a partly staged one leave nothing staged
_ST_PZ_NEW cs1
_ST_PZ_C f.txt $'1\n2\n3' "CS1 base"
print -r -- hello > new.txt && git add -N new.txt
_ST_TTY -- --commit --text "CS1 new" -- new.txt
_ST_EQ "an intent-to-add file committed at a terminal leaves no staged removal" "$RC:$(git status --porcelain)" "0:"
_ST_OUT_LACKS "and names nothing left" 'Left as they were'
print -r -- $'1x\n2\n3' > f.txt && git add f.txt && print -r -- $'1x\n2\n3x' > f.txt
_ST_TTY -- --commit --text "CS1 whole" -- f.txt
_ST_EQ "a partly staged file committed whole leaves no staged revert" "$RC:$(git status --porcelain):$(git show HEAD:f.txt | tail -1)" "0::3x"
_ST_OUT_LACKS "nor reads as edits merged" 'merged onto what landed'
# As does a removal committed, and a file untracked by hand then committed whole
git rm -q f.txt
_ST_TTY -- --commit --text "CS1 rm" -- f.txt
_ST_EQ "a removal committed at a terminal leaves nothing behind" "$RC:$(git status --porcelain)" "0:"
_ST_OUT_LACKS "naming nothing left" 'Left as they were'
git rm -q --cached new.txt && print -r -- hello2 > new.txt
_ST_TTY -- --commit --text "CS1 back" -- new.txt
_ST_EQ "an entry removed by hand, the file then committed whole, is re-synced" "$RC:$(git status --porcelain)" "0:"
# While staging the run never read is no entry of its own – a drop leaves a staged and edited file
_ST_PZ_C g.txt $'1\n2\n3' "CS1 g"
_ST_PZ_C g.txt $'1\n2x\n3' "CS1 g edit"
_ST_PZ_C t.txt t "CS1 tip"
print -r -- $'0\n1\n2x\n3' > g.txt && git add g.txt && print -r -- $'0\n1\n2x\n3\n4' > g.txt
_ST_TTY -- -d -y HEAD~1
_ST_OUT_HAS "a staged and edited file a drop changed is still left" 'g.txt – staged and unstaged edits both, made before the rewrite'
git checkout -q HEAD -- g.txt
# An intent-to-add entry whose file is gone gives way to what a drop brings back, either path
_ST_PZ_NEW cs2
_ST_PZ_C a.txt a "CS2 base"
_ST_PZ_C n.txt landed "CS2 add n"
git rm -q n.txt && git commit -qm "CS2 rm n"
_ST_PZ_C z.txt z "CS2 tip"
print -r -- x > n.txt && git add -N n.txt && rm -f n.txt
_ST_TTY -- -d -y HEAD~1
_ST_EQ "an intent-to-add entry with its file gone takes what the drop brings back" "$RC:$(git status --porcelain):$(<n.txt)" "0::landed"
_ST_PZ_C n.txt landed2 "CS2 n again"
git rm -q n.txt && git commit -qm "CS2 rm n again"
_ST_PZ_C y.txt y "CS2 tip2"
print -r -- x > n.txt && git add -N n.txt && rm -f n.txt
_ST_RUN -d -y HEAD~1
_ST_OUT_HAS "as an agent's re-sync takes it" 'Index entries re-synced to the new tip: n.txt'
# A plain commit at a terminal reads as nothing to merge, and one its hook added to as come along
_ST_PZ_NEW cs3
_ST_PZ_C f.txt $'1\n2' "CS3 base"
print -r -- $'1x\n2' > f.txt
_ST_TTY -- --commit --text "CS3 plain" -- f.txt
_ST_EQ "a file committed at a terminal is in sync" "$RC:$(git status --porcelain)" "0:"
_ST_OUT_LACKS "never named as edits merged" 'merged onto what landed'
printf '#!/bin/sh\nprintf "hooked\\n" >> f.txt && git add f.txt\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
print -r -- $'1y\n2' > f.txt
_ST_TTY -- --commit --text "CS3 hooked" -- f.txt
_ST_EQ "a file its commit's hook changed takes the hook's version" "$RC:$(git status --porcelain):$(tail -1 f.txt)" "0::hooked"
_ST_OUT_HAS "named as come along" 'now as they landed: f.txt'
rm -f .git/hooks/pre-commit
# A --tree commit at a terminal names its move a landing
print -r -- $'1z\n2' > f.txt && git add f.txt && print -r -- $'1z\n2z' > f.txt
_ST_TTY -- --commit --text "CS3 tree" --tree="$(_ST_COMPOSE f.txt 'tree')"
_ST_OUT_HAS "a commit's staged and edited file is made before the landing" 'f.txt – staged and unstaged edits both, made before the landing'
git reset -q --hard
# A directory where a file lands stays, named, unrestored – an untracked file beside it gets one
_ST_PZ_NEW cs4
_ST_PZ_C a.txt a "CS4 base"
_ST_PZ_C x landed "CS4 add x"
_ST_PZ_C y landed "CS4 add y"
git rm -q x y && git commit -qm "CS4 rm x y"
_ST_PZ_C z.txt z "CS4 tip"
mkdir x && print -r -- precious > x/mine.txt && print -r -- mine > y
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a directory where a terminal drop lands a file keeps its files" "$RC:$(<x/mine.txt)" "0:precious"
_ST_OUT_HAS "named as a directory" 'x – your directory stands where the rewrite put a file'
_ST_OUT_HAS "while an untracked file there is offered the restore" 'Take what landed with: git restore -- y$'
_ST_PZ_NEW cs4b
_ST_PZ_C a.txt a "CS4b base"
_ST_PZ_C x landed "CS4b add x"
git rm -q x && git commit -qm "CS4b rm x"
_ST_PZ_C z.txt z "CS4b tip"
mkdir x && print -r -- precious > x/mine.txt
_ST_RUN -d -y HEAD~1
_ST_OUT_HAS "an agent's drop names the directory as such" 'Worktree directories left alone where the rewrite put a file'
_ST_OUT_LACKS "offering it no discard" 'discard it with'
_ST_EQ "and keeps its files" "$(<x/mine.txt)" "precious"
# A path under a symlink of the caller's stays as it is – a restore would replace the link
_ST_PZ_NEW cs5
_ST_PZ_C a.txt a "CS5 base"
mkdir d && _ST_PZ_C d/f.txt landed "CS5 add d"
git rm -rq d && git commit -qm "CS5 rm d"
_ST_PZ_C z.txt z "CS5 tip"
CS_EXT="$TMP/cs5-ext" && mkdir -p "$CS_EXT" && print -r -- theirs > "$CS_EXT/other.txt"
ln -s "$CS_EXT" d
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a path under a symlink of the caller's leaves the link" "$RC:$(test -L d && echo link):$(ls "$CS_EXT" | tr '\n' ' ')" "0:link:other.txt "
_ST_OUT_HAS "named as such" 'd/f.txt – under your symlink d, which git writes no file through'
_ST_OUT_LACKS "with no restore offered" 'git restore -- d/f.txt'
_ST_PZ_NEW cs5b
_ST_PZ_C a.txt a "CS5b base"
mkdir d && _ST_PZ_C d/f.txt landed "CS5b add d"
git rm -rq d && git commit -qm "CS5b rm d"
_ST_PZ_C z.txt z "CS5b tip"
ln -s "$CS_EXT" d
_ST_RUN -d -y HEAD~1
_ST_OUT_HAS "as does an agent's drop" 'Worktree paths left alone under a symlink of yours.*d/f.txt'
_ST_OUT_LACKS "offering no discard" 'discard it with'
_ST_CHECK "the link kept" test -L d
# An entry a peer stages while the sync waits for the index stays staged, named, offered no restore
_ST_PZ_NEW cs6
_ST_PZ_C a.txt a "CS6 base"
_ST_PZ_C b.txt $'b1\nb2' "CS6 b"
_ST_PZ_C b.txt $'b1\nb2x' "CS6 b edit"
_ST_PZ_C c.txt c "CS6 tip"
CS_REAL=$(whence -p git)
CS_BLOB=$(print -r -- PEERSTAGED | git hash-object -w --stdin)
CS_BIN="$TMP/cs6-bin" && mkdir -p "$CS_BIN"
# Once the sync has read the staging, a peer stages `b.txt` and holds the index a second
cat > "$CS_BIN/git" <<EOF
#!/bin/sh
"$CS_REAL" "\$@"; rc=\$?
case " \$* " in *" diff --cached --ignore-submodules=dirty -z --name-only --no-renames "*)
  if [ ! -e "$PWD/.git/cs6-mark" ]; then
    : > "$PWD/.git/cs6-mark"
    ( unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE; cd "$PWD" && cp .git/index .git/cs6-idx && \\
      GIT_INDEX_FILE=.git/cs6-idx "$CS_REAL" update-index --cacheinfo 100644,$CS_BLOB,b.txt && \\
      cp .git/cs6-idx .git/index.lock && { (sleep 1; mv .git/index.lock .git/index) & } ) >/dev/null 2>&1
  fi ;;
esac
exit \$rc
EOF
chmod +x "$CS_BIN/git"
_ST_TTY PATH="$CS_BIN:$PATH" -- -d -y HEAD~1
_ST_EQ "a peer's staging after the sync's read stays staged" "$RC:$(git show :b.txt)" "0:PEERSTAGED"
_ST_OUT_HAS "named as staged meanwhile" 'b.txt – staged meanwhile'
_ST_OUT_LACKS "never offered a restore that discards it" 'Take what landed once it is free'
# A pause another label made is left to it by --status, its owner told the step
_ST_PZ_NEW cs7
_ST_PZ_C f.txt $'1\n2\n3' "CS7 base"
_ST_PZ_C f.txt $'1\n2x\n3' "CS7 edit"
_ST_PZ_C f.txt $'1\n2y\n3' "CS7 edit2"
print -r -- $'1\n2z\n3' > f.txt && git add f.txt
GIT_EDIT_ACTOR=cs-alice _ST_RUN --amend-into=HEAD~1 -- f.txt
GIT_EDIT_ACTOR=cs-bob _ST_RUN --status
_ST_OUT_HAS "--status to another label names whose pause it is in its trailer" "^git-edit: paused – amend-into [0-9a-f]* is cs-alice's, not yours: leave it to that caller"
_ST_OUT_LACKS "with no resolve line" 'Resolve there'
_ST_OUT_LACKS "nor a trailer telling it to resolve" 'resolve in'
GIT_EDIT_ACTOR=cs-alice _ST_RUN --status
_ST_OUT_HAS "while its owner is told the step" "^git-edit: conflict – resolve in"
_ST_RUN --status
_ST_OUT_HAS "as is an unlabeled caller" 'Resolve there, then git edit --continue'
GIT_EDIT_ACTOR=cs-alice _ST_RUN --abort
# The second checkout's entries left alone name the tip as the primary's do
_ST_PZ_NEW cs8
_ST_PZ_C a.txt a "CS8 base"
_ST_PZ_C b.txt b1 "CS8 b"
_ST_PZ_C c.txt c "CS8 tip"
git worktree add -q -f "$TMP/cs8-second" main 2>/dev/null
print -r -- mine > "$TMP/cs8-second/b.txt" && git -C "$TMP/cs8-second" add b.txt
_ST_RUN -d -y HEAD~1
_ST_OUT_HAS "a second checkout's entry left alone by a drop differs from the pre-rewrite tip" 'left alone, differing from the pre-rewrite tip: b.txt'
print -r -- a2 > a.txt && print -r -- peer > "$TMP/cs8-second/a.txt" && git -C "$TMP/cs8-second" add a.txt
_ST_RUN --commit --text "CS8 a2" -- a.txt
_ST_OUT_HAS "and one a commit left alone from the previous tip" 'left alone, differing from the previous tip: a.txt'
git worktree remove -f -f "$TMP/cs8-second" 2>/dev/null
# A name holding a newline lists on one line, as its quoted form
_ST_PZ_NEW cs9
_ST_PZ_C a.txt a "CS9 base"
print -r -- 1 > $'nl\nname' && git add -A && git commit -qm "CS9 add"
print -r -- 2 > $'nl\nname' && git add -A && git commit -qm "CS9 edit"
_ST_PZ_C z.txt z "CS9 tip"
_ST_RUN -d -y HEAD~1
_ST_EQ "a stale name holding a newline is one line of the list" "$(print -r -- "$OUT" | grep -cxF "  \$'nl\\nname'"):$(print -r -- "$OUT" | grep -cx '  name')" "1:0"
# A removed name ending in a CR hashes as itself, not as the name without it, its clean pasteable
_ST_PZ_NEW cs9b
_ST_PZ_C a.txt a "CS9b base"
print -r -- gone > $'Icon\r' && print -r -- other > Icon && git add $'Icon\r' && git commit -qm "CS9b add"
_ST_PZ_C z.txt z "CS9b tip"
_ST_RUN -d -y HEAD~1
_ST_OUT_HAS "a dropped name ending in a CR is named as the dropped content" "discard it with: git clean -f -- \$'Icon\\\\r'"
eval "$(print -r -- "$OUT" | sed -n 's/^Keep it, or discard it with: //p')"
_ST_EQ "whose clean takes that file alone" "$(test -e $'Icon\r' && echo cr):$(<Icon)" ":other"
# A case-only rename on a filesystem that ignores case merges the landed side, and a carry onto it
# takes the landed spelling
_ST_PZ_NEW cs10
print -r -- probe > ci-probe && [ -e CI-PROBE ] && CS_CI=1
rm -f ci-probe
if [ -n "$CS_CI" ]; then
	_ST_PZ_C readme.md $'1\n2\n3\n4\n5\n6\n7\n8' "CS10 base"
	_ST_PZ_C o.txt o "CS10 other"
	git mv readme.md README.md && print -r -- $'1\n2\n3\n4\n5\n6\n7\n8x' > README.md && git add README.md && git commit -qm "CS10 case + 8x"
	_ST_PZ_C z.txt z "CS10 tip"
	print -r -- $'1\n2\n3\n4\n5\n6\n7\n8mine' > README.md
	_ST_TTY -- -d -y HEAD~1
	_ST_OUT_HAS "a case-only rename's conflict is named" 'conflict with what landed.*README.md → readme.md'
	eval "$(print -r -- "$OUT" | sed -n 's/^  \(T=\$(mktemp -d) && git cat-file --filters .*"\$T\/landed"\)$/\1/p')"
	_ST_EQ "its merge brings in the landed side, markers and all" "$(grep -c '^8$' readme.md):$(grep -c '^8mine$' readme.md):$(grep -c '^<<<<<<<' readme.md)" "1:1:1"
	_ST_EQ "the file named as landed" "$(ls | grep -ix readme.md)" "readme.md"
	git reset -q --hard
	_ST_PZ_NEW cs11
	_ST_PZ_C readme.md $'1\n2\n3\n4\n5\n6\n7\n8' "CS11 base"
	_ST_PZ_C o.txt o "CS11 other"
	git mv readme.md README.md && print -r -- $'1x\n2\n3\n4\n5\n6\n7\n8' > README.md && git add README.md && git commit -qm "CS11 case + 1x"
	_ST_PZ_C z.txt z "CS11 tip"
	print -r -- $'1x\n2\n3\n4\n5\n6\n7\n8mine' > README.md
	_ST_TTY -- -d -y HEAD~1
	_ST_OUT_HAS "edits carried over a case-only rename" 'merged onto what landed: README.md → readme.md'
	_ST_EQ "take the landed spelling on disk and in the index" "$(ls | grep -ix readme.md):$(git ls-files | grep -ix readme.md):$(tail -1 readme.md)" "readme.md:readme.md:8mine"
	# An agent's case-only rename offers no clean of the old name, which does nothing there – the file
	# under it is the new name's, stale where it holds the old content and taking the restore
	_ST_PZ_NEW cs12
	_ST_PZ_C readme.md $'1\n2' "CS12 base"
	_ST_PZ_C o.txt o "CS12 other"
	_ST_RUN --exec -- sh -c 'git mv readme.md README.md && git commit -qm "CS12 case"'
	_ST_EQ "a pure case-only rename leaves the checkout current" "$RC:$(git status --porcelain)" "0:"
	_ST_OUT_LACKS "with no clean of the old name" 'git clean'
	_ST_RUN --exec -- sh -c 'git rm -q README.md && echo new > readme.md && git add readme.md && git commit -qm "CS12 case back + edit"'
	_ST_OUT_LACKS "nor where the content changed too" 'git clean'
	_ST_OUT_HAS "where the new name is stale instead" 'Reconcile those paths.*git restore --source=HEAD --worktree -- readme.md$'
	eval "$(print -r -- "$OUT" | sed -n 's/^Reconcile those paths[^:]*: //p')"
	_ST_EQ "whose restore reads right" "$(ls | grep -ix readme.md):$(<readme.md):$(git status --porcelain)" "readme.md:new:"
fi
cd "$TMP/repo"
