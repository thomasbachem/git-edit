# A fold that replaces lines resolves its replay's stops as an `--edits` fold does, each hunk
# its old lines to its new ones – taken whole, staged, `--patch`, `--put` or `--tree` alike:
# • A file it inserts a line in, or a commit holding a replaced line twice or in a longer one, stops
# • A resume goes on so, bar a file a stop resolved by hand otherwise than the fold makes it
_ST_SCENARIO "\e[1;96m[226] whole and staged folds of replaced lines resolve their stops by replacement\e[0m"
local RL_T RL_O RL_WT
local -a RL_C

# Builds a Markdown file one paragraph a line, a later commit inserting a paragraph right
# after the one the fold edits and another rewording the last – sets `RL_T`, `RL_C` and `RL_O`
_RL_DOC () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	_ST_PZ_C init.txt i "RL init"
	print -l "# Title" "" "First paragraph, one line." "" "Last paragraph, as written." > doc.md && git add doc.md && git commit -qm "RL target"
	RL_T=$(git rev-parse HEAD)
	print -l "# Title" "" "First paragraph, one line." "Inserted paragraph." "" "Last paragraph, as written." > doc.md && git commit -qam "RL c1 inserts"
	RL_C=("$(git rev-parse HEAD)")
	print -l "# Title" "" "First paragraph, one line." "Inserted paragraph." "" "Last paragraph, reworded." > doc.md && git commit -qam "RL c2 rewords"
	RL_C+=("$(git rev-parse HEAD)")
	RL_O=$(git rev-parse HEAD)
}
# Prints <rev>'s `doc.md` on one line
_RL_AT () {
	# Args: <rev>
	git show "$1:doc.md" | tr '\n' '|'
}

# The reported case – one paragraph line edited, folded whole, landing with no pause
_RL_DOC rl1
sed 's/^First paragraph, one line\.$/First paragraph, edited./' doc.md > doc.new && mv doc.new doc.md
_ST_RUN --amend-into="$RL_T" --whole -- doc.md
_ST_EQ "a whole fold replacing a line beside a later insertion lands with no pause" "$RC" "0"
_ST_OUT_HAS "making its replacements at each stop" "Made the fold's line replacements in the 2 commit(s) the replay stopped at"
_ST_EQ "the target holds the edit and nothing later" "$(_RL_AT HEAD~2)" "# Title||First paragraph, edited.||Last paragraph, as written.|"
_ST_EQ "the commit inserting beside it keeps its insertion" "$(_RL_AT HEAD~1)" "# Title||First paragraph, edited.|Inserted paragraph.||Last paragraph, as written.|"
_ST_EQ "the tip holds the edit, the checkout clean" \
	"$(_RL_AT HEAD):$(git status --porcelain -- doc.md)" "# Title||First paragraph, edited.|Inserted paragraph.||Last paragraph, reworded.|:"
_ST_EQ "subjects kept, on the target's own parent" \
	"$(git log --format=%s -n 3 HEAD | tr '\n' '|'):$(git rev-parse HEAD~3)" "RL c2 rewords|RL c1 inserts|RL target|:$(git rev-parse "$RL_T^")"

# The same from the index, the fold's staging re-synced once it lands
_RL_DOC rl2
sed 's/^First paragraph, one line\.$/First paragraph, staged./' doc.md > doc.new && mv doc.new doc.md && git add doc.md
_ST_RUN --amend-into="$RL_T" -- doc.md
_ST_EQ "a staged fold replacing a line beside a later insertion lands with no pause" \
	"$RC:$(_RL_AT HEAD~2):$(_RL_AT HEAD)" \
	"0:# Title||First paragraph, staged.||Last paragraph, as written.|:# Title||First paragraph, staged.|Inserted paragraph.||Last paragraph, reworded.|"
_ST_OUT_HAS "its stops resolved" "Made the fold's line replacements in the 2 commit(s) the replay stopped at"
_ST_EQ "nothing left staged" "$(git diff --cached --name-only)" ""

# A file a later commit renamed takes the edit under each name it had
_ST_PZ_NEW rl2b
_ST_PZ_C init.txt i "RL2b init"
print -l "# Title" "" "First paragraph, one line." "" P2 "" P3 "" P4 "" P5 "" Last > doc.md && git add doc.md && git commit -qm "RL2b target"
RL_T=$(git rev-parse HEAD)
print -l "# Title" "" "First paragraph, one line." "Inserted paragraph." "" P2 "" P3 "" P4 "" P5 "" Last > doc.md && git commit -qam "RL2b c1 inserts"
git mv doc.md guide.md && git commit -qm "RL2b c2 renames"
sed 's/^First paragraph, one line\.$/First paragraph, renamed./' guide.md > doc.new && mv doc.new guide.md && git add guide.md
_ST_RUN --amend-into="$RL_T" -- guide.md
_ST_EQ "a staged fold of a file renamed since lands, edited under both names" \
	"$RC:$(git show HEAD~2:doc.md | sed -n 3p):$(git show HEAD~1:doc.md | sed -n 3,4p | tr '\n' ' '):$(git show HEAD:guide.md | sed -n 3p):$(git diff-tree -r -M --name-status --no-commit-id HEAD | cut -c1)" \
	"0:First paragraph, renamed.:First paragraph, renamed. Inserted paragraph. :First paragraph, renamed.:R"
