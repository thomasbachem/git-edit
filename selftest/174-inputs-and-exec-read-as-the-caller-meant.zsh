# An `--exec` command runs where the caller stands, `GIT_PREFIX` naming it, and a program the tip
# lacks refuses with the path to run; a patch applies byte for byte, whatever the repo's whitespace
# settings; and every remedy for inputs a landing or the tip stands against names the step that
# works – a staged fold the carry and the re-stage, an edit the commit that renamed or removed its
# path or the key read from where the caller stands, a put its file's new name, a removal what
# landed on it – while a moved tip names the inputs, and `--commit` beside `-C` or a removal below
# the commit adding its path is named for what was passed
_ST_SCENARIO "\e[1;96m[174] inputs and --exec read as the caller meant, every remedy a working step\e[0m"
local IX_T IX_C IX_REAL IX_PEER
# Lands <file> as <lines> on a branch of its own, through `--land` under the peer's label, leaving the
# checkout's copy as it was
_IX_PEER_LANDS () {
	# Args: <name> <subject> <file> <line>...
	git branch "$1" && git worktree add -q "$TMP/$1-wt" "$1" && print -l "${@:4}" > "$TMP/$1-wt/$3" && \
		git -C "$TMP/$1-wt" commit -qam "$2" && \
		GIT_EDIT_ACTOR=ix-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --land="$1" </dev/null >/dev/null 2>&1
}

# A command run from a subdirectory runs in the worktree's copy of it, `GIT_PREFIX` naming it – once,
# a relative path there named the top-level file of the same name, which landed `ok`
_ST_PZ_NEW ix1
mkdir sub && print -r -- 'version = 1' > config.txt && print -r -- 'version = 1' > sub/config.txt
print -l '#!/bin/sh' 'echo ran-tool' > sub/tool.sh && chmod +x sub/tool.sh
git add . && git commit -qm "IX1 base"
cd sub
_ST_RUN --exec -- sh -c 'print_it () { printf "%s|%s\n" "$GIT_PREFIX" "${PWD##*/}" > "$1"; }; print_it "$0" && echo "version = 2" > config.txt && git commit -qam "IX1 bump"' "$TMP/ix1-where"
cd ..
_ST_EQ "an --exec command from a subdirectory changes the file it names there" \
	"$RC:$(git show HEAD:sub/config.txt):$(git show HEAD:config.txt)" "0:version = 2:version = 1"
_ST_EQ "running in that directory, GIT_PREFIX naming it as git does for an alias" "$(<"$TMP/ix1-where")" "sub/|sub"
_ST_RUN --exec -- sh -c 'printf "%s|%s\n" "$GIT_PREFIX" "$(git rev-parse --show-prefix)" > "$0"' "$TMP/ix1-top"
_ST_EQ "from the top it runs at the top, GIT_PREFIX empty" "$RC:$(<"$TMP/ix1-top")" "0:|"
cd sub
_ST_RUN --exec -- ./tool.sh
cd ..
_ST_EQ "a committed program named relative to the subdirectory runs" "$RC" "0"
_ST_OUT_HAS "as its output shows" 'ran-tool'
# A directory the tip lacks runs the command at the top, said so, `GIT_PREFIX` still naming it
mkdir -p newdir && cd newdir
_ST_RUN --exec -- sh -c 'printf "%s|%s\n" "$GIT_PREFIX" "$(git rev-parse --show-prefix)" > "$0"' "$TMP/ix1-new"
cd ..
_ST_EQ "a directory the tip lacks runs it at the top" "$RC:$(<"$TMP/ix1-new")" "0:newdir/|"
_ST_OUT_HAS "and says so" 'the tip has no newdir/ – the command runs at the worktree.s top'
# A program only the checkout holds refuses before it runs, naming the absolute path – once, a bare 127
IX_T=$(git rev-parse HEAD)
print -l '#!/bin/sh' 'echo ran-fix' > sub/fix.sh && chmod +x sub/fix.sh
cd sub
_ST_RUN --exec -- ./fix.sh arg1
cd ..
_ST_EQ "a relative program the tip lacks refuses" "$RC:$(git rev-parse HEAD)" "1:$IX_T"
_ST_OUT_HAS "naming why" '--exec ./fix.sh: not at the tip – the command runs in a fresh worktree of it'
_ST_OUT_HAS "and the absolute path to run instead, arguments kept" 'git edit --exec -- .*/sub/fix\.sh arg1'

