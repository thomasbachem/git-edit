# `--carry` brings every path a landing changed – an entry still on the old tip, a directory turned
# into a file, a retargeted symlink, a landed mode – but never through a symlink, outside a sparse
# checkout or over another's staging, each path left there named once with its next step
# A terminal run's sync keeps a renamed directory's ignored files and takes out its emptied ones
_ST_SCENARIO "\e[1;96m[163] --carry brings each changed path once, never through a link, a cone or a peer's staging\e[0m"
local CZ_OLD CZ_B CZ_REAL=${commands[git]}

# Moves `main` to `topic` as a landing made elsewhere does – the index and files left as they were
_CZ_RAW () {
	git update-ref refs/heads/main topic "$CZ_OLD"
}
# Writes `<dir>/git` standing in for the real one, running <script> first where
# <case pattern> takes the call's arguments
_CZ_STAND_IN () {
	# Args: <dir> <case pattern> <script>
	mkdir -p "$1"
	{
		print -r -- '#!/bin/sh'
		print -r -- "case \" \$* \" in $2) $3 ;; esac"
		print -r -- "exec ${(q)CZ_REAL} \"\$@\""
	} > "$1/git"
	chmod +x "$1/git"
}

# An entry a locked index left on the old tip is re-synced by the next carry, a file the carry wrote
# then named once, as written with its entry left – and a mode alone changed in the checkout is kept
# as the content takes what landed, as a file deleted there stays deleted
_ST_PZ_NEW cz1
print -l 1 2 3 > a.txt && print -l x y > b.txt && print a > m.txt && print g > g.txt
git add -A && git commit -qm "CZ1 base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && print -l 1 2 3 4 > a.txt && print -l x y z > b.txt && print a2 > m.txt && print g2 > g.txt
git commit -qam "CZ1 topic" && git checkout -q main
print -l 0 1 2 3 > a.txt && chmod +x m.txt && mv g.txt "$TMP/cz1-g.txt"
_CZ_RAW
: > .git/index.lock
_ST_RUN --carry="$CZ_OLD"
mv .git/index.lock "$TMP/cz1-index.lock"
_ST_EQ "a locked index fails the carry" "$RC" "1"
_ST_OUT_HAS "each file it wrote named once, as written with its entry left, and the re-sync" 'Index entries left on the pre-rewrite content, the index locked: a\.txt (written, edits carried), b\.txt (written, brought to what landed), g\.txt, m\.txt (written, brought to what landed) – re-sync them once it is free, the files left as they are: git restore --source=HEAD --staged -- a\.txt b\.txt g\.txt m\.txt$'
_ST_OUT_LACKS "never as carried, nor as left to merge by hand" 'Carried onto the new content\|to merge by hand'
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "the next carry re-syncs every entry left behind" "$RC:$(git diff --cached --name-only | tr '\n' ' ')" "0:"
_ST_OUT_HAS "naming them" 'Index entries brought to what landed, their files left as they are: a\.txt, b\.txt, g\.txt, m\.txt$'
_ST_EQ "the edits carried, the mode-only file brought, the deleted one still gone" "$(tr '\n' ' ' < a.txt):$(cat m.txt):$(git status --porcelain | tr '\n' '|')" "0 1 2 3 4 :a2: M a.txt| D g.txt| M m.txt|"
_ST_CHECK "the mode the checkout gave it kept" test -x m.txt
_ST_RUN --carry="$CZ_OLD"
_ST_OUT_HAS "and a third finds nothing" 'Nothing to carry'

# A landing turning a directory into a file and a file into a directory – the removals go first
_ST_PZ_NEW cz2
mkdir d && print b > d/b && print c > f
git add -A && git commit -qm "CZ2 base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && git rm -q -r d f && print new-d > d && mkdir f && print fb > f/b
git add -A && git commit -qm "CZ2 topic" && git checkout -q main
_CZ_RAW
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "a directory turned into a file is written" "$RC:$(cat d 2>/dev/null):$(cat f/b 2>/dev/null):$(git status --porcelain)" "0:new-d:fb:"
_ST_OUT_HAS "and the file that went named as removed" 'Brought to what landed, holding no edits: d/b (removed), f (removed), d, f/b'