_ST_OUT_HAS "its stops under the old name resolved" "Made the fold's line replacements in the 2 commit(s) the replay stopped at"

# A last line stored without a line end takes the edit byte for byte, still without one
_ST_PZ_NEW rl3
_ST_PZ_C init.txt i "RL3 init"
printf 'Lead.\n\nLast line.' > end.md && git add end.md && git commit -qm "RL3 target"
RL_T=$(git rev-parse HEAD)
printf 'Lead.\n\nInserted.\nLast line.' > end.md && git commit -qam "RL3 c1 inserts"
printf 'Lead, reworded.\n\nInserted.\nLast line.' > end.md && git commit -qam "RL3 c2 rewords"
printf 'Lead, reworded.\n\nInserted.\nLast line, edited.' > end.md
_ST_RUN --amend-into="$RL_T" --whole -- end.md
_ST_EQ "a last line without a line end, edited beside an insertion, lands with no pause" \
	"$RC:$(git show HEAD~2:end.md | git hash-object --stdin):$(git show HEAD:end.md | git hash-object --stdin)" \
	"0:$(printf 'Lead.\n\nLast line, edited.' | git hash-object --stdin):$(printf 'Lead, reworded.\n\nInserted.\nLast line, edited.' | git hash-object --stdin)"
_ST_OUT_HAS "each of its stops resolved" "Made the fold's line replacements in the 2 commit(s) the replay stopped at"

# A fold inserting a line anywhere derives nothing – its stop pauses, and `--abort` leaves it all
_RL_DOC rl4
print -l "# Title" "Subtitle." "" "First paragraph, inserted beside." "Inserted paragraph." "" "Last paragraph, reworded." > doc.md
_ST_RUN --amend-into="$RL_T" --whole -- doc.md
RL_WT=$(_ST_PZ_WT)
_ST_EQ "a whole fold inserting a line stops at its target" \
	"$RC:$(git -C "${RL_WT:-$ST_NO_WT}" log -1 --format=%s HEAD 2>/dev/null):$(git -C "${RL_WT:-$ST_NO_WT}" diff --name-only --diff-filter=U 2>/dev/null):$(git rev-parse HEAD)" \
	"2:RL target:doc.md:$RL_O"
_ST_OUT_LACKS "resolving none of it" "Made the"
_ST_RUN --abort
_ST_EQ "--abort leaves the branch, the checkout's file and no pause" \
	"$RC:$(git rev-parse HEAD):$(sed -n 2p doc.md):$(_ST_PZ_WT):$([ -d "${RL_WT:-$ST_NO_WT}" ] && print kept)" "0:$RL_O:Subtitle.::"

# A stop at a commit holding a replaced line twice pauses there, the stops below it resolved
_ST_PZ_NEW rl5
_ST_PZ_C init.txt i "RL5 init"
print -l h OLD "after 0" m1 m2 m3 m4 m5 m6 end > f.txt && git add f.txt && git commit -qm "RL5 target"
RL_T=$(git rev-parse HEAD)
print -l h OLD "after 1" m1 m2 m3 m4 m5 m6 end OLD > f.txt && git commit -qam "RL5 c1 copies"
print -l h OLD "after 1" m1 m2 m3 m4 m5 m6 end > f.txt && git commit -qam "RL5 c2 drops the copy"
RL_O=$(git rev-parse HEAD)
print -l h NEW "after 1" m1 m2 m3 m4 m5 m6 end > f.txt && git add f.txt
_ST_RUN --amend-into="$RL_T" -- f.txt
RL_WT=$(_ST_PZ_WT)
_ST_EQ "a staged fold stops at the commit holding its old line twice" \
	"$RC:$(git -C "${RL_WT:-$ST_NO_WT}" log -1 --format=%s REBASE_HEAD 2>/dev/null):$(git -C "${RL_WT:-$ST_NO_WT}" diff --name-only --diff-filter=U 2>/dev/null)" "2:RL5 c1 copies:f.txt"
_ST_OUT_HAS "the target's stop below it resolved" "Made the fold's line replacements in the 1 commit(s) the replay stopped at"
_ST_EQ "the target rebuilt there with the edit" "$(git -C "${RL_WT:-$ST_NO_WT}" show HEAD:f.txt 2>/dev/null | sed -n 2,3p | tr '\n' ' ')" "NEW after 0 "
_ST_RUN --abort
_ST_EQ "--abort leaves the branch and the staging" "$RC:$(git rev-parse HEAD):$(git diff --cached --name-only)" "0:$RL_O:f.txt"
git restore --staged -- f.txt && git checkout -q -- f.txt

