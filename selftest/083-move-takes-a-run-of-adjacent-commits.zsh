# A run of adjacent commits moves as one block, in one replay
# Landing several new commits at one spot a commit at a time replays the span once per commit
# – and verifies it once per commit under a standing `edit.verifySpan`, which cost a
# landing three passes over 185 commits. A run `<oldest>..<newest>` moves in one, read
# inclusive and either way round, as `-d` reads a range
_ST_SCENARIO "\e[1;96m[83] --move takes a run of adjacent commits as one block\e[0m"
local RN
for RN in anchor x1 x2 "run a" "run b" "run c"; do
	echo "$RN" > "rn_${RN// /_}.txt" && git add "rn_${RN// /_}.txt" && git commit -qm "RN $RN"
done
local RN_TREE=$(git rev-parse 'HEAD^{tree}')
local RN_MOVES=$(git reflog show --format=%H "$(git symbolic-ref HEAD)" | wc -l | tr -d ' ')
: > "$TMP/rn-count"
_ST_RUN --verify="echo run >> '$TMP/rn-count'" --verify-span --move="$(git rev-parse ':/RN run a')..$(git rev-parse ':/RN run c')" --after="$(git rev-parse ':/RN anchor')"
_ST_EQ "a run moves down" "$RC" "0"
_ST_OUT_HAS "announced as one" 'Moving 3 commits'
_ST_EQ "whole and in its own order, right after the anchor" "$(git log --format=%s -6 | tr '\n' '|')" "RN x2|RN x1|RN run c|RN run b|RN run a|RN anchor|"
_ST_EQ "with the tip tree kept" "$(git rev-parse 'HEAD^{tree}')" "$RN_TREE"
_ST_EQ "in one ref move" "$(( $(git reflog show --format=%H "$(git symbolic-ref HEAD)" | wc -l) - RN_MOVES ))" "1"
_ST_EQ "verifying each rebuilt commit once" "$(wc -l < "$TMP/rn-count" | tr -d ' ')" "5"
_ST_RUN --move="$(git rev-parse ':/RN run c')..$(git rev-parse ':/RN run a')" --after="$(git rev-parse ':/RN x2')"
_ST_EQ "ends given newest first move it back up" "$RC" "0"
_ST_EQ "to the tip" "$(git log --format=%s -6 | tr '\n' '|')" "RN run c|RN run b|RN run a|RN x2|RN x1|RN anchor|"
_ST_RUN --move="$(git rev-parse ':/RN run a').." --before="$(git rev-parse ':/RN x1')"
_ST_EQ "an open end runs to HEAD" "$RC" "0"
_ST_EQ "and moves before an anchor too" "$(git log --format=%s -6 | tr '\n' '|')" "RN x2|RN x1|RN run c|RN run b|RN run a|RN anchor|"
_ST_RUN --move="$(git rev-parse ':/RN run a')..$(git rev-parse ':/RN run c')" --after="$(git rev-parse ':/RN anchor')"
_ST_EQ "a run in position is a no-op" "$RC" "0"
_ST_OUT_HAS "saying so" 'already sit directly after'
local RN_HEAD=$(git rev-parse HEAD)
_ST_RUN --move="$(git rev-parse ':/RN run a')..$(git rev-parse ':/RN run c')" --after="$(git rev-parse ':/RN run b')"
_ST_EQ "an anchor inside the run refuses" "$RC" "1"
_ST_OUT_HAS "naming where it lies" 'lies inside the moved run'
# An anchor given twice placed the commit after the last one alone, with nothing said
_ST_RUN --move="$(git rev-parse ':/RN run a')" --after="$(git rev-parse ':/RN x2')" --after="$(git rev-parse ':/RN x1')"
_ST_EQ "--after given twice refuses" "$RC" "1"
_ST_OUT_HAS "naming the repeat" '--after given twice – it names one commit'
_ST_RUN --move="$(git rev-parse ':/RN run a')" --before="$(git rev-parse ':/RN x2')" --before="$(git rev-parse ':/RN x1')"
_ST_EQ "--before given twice refuses" "$RC" "1"
_ST_OUT_HAS "naming it there too" '--before given twice – it names one commit'
_ST_EQ "neither moving anything" "$(git rev-parse HEAD)" "$RN_HEAD"
_ST_RUN --move="$(git rev-parse ':/RN run a')" "$(git rev-parse ':/RN run b')" --after="$(git rev-parse ':/RN x2')"
_ST_EQ "a second commit as a positional refuses" "$RC" "1"
_ST_OUT_HAS "naming the forms that take several" 'several commits go as --move=<a> --move=<b>'