# A symlink to a directory the landing retargets is replaced, never followed
_ST_PZ_NEW cz3
mkdir t1 t2 && print x > t1/x && print y > t2/y && ln -s t1 link
git add -A && git commit -qm "CZ3 base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && ln -sfn t2 link && git add -A && git commit -qm "CZ3 topic" && git checkout -q main
_CZ_RAW
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "a retargeted symlink points where it landed" "$RC:$(readlink link):$(ls -A t1 | tr '\n' ' '):$(git status --porcelain)" "0:t2:x :"

# A rename into a directory the checkout holds as an untracked symlink writes nothing through it
_ST_PZ_NEW cz4
mkdir -p "$TMP/cz4-out"
print -l 1 2 3 4 > a.txt && print -l x y > b.txt
git add -A && git commit -qm "CZ4 base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && mkdir lib doc && git mv a.txt lib/a.txt && git mv b.txt lib/b.txt && print n > doc/n.txt
git add -A && git commit -qm "CZ4 topic" && git checkout -q main
ln -s "$TMP/cz4-out" lib && print -l 1 2 3 4 5 > a.txt
_CZ_RAW
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "a rename under the caller's symlink fails the carry" "$RC" "1"
_ST_OUT_HAS "named with its source and the link" 'to merge by hand: a\.txt → lib/a\.txt – under your symlink lib, which git writes no file through, b\.txt → lib/b\.txt – under your symlink lib, which git writes no file through$'
_ST_EQ "nothing written where the link points, the edits where they were" "$(ls -A "$TMP/cz4-out"):$(tr '\n' ' ' < a.txt):$(cat b.txt)" ":1 2 3 4 5 :x
y"
_ST_EQ "while a file it adds elsewhere is written" "$(cat doc/n.txt 2>/dev/null)" "n"

# A renamed directory's own `.gitignore` still tells what stays behind –
# the carry's and a terminal sync's
_ST_PZ_NEW cz5
mkdir old && print a > old/a.js && print '*.log' > old/.gitignore
git add -A && git commit -qm "CZ5 base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && git mv old new && git commit -qm "CZ5 topic" && git checkout -q main
print log > old/build.log && print u > old/u.txt
_CZ_RAW
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "the carry leaves a file the directory's own .gitignore ignores" "$RC:$(cat old/build.log 2>/dev/null):$(LC_ALL=C ls -A new | tr '\n' ' ')" "0:log:.gitignore a.js u.txt "
_ST_OUT_HAS "while the untracked one moves along" 'moved along with their renamed directory: old/u\.txt → new/u\.txt$'
_ST_PZ_NEW cz5t
mkdir old && print a > old/a.js && print '*.log' > old/.gitignore
git add -A && git commit -qm "CZ5T base"
git checkout -q -b topic && git mv old new && git commit -qm "CZ5T topic" && git checkout -q main
print log > old/build.log && print u > old/u.txt
_ST_TTY -- --land=topic
_ST_EQ "as does a terminal landing's sync" "$RC:$(cat old/build.log 2>/dev/null):$(LC_ALL=C ls -A new | tr '\n' ' ')" "0:log:.gitignore a.js u.txt "

# Staging in the way of an entry the carry adds – a peer's file staged where its directory goes – is
# kept, the path named once, as left
_ST_PZ_NEW cz6
print a > a.txt && git add a.txt && git commit -qm "CZ6 base" && CZ_OLD=$(git rev-parse HEAD)
mkdir d && print x > d/x.txt && git add d && git commit -qm "CZ6 d"
git rm -q --cached -r d && mv d "$TMP/cz6-d"
CZ_B=$(print PEER | git hash-object -w --stdin)
git update-index --add --cacheinfo "100644,$CZ_B,d"
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "staging in an entry's way fails the carry, the peer's entry kept" "$RC:$(git ls-files -s -- d | cut -d' ' -f2)" "1:$CZ_B"
_ST_OUT_HAS "the path named once, as left, and why" "Left as they were, staging in their way: d/x\.txt (d staged where its directory goes) – carry them once that staging is committed or unstaged: git edit --carry=${CZ_OLD:0:12}$"
_ST_OUT_LACKS "never as brought too" 'Brought to what landed'
# A peer staging a file while the carry merges it keeps that staging, the file carried all the same
_ST_PZ_NEW cz6k
print -l 1 2 3 > a.txt && git add -A && git commit -qm "CZ6K base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && print -l 1 2 3 4 > a.txt && git commit -qam "CZ6K topic" && git checkout -q main
print -l 0 1 2 3 > a.txt
_CZ_RAW
CZ_B=$(print PEER | git hash-object -w --stdin)
_CZ_STAND_IN "$TMP/cz6k-bin" '*" merge-file "*' "if [ -e ${(q)TMP}/cz6k-bin/arm ]; then mv ${(q)TMP}/cz6k-bin/arm ${(q)TMP}/cz6k-bin/fired; ${(q)CZ_REAL} update-index --cacheinfo 100644,$CZ_B,a.txt; fi"
: > "$TMP/cz6k-bin/arm"
PATH="$TMP/cz6k-bin:$PATH" _ST_RUN --carry="$CZ_OLD"
_ST_EQ "a peer's staging meanwhile is kept, the carry ending ok" "$RC:$(git show :a.txt):$(tr '\n' ' ' < a.txt)" "0:PEER:0 1 2 3 4 "
_ST_OUT_HAS "the file named as carried, its entry as left" 'Carried onto the new content: a\.txt (its index entry left as staged meanwhile)$'

