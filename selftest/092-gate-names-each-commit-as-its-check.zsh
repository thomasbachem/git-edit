# A span tier can run for minutes, and a caller following along saw nothing until the end –
# while a captured run, which nobody watches live, would carry a line per commit
_ST_SCENARIO "\e[1;96m[92] the gate names each commit as its check starts, where someone watches\e[0m"
local VP
for VP in base one two; do
	echo "$VP" > "vp_$VP.txt" && git add "vp_$VP.txt" && git commit -qm "VP $VP"
done
local VP_TWO=$(git rev-parse ':/VP two') VP_BASE=$(git rev-parse ':/VP base')
git config edit.verifyCmd true
git config edit.verifySpan true
_ST_RUN --move="$VP_TWO" --after="$VP_BASE"
_ST_EQ "a move under the span applies" "$RC" "0"
_ST_OUT_HAS "reporting its gate" '^Verified 2 commit(s) with'
_ST_OUT_LACKS "without a line per commit on a captured run" '^Checking '
_ST_RUN --undo
GIT_EDIT_PROGRESS=1 _ST_RUN --move="$VP_TWO" --after="$VP_BASE"
_ST_EQ "and again where a caller asks for progress" "$RC" "0"
_ST_OUT_HAS "naming the first commit it checks" '^Checking 1 of 2 – [0-9a-f]\{7,\} VP two$'
_ST_OUT_HAS "and the last" '^Checking 2 of 2 – [0-9a-f]\{7,\} VP one$'
git config --unset edit.verifySpan
git config --unset edit.verifyCmd