# A replaced line matches a whole line only – a commit holding it inside a longer one pauses
_ST_PZ_NEW rl6
_ST_PZ_C init.txt i "RL6 init"
print -l a "max = 1;" z > v.txt && git add v.txt && git commit -qm "RL6 target"
RL_T=$(git rev-parse HEAD)
print -l a "x = 1;" z > v.txt && git commit -qam "RL6 c1 renames"
RL_O=$(git rev-parse HEAD)
print -l a "x = 2;" z > v.txt
_ST_RUN --amend-into="$RL_T" --whole -- v.txt
RL_WT=$(_ST_PZ_WT)
_ST_EQ "a whole fold whose line the target holds only inside a longer one stops there" \
	"$RC:$(git -C "${RL_WT:-$ST_NO_WT}" diff --name-only --diff-filter=U 2>/dev/null):$(git rev-parse HEAD)" "2:v.txt:$RL_O"
_ST_OUT_LACKS "replacing nothing inside that line" "Made the"
_ST_RUN --abort
_ST_EQ "--abort leaves the branch and the checkout's file" "$RC:$(git rev-parse HEAD):$(sed -n 2p v.txt)" "0:$RL_O:x = 2;"
git checkout -q -- v.txt

# Each replaced line its own edit, whatever context a configured diff would join two hunks with
_ST_PZ_NEW rl7
git config diff.interHunkContext 5
_ST_PZ_C init.txt i "RL7 init"
print -l a b c d e > w.txt && git add w.txt && git commit -qm "RL7 target"
RL_T=$(git rev-parse HEAD)
print -l a B2 c d e > w.txt && git commit -qam "RL7 c1 rewords b"
print -l A B2 c D e > w.txt
_ST_RUN --amend-into="$RL_T" --whole -- w.txt
_ST_EQ "a whole fold of two lines a configured diff joins lands, each line replaced on its own" \
	"$RC:$(git show HEAD~1:w.txt | tr '\n' ' '):$(git show HEAD:w.txt | tr '\n' ' ')" "0:A b c D e :A B2 c D e "
# A fold of `--patch`, `--put` or `--tree` derives its replacements as a whole one does
_RL_DOC rl8
sed 's/^First paragraph, one line\.$/First paragraph, edited./' doc.md > doc.new
git diff --no-index doc.md doc.new | sed 's#a/doc.md#a/doc.md#;s#b/doc.new#b/doc.md#' > "$TMP/rl8.patch"
_ST_RUN --amend-into="$RL_T" --patch="$TMP/rl8.patch"
_ST_EQ "a --patch fold resolves its stops" "$RC:$(_RL_AT HEAD~2)" "0:# Title||First paragraph, edited.||Last paragraph, as written.|"
_RL_DOC rl9
git show HEAD:doc.md | sed 's/^First paragraph, one line\.$/First paragraph, edited./' > "$TMP/rl9.md"
_ST_RUN --amend-into="$RL_T" --put="doc.md=$TMP/rl9.md" --base="$(git rev-parse HEAD)"
_ST_EQ "a --put fold resolves its stops" "$RC:$(_RL_AT HEAD~2)" "0:# Title||First paragraph, edited.||Last paragraph, as written.|"
_RL_DOC rl10
RL_WT=$(git show HEAD:doc.md | sed 's/^First paragraph, one line\.$/First paragraph, edited./' | git hash-object -w --stdin)
GIT_INDEX_FILE="$TMP/rl10.idx" git read-tree HEAD && GIT_INDEX_FILE="$TMP/rl10.idx" git update-index --cacheinfo "100644,$RL_WT,doc.md"
RL_WT=$(GIT_INDEX_FILE="$TMP/rl10.idx" git write-tree)
_ST_RUN --amend-into="$RL_T" --tree="$RL_WT"
_ST_EQ "a --tree fold resolves its stops" "$RC:$(_RL_AT HEAD~2)" "0:# Title||First paragraph, edited.||Last paragraph, as written.|"
# A resume goes on resolving: past two stops its inserted line needs by hand,
# the third its replaced one alone conflicts in resolves itself
_ST_PZ_NEW rl11
print -l g1 g2 > g && print -l h1 "the line" h3 > h && git add g h && git commit -qm "RL11 target"
RL_T=$(git rev-parse HEAD)
print -l g1 G2 > g && git commit -qam "RL11 changes g"
print -l y1 "the line" y3 > h && git commit -qam "RL11 changes h"
_ST_PZ_C k k1 "RL11 later"
print -l g1 new G2 > g && print -l y1 "the fixed line" y3 > h
_ST_RUN --amend-into="$RL_T" --whole -- g h
RL_WT=$(_ST_PZ_WT)
print -l g1 new g2 > "${RL_WT:-$ST_NO_WT}/g" && print -l h1 "the fixed line" h3 > "${RL_WT:-$ST_NO_WT}/h"
git -C "${RL_WT:-$ST_NO_WT}" add g h
_ST_RUN --continue
print -l g1 new G2 > "${RL_WT:-$ST_NO_WT}/g" && git -C "${RL_WT:-$ST_NO_WT}" add g
_ST_RUN --continue
_ST_EQ "the stop after them resolves itself on resume" \
	"$RC:$(git show HEAD~3:h | tr '\n' ' '):$(git show HEAD~1:h | tr '\n' ' '):$(git show HEAD:g | tr '\n' ' ')" \
	"0:h1 the fixed line h3 :y1 the fixed line y3 :g1 new G2 "
