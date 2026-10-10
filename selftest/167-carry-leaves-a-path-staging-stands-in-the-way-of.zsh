# `--carry` leaves a path whose new entry would drop staging in its way – a file staged where its
# directory goes, files staged under it – whole, neither file nor entry written, a rename's source
# and a renamed directory's untracked files staying with it, named once with the carry to run
# again; a directory of a peer's files where a file lands is never replaced, and staging put in
# the way meanwhile still keeps its entry out, the file named as written
_ST_SCENARIO "\e[1;96m[167] --carry leaves a path staging stands in the way of whole, named with the carry to run again\e[0m"
local KC_OLD KC_B KC_REAL=${commands[git]}

# Moves `main` to `topic` the way a landing made elsewhere does – the index and files left as they were
_KC_RAW () {
	git update-ref refs/heads/main topic "$KC_OLD"
}
# Stages <path> as a peer's file the checkout doesn't hold
_KC_PEER () {
	# Args: <path>
	git update-index --add --cacheinfo "100644,$KC_B,$1"
}

# A file staged where the landing puts a directory leaves the file under it unwritten, its entry
# too, while the rest is carried – and the carry named runs once that staging is gone
_ST_PZ_NEW kc1
print -l 1 2 3 > a.txt && git add -A && git commit -qm "KC1 base" && KC_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && print -l 1 2 3 4 > a.txt && mkdir d && print x > d/x.txt
git add -A && git commit -qm "KC1 topic" && git checkout -q main
print -l 0 1 2 3 > a.txt
_KC_RAW
KC_B=$(print PEER | git hash-object -w --stdin)
_KC_PEER d
_ST_RUN --carry="$KC_OLD"
_ST_EQ "a file staged where its directory goes fails the carry, the peer's entry kept" "$RC:$(git ls-files -s -- d | cut -d' ' -f2)" "1:$KC_B"
_ST_EQ "neither the file under it nor its entry written" "$([ -e d ] && print there):$(git ls-files -- d/x.txt)" ":"
_ST_OUT_HAS "named once as left, with why and the carry to run again" "^Left as they were, staging in their way: d/x\.txt (d staged where its directory goes) – carry them once that staging is committed or unstaged: git edit --carry=${KC_OLD:0:12}$"
_ST_OUT_LACKS "never as written with its entry left" 'Index entries not written\|Brought to what landed'
_ST_EQ "while the rest is carried" "$(tr '\n' ' ' < a.txt)" "0 1 2 3 4 "
git rm -q --cached d
_ST_RUN --carry="$KC_OLD"
_ST_EQ "the carry it names writes it once the staging is gone" "$RC:$(cat d/x.txt 2>/dev/null):$(git status --porcelain | tr '\n' '|')" "0:x: M a.txt|"

# Files staged under a path the landing puts a file at leave that file unwritten
_ST_PZ_NEW kc2
print a > a.txt && git add -A && git commit -qm "KC2 base" && KC_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && print p > P && git add -A && git commit -qm "KC2 topic" && git checkout -q main
_KC_RAW
KC_B=$(print PEER | git hash-object -w --stdin)
_KC_PEER P/a.md && _KC_PEER P/b.md
_ST_RUN --carry="$KC_OLD"
_ST_EQ "files staged under a path a file lands at stay staged, nothing written there" "$RC:$(git ls-files -- P | tr '\n' ' '):$([ -e P ] && print there)" "1:P/a.md P/b.md :"
_ST_OUT_HAS "named as staged under it" '^Left as they were, staging in their way: P (files staged under it where the rewrite put a file) – carry them'
# Where the peer's files are in the checkout, staged and untracked, the directory stays whole
_ST_PZ_NEW kc3
print a > a.txt && git add -A && git commit -qm "KC3 base" && KC_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && print p > P && git add -A && git commit -qm "KC3 topic" && git checkout -q main
_KC_RAW
mkdir P && print mine > P/a.md && git add P/a.md && print u > P/u.txt
_ST_RUN --carry="$KC_OLD"
_ST_EQ "a directory of a peer's files where a file lands keeps them, staged and untracked" "$RC:$(cat P/a.md P/u.txt 2>/dev/null | tr '\n' ' '):$(git ls-files -- P)" "1:mine u :P/a.md"
_ST_OUT_HAS "named as a directory standing there" 'P – your directory stands where the rewrite put a file'

