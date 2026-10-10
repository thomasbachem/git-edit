# The landings guard reads what a landing became, and its remedies hold:
# • A landing whose lines a later one rewrote is judged with every later one on the file, so a stale
#   file predating both refuses, naming the carry from its old tip – a fresh file, a hand-made edit
#   on the line, and the caller's own later landing taken back alone, still land
# • An input on a small file a peer added is meant, never "your own file" – a whole file still is
# • A file whose sync record matches the landing names the record's merge, never the carry that
#   conflicts as the sync did
# • A fold judges only the landings at or below its target – the replay applies those above again
# • `--base` compares a path's mode too
# • A staged fold's carry says it stages a file staged whole again, with no `git add` after it
# • `-h` says every landing brings the checkout along
# • `--onto` on a branch with nothing past its fork moves it to the upstream – a fast-forward, or
#   past the rewrite of what it held
_ST_SCENARIO "\e[1;96m[217] the guard reads later landings and folds, a replant behind its upstream moves\e[0m"
local GL_T GL_B GL_X

# A peer's landing of line 2, then a second one rewriting it by <actor>
_GL217_TWO () {
	# Args: <repo name> <actor of the second landing>
	_ST_PZ_NEW "$1"
	print -l 1 2 3 4 5 6 7 8 > f.txt && print g > g.txt && git add -A && git commit -qm "GL base"
	GL_B=$(git rev-parse HEAD)
	GIT_EDIT_ACTOR=gl-a _ST_RUN --commit --text "GL A line 2" --edits '{"f.txt": [["2\n", "2A\n"]]}'
	GIT_EDIT_ACTOR=$2 _ST_RUN --commit --text "GL second" --edits '{"f.txt": [["2A\n", "2C\n"]]}'
	GL_T=$(git rev-parse HEAD)
}

# V2-1: a stale buffer predating both landings
_GL217_TWO gl1 gl-c
print -l 1 2 3 4 5 6 7B 8 > f.txt
GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL1 B whole" -- f.txt
_ST_EQ "a stale file predating two landings on one line refuses" "$RC:$(git rev-parse HEAD)" "1:$GL_T"
_ST_OUT_HAS "naming the first as changed again since" "gl-a's commit run .* ago (${GL_B:0:7}\.\.[0-9a-f]*), changed again since"
_ST_OUT_HAS "and the carry from its old tip" "git edit --carry=${GL_B:0:12}"
GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL1 B edits" --edits '{"f.txt": [["2C\n", "2\n"], ["7\n", "7B\n"]]}'
_ST_EQ "as do edits cut from it" "$RC:$(git rev-parse HEAD)" "1:$GL_T"
git diff HEAD -- f.txt > "$TMP/gl1.patch"
GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL1 B patch" --patch "$TMP/gl1.patch"
_ST_EQ "and a patch" "$RC:$(git rev-parse HEAD)" "1:$GL_T"
GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL1 B reword" --edits '{"f.txt": [["2C\n", "2X\n"]]}'
_ST_EQ "while a hand-made edit on the line lands" "$RC:$(git show HEAD:f.txt | sed -n 2p)" "0:2X"
print -l 1 2X 3 4 5 6 7B 8 > f.txt
GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL1 B fresh" -- f.txt
_ST_EQ "as does a fresh file taken whole" "$RC:$(git show HEAD:f.txt | sed -n 7p)" "0:7B"
# The caller's own second landing: a stale file still refuses, its own landing undone alone lands
_GL217_TWO gl1o gl-b
print -l 1 2 3 4 5 6 7B 8 > f.txt
GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL1o B whole" -- f.txt
_ST_EQ "a stale file predating a peer's landing and the caller's own refuses" "$RC:$(git rev-parse HEAD)" "1:$GL_T"
print -l 1 2A 3 4 5 6 7B 8 > f.txt
GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL1o B own undone" -- f.txt
_ST_EQ "while one taking back only the caller's own landing lands" "$RC:$(git show HEAD:f.txt | sed -n 2p)" "0:2A"

# V2-3: an input on a small file a peer added is meant
_ST_PZ_NEW gl3
print g > g.txt && git add -A && git commit -qm "GL3 base"
print 1.0 > VERSION
GIT_EDIT_ACTOR=gl-a _ST_RUN --commit --text "GL3 A adds VERSION" -- VERSION
GL_T=$(git rev-parse HEAD)
print 1.1 > VERSION
GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL3 B whole" -- VERSION
_ST_EQ "a whole file in place of one a peer added refuses" "$RC:$(git rev-parse HEAD)" "1:$GL_T"
_ST_OUT_HAS "as the caller's own" 'Your own VERSION stands where another caller added one'
GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL3 B bump" --edits '{"VERSION": [["1.0\n", "1.1\n"]]}'
_ST_EQ "while an edit of it lands" "$RC:$(git show HEAD:VERSION)" "0:1.1"
_ST_OUT_LACKS "never read as the caller's own file" 'Your own VERSION'