# A rename whose old path holds staged edits stays there, named – the move would orphan that staging
_ST_PZ_NEW cz7
print -l 1 2 3 4 5 6 7 8 > src.txt && print -l q > q.txt
git add -A && git commit -qm "CZ7 base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && git mv src.txt dst.txt && git mv q.txt r.txt && git commit -qm "CZ7 topic" && git checkout -q main
print -l 1 PEER 3 4 5 6 7 8 > src.txt && git add src.txt
_CZ_RAW
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "a rename's staged old path stays, its staging with it" "$RC:$(git show :src.txt | tr '\n' ' '):$([ -e dst.txt ] && print there)" "1:1 PEER 3 4 5 6 7 8 :"
_ST_OUT_HAS "named with what to do" 'to merge by hand: src\.txt → dst\.txt – staged changes at its old path, which stays as it is till they are committed or unstaged$'
_ST_EQ "while a rename with no staging moves" "$(cat r.txt 2>/dev/null):$([ -e q.txt ] && print there)" "q:"

# A conflicting rename lands its new path, the edits left untracked at the old one, with the command
# merging them – as a conflict in place names its own
_ST_PZ_NEW cz8
print -l 1 2 3 4 5 6 > a.txt && print -l 1 2 3 4 5 6 > c.txt
git add -A && git commit -qm "CZ8 base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && git mv a.txt b.txt && print -l 1 2 THEIRS 4 5 6 > b.txt && print -l 1 2 THEIRS 4 5 6 > c.txt
git add -A && git commit -qm "CZ8 topic" && git checkout -q main
print -l 1 2 MINE 4 5 6 > a.txt && print -l 1 2 MINE 4 5 6 > c.txt
_CZ_RAW
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "a conflict fails the carry, the new path as landed, the edits where they were" "$RC:$(tr '\n' ' ' < b.txt):$(tr '\n' ' ' < a.txt):$(git status --porcelain | tr '\n' '|')" "1:1 2 THEIRS 4 5 6 :1 2 MINE 4 5 6 : M c.txt|?? a.txt|"
_ST_OUT_HAS "the rename named by both paths and where the edits are" 'to merge by hand: a\.txt → b\.txt – 1 conflict(s), the edits left at a\.txt, c\.txt – 1 conflict(s)$'
_ST_OUT_HAS "with the command that merges them into the new path" "^  git cat-file --filters ${CZ_OLD:0:12}:a\.txt > [^ ]*/\.git/git-edit-base && git merge-file -- b\.txt [^ ]*/\.git/git-edit-base a\.txt; rm -f [^ ]*/\.git/git-edit-base$"
_ST_OUT_HAS "and the one in place its own" "^  git cat-file --filters ${CZ_OLD:0:12}:c\.txt > [^ ]*/\.git/git-edit-base && git cat-file --filters $(git rev-parse --short=12 HEAD):c\.txt > [^ ]*/\.git/git-edit-landed && git merge-file -- c\.txt"
# One whose entries a locked index kept on the old tip says so on its own line, with the re-sync
_ST_PZ_NEW cz8l
print -l 1 2 3 4 5 6 > a.txt
git add -A && git commit -qm "CZ8L base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && git mv a.txt b.txt && print -l 1 2 THEIRS 4 5 6 > b.txt && git add -A && git commit -qm "CZ8L topic" && git checkout -q main
print -l 1 2 MINE 4 5 6 > a.txt
_CZ_RAW
: > .git/index.lock
_ST_RUN --carry="$CZ_OLD"
mv .git/index.lock "$TMP/cz8l-index.lock"
_ST_OUT_HAS "a conflicting rename's entries left by a locked index named on its line, once" 'to merge by hand: a\.txt → b\.txt – 1 conflict(s), the edits left at a\.txt, its index entry not re-synced, the index locked – once it is free: git restore --source=HEAD --staged -- a\.txt b\.txt$'
_ST_OUT_LACKS "never on a line of their own" 'Index entries left'

