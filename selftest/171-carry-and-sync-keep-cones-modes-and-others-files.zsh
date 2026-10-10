# `--carry` and a terminal run's sync bring a file swapped for a directory either way, keep what lies
# outside a sparse checkout, take a mode from the index where git reads no executable bit, merge
# under the attributes the edits were made under, respell a directory renamed by case alone, keep
# their temporaries out of the checkout, a peer's file and a peer's late edit whole, and supersede an
# intent-to-add entry an empty landed file matches – each path named once with a step that works
_ST_SCENARIO "\e[1;96m[171] --carry and a terminal sync keep cones, modes, attributes and others' files\e[0m"
local CS_OLD CS_REAL=${commands[git]} CS_CMD CS_GOT

# Moves `main` to `topic` the way a landing made elsewhere does – the index and files left as they were
_CS_RAW () {
	git update-ref refs/heads/main topic "$CS_OLD"
}
# Writes `<dir>/git` standing in for the real one, running <script> first where <case pattern> takes
# the call's arguments
_CS_STAND_IN () {
	# Args: <dir> <case pattern> <script>
	mkdir -p "$1"
	{
		print -r -- '#!/bin/sh'
		print -r -- "case \" \$* \" in $2) $3 ;; esac"
		print -r -- "exec ${(q)CS_REAL} \"\$@\""
	} > "$1/git"
	chmod +x "$1/git"
}

# A terminal drop of a commit that turned file `d` into `d/x` – the file goes, the directory's file
# comes, in one two-tree merge, none of it read as staging in the way
_ST_PZ_NEW cs1
print a > a.txt && print dfile > d && git add -A && git commit -qm "CS1 base"
git rm -q d && mkdir d && print x > d/x && git add d/x && git commit -qm "CS1 d to dir"
_ST_PZ_C t.txt t "CS1 tip"
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a file the drop turns back from a directory is written, the checkout clean" "$RC:$(cat d 2>/dev/null):$(git status --porcelain)" "0:dfile:"
_ST_OUT_LACKS "never named as left" 'Left as they were'
# And the other way round – a directory's file goes, and the file in its place comes
_ST_PZ_NEW cs1b
print a > a.txt && mkdir d && print x > d/x && git add -A && git commit -qm "CS1B base"
git rm -q d/x && print dfile > d && git add d && git commit -qm "CS1B d to file"
_ST_PZ_C t.txt t "CS1B tip"
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a directory the drop turns back from a file is written, the checkout clean" "$RC:$(cat d/x 2>/dev/null):$(git status --porcelain)" "0:x:"
_ST_OUT_LACKS "never blamed on staging in its way" 'staged where its directory goes'
# While an untracked file in that directory keeps it there, named
_ST_PZ_NEW cs1c
print a > a.txt && print dfile > d && git add -A && git commit -qm "CS1C base"
git rm -q d && mkdir d && print x > d/x && git add d/x && git commit -qm "CS1C d to dir"
_ST_PZ_C t.txt t "CS1C tip"
print mine > d/mine.txt
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a directory holding an untracked file stays a directory" "$RC:$(cat d/mine.txt):$([ -d d ] && print dir)" "0:mine:dir"
_ST_OUT_HAS "named as the caller's" 'd – your directory stands where the rewrite put a file'
# And an edited file stays, its directory's file not written in its place
_ST_PZ_NEW cs1d
print a > a.txt && mkdir d && print x > d/x && git add -A && git commit -qm "CS1D base"
git rm -q d/x && print dfile > d && git add d && git commit -qm "CS1D d to file"
_ST_PZ_C t.txt t "CS1D tip"
print dfile-mine > d
_ST_TTY -- -d -y HEAD~1
_ST_EQ "an edited file where a directory comes back stays" "$RC:$(cat d 2>/dev/null)" "0:dfile-mine"