_ST_OUT_HAS "saying so" "Made the fold's line replacements in the 1 later commit(s)"
# A fold adding a file besides derives the replacements of the others, their stops resolving
_RL_DOC rl12
sed 's/^First paragraph, one line\.$/First paragraph, edited./' doc.md > doc.new && mv doc.new doc.md
print new > added.txt
_ST_RUN --amend-into="$RL_T" --whole -- doc.md added.txt
_ST_EQ "one adding a file resolves the stops of its replaced lines" \
	"$RC:$(_RL_AT HEAD~2):$(git show HEAD~2:added.txt)" "0:# Title||First paragraph, edited.||Last paragraph, as written.|:new"
# A file resolved by hand otherwise than the fold makes it – here at a target holding the replaced
# line twice – keeps its later stops for the resolver, so the resume never undoes that resolution
_ST_PZ_NEW rl13
print -l a "the line" b "the line" c > f && git add f && git commit -qm "RL13 target"
RL_T=$(git rev-parse HEAD)
print -l a "the line" b c > f && git commit -qam "RL13 drops the twin"
print -l a2 "the line" b2 c > f && git commit -qam "RL13 changes around it"
_ST_PZ_C k k1 "RL13 later"
print -l a2 "the fixed line" b2 c > f
_ST_RUN --amend-into="$RL_T" --whole -- f
RL_WT=$(_ST_PZ_WT)
print -l a "the hand line" b "the line" c > "${RL_WT:-$ST_NO_WT}/f" && git -C "${RL_WT:-$ST_NO_WT}" add f
_ST_RUN --continue
_ST_EQ "its later stop pauses rather than replace its line" "$RC:$(git -C "${RL_WT:-$ST_NO_WT}" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
# As does one renamed between the stop resolved by hand and the next in it
_ST_PZ_NEW rl14
print -l l1 "the line" l3 > f && git add f && git commit -qm "RL14 target"
RL_T=$(git rev-parse HEAD)
git mv f g && git commit -qm "RL14 renames f"
print -l m1 "the line" m3 > g && git commit -qam "RL14 changes around it"
_ST_PZ_C k k1 "RL14 later"
print -l m1 "the fixed line" m3 > g
GIT_EDIT_NO_SELF_RESOLVE=1 _ST_RUN --amend-into="$RL_T" --whole -- g
RL_WT=$(_ST_PZ_WT)
print -l l1 "the hand line" l3 > "${RL_WT:-$ST_NO_WT}/f" && git -C "${RL_WT:-$ST_NO_WT}" add f
_ST_RUN --continue
_ST_EQ "a rename between them keeps that stop the resolver's too" "$RC:$(git -C "${RL_WT:-$ST_NO_WT}" diff --name-only --diff-filter=U)" "2:g"
_ST_RUN --abort
# As does one a stop's resolution gave another mode, its text as the fold makes it
_ST_PZ_NEW rl15
print -l l1 "the line" l3 > f && git add f && git commit -qm "RL15 target"
RL_T=$(git rev-parse HEAD)
print -l m1 "the line" m3 > f && git commit -qam "RL15 changes around it"
_ST_PZ_C k k1 "RL15 later"
print -l m1 "the fixed line" m3 > f
GIT_EDIT_NO_SELF_RESOLVE=1 _ST_RUN --amend-into="$RL_T" --whole -- f
RL_WT=$(_ST_PZ_WT)
print -l l1 "the fixed line" l3 > "${RL_WT:-$ST_NO_WT}/f" && chmod +x "${RL_WT:-$ST_NO_WT}/f" && git -C "${RL_WT:-$ST_NO_WT}" add f
_ST_RUN --continue --allow-mode-change
_ST_EQ "a mode it kept keeps the next stop the resolver's" "$RC:$(git -C "${RL_WT:-$ST_NO_WT}" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
cd "$TMP/repo"