# A patch applies as cut – once, `apply.whitespace=fix` stripped its trailing blanks and `error`
# refused it as not applying, and `apply.ignoreWhitespace` matched context it lacks
_ST_PZ_NEW ix2
print -l "line "{1..5} > f.txt && git add f.txt && git commit -qm "IX2 base"
print -l "line 1" "line 2   " "line "{3..5} > f.txt && git diff > "$TMP/ix2-ws.patch" && git checkout -q -- f.txt
git config apply.whitespace fix
_ST_RUN --commit --text "IX2 ws" --patch "$TMP/ix2-ws.patch"
_ST_EQ "a patch under apply.whitespace=fix keeps its trailing blanks" "$RC:$(git show HEAD:f.txt | sed -n 2p)" "0:line 2   "
git config apply.whitespace error
print -r -- "x  " >> f.txt && git diff > "$TMP/ix2-ws2.patch" && git checkout -q -- f.txt
_ST_RUN --commit --text "IX2 ws2" --patch "$TMP/ix2-ws2.patch"
_ST_EQ "and under apply.whitespace=error applies all the same" "$RC:$(git show HEAD:f.txt | tail -1)" "0:x  "
git config --unset apply.whitespace
git config apply.ignoreWhitespace change
print -r -- "y" >> f.txt && git diff > "$TMP/ix2-ws3.patch" && git checkout -q -- f.txt
sed 's/^ line 1$/ line   1/' "$TMP/ix2-ws3.patch" > "$TMP/ix2-ws3b.patch"
IX_T=$(git rev-parse HEAD)
_ST_RUN --commit --text "IX2 ws3" --patch "$TMP/ix2-ws3b.patch"
_ST_EQ "context it lacks refuses under apply.ignoreWhitespace=change" "$RC:$(git rev-parse HEAD)" "1:$IX_T"
_ST_OUT_HAS "as not applying" 'does not apply to the tip'
_ST_RUN --commit --text "IX2 ws3" --patch "$TMP/ix2-ws3.patch"
_ST_EQ "while the patch as cut applies" "$RC:$(git show HEAD:f.txt | tail -1)" "0:y"
git config --unset apply.ignoreWhitespace

# A staged fold taking back a landing names the carry into the checkout and the re-stage, which
# then land – once, only "stage those files again from content that holds it"
_ST_PZ_NEW ix3
print -l "line "{1..20} > f.txt && git add f.txt && git commit -qm "IX3 base"
_ST_PZ_C h.txt h "IX3 h" && IX_T=$(git rev-parse HEAD)
_IX_PEER_LANDS ix3-feat "IX3 B" f.txt "line "{1..14} "line 15 B" "line "{16..20}
print -l "line 1" "line 2 A" "line "{3..20} > f.txt && git add f.txt
GIT_EDIT_ACTOR=ix-self _ST_RUN --amend-into="$IX_T" -- f.txt
_ST_EQ "a staged fold taking back a landing refuses" "$RC" "1"
_ST_OUT_HAS "naming the carry into the checkout" "merge that into the checkout with 'git edit --carry=[0-9a-f]\{12\}'"
_ST_OUT_HAS "and the re-stage" 'Then stage them again with: git add -- f\.txt'
IX_C=$(grep -o -e '--carry=[0-9a-f]*' <<<"$OUT" | head -1)
GIT_EDIT_ACTOR=ix-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" "$IX_C" </dev/null >/dev/null 2>&1
git add f.txt
GIT_EDIT_ACTOR=ix-self _ST_RUN --amend-into="$IX_T" -- f.txt
_ST_EQ "followed as printed, the fold lands keeping what landed" \
	"$RC:$(git show HEAD~1:f.txt | sed -n 2p):$(git show HEAD:f.txt | sed -n 15p)" "0:line 2 A:line 15 B"
# Each of two bits taken back names its own command – once, the second took the first line as its `cd`
_ST_PZ_NEW ix3b
print -r -- a > a.sh && print -r -- b > b.sh && chmod +x b.sh && git add . && git commit -qm "IX3B base"
git branch ix3b-feat && git worktree add -q "$TMP/ix3b-wt" ix3b-feat
chmod +x "$TMP/ix3b-wt/a.sh" && chmod -x "$TMP/ix3b-wt/b.sh" && git -C "$TMP/ix3b-wt" commit -qam "IX3B flips"
GIT_EDIT_ACTOR=ix-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --land=ix3b-feat </dev/null >/dev/null 2>&1
chmod -x a.sh && chmod +x b.sh && print -r -- a2 > a.sh && print -r -- b2 > b.sh
GIT_EDIT_ACTOR=ix-self _ST_RUN --commit --text "IX3B self" --allow-mode-change -- a.sh b.sh
_ST_OUT_HAS "the first bit named" '^  Take the bit that landed with: chmod -- +x a\.sh$'
_ST_OUT_HAS "and the second as its own command" '^  Take the bit that landed with: chmod -- -x b\.sh$'