# A rename out of a sparse checkout: an agent's landing names the edits left at the old path, and
# `--carry` too, with the widening that takes them along – which, run as printed, carries them – while
# an untracked file whose place lies outside stays where it is
# A git before 2.42 asks no patterns, so every path the move adds reads as maybe outside, and moves
# without `--sparse`
local CS_MV="git mv" CS_WHY="maybe outside your sparse checkout, which this git can't ask (2\.42 can)"
_ST_SPARSE_RULES_OK && CS_MV="git mv --sparse" CS_WHY="outside your sparse checkout"
_ST_PZ_NEW cs2
mkdir in out && print -l 1 2 3 4 5 > in/f.txt && print o > out/o.txt && git add -A && git commit -qm "CS2 base"
_ST_PZ_C t.txt t "CS2 tip"
CS_OLD=$(git rev-parse HEAD)
git sparse-checkout set --cone in
print -l 1 2 3 4 5 EDIT > in/f.txt && print mine > in/notes.txt
_ST_RUN --exec -- sh -c "$CS_MV in/f.txt out/f.txt && git commit -qm 'CS2 move f out'"
_ST_OUT_HAS "the landing names the rename the edits are left behind by" 'with uncommitted edits left untracked at the old path and the new one missing: in/f\.txt → out/f\.txt$'
_ST_OUT_HAS "and the untracked file as outside the cone" "in/notes\.txt – untracked, its place out/notes\.txt $CS_WHY\$"
_ST_EQ "the new path's entry flagged outside it, never read as deleted" "$(git ls-files -t -- out/f.txt):$(git status --porcelain -- out)" "S out/f.txt:"
_ST_RUN --carry="$CS_OLD"
_ST_EQ "the carry writes nothing outside the cone, the edits where they were" "$RC:$([ -e out ] && print there):$(tr '\n' ' ' < in/f.txt):$(cat in/notes.txt)" "1::1 2 3 4 5 EDIT :mine"
_ST_OUT_HAS "naming the rename with the widening that carries it" "in/f\.txt → out/f\.txt – renamed $CS_WHY, the edits left at in/f\.txt – carry them once it takes that path in: git sparse-checkout add -- out && git edit --carry=${CS_OLD:0:12}"
_ST_OUT_LACKS "never moving the untracked file out of it" 'Untracked files moved along'
CS_CMD=$(print -r -- "$OUT" | grep -o 'git sparse-checkout add -- out && git edit --carry=[0-9a-f]*' | head -1)
PATH="$TMP/cs2-bin:$PATH"
mkdir -p "$TMP/cs2-bin" && ln -sf "$SELF" "$TMP/cs2-bin/git-edit"
CS_CMD=$(eval "$CS_CMD" 2>&1)
CS_GOT="$?:$(tr '\n' ' ' < out/f.txt 2>/dev/null):$(cat out/notes.txt 2>/dev/null):$([ -e in ] && print there)"
# The untracked file stays below 2.42, its place still maybe outside
if _ST_SPARSE_RULES_OK; then
	_ST_EQ "the widening run as printed carries the edits along" "$CS_GOT" "0:1 2 3 4 5 EDIT :mine:"
else
	_ST_EQ "the widening run as printed carries the edits along" "$CS_GOT:$(cat in/notes.txt)" "1:1 2 3 4 5 EDIT ::there:mine"
