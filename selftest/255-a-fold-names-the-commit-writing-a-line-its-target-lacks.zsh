# A fold replacing a line its target lacks, as a later commit wrote it, stops at its own step,
# where no replacement resolves it – so that commit is named:
# • An `--edits` fold refuses before replaying, its old texts known up front
# • Any other stops there as before, the pause naming it
# • A line the target holds, or a replaced line whose changed words it holds, names none
_ST_SCENARIO "\e[1;96m[255] a fold names the commit writing a line its target lacks\e[0m"
local LK_T LK_TIP
_ST_PZ_NEW lk
_ST_PZ_C f.txt $'alpha\nbravo\ncharlie' "LK base"
_ST_PZ_C g.txt g "LK target"
LK_T=$(git rev-parse HEAD)
_ST_PZ_C f.txt $'alpha\nbravo\ncharlie as written later' "LK writes charlie"
_ST_PZ_C h.txt h "LK other"
LK_TIP=$(git rev-parse HEAD)
_ST_RUN --amend-into="$LK_T" --edits '{"f.txt": [["alpha", "alpha fixed"], ["charlie as written later", "charlie fixed"]]}'
_ST_EQ "an edit of a line a later commit wrote refuses, nothing landed" "$RC:$(git rev-parse HEAD)" "1:$LK_TIP"
_ST_OUT_HAS "naming the edit and the commit writing its line" \
	"^  f.txt: edit 2 ('charlie as written later') – written by $(git rev-parse --short ':/LK writes charlie') (LK writes charlie)$"
_ST_OUT_LACKS "never the one the target holds" 'f.txt: edit 1 '
_ST_OUT_HAS "and where each goes" "Nothing landed – fold those edits into the commit named or a later one, the rest into ${LK_T:0:7} apart"
_ST_OUT_LACKS "before any replay" 'Conflict during the fold'
# One taking that line back to what the target holds merges there clean, dissolving in the replay
_ST_RUN --amend-into="$LK_T" --edits '{"f.txt": [["charlie as written later", "charlie"], ["alpha", "alpha fixed"]]}'
_ST_EQ "an edit taking a later line back to the target's lands beside the rest" \
	"$RC:$(git show "$(git rev-parse ':/LK target')":f.txt | tr '\n' '|'):$(git show HEAD:f.txt | tr '\n' '|')" \
	"0:alpha fixed|bravo|charlie|:alpha fixed|bravo|charlie as written later|"
# One the target holds folds as before
_ST_RUN --amend-into="$(git rev-parse ':/LK target')" --edits '{"f.txt": [["bravo", "bravo fixed"]]}'
_ST_EQ "an edit of a line the target holds lands" "$RC:$(git show "$(git rev-parse ':/LK target')":f.txt | tr '\n' '|')" "0:alpha fixed|bravo fixed|charlie|"
# A staged fold of the same line stops at its own step, the pause naming the writer
_ST_PZ_NEW lk2
_ST_PZ_C f.txt $'alpha\nbravo\ncharlie' "LK2 base"
_ST_PZ_C g.txt g "LK2 target"
LK_T=$(git rev-parse HEAD)
_ST_PZ_C f.txt $'alpha\nbravo\ncharlie as written later' "LK2 writes charlie"
_ST_PZ_C h.txt h "LK2 other"
print -l alpha bravo "charlie fixed" > f.txt && git add f.txt
_ST_RUN --amend-into="$LK_T" -- f.txt
_ST_EQ "a staged fold of that line pauses at its own step" "$RC" "2"
_ST_OUT_HAS "saying the target lacks it" "^${LK_T:0:7} lacks lines this step's change replaces – later commits write them"
_ST_OUT_HAS "naming the writer and the line" \
	"^  $(git rev-parse --short ':/LK2 writes charlie') LK2 writes charlie – f.txt:3 'charlie as written later'$"
_ST_RUN --status
_ST_OUT_HAS "as --status does" "^  $(git rev-parse --short ':/LK2 writes charlie') LK2 writes charlie – f.txt:3 "
_ST_RUN --abort
git restore --staged f.txt && git checkout -q f.txt
# As does a squash's fixup of it
_ST_PZ_C f.txt $'alpha\nbravo\ncharlie fixed' "fixup! LK2 target"
_ST_RUN -s=auto HEAD
_ST_EQ "a squash's fixup of that line pauses" "$RC" "2"
_ST_OUT_HAS "naming the writer alike" \
	"^  $(git rev-parse --short ':/LK2 writes charlie') LK2 writes charlie – f.txt:3 'charlie as written later'$"
_ST_RUN --abort
# A replaced line whose changed words the target holds, rewrapped since, names none
_ST_PZ_NEW lk3
_ST_PZ_C c $'// alpha bravo charlie delta\n// echo foxtrot golf hotel' "LK3 target"
LK_T=$(git rev-parse HEAD)
_ST_PZ_C c $'// alpha bravo charlie\n// delta echo foxtrot golf hotel' "LK3 rewrap"
print -l "// alpha bravo charlie" "// delta echo FOXTROT golf hotel" > c && git add c
GIT_EDIT_NO_SELF_RESOLVE=1 _ST_RUN --amend-into="$LK_T" -- c
_ST_EQ "a rewrapped line's fold unresolved pauses" "$RC" "2"
_ST_OUT_LACKS "naming no writer, the target holding its words" 'lacks lines'
_ST_RUN --abort
git restore --staged c && git checkout -q c
cd "$TMP/repo"