# A rename into a directory a file is staged in the place of leaves the old path as it is, edits,
# entry and all
_ST_PZ_NEW kc4
print -l 1 2 3 4 5 6 > src.txt && git add -A && git commit -qm "KC4 base" && KC_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && mkdir d && git mv src.txt d/x.txt && git commit -qm "KC4 topic" && git checkout -q main
print -l 1 2 3 4 5 6 7 > src.txt
_KC_RAW
KC_B=$(print PEER | git hash-object -w --stdin)
_KC_PEER d
_ST_RUN --carry="$KC_OLD"
_ST_EQ "a rename whose new path staging stands in the way of stays at its old path" "$RC:$(tr '\n' ' ' < src.txt 2>/dev/null):$([ -e d ] && print there):$(git ls-files -s -- src.txt | cut -d' ' -f2)" "1:1 2 3 4 5 6 7 ::$(git rev-parse "${KC_OLD}:src.txt")"
_ST_OUT_HAS "named by both paths" 'staging in their way: src\.txt → d/x\.txt (d staged where its directory goes) – carry them'
# As do a renamed directory's tracked and untracked files where its new name is staged as a file
_ST_PZ_NEW kc5
mkdir old && print a > old/a.js && git add -A && git commit -qm "KC5 base" && KC_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && git mv old new && git commit -qm "KC5 topic" && git checkout -q main
print u > old/u.txt
_KC_RAW
KC_B=$(print PEER | git hash-object -w --stdin)
_KC_PEER new
_ST_RUN --carry="$KC_OLD"
_ST_EQ "a directory renamed where its new name is staged stays, untracked files and all" "$RC:$(command ls -A old | tr '\n' ' '):$([ -e new ] && print there)" "1:a.js u.txt :"
_ST_OUT_HAS "the tracked file named as left" 'staging in their way: old/a\.js → new/a\.js (new staged where its directory goes) – carry them'
_ST_OUT_HAS "the untracked one too" 'old/u\.txt – untracked, new staged where its directory goes'

# Outside a sparse checkout, an entry alone would drop the staging all the same
_ST_PZ_NEW kc6
mkdir in && print i > in/i.txt && git add -A && git commit -qm "KC6 base" && KC_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && mkdir gen && print g > gen/x.txt && git add -A && git commit -qm "KC6 topic" && git checkout -q main
git sparse-checkout set --cone in
_KC_RAW
KC_B=$(print PEER | git hash-object -w --stdin)
_KC_PEER gen
_ST_RUN --carry="$KC_OLD"
_ST_EQ "an entry outside the cone staging stands in the way of stays out" "$RC:$(git ls-files -- gen gen/x.txt | tr '\n' ' ')" "1:gen "
_ST_OUT_HAS "named alike" 'staging in their way: gen/x\.txt (gen staged where its directory goes) – carry them'
git sparse-checkout disable 2>/dev/null

# Staging put in the way while the carry writes keeps its entry out all the same – the file named
# as written, its entry left
_ST_PZ_NEW kc7
print a > a.txt && git add -A && git commit -qm "KC7 base" && KC_OLD=$(git rev-parse HEAD)
git checkout -q -b topic && mkdir d && print x > d/x.txt && git add -A && git commit -qm "KC7 topic" && git checkout -q main
_KC_RAW
KC_B=$(print PEER | git hash-object -w --stdin)
mkdir -p "$TMP/kc7-bin"
{
	print -r -- '#!/bin/sh'
	print -r -- "case \" \$* \" in *' --path=d/x.txt '*) if [ -e ${(q)TMP}/kc7-bin/arm ]; then mv ${(q)TMP}/kc7-bin/arm ${(q)TMP}/kc7-bin/fired; ${(q)KC_REAL} -C ${(q)PWD} update-index --add --cacheinfo 100644,$KC_B,d; fi ;; esac"
	print -r -- "exec ${(q)KC_REAL} \"\$@\""
} > "$TMP/kc7-bin/git"
chmod +x "$TMP/kc7-bin/git"
: > "$TMP/kc7-bin/arm"
PATH="$TMP/kc7-bin:$PATH" _ST_RUN --carry="$KC_OLD"
_ST_EQ "staging put in the way meanwhile keeps its entry" "$RC:$([ -e "$TMP/kc7-bin/fired" ] && print fired):$(git ls-files -s -- d | cut -d' ' -f2)" "1:fired:$KC_B"
_ST_OUT_HAS "the file named as written, its entry left" 'Index entries not written, staging in their way: d/x\.txt (written, brought to what landed – d staged where its directory goes)'
cd "$TMP/repo"