# V2-4: a recorded file whose edits sit beside the landing names the record's merge
_ST_PZ_NEW gl4
print -l 1 2 3 4 5 6 > f.txt && git add -A && git commit -qm "GL4 base"
GL_B=$(git rev-parse HEAD)
print -l 1 2 3-final 4 5 6-final > f.txt
touch -t 202601010000 f.txt
GIT_EDIT_ACTOR=gl-a _ST_RUN --commit --text "GL4 A line 5" --edits '{"f.txt": [["5\n", "5A\n"]]}'
GL_T=$(git rev-parse HEAD)
_ST_EQ "the landing's sync leaves the file recorded" "$RC:$(cut -f2 .git/git-edit-unbrought 2>/dev/null)" "0:f.txt"
GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL4 B whole" -- f.txt
_ST_EQ "the file taken whole refuses" "$RC:$(git rev-parse HEAD)" "1:$GL_T"
_ST_OUT_HAS "naming the record's merge" "git cat-file --filters ${GL_B:0:12}:f.txt > \"\$T/base\" && git cat-file --filters ${GL_T:0:12}:f.txt > \"\$T/landed\" && git merge-file -- f.txt"
_ST_OUT_LACKS "never the carry, which conflicts as the sync did" 'git edit --carry='

# V2-5: a fold below a peer's landing lands, the replay keeping it, one above refuses
for GL_X in below above; do
	_ST_PZ_NEW gl5-$GL_X
	print -l 1 2 3 4 5 6 7 8 > f.txt && print g > g.txt && git add -A && git commit -qm "GL5 base"
	[ $GL_X = below ] && { GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL5 B own" --edits '{"f.txt": [["7\n", "7B\n"]]}'; GL_B=$(git rev-parse HEAD); }
	GIT_EDIT_ACTOR=gl-a _ST_RUN --commit --text "GL5 A line 2" --edits '{"f.txt": [["2\n", "2A\n"]]}'
	[ $GL_X = above ] && { GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL5 B own" --edits '{"f.txt": [["7\n", "7B\n"]]}'; GL_B=$(git rev-parse HEAD); }
	GL_T=$(git rev-parse HEAD)
	print -l 1 2 3 4 5 6B 7B 8 > f.txt && git add f.txt
	GIT_EDIT_ACTOR=gl-b _ST_RUN --amend-into="$GL_B"
	if [ $GL_X = below ]; then
		_ST_EQ "a staged fold into a commit below a peer's landing lands, keeping it" "$RC:$(git show HEAD:f.txt | tr '\n' ' ')" "0:1 2A 3 4 5 6B 7B 8 "
		GL_B=$(git rev-parse HEAD~1)
		GIT_EDIT_ACTOR=gl-b _ST_RUN --amend-into="$GL_B" --edits '{"f.txt": [["2A\n", "2\n"], ["5\n", "5B\n"]]}'
		_ST_EQ "as do a fold's edits cut from a stale file" "$RC:$(git show HEAD:f.txt | tr '\n' ' ')" "0:1 2A 3 4 5B 6B 7B 8 "
	else
		_ST_EQ "one into a commit above it refuses" "$RC:$(git rev-parse HEAD)" "1:$GL_T"
		_ST_OUT_HAS "naming the landing" "gl-a's commit run"
	fi
done

# V2-6: --base compares a path's mode
_ST_PZ_NEW gl6
print -l 1 2 > f.txt && print g > g.txt && git add -A && git commit -qm "GL6 base"
GL_B=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=gl-a _ST_RUN --commit --text "GL6 A +x" --chmod f.txt=+x
GL_T=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL6 B -x" --chmod f.txt=-x --base="$GL_B"
_ST_EQ "a bit set since --base refuses" "$RC:$(git rev-parse HEAD)" "1:$GL_T"
_ST_OUT_HAS "naming the path" 'Changed between --base .* would take that back: f\.txt'
GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL6 B g +x" --chmod g.txt=+x --base="$GL_B"
_ST_EQ "while one on a path left alone lands" "$RC:$(git ls-tree HEAD g.txt | cut -c1-6)" "0:100755"

# V2-7: a staged fold's carry stages again what was staged whole
for GL_X in same more; do
	_ST_PZ_NEW gl7-$GL_X
	print -l 1 2 3 4 5 6 7 8 > f.txt && print g > g.txt && git add -A && git commit -qm "GL7 base"
	GIT_EDIT_ACTOR=gl-a _ST_RUN --commit --text "GL7 A line 2" --edits '{"f.txt": [["2\n", "2A\n"]]}'
	GIT_EDIT_ACTOR=gl-b _ST_RUN --commit --text "GL7 B own" --edits '{"g.txt": [["g\n", "gB\n"]]}'
	GL_T=$(git rev-parse HEAD)
	print -l 1 2 3 4 5 6 7B 8 > f.txt && git add f.txt
	[ $GL_X = more ] && print -l 1 2 3 4 5 6 7B 8 9 > f.txt
	touch -t 202601010000 f.txt
	GIT_EDIT_ACTOR=gl-b _ST_RUN --amend-into="$GL_T"
	_ST_EQ "a stale staged fold above a landing refuses ($GL_X)" "$RC:$(git rev-parse HEAD)" "1:$GL_T"
	if [ $GL_X = same ]; then
		_ST_OUT_HAS "saying the carry stages the file again" "which stages each file again as merged, as you staged it whole\.$"
		_ST_OUT_LACKS "with no git add to follow" 'git add -- f\.txt'
		GL_X=$(print -r -- "$OUT" | grep -oE 'git edit --carry=[0-9a-f]+' | head -1)
		GIT_EDIT_ACTOR=gl-b _ST_RUN ${GL_X#git edit }
		_ST_EQ "and the carry does" "$RC:$(git show :f.txt | tr '\n' ' ')" "0:1 2A 3 4 5 6 7B 8 "
		GIT_EDIT_ACTOR=gl-b _ST_RUN --amend-into="$GL_T"
		_ST_EQ "so the fold lands next" "$RC:$(git show HEAD:f.txt | tr '\n' ' ')" "0:1 2A 3 4 5 6 7B 8 "
	else
		_ST_OUT_HAS "while one holding more says it leaves the staging" "which leaves the staging as it is\.$"
		_ST_OUT_HAS "naming the staging's rebuild" 'Then rebuild the staging of f\.txt alone'
	fi
done

# V3-1: `-h` says every landing brings the checkout along
_ST_RUN -h
_ST_OUT_HAS "-h says every landing brings the checkout along" 'every run that lands brings the'
_ST_OUT_LACKS "never that one elsewhere leaves it" 'checkout is left as it was, with the hints'

# V3-2: a replant with nothing past the fork fast-forwards to the upstream
_ST_PZ_NEW gl9
print a > a.txt && git add -A && git commit -qm "GL9 base"
git branch side
print b > b.txt && git add -A && git commit -qm "GL9 main ahead"
GL_T=$(git rev-parse HEAD)
git checkout -q side
GL_B=$(git rev-parse HEAD)
GIT_EDIT_ACTOR=gl-s _ST_RUN --onto=main
_ST_EQ "--onto with nothing past the fork moves the branch to the upstream" "$RC:$(git rev-parse side):$(<b.txt)" "0:$GL_T:b"
_ST_OUT_HAS "saying so" "Branch 'side' carries no commits past the fork – fast-forwarded by 1 commit(s) to main"
_ST_OUT_HAS "the trailer naming the move" 'git-edit: ok – refs/heads/side moved'
GIT_EDIT_ACTOR=gl-s _ST_RUN --onto=main
_ST_EQ "one already there ends unchanged" "$RC:$(git rev-parse side)" "0:$GL_T"
_ST_OUT_HAS "saying it is there already" 'Already at main – nothing to replay\.$'
GIT_EDIT_ACTOR=gl-s _ST_RUN --undo
_ST_EQ "and --undo takes the move back, the checkout with it" "$RC:$(git rev-parse side):$([ -e b.txt ] && print kept || print gone)" "0:$GL_B:gone"
GIT_EDIT_ACTOR=gl-s _ST_RUN --onto=side
_ST_EQ "while the branch named as its own upstream still refuses" "$RC:$(git rev-parse side)" "1:$GL_B"
_ST_OUT_HAS "as itself" '--onto target is the branch itself'
# As does one the upstream rewrote under it since, no longer on the upstream's line
_ST_PZ_NEW gl9b
print a > a.txt && git add -A && git commit -qm "GL9b base"
print s > s.txt && git add -A && git commit -qm "GL9b S1"
git branch side
print b > b.txt && git add -A && git commit -qm "GL9b main ahead"
GIT_EDIT_ACTOR=gl-p _ST_RUN -M --text "GL9b S1 reworded" HEAD~1
GL_T=$(git rev-parse HEAD)
git checkout -q side
GIT_EDIT_ACTOR=gl-s _ST_RUN --onto=main
_ST_EQ "--onto on a branch the upstream rewrote, nothing of its own past the fork, moves it there" \
	"$RC:$(git rev-parse side):$(<b.txt)" "0:$GL_T:b"
_ST_OUT_HAS "saying the upstream rewrote what it held" "Branch 'side' carries no commits past the fork – moved to main ([0-9a-f]*), which rewrote the commits it held\.$"
