# A flagged file's hidden edits stay out of its index entry, as an unflagged file's do – every flag
# kept, assume-unchanged and skip-worktree alike:
# • A carry merges hidden edits onto what landed, the entry left on that, the edits unstaged
# • A file staged whole before it was flagged is staged merged, as an unflagged one is
# • A sync leaves staged and hidden edits both as they were, named, nothing staged
_ST_SCENARIO "\e[1;96m[238] flagged files' hidden edits stay out of their entries\e[0m"
local FH_FLAG FH_TAG FH_BASE FH_SIX=$'1\n2\n3\n4\n5\n6'
for FH_FLAG in assume-unchanged skip-worktree; do
	FH_TAG=h
	[ "$FH_FLAG" = skip-worktree ] && FH_TAG=S
	# A peer's landing brings the checkout along, which held edits on the old content then
	_ST_PZ_NEW "fh-$FH_FLAG"
	_ST_PZ_C f.txt "$FH_SIX" "FH base"
	FH_BASE=$(git rev-parse HEAD)
	print -r -- $'1\nB\n3\n4\n5\n6' > f.txt
	GIT_EDIT_ACTOR=fh-peer _ST_RUN --commit --text "FH peer" -- f.txt
	print -r -- $'1\n2\n3\n4\nE\n6' > f.txt
	git update-index --$FH_FLAG f.txt
	_ST_RUN --carry="$FH_BASE"
	_ST_EQ "$FH_FLAG: a carry merges hidden edits onto what landed" "${RC}:$(tr '\n' ' ' < f.txt)" "0:1 B 3 4 E 6 "
	_ST_EQ "$FH_FLAG: its entry left on what landed, its flag kept" \
		"$(git rev-parse :f.txt):$(git ls-files -v f.txt)" "$(git rev-parse HEAD:f.txt):$FH_TAG f.txt"
	git update-index --no-$FH_FLAG f.txt
	_ST_EQ "$FH_FLAG: the edits unstaged once unflagged" "$(git status --short f.txt)" " M f.txt"
	# The same edits staged whole before the flag
	_ST_PZ_NEW "fh-$FH_FLAG-staged"
	_ST_PZ_C f.txt "$FH_SIX" "FH base"
	FH_BASE=$(git rev-parse HEAD)
	print -r -- $'1\nB\n3\n4\n5\n6' > f.txt
	GIT_EDIT_ACTOR=fh-peer _ST_RUN --commit --text "FH peer" -- f.txt
	print -r -- $'1\n2\n3\n4\nE\n6' > f.txt
	git add f.txt && git update-index --$FH_FLAG f.txt
	_ST_RUN --carry="$FH_BASE"
	_ST_EQ "$FH_FLAG: a file staged whole merges onto what landed, its flag kept" \
		"${RC}:$(tr '\n' ' ' < f.txt):$(git ls-files -v f.txt)" "0:1 B 3 4 E 6 :$FH_TAG f.txt"
	_ST_EQ "$FH_FLAG: its entry the merged file, as staged before" "$(git cat-file -p :f.txt | tr '\n' ' ')" "1 B 3 4 E 6 "
	# A sync over staged edits with more hidden past them
	_ST_PZ_NEW "fh-$FH_FLAG-sync"
	_ST_PZ_C f.txt "$FH_SIX" "FH base" && _ST_PZ_C f.txt $'1\nB\n3\n4\n5\n6' "FH change" && _ST_PZ_C t.txt t "FH tip"
	print -r -- $'1\nB\n3\n4\nE\n6' > f.txt
	git add f.txt
	print -r -- $'1\nB\n3\n4\nE\nF' > f.txt
	git update-index --$FH_FLAG f.txt
	_ST_RUN -d -y HEAD~1
	_ST_EQ "$FH_FLAG: a sync leaves staged and hidden edits both as they were, its flag kept" \
		"${RC}:$(git log -1 --format=%s HEAD~1):$(tr '\n' ' ' < f.txt):$(git ls-files -v f.txt)" "0:FH base:1 B 3 4 E F :$FH_TAG f.txt"
	_ST_EQ "$FH_FLAG: its entry as staged" "$(git cat-file -p :f.txt | tr '\n' ' ')" "1 B 3 4 E 6 "
	_ST_OUT_HAS "$FH_FLAG: named as an unflagged one is" 'f\.txt – staged and unstaged edits both'
done
