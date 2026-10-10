# A file committed with CRLF under `eol=lf` reads as modified wherever git wrote it in its index's
# second – a pause there resumes, a first run replays over it, an edit or split takes in no
# renormalization of it, a change left unstaged is named as what refuses the continue, and a
# checkout's sync and its hints read it as the content it holds rather than as the caller's edit
_ST_SCENARIO "\e[1;96m[169] renormalised files block no resume and pass as nobody's edit\e[0m"
local RN_WT RN_CR RN_LF RN_TIP RN_X
# Writes <path> as <printf format> and stages its bytes unfiltered, as a commit made
# before the attribute holds them
_RN_RAW () {
	# Args: <path> <printf format>
	printf "$2" > "$1" && git update-index --add --cacheinfo "100644,$(git hash-object -w --no-filters -- "$1"),$1"
}
# Starts repo <name> with `crlf.txt` committed CRLF, then `.gitattributes` putting
# text files under `eol=lf`, then `f.txt` – every later file staged by name, as
# `commit -a` would renormalize `crlf.txt`
_RN_REPO () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	git config rerere.enabled false
	_RN_RAW crlf.txt 'one\r\ntwo\r\n' && git commit -qm "RN crlf"
	print -r -- '*.txt text eol=lf' > .gitattributes && git add .gitattributes && git commit -qm "RN attrs"
	print -l 1 2 3 4 5 6 7 8 9 > f.txt && git add f.txt && git commit -qm "RN base"
	RN_CR=$(git rev-parse HEAD:crlf.txt)
}
# Commits <path> as <printf format> onto <branch>, its checkout untouched – a checkout of the branch
# would refuse over the CRLF file
_RN_ON () {
	# Args: <branch> <path> <printf format> <subject>
	local IDX=$TMP/rn-on-index B
	rm -f "$IDX"
	B=$(printf "$3" | git hash-object -w --stdin --no-filters) && GIT_INDEX_FILE=$IDX git read-tree "$1" && \
		GIT_INDEX_FILE=$IDX git update-index --add --cacheinfo "100644,$B,$2" && \
		git update-ref "refs/heads/$1" "$(git commit-tree -p "$1" -m "$4" "$(GIT_INDEX_FILE=$IDX git write-tree)")"
}
# Writes `f.txt` as the given lines and commits it by name
_RN_F () {
	# Args: <subject> <line>...
	print -l "${@:2}" > f.txt && git add f.txt && git commit -qm "$1"
}

# A drop's pause resumes, its worktree naming only the conflict – once, `git rebase --continue`
# refused over the CRLF file forever, and the refusal read "staged changes remain"
_RN_REPO rn1
_RN_F "RN1 Y" 1 2 DEBUG 3 4 5 6 7 8 9
_RN_F "RN1 Z" 1 2 DEBUG 3z 4 5 6 7 8 9
_ST_PZ_C t.txt top "RN1 top"
_ST_RUN -d -y HEAD~2
RN_WT=$(_ST_PZ_WT)
_ST_EQ "a drop's conflict pause names only the conflicted file" "$RC:$(git -C "${RN_WT:-$ST_NO_WT}" status --porcelain | tr '\n' ' ')" "2:UU f.txt "
_ST_RESOLVE "${RN_WT:-$ST_NO_WT}" f.txt "$(print -l 1 2 3z 4 5 6 7 8 9)"
_ST_RUN --continue
_ST_EQ "and resumes, the CRLF file landing as committed" "$RC:$(git log -1 --format=%s HEAD~1):$(git rev-parse HEAD:crlf.txt)" "0:RN1 Z:$RN_CR"

# A change left unstaged is named as what refuses the continue, with the commands that clear it
_RN_REPO rn2
_RN_F "RN2 Y" 1 2 DEBUG 3 4 5 6 7 8 9
_RN_F "RN2 Z" 1 2 DEBUG 3z 4 5 6 7 8 9
_ST_PZ_C t.txt top "RN2 top"
_ST_RUN -d -y HEAD~2
RN_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RN_WT:-$ST_NO_WT}" f.txt "$(print -l 1 2 3z 4 5 6 7 8 9)"
printf 'zzz\r\n' >> "${RN_WT:-$ST_NO_WT}/crlf.txt"
_ST_RUN --continue
_ST_EQ "a change left unstaged refuses the continue" "$RC" "1"
_ST_OUT_HAS "named as what refuses it" 'changes left unstaged in crlf.txt refuse the continue'
_ST_OUT_HAS "with the stage and the restore that clear it" 'restore -- crlf.txt$'
_ST_OUT_LACKS "never as staged changes remaining" 'staged changes remain'
git -C "${RN_WT:-$ST_NO_WT}" restore -- crlf.txt
_ST_RUN --continue
_ST_EQ "while restored, the pause resumes" "$RC:$(git rev-parse HEAD:crlf.txt)" "0:$RN_CR"

