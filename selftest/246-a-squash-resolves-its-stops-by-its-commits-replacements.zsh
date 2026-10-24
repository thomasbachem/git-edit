# A squash of commits replacing lines resolves its replay's stops as `-s=auto` does
# – into the oldest or a named target, given a message or not – while a commit it
# folds adding a line pauses the stop, as does a drop's replay, which folds nothing
_ST_SCENARIO "\e[1;96m[246] a squash resolves its stops by its commits' replacements\e[0m"
local SQ_T
# Commits a line its neighbors' later change conflicts with, then the commit fixing it
_SQ_FIXED () {
	_ST_PZ_NEW "$1"
	print -l x1 "the comment" x3 > f && git add f && git commit -qm "SQ replaced"
	SQ_T=$(git rev-parse HEAD)
	print -l y1 "the comment" y3 > f && git commit -qam "SQ around it"
	_ST_PZ_C g g1 "SQ beside"
	print -l y1 "the fixed comment" y3 > f && git commit -qam "SQ fixes the comment"
}
_SQ_FIXED sq
_ST_RUN -s="$SQ_T" HEAD
_ST_EQ "a squash into a named target resolves the stops it meets" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~2:f | tr '\n' ' '):$(git show HEAD~1:f | tr '\n' ' ')" \
	"0:SQ beside|SQ around it|SQ replaced|:x1 the fixed comment x3 :y1 the fixed comment y3 "
_ST_OUT_HAS "saying so" "Made the fixups' line replacements at"
_SQ_FIXED sq-text
_ST_RUN -s="$SQ_T" --text "SQ replaced and fixed" HEAD
_ST_EQ "as does one given a message, which the target takes" \
	"$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD~1:f | tr '\n' ' ')" \
	"0:SQ beside|SQ around it|SQ replaced and fixed|:y1 the fixed comment y3 "
_SQ_FIXED sq-oldest
_ST_RUN -s "$SQ_T" HEAD
_ST_EQ "and one into the oldest of its commits" "$RC:$(git show HEAD~2:f | tr '\n' ' ')" "0:x1 the fixed comment x3 "
_SQ_FIXED sq-added
print -l y1 "the fixed comment" added y3 > f && git commit -qam "SQ adds a line"
_ST_RUN -s="$SQ_T" HEAD
_ST_EQ "a commit it folds adding a line pauses" "$RC" "2"
_ST_RUN --abort
_SQ_FIXED sq-drop
_ST_RUN -d HEAD~2 --yes
_ST_EQ "a drop's stop pauses, as it folds nothing in" "$RC:$(git -C "$(_ST_PZ_WT)" diff --name-only --diff-filter=U)" "2:f"
_ST_RUN --abort
unfunction _SQ_FIXED
cd "$TMP/repo"