# An edit of a path the tip lacks names the commit that renamed or removed it, or the key read from
# where the caller stands – once, always "--put it if it is new", which the put's refusal answered
# with "replay your change with --edits"
_ST_PZ_NEW ix4
print -l "line "{1..20} > f.txt && mkdir sub && print -l "line "{1..3} > sub/s.txt && print -r -- r > r.txt
git add . && git commit -qm "IX4 base"
git branch ix4-feat && git worktree add -q "$TMP/ix4-wt" ix4-feat
git -C "$TMP/ix4-wt" mv f.txt g.txt && git -C "$TMP/ix4-wt" commit -qm "IX4 B renames"
GIT_EDIT_ACTOR=ix-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --land=ix4-feat </dev/null >/dev/null 2>&1
IX_T=$(git rev-parse HEAD)
print -l "line 1" "line 2 A" "line "{3..20} > f.txt
GIT_EDIT_ACTOR=ix-self _ST_RUN --commit --text "IX4 A" --edits '{"f.txt": [["line 2\n", "line 2 A\n"]]}'
_ST_EQ "an edit of a path renamed away refuses" "$RC:$(git rev-parse HEAD)" "1:$IX_T"
_ST_OUT_HAS "naming the commit and the new name" 'f\.txt: not a file at the tip – [0-9a-f]\{7\} (IX4 B renames) renamed it to g\.txt'
_ST_OUT_HAS "and the key to edit it by" 'Edit it under that name, keying the edits g\.txt'
_ST_OUT_LACKS "never pointing at a put" 'put it if it is new'
cp f.txt "$TMP/ix4-put"
GIT_EDIT_ACTOR=ix-self _ST_RUN --commit --text "IX4 A" --put f.txt="$TMP/ix4-put"
_ST_EQ "a put of it refuses" "$RC:$(git rev-parse HEAD)" "1:$IX_T"
_ST_OUT_HAS "naming its new name to replay the change on" 'f\.txt is g\.txt at the tip – replay your change there with --edits on g\.txt'
_ST_OUT_LACKS "never the bare rebuild" 'What you put predates'
GIT_EDIT_ACTOR=ix-self _ST_RUN --commit --text "IX4 A" --edits '{"g.txt": [["line 2\n", "line 2 A\n"]]}'
_ST_EQ "followed, the edit lands on the new name" "$RC:$(git show HEAD:g.txt | sed -n 2p)" "0:line 2 A"
git rm -q r.txt && git commit -qm "IX4 drop r"
_ST_RUN --commit --text "IX4 r" --edits '{"r.txt": [["r", "s"]]}'
_ST_OUT_HAS "a removed path names the commit that removed it" 'r\.txt: not a file at the tip – [0-9a-f]\{7\} (IX4 drop r) removed it'
_ST_OUT_HAS "and how to put it back where meant" "See why with 'git show --stat [0-9a-f]\{12\}' – put the file back only where that is meant, as --put <path>=<file> --base="
cd sub
_ST_RUN --commit --text "IX4 sub" --edits '{"sub/s.txt": [["line 2", "line 2 S"]]}'
_ST_OUT_HAS "a key spelled from the top, given from a subdirectory, is read from there" 'sub/s\.txt: not a file at the tip – paths are read from where you stand, sub/, so it names sub/sub/s\.txt'
_ST_OUT_HAS "naming the key that names the file" 'For sub/s\.txt, key the edits s\.txt'
_ST_RUN --commit --text "IX4 sub" --edits '{"s.txt": [["line 2", "line 2 S"]]}'
cd ..
_ST_EQ "which lands" "$RC:$(git show HEAD:sub/s.txt | sed -n 2p)" "0:line 2 S"

# A moved tip names the inputs, never a --tree the caller never passed – the branch moved by a
# stand-in for git as the inputs are composed
_ST_PZ_NEW ix5
print -l "line "{1..10} > f.txt && print -r -- g > g.txt && git add . && git commit -qm "IX5 base"
IX_T=$(git rev-parse HEAD)
_ST_PZ_C g.txt g2 "IX5 second"
IX_REAL=$(whence -p git)
mkdir -p "$TMP/ix5-shim"
printf '#!/bin/sh\ncase " $* " in *"inputs composed on"*) if [ -e "%s/ix5-arm" ]; then rm -f "%s/ix5-arm"; "%s" update-ref refs/heads/main "$("%s" commit-tree -p HEAD -m "IX5 peer" "HEAD^{tree}")"; fi ;; esac\nexec "%s" "$@"\n' \
	"$TMP" "$TMP" "$IX_REAL" "$IX_REAL" "$IX_REAL" > "$TMP/ix5-shim/git"