# A first run replays commits rewriting the CRLF file – once, git refused to start over it, or to
# write it a second time in the second it was checked out
_RN_REPO rn3
_RN_F "RN3 Y" 1 2 DEBUG 3 4 5 6 7 8 9
_RN_RAW crlf.txt 'one\r\ntwo\r\nthree\r\n' && git commit -qm "RN3 three"
_RN_RAW crlf.txt 'one\r\ntwo\r\nthree\r\nfour\r\n' && git commit -qm "RN3 four"
RN_X=$(git rev-parse HEAD:crlf.txt)
_ST_PZ_C t.txt top "RN3 top"
_ST_RUN -d -y HEAD~3
_ST_EQ "a drop replays the commits rewriting the CRLF file" "$RC:$(git log --format=%s -4 | tr '\n' ' ')" "0:RN3 top RN3 four RN3 three RN base "
_ST_EQ "each blob as committed" "$(git rev-parse HEAD:crlf.txt)" "$RN_X"

# An edit's pause shows no change, and the amend takes in only the caller's
_RN_REPO rn4
_RN_F "RN4 ten" 1 2 3 4 5 6 7 8 9 10
_ST_PZ_C t.txt top "RN4 top"
_ST_RUN -e HEAD~1
RN_WT=$(_ST_PZ_WT)
_ST_EQ "an edit's pause shows no change" "$RC:$(git -C "${RN_WT:-$ST_NO_WT}" status --porcelain | wc -l | tr -d ' ')" "2:0"
print -l 1 2 3 4 5 6 7 8 9 10 11 > "${RN_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
_ST_EQ "and its amend takes in only the caller's change" "$RC:$(git show --name-only --format= HEAD~1 | tr '\n' ' '):$(git rev-parse HEAD:crlf.txt)" "0:f.txt :$RN_CR"
# While one with nothing changed has nothing to amend
_ST_RUN -e HEAD~1
_ST_RUN --continue
_ST_EQ "one with nothing changed amends nothing" "$RC:$(git rev-parse HEAD:crlf.txt)" "1:$RN_CR"
_ST_OUT_HAS "saying so" 'Nothing to amend'
_ST_RUN --abort

# A fold's, a reorder's and a replant's pauses resume
_RN_REPO rn5
_RN_F "RN5 X" 1 2 X 4 5 6 7 8 9
_RN_F "RN5 Y" 1 2 Y 4 5 6 7 8 9
print -l 1 2 Z 4 5 6 7 8 9 > f.txt && git add f.txt
_ST_RUN --amend-into HEAD~1 -- f.txt
RN_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RN_WT:-$ST_NO_WT}" f.txt "$(print -l 1 2 Z 4 5 6 7 8 9)"
printf 'zzz\r\n' >> "${RN_WT:-$ST_NO_WT}/crlf.txt"
_ST_RUN --continue
_ST_EQ "a fold's resume refused over a change left unstaged pauses on" "$RC" "2"
_ST_OUT_HAS "headed by what refuses it" '^Changes left unstaged refuse the continue'
_ST_OUT_LACKS "never as a conflict continuing" 'Conflict continues'
git -C "${RN_WT:-$ST_NO_WT}" restore -- crlf.txt
_ST_RUN --continue
_ST_EQ "a fold's pause resumes, to its next stop" "$RC:$(git -C "${RN_WT:-$ST_NO_WT}" status --porcelain | tr '\n' ' ')" "2:UU f.txt "
_ST_RESOLVE "${RN_WT:-$ST_NO_WT}" f.txt "$(print -l 1 2 Y 4 5 6 7 8 9)"
_ST_RUN --continue
_ST_EQ "and on to its landing" "$RC:$(git rev-parse HEAD~1:f.txt HEAD:crlf.txt | tr '\n' ' ')" "0:$(print -l 1 2 Z 4 5 6 7 8 9 | git hash-object --stdin) $RN_CR "
_RN_REPO rn6
_RN_F "RN6 X" 1 2 X 4 5 6 7 8 9
_RN_F "RN6 Y" 1 2 X Y 5 6 7 8 9
_ST_RUN --reorder HEAD HEAD~1
RN_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RN_WT:-$ST_NO_WT}" f.txt "$(print -l 1 2 3 Y 5 6 7 8 9)"
_ST_RUN --continue
_ST_EQ "a reorder's pause resumes" "$RC:$(git log --format=%s -2 | tr '\n' ' '):$(git rev-parse HEAD:crlf.txt)" "0:RN6 X RN6 Y :$RN_CR"
_RN_REPO rn7
git branch rn7-up
_RN_F "RN7 F" 1 2 F 4 5 6 7 8 9
git checkout -q rn7-up
_RN_F "RN7 U" 1 2 U 4 5 6 7 8 9
git checkout -q main
_ST_RUN --onto rn7-up
RN_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${RN_WT:-$ST_NO_WT}" f.txt "$(print -l 1 2 F 4 5 6 7 8 9)"
_ST_RUN --continue
_ST_EQ "a replant's pause resumes" "$RC:$(git log --format=%s -2 | tr '\n' ' '):$(git rev-parse HEAD:crlf.txt)" "0:RN7 F RN7 U :$RN_CR"
# One over an upstream rewriting the CRLF file lands, its checkout brought along as any landing's,
# the file holding no edits taking what landed
_RN_REPO rn7b
git branch rn7b-up
_RN_F "RN7b F" 1 2 F 4 5 6 7 8 9
_RN_ON rn7b-up crlf.txt 'one\r\ntwo\r\nup\r\n' "RN7b U"
RN_X=$(git rev-parse rn7b-up:crlf.txt)
# Its stat made other than the index's, so git reads it again – one the index took a second or more
# after it was written, as under load, git trusts as clean, letting the update through
touch -m -t 200001010000 crlf.txt
_ST_RUN --onto rn7b-up
_ST_EQ "a replant over an upstream rewriting the CRLF file lands" "$RC:$(git log --format=%s -2 | tr '\n' ' ')" "0:RN7b F RN7b U "
_ST_EQ "its checkout brought along" "$(git rev-parse :crlf.txt)" "$RN_X"
_ST_OUT_HAS "naming the file" "now as they landed: crlf.txt"