fi
PATH=${PATH#"$TMP/cs2-bin:"}
# A raw landing renaming one file edited, one not: the unedited one goes, the edited one's old entry
# too, never left reading as a staged re-add
_ST_PZ_NEW cs2b
mkdir in out && print -l 1 2 3 > in/f.txt && print -l a b > in/u.txt && print o > out/o.txt && git add -A && git commit -qm "CS2B base"
CS_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && git mv in/f.txt out/f.txt && git mv in/u.txt out/u.txt && git commit -qm "CS2B topic" && git checkout -q main
git sparse-checkout set --cone in
print -l 1 2 3 EDIT > in/f.txt
_CS_RAW
_ST_RUN --carry="$CS_OLD"
_ST_EQ "an unedited source goes, the edited one stays untracked, nothing written outside" "$RC:$([ -e in/u.txt ] && print there):$(git status --porcelain --untracked-files=all | tr '\n' '|'):$([ -e out ] && print there)" "1::?? in/f.txt|:"
_ST_EQ "both new paths' entries flagged outside the cone" "$(git ls-files -t -- out | tr '\n' '|')" "S out/f.txt|S out/o.txt|S out/u.txt|"
_ST_OUT_HAS "the unedited one named with its entry alone" 'Brought to what landed, holding no edits: in/u\.txt → out/u\.txt (outside your sparse checkout, its entry alone)$'
_ST_RUN --carry="$CS_OLD"
_ST_OUT_HAS "a second carry names the edits again" "in/f\.txt → out/f\.txt – renamed $CS_WHY"
# A terminal landing of such a rename writes nothing outside the cone either
_ST_PZ_NEW cs2c
mkdir in out && print -l 1 2 3 4 5 > in/f.txt && print o > out/o.txt && git add -A && git commit -qm "CS2C base"
git sparse-checkout set --cone in
print -l 1 2 3 4 5 EDIT > in/f.txt && print mine > in/notes.txt
_ST_TTY -- --exec -y -- sh -c "$CS_MV in/f.txt out/f.txt && git commit -qm 'CS2C move f out'"
_ST_EQ "a terminal sync writes nothing outside the cone, the edits where they were" "$RC:$([ -e out ] && print there):$(tr '\n' ' ' < in/f.txt):$(cat in/notes.txt)" "0::1 2 3 4 5 EDIT :mine"
_ST_EQ "the new path's entry flagged outside it" "$(git ls-files -t -- out/f.txt)" "S out/f.txt"
_ST_OUT_HAS "naming the rename with the carry that takes it along" "in/f\.txt → out/f\.txt – renamed $CS_WHY, the edits left at in/f\.txt – carry them once it takes that path in: git sparse-checkout add -- out && git edit --carry="
_ST_OUT_HAS "and the untracked file left" "in/notes\.txt – untracked, its place out/notes\.txt $CS_WHY"

# Under `core.fileMode=false` a terminal sync takes no mode off the disk's executable bit
_ST_PZ_NEW cs3
git config core.fileMode false
print -l 1 2 3 4 5 6 7 8 > f.txt && git add -A && git commit -qm "CS3 base"
chmod +x f.txt && print -l 1 2 3 4 5 6 7 MINE > f.txt && git add f.txt
_ST_TTY -- --exec -y -- sh -c "sed 's/^1\$/ONE/' f.txt > t && mv t f.txt && git commit -qam 'CS3 landed'"
_ST_EQ "edits staged whole keep the mode git staged them at" "$RC:$(git ls-files -s f.txt | cut -c1-6):$(git diff --cached --summary)" "0:100644:"
_ST_EQ "merged onto what landed" "$(git show :f.txt | tr '\n' ' ')" "ONE 2 3 4 5 6 7 MINE "
# Where git reads the bit, the checkout's own chmod still goes along
_ST_PZ_NEW cs3b
print -l 1 2 3 4 5 6 7 8 > f.txt && git add -A && git commit -qm "CS3B base"
print -l 1 2 3 4 5 6 7 MINE > f.txt && chmod +x f.txt && git add f.txt
_ST_TTY -- --exec -y -- sh -c "sed 's/^1\$/ONE/' f.txt > t && mv t f.txt && git commit -qam 'CS3B landed'"
_ST_EQ "a chmod the checkout made is kept" "$RC:$(git ls-files -s f.txt | cut -c1-6)" "0:100755"
# And a second `--carry` across a mode the landing changed finds its edits carried already
_ST_PZ_NEW cs3c
git config core.fileMode false
print -l a b > m.sh && print -l a b c d e > k.sh && git add -A && git commit -qm "CS3C base"
_ST_PZ_C t.txt t "CS3C tip"
CS_OLD=$(git rev-parse HEAD)
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --edits '{"k.sh": [["e\n", "E\n"]]}' --chmod m.sh=+x --chmod k.sh=+x
git restore --source="$CS_OLD" -- k.sh m.sh && chmod -x m.sh k.sh && print -l K a b c d e > k.sh
_ST_RUN --carry="$CS_OLD"
_ST_EQ "the first carry merges the edits" "$RC:$(tr '\n' ' ' < k.sh)" "0:K a b c d E "
_ST_RUN --carry="$CS_OLD"
_ST_EQ "a second finds nothing to carry" "$RC" "0"
_ST_OUT_HAS "saying so" 'Nothing to carry'
_ST_OUT_LACKS "never refusing the carried edits, nor bringing the mode-only file again" 'the merge would alter the edits\|Brought to what landed'

# A peer writing its own file where the landing adds one, as the sync runs, keeps it – offered, never
# named as a stale file to take
_ST_PZ_NEW cs4
print c > c.txt && git add -A && git commit -qm "CS4 base"
_CS_STAND_IN "$TMP/cs4-bin" "*\" update-ref -m \"*) : > ${(q)PWD}/.git/cs-armed ;; *\" ls-files -v -z \"*" "[ -e ${(q)PWD}/.git/cs-armed ] && [ ! -e ${(q)PWD}/.git/cs-fired ] && : > ${(q)PWD}/.git/cs-fired && echo PEER > ${(q)PWD}/n.txt"
_ST_TTY PATH="$TMP/cs4-bin:$PATH" -- --exec -y -- sh -c 'echo landed-n > n.txt && echo C > c.txt && git add -A && git commit -qm "CS4 landed"'
_ST_EQ "the peer's file stays, as a change to what landed" "$RC:$([ -e .git/cs-fired ] && print fired):$(cat n.txt):$(git status --porcelain | tr '\n' '|')" "0:fired:PEER: M n.txt|"
_ST_OUT_HAS "named as a file of someone's" 'Files of yours stood where the landing put its own – yours stay, as changes to them: n\.txt$'
_ST_OUT_LACKS "never as one git refused, to take" 'Not brought along'

# A peer editing a renamed file as the sync runs has its edits carried to the new path
_ST_PZ_NEW cs5
print -l 1 2 3 4 5 > r.txt && print o > o.txt && git add -A && git commit -qm "CS5 base"
_CS_STAND_IN "$TMP/cs5-bin" "*\" update-ref -m \"*) : > ${(q)PWD}/.git/cs-armed ;; *\" ls-files -v -z \"*" "[ -e ${(q)PWD}/.git/cs-armed ] && [ ! -e ${(q)PWD}/.git/cs-fired ] && : > ${(q)PWD}/.git/cs-fired && printf '1\n2\n3\n4\n5\nPEER\n' > ${(q)PWD}/r.txt"
_ST_TTY PATH="$TMP/cs5-bin:$PATH" -- --exec -y -- sh -c 'mkdir s && git mv r.txt s/r.txt && git commit -qm "CS5 move r"'
_ST_EQ "the late edits follow the rename" "$RC:$([ -e .git/cs-fired ] && print fired):$([ -e r.txt ] && print there):$(tr '\n' ' ' < s/r.txt)" "0:fired::1 2 3 4 5 PEER "
_ST_OUT_HAS "named as merged by both paths" 'Your uncommitted edits merged onto what landed: r\.txt → s/r\.txt$'

# A landing adding `eol=crlf` merges edits beside its own as a carry and a sync alike
_ST_PZ_NEW cs6
print -l 1 2 3 4 5 6 > f.txt && git add -A && git commit -qm "CS6 base"
CS_OLD=$(git rev-parse HEAD)
_ST_RUN --exec -- sh -c 'printf "*.txt eol=crlf\n" > .gitattributes && printf "ONE\n2\n3\n4\n5\n6\n" > f.txt && git add -A && git commit -qm "CS6 attrs"'
print -l 1 2 3 4 MINE 6 > f.txt
_ST_RUN --carry="$CS_OLD"
# A git before 2.40 reads attributes off no tree, so each side merges under the new ones, where `eol`
# rewrites every line – the edits left as they were, named as a conflict
if _ST_ATTR_SOURCE_OK; then
	_ST_EQ "the carry merges cleanly under the attributes the edits were made under" "$RC:$(tr -d '\r' < f.txt | tr '\n' ' ')" "0:ONE 2 3 4 MINE 6 "
else
	_ST_EQ "a carry below git 2.40 leaves the edits as they were" "$RC:$(tr -d '\r' < f.txt | tr '\n' ' ')" "1:1 2 3 4 MINE 6 "
	_ST_OUT_HAS "named with the merge that brings them in" 'Left as they were, to merge by hand: f\.txt – 1 conflict(s)'
fi
_ST_PZ_NEW cs6b
print -l 1 2 3 4 5 6 > f.txt && git add -A && git commit -qm "CS6B base"
print -l 1 2 3 4 MINE 6 > f.txt
_ST_TTY -- --exec -y -- sh -c 'printf "*.txt eol=crlf\n" > .gitattributes && printf "ONE\n2\n3\n4\n5\n6\n" > f.txt && git add -A && git commit -qm "CS6B attrs"'
if _ST_ATTR_SOURCE_OK; then
	_ST_EQ "and so does a terminal sync" "$RC:$(tr -d '\r' < f.txt | tr '\n' ' ')" "0:ONE 2 3 4 MINE 6 "
	_ST_OUT_LACKS "never as a conflict" 'conflict with what landed'
else
	_ST_EQ "as does a terminal sync" "$RC:$(tr -d '\r' < f.txt | tr '\n' ' ')" "0:1 2 3 4 MINE 6 "
	_ST_OUT_HAS "named as a conflict" 'Your uncommitted edits conflict with what landed – left as they were, as changes to it: f\.txt'
fi

# A name near the length limit takes the printed merge command all the same
_ST_PZ_NEW cs7
local CS_N=${(l:241::n:)}.txt
print -l 1 2 3 > "$CS_N" && git add -A && git commit -qm "CS7 base"
_ST_PZ_C t.txt t "CS7 tip"
CS_OLD=$(git rev-parse HEAD)
print -l 1 LANDED 3 > "$CS_N" && git add -- "$CS_N"
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" -- "$CS_N"
git restore --source="$CS_OLD" -- "$CS_N" 2>/dev/null; print -l 1 MINE 3 > "$CS_N"
_ST_RUN --carry="$CS_OLD"
CS_CMD=$(print -r -- "$OUT" | grep -A1 'Merge the conflicting' | tail -1 | sed 's/^ *//')
CS_CMD=$(eval "$CS_CMD" 2>&1)
_ST_EQ "the printed merge runs on a 245-byte name, markers and all" "$(grep -c '^<<<<<<<\|^>>>>>>>' "$CS_N"):$(git status --porcelain --untracked-files=all | grep -c git-edit)" "2:0"
_ST_EQ "its temporaries never in the checkout" "$CS_CMD" ""

# A directory renamed by case alone takes the new spelling, a second carry finding nothing
_ST_PZ_NEW cs8
if [ "$(git config core.ignorecase)" = true ]; then
	mkdir Lib && print -l 1 2 3 > Lib/x.txt && print -l 1 2 3 > Lib/y.txt && print -l 1 2 3 4 5 > Lib/z.txt
	git add -A && git commit -qm "CS8 base" && CS_OLD=$(git rev-parse HEAD)
	git checkout -q -b topic && git mv Lib tmpdir && git mv tmpdir lib && print -l 1 2 3 4 FIVE > lib/z.txt && git add -A && git commit -qm "CS8 topic"
	git checkout -q main
	print -l 1 2 3 MINE > Lib/y.txt && print -l ONE 2 3 4 5 > Lib/z.txt
	_CS_RAW
	_ST_RUN --carry="$CS_OLD"
	_ST_EQ "the directory takes the new spelling, the edits merged" "$RC:$(print -l *(/)):$(tr '\n' ' ' < lib/z.txt)" "0:lib:ONE 2 3 4 FIVE "
	_ST_OUT_HAS "named" 'Directories the rewrite renamed by case alone, now spelled as it has them: Lib → lib$'
	_ST_RUN --carry="$CS_OLD"
	_ST_OUT_HAS "and a second carry finds nothing" 'Nothing to carry'
fi

# A peer's `git add -A` as the carry and the sync write stages none of their temporaries
_ST_PZ_NEW cs9
print u > u.txt && git add -A && git commit -qm "CS9 base"
CS_OLD=$(git rev-parse HEAD)
_ST_RUN --exec -- sh -c 'echo U > u.txt && git commit -qam "CS9 landed"'
_CS_STAND_IN "$TMP/cs9-bin" '*" cat-file --filters --path="*' "[ -e ${(q)PWD}/.git/cs-fired ] || { : > ${(q)PWD}/.git/cs-fired; ${(q)CS_REAL} -C ${(q)PWD} add -A; }"
PATH="$TMP/cs9-bin:$PATH" _ST_RUN --carry="$CS_OLD"
_ST_EQ "the carry's temporary is never staged" "$RC:$([ -e .git/cs-fired ] && print fired):$(git ls-files | grep -c git-edit)" "0:fired:0"
_ST_PZ_NEW cs9b
print -l 1 2 3 4 5 > u.txt && git add -A && git commit -qm "CS9B base"
print -l 1 2 3 4 5 MINE > u.txt
_CS_STAND_IN "$TMP/cs9b-bin" "*\" update-ref -m \"*) : > ${(q)PWD}/.git/cs-armed ;; *\" hash-object -- u.txt \"*" "[ -e ${(q)PWD}/.git/cs-armed ] && [ ! -e ${(q)PWD}/.git/cs-fired ] && [ -n \"\$(ls -A ${(q)PWD} ${(q)PWD}/.git | grep git-edit-sync)\" ] && : > ${(q)PWD}/.git/cs-fired && ${(q)CS_REAL} -C ${(q)PWD} add -A"
_ST_TTY PATH="$TMP/cs9b-bin:$PATH" -- --exec -y -- sh -c "sed 's/^1\$/ONE/' u.txt > t && mv t u.txt && git commit -qam 'CS9B landed'"
_ST_EQ "nor the sync's, written in the git dir" "$RC:$([ -e .git/cs-fired ] && print fired):$(git ls-files | grep -c git-edit):$(tr '\n' ' ' < u.txt)" "0:fired:0:ONE 2 3 4 5 MINE "

# An intent-to-add entry an empty landed file matches is superseded – by an agent's landing, a raw
# one's carry, and a terminal sync – never left reading as a staged removal
_ST_PZ_NEW cs10
print base > base.txt && git add -A && git commit -qm "CS10 base"
mkdir pkg && : > pkg/__init__.py && git add -N pkg/__init__.py
_ST_RUN --exec -- sh -c 'mkdir -p pkg && : > pkg/__init__.py && git add pkg/__init__.py && git commit -qm "CS10 add pkg"'
_ST_EQ "an agent's landing re-syncs it" "$RC:$(git status --porcelain)" "0:"
_ST_PZ_NEW cs10b
print base > base.txt && git add -A && git commit -qm "CS10B base"
CS_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && mkdir pkg && : > pkg/__init__.py && git add pkg && git commit -qm "CS10B topic" && git checkout -q main
mkdir pkg && : > pkg/__init__.py && git add -N pkg/__init__.py
_CS_RAW
_ST_RUN --carry="$CS_OLD"
_ST_EQ "a carry after a raw landing takes what landed" "$RC:$(git status --porcelain)" "0:"
_ST_OUT_HAS "named" 'Index entries brought to what landed, their files left as they are: pkg/__init__\.py$'
_ST_PZ_NEW cs10c
print base > base.txt && git add -A && git commit -qm "CS10C base"
mkdir pkg && : > pkg/__init__.py && git add -N pkg/__init__.py
_ST_TTY -- --exec -y -- sh -c 'mkdir -p pkg && : > pkg/__init__.py && git add pkg/__init__.py && git commit -qm "CS10C add pkg"'
_ST_EQ "and a terminal sync" "$RC:$(git status --porcelain)" "0:"
# One holding content of the caller's keeps it, as a change to what landed
_ST_PZ_NEW cs10d
print base > base.txt && git add -A && git commit -qm "CS10D base"
print mine > n.txt && git add -N n.txt
_ST_RUN --exec -- sh -c 'echo theirs > n.txt && git add n.txt && git commit -qm "CS10D add n"'
_ST_EQ "an intent-to-add file with content stays the caller's" "$RC:$(cat n.txt):$(git status --porcelain)" "0:mine: M n.txt"

# A rename's old path edited again once the carry checked it stays, named, never removed
_ST_PZ_NEW cs11
print -l 1 2 3 4 5 > r.txt && print o > o.txt && git add -A && git commit -qm "CS11 base"
CS_OLD=$(git rev-parse HEAD)
_ST_RUN --exec -- sh -c "mkdir s && git mv r.txt s/r.txt && sed 's/^1\$/ONE/' s/r.txt > t && mv t s/r.txt && git commit -qam 'CS11 move r'"
print -l 1 2 3 4 5 MINE > r.txt
mkdir -p "$TMP/cs11-bin"
{
	print -r -- '#!/bin/sh'
	print -r -- 'case " $* " in *" hash-object -- r.txt "*)'
	print -r -- "  N=\$(cat ${(q)PWD}/.git/cs-n 2>/dev/null || echo 0); N=\$((N+1)); echo \$N > ${(q)PWD}/.git/cs-n"
	print -r -- "  if [ \$N = 2 ]; then OUT=\$(${(q)CS_REAL} \"\$@\"); RC=\$?; printf '1\n2\n3\n4\n5\nMINE\nPEER\n' > ${(q)PWD}/r.txt; echo \"\$OUT\"; exit \$RC; fi ;;"
	print -r -- 'esac'
	print -r -- "exec ${(q)CS_REAL} \"\$@\""
} > "$TMP/cs11-bin/git"
chmod +x "$TMP/cs11-bin/git"
PATH="$TMP/cs11-bin:$PATH" _ST_RUN --carry="$CS_OLD"
_ST_EQ "the late edit stays at the old path, the edits read before carried" "$RC:$(tr '\n' ' ' < r.txt 2>/dev/null):$(tr '\n' ' ' < s/r.txt)" "1:1 2 3 4 5 MINE PEER :ONE 2 3 4 5 MINE "
_ST_OUT_HAS "named" 'r\.txt – edited again while carrying, kept untracked – the edits read before went to s/r\.txt'

# A cherry-pick sequence stopped and its stop committed by hand is still halfway through
_ST_PZ_NEW cs12
print -l a b > f.txt && git add -A && git commit -qm "CS12 base"
git checkout -q -b side && print -l a SIDE > f.txt && git commit -qam "CS12 s1" && print x > x.txt && git add x.txt && git commit -qm "CS12 s2"
git checkout -q main && print -l a MAIN > f.txt && git commit -qam "CS12 m1"
CS_OLD=$(git rev-parse HEAD)
git cherry-pick side~1 side >/dev/null 2>&1; print -l a BOTH > f.txt && git add f.txt && git commit -q --no-edit 2>/dev/null
_ST_RUN --carry="$CS_OLD"
_ST_EQ "a carry refuses" "$RC:$([ -d .git/sequencer ] && print seq)" "1:seq"
_ST_OUT_HAS "naming the sequence" 'halfway through a cherry-pick or revert sequence – finish or abort it first'
git cherry-pick --quit 2>/dev/null

# Under `core.symlinks=false` a landed link comes as the file git writes for one
_ST_PZ_NEW cs13
git config core.symlinks false
print t > target.txt && git add -A && git commit -qm "CS13 base"
CS_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && git update-index --add --cacheinfo "120000,$(printf target.txt | git hash-object -w --stdin),l" && git commit -qm "CS13 topic" && git checkout -q main
_CS_RAW
_ST_RUN --carry="$CS_OLD"
_ST_EQ "a plain file holding the target" "$RC:$([ -L l ] && print link):$(cat l):$(git status --porcelain)" "0::target.txt:"