# A merged file takes the mode that landed, unless the checkout changed its own
_ST_PZ_NEW cz9
print -l 1 2 3 4 5 6 > x.sh && print -l 1 2 3 4 5 6 > y.sh
git add -A && git commit -qm "CZ9 base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && print -l 1 2 3 4 5 6 7 > x.sh && chmod +x x.sh && print -l 1 2 3 4 5 6 7 > y.sh
git commit -qam "CZ9 topic" && git checkout -q main
print -l 0 1 2 3 4 5 6 > x.sh && print -l 0 1 2 3 4 5 6 > y.sh && chmod +x y.sh
_CZ_RAW
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "both carried" "$RC:$(tr '\n' ' ' < x.sh)" "0:0 1 2 3 4 5 6 7 "
_ST_CHECK "a mode the landing changed taken" test -x x.sh
_ST_CHECK "one the checkout changed kept" test -x y.sh

# A sparse checkout's file outside its cone is never written, its entry alone taking what landed
_ST_PZ_NEW cz10
mkdir in out && print i > in/i.txt && print o > out/o.txt
git add -A && git commit -qm "CZ10 base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && print n > out/new.txt && print i2 > in/i.txt && print o2 > out/o.txt && print j > in/j.txt
git add -A && git commit -qm "CZ10 topic" && git checkout -q main
git sparse-checkout set --cone in
_CZ_RAW
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "nothing written outside the cone" "$RC:$([ -e out ] && print there):$(git diff --cached --name-only)" "0::"
_ST_EQ "the entries there flagged as outside it" "$(git ls-files -t -- out | tr '\n' '|')" "S out/new.txt|S out/o.txt|"
# A git before 2.42 asks no patterns, so the one added inside is left out too, as below
if _ST_SPARSE_RULES_OK; then
	_ST_EQ "while the files inside it are written" "$(cat in/i.txt):$(cat in/j.txt 2>/dev/null):$(git ls-files -t -- in | tr '\n' '|')" "i2:j:H in/i.txt|H in/j.txt|"
else
	_ST_EQ "while the files inside it are written, the one added left out below git 2.42" "$(cat in/i.txt):$(cat in/j.txt 2>/dev/null):$(git ls-files -t -- in | tr '\n' '|')" "i2::H in/i.txt|S in/j.txt|"
fi
# A git that can't ask the patterns leaves out every file the rewrite added, naming the reapply
_ST_PZ_NEW cz10b
mkdir in out && print i > in/i.txt && print o > out/o.txt
git add -A && git commit -qm "CZ10B base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && print n > out/new.txt && print j > in/j.txt
git add -A && git commit -qm "CZ10B topic" && git checkout -q main
git sparse-checkout set --cone in
_CZ_RAW
_CZ_STAND_IN "$TMP/cz10b-bin" '*" sparse-checkout check-rules "*' 'exit 129'
PATH="$TMP/cz10b-bin:$PATH" _ST_RUN --carry="$CZ_OLD"
_ST_EQ "a git asking no patterns writes no file it added" "$RC:$([ -e in/j.txt ] || [ -e out ] && print there)" "0:"
_ST_OUT_HAS "naming them with the reapply" "can't ask your sparse checkout's patterns (2\.42 can) – the files the rewrite added, left out as outside it: in/j\.txt, out/new\.txt – write those inside it with: git sparse-checkout reapply$"
git sparse-checkout reapply 2>/dev/null
_ST_EQ "which writes the ones inside it" "$(cat in/j.txt 2>/dev/null):$([ -e out ] && print there)" "j:"

