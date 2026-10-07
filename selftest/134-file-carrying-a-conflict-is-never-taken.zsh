# A file carrying a conflict is never taken whole, nor written into by a terminal's sync
_ST_SCENARIO "\e[1;96m[134] a file carrying a conflict is never taken whole, nor written into by a sync\e[0m"
local MK_T
_ST_PZ_NEW mk1
_ST_PZ_C f.txt $'1\n2\n3' "MK base" && MK_T=$(git rev-parse HEAD)
print -r -- $'1\n<<<<<<< ours\n2a\n=======\n2b\n>>>>>>> theirs\n3' > f.txt
_ST_RUN --commit --text "MK markers" -- f.txt
_ST_EQ "--commit refuses a file carrying conflict markers" "$RC:$(git rev-parse HEAD)" "1:$MK_T"
_ST_OUT_HAS "naming it" 'Conflict markers in 1 file(s) taken whole – nothing landed: f.txt'
_ST_RUN --amend-into="$MK_T" --whole -- f.txt
_ST_EQ "as does a --whole fold" "$RC:$(git rev-parse HEAD)" "1:$MK_T"
# Lines the tip already holds are the file's own, as is an underline of seven `=` alone
print -r -- $'1\n<<<<<<< ours\n2a\n=======\n2b\n>>>>>>> theirs\n3' > f.txt
git add f.txt && git commit -qm "MK markers as content"
print -r -- $'1\n<<<<<<< ours\n2a\n=======\n2b\n>>>>>>> theirs\n3\n4' > f.txt
print -r -- $'Title\n=======\ntext' > t.md
_ST_RUN --commit --text "MK edits beside" -- f.txt t.md
_ST_EQ "markers the tip holds already, and a heading's underline, land" "$RC:$(git log -1 --format=%s)" "0:MK edits beside"
# A larger marker size makes them content, as `git diff --check` reads it
print -r -- 'g.txt conflict-marker-size=32' > .gitattributes && git add .gitattributes && git commit -qm "MK attrs"
print -r -- $'<<<<<<< a\nx\n>>>>>>> b' > g.txt
_ST_RUN --commit --text "MK fixture" -- g.txt
_ST_EQ "markers below a file's conflict-marker-size are its content" "$RC:$(git log -1 --format=%s)" "0:MK fixture"
# A rename the carry can't merge cleanly lands its new path, the edits left at the old one
_ST_PZ_NEW mk2
_ST_PZ_C base.txt b "MK2 base"
print -l 1 2 3 4 5 6 7 8 > r && git add r && git commit -qm "MK2 adds r"
git mv r s && print -l 1 2x 3 4 5 6 7 8 > s && git add s && git commit -qm "MK2 renames r"
_ST_PZ_C c.txt c "MK2 c"
print -l 1 2y 3 4 5 6 7 8 > s
_ST_TTY -- -d -y HEAD~1
_ST_EQ "a rename conflicting with edits lands its new path, the edits untracked at the old" \
	"$RC:$(git status --porcelain | sort | tr '\n' '|'):$(sed -n 2p r):$(sed -n 2p s)" "0:?? s|:2:2y"
cd "$TMP/repo"