# A split takes no renormalisation for a change of the caller's
_RN_REPO rn8
print -l 1 2 3 4 5 6 7 8 9 A > f.txt && print -r -- g > g.txt && git add f.txt g.txt && git commit -qm "RN8 AG"
_ST_RUN --split HEAD
RN_WT=$(_ST_PZ_WT)
git -C "${RN_WT:-$ST_NO_WT}" checkout HEAD~1 -- f.txt
_ST_RUN --continue --text "RN8 G"
_ST_EQ "a split's first commit takes only what the caller left" "$RC:$(git show --name-only --format= HEAD~1 | tr '\n' ' '):$(git rev-parse HEAD:crlf.txt)" "0:g.txt :$RN_CR"

# A rewrite that can't bring the checkout along reads a checkout file byte for byte a tip's blob as
# that tip's content – the new one's as nothing to reconcile, the old one's as stale, never as edits
_RN_REPO rn9
_RN_RAW crlf.txt 'one\ntwo\n' && print -l 1 2 Y 4 5 6 7 8 9 > f.txt && git add f.txt && git commit -qm "RN9 renormalise"
_ST_PZ_C t.txt top "RN9 top"
printf 'one\r\ntwo\r\n' > crlf.txt
_ST_RUN_UNSYNCED -d -y HEAD~1
_ST_EQ "a drop taking a renormalisation back lands" "$RC:$(git rev-parse HEAD:crlf.txt)" "0:$RN_CR"
_ST_OUT_HAS "naming the dropped file still in the checkout" '^  f\.txt$'
_ST_OUT_LACKS "never the one holding the landed content" '^  crlf\.txt$'
_RN_REPO rn9b
_RN_RAW crlf.txt 'one\r\ntwo\r\nthree\r\n' && git commit -qm "RN9b three"
_ST_PZ_C t.txt top "RN9b top"
_ST_RUN_UNSYNCED -d -y HEAD~1
_ST_OUT_HAS "while one holding the dropped content is stale" '^  crlf\.txt$'
_ST_OUT_LACKS "not an edit" 'crlf\.txt.*edit\|edit.*crlf\.txt'
_RN_REPO rn9c
_RN_RAW crlf2.txt 'a\r\nb\r\n' && git commit -qm "RN9c add"
_ST_PZ_C t.txt top "RN9c top"
_ST_RUN_UNSYNCED -d -y HEAD~1
_ST_OUT_HAS "one the drop removes, still as before, is named as left" '^  crlf2\.txt$'
_ST_OUT_LACKS "never as edits" 'crlf2\.txt.*edit'
# A terminal's sync brings it along as a file still as before, a removed one taken out
_RN_REPO rn10
_RN_RAW crlf.txt 'one\r\ntwo\r\nthree\r\n' && git commit -qm "RN10 three"
_ST_PZ_C t.txt top "RN10 top"
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a terminal drop syncs the CRLF file to what landed" "$RC:$(git hash-object --no-filters crlf.txt)" "0:$RN_CR"
_ST_OUT_LACKS "never keeping it as an edit of the caller's" 'Left as they were.*crlf\.txt'
_ST_EQ "its index on the new tip" "$(git rev-parse :crlf.txt)" "$RN_CR"
_RN_REPO rn10c
_RN_RAW crlf2.txt 'a\r\nb\r\n' && git commit -qm "RN10c add"
_ST_PZ_C t.txt top "RN10c top"
_ST_TTY -- -d -y HEAD~1
_ST_EQ "one the terminal drop removes goes, as a file still as before" "$RC:$([ -e crlf2.txt ] && echo kept)" "0:"
_ST_OUT_LACKS "never kept as edits" 'your edits to them stay'
# While a real edit there is still the caller's
_RN_REPO rn10b
_RN_RAW crlf.txt 'one\r\ntwo\r\nthree\r\n' && git commit -qm "RN10b three"
_ST_PZ_C t.txt top "RN10b top"
printf 'one\r\ntwo\r\nthree\r\nmine\r\n' > crlf.txt
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a real edit there stays the caller's" "$RC:$(tail -1 crlf.txt)" $'0:mine\r'
cd "$TMP/repo"