# A terminal landing renaming a directory whole takes out the directories an edited file left empty
_ST_PZ_NEW cz11
mkdir -p old/deep && print -l 1 2 3 4 5 6 > old/deep/a.txt && print b > old/b.txt
git add -A && git commit -qm "CZ11 base"
git checkout -q -b topic && git mv old new && git commit -qm "CZ11 topic" && git checkout -q main
print -l 1 2 3 4 5 6 7 > old/deep/a.txt
_ST_TTY -- --land=topic
_ST_EQ "a terminal landing carries the edited file out of the renamed directory, none of it left" "$RC:$(tr '\n' ' ' < new/deep/a.txt):$([ -e old ] && print there)" "0:1 2 3 4 5 6 7 :"

# A renamed symlink whose new path the checkout holds exactly as landed moves as a file would
_ST_PZ_NEW cz12
print t > target.txt && ln -s target.txt old.lnk && print -l 1 2 3 > f.txt
git add -A && git commit -qm "CZ12 base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && git mv old.lnk new.lnk && git mv f.txt g.txt && git commit -qm "CZ12 topic" && git checkout -q main
_CZ_RAW
ln -s target.txt new.lnk && print -l 1 2 3 > g.txt
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "a renamed symlink already in place moves" "$RC:$(readlink new.lnk):$([ -L old.lnk ] || [ -e f.txt ] && print there):$(git status --porcelain)" "0:target.txt::"

# Case-only renames on a filesystem that ignores case are carried once
_ST_PZ_NEW cz13
if [ "$(git config core.ignorecase)" = true ]; then
	print -l 1 2 3 4 5 6 > Edit.txt && print same > Plain.txt && ln -s nowhere Lnk
	git add -A && git commit -qm "CZ13 base" && CZ_OLD=$(git rev-parse HEAD)
	git checkout -q -b topic && git mv Edit.txt edit.txt && git mv Plain.txt plain.txt && git mv Lnk lnk && git commit -qm "CZ13 topic" && git checkout -q main
	print -l 1 2 3 4 5 6 7 > Edit.txt
	_CZ_RAW
	_ST_RUN --carry="$CZ_OLD"
	_ST_OUT_HAS "a case-only rename is carried" 'Carried onto the new content: Edit\.txt → edit\.txt$'
	_ST_EQ "a dangling symlink's too, never removed as another file" "$(readlink lnk):$(git status --porcelain -- lnk)" "nowhere:"
	_ST_RUN --carry="$CZ_OLD"
	_ST_OUT_HAS "and a second carry finds nothing" 'Nothing to carry'
fi

# A checkout halfway through a merge is the merge's to finish
_ST_PZ_NEW cz14
print a > a.txt && git add -A && git commit -qm "CZ14 base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b x && print x > a.txt && git commit -qam "CZ14 x" && git checkout -q main
print y > a.txt && git commit -qam "CZ14 y" && git merge -q x >/dev/null 2>&1
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "a carry mid-merge refuses, touching nothing" "$RC:$(git ls-files -u | wc -l | tr -d ' ')" "1:3"
_ST_OUT_HAS "naming it" 'halfway through a merge – finish or abort it first, then run --carry again'

# A name near the length limit is written all the same, as is a file whose mode git doesn't track
_ST_PZ_NEW cz15
CZ_B=${(l:240::n:)}.txt
print -l 1 2 3 > "$CZ_B" && print -l u > u.txt
git add -A && git commit -qm "CZ15 base" && CZ_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && print -l 1 2 3 4 > "$CZ_B" && print -l u v > u.txt && git commit -qam "CZ15 topic" && git checkout -q main
print -l 0 1 2 3 > "$CZ_B" && git config core.fileMode false && chmod +x u.txt
_CZ_RAW
_ST_RUN --carry="$CZ_OLD"
_ST_EQ "a name near the length limit carried" "$RC:$(tr '\n' ' ' < "$CZ_B")" "0:0 1 2 3 4 "
_ST_EQ "an unedited file whose mode git doesn't track brought, its entry too" "$(tr '\n' ' ' < u.txt):$(git diff --cached --name-only)" "u v :"
cd "$TMP/repo"