chmod +x "$TMP/ix5-shim/git"
: > "$TMP/ix5-arm"
PATH="$TMP/ix5-shim:$PATH" _ST_RUN --amend-into="$IX_T" --edits '{"f.txt": [["line 3\n", "line 3 A\n"]]}'
_ST_EQ "a fold of inputs whose tip moved meanwhile refuses" "$RC:$(git log -1 --format=%s)" "1:IX5 peer"
_ST_OUT_HAS "naming the inputs" 'The inputs were composed on [0-9a-f]\{7\}, but the branch moved to [0-9a-f]\{7\} since – nothing was applied'
_ST_OUT_LACKS "never a --tree" '--tree [0-9a-f]'
_ST_RUN --amend-into="$IX_T" --edits '{"f.txt": [["line 3\n", "line 3 A\n"]]}'
_ST_EQ "run again, it lands" "$RC:$(git show HEAD~2:f.txt | sed -n 3p)" "0:line 3 A"

# A removal taking back a landing names what landed alone, a put its rebuild – once, a removal
# was told "What you put predates what landed"
_ST_PZ_NEW ix6
print -l "line "{1..10} > f.txt && print -l "line "{1..10} > p.txt && git add . && git commit -qm "IX6 base"
_IX_PEER_LANDS ix6-feat "IX6 B" f.txt "line "{1..3} "line 4 B" "line "{5..10}
IX_T=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=ix-self _ST_RUN --commit --text "IX6 rm" --rm f.txt
_ST_EQ "a removal taking back a landing refuses" "$RC:$(git rev-parse HEAD)" "1:$IX_T"
_ST_OUT_HAS "naming what landed to look at" 'Look at what landed on f\.txt first – keep the file, or remove it with --base as below'
_ST_OUT_LACKS "never a put's remedy" 'What you put predates'
cp f.txt "$TMP/ix6-put"
GIT_EDIT_ACTOR=ix-self _ST_RUN --commit --text "IX6 put" --put f.txt="$TMP/ix6-put"
_ST_OUT_HAS "while a stale put names its rebuild from the tip" "What you put predates what landed – rebuild it from the tip, .*: f\.txt (the tip's copy: git show [0-9a-f]\{12\}:<path>)"

# `--commit` beside `-C` names `-C`, and only the `--amend-into` mix-up names the fold of whole files
_ST_PZ_NEW ix7
_ST_PZ_C f.txt a "IX7 base" && IX_T=$(git rev-parse HEAD)
print -r -- b > n.txt && git add n.txt && git commit -qm "IX7 add n"
print -r -- c > f.txt
_ST_RUN --commit -C --text "IX7" -- f.txt
_ST_OUT_HAS "--commit beside -C names -C" 'Option --commit cannot be combined with -C – it commits on the checked-out branch.s tip'
_ST_OUT_LACKS "never the fold of whole files" 'amend-into=<sha> --whole'
_ST_RUN --commit --amend-into="$IX_T" --text "IX7" -- f.txt
_ST_OUT_HAS "while beside --amend-into it does" 'folding whole files into a past commit takes --amend-into=<sha> --whole'
git checkout -q -- f.txt
# A removal folded below the commit adding its path refuses as bringing nothing about, no override
# offered – once, named an add/add conflict with --allow-new-path to override
_ST_RUN --amend-into="$IX_T" --rm n.txt
_ST_EQ "a removal below the commit adding its path refuses" "$RC:$(git log -1 --format=%s)" "1:IX7 add n"
_ST_OUT_HAS "as the later add brings it back" 'Removed path(s) absent at [0-9a-f]\{7\} – the commit that adds them comes later and brings them back'
_ST_OUT_LACKS "offering no override" 'allow-new-path'
print -r -- m > m.txt && git add m.txt && git commit -qm "IX7 add m" && print -r -- m2 > m.txt && git add m.txt
_ST_RUN --amend-into="$IX_T" -- m.txt
_ST_OUT_HAS "while a staged path below its add still offers one" 'or pass --allow-new-path to override\.'
git rm -q n.txt
_ST_RUN --amend-into="$IX_T" -- m.txt n.txt
_ST_OUT_HAS "a removal beside it is listed with it" 'n\.txt – arrives in [0-9a-f]\{7\} (IX7 add n), bringing back what the fold removes'
_ST_OUT_HAS "the override named for the added ones alone" 'override for the added ones, folding the removals apart'
git reset -q -- m.txt n.txt && git checkout -q -- m.txt n.txt
cd "$TMP/repo"
