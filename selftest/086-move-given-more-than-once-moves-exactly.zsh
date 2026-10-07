# A range takes every commit between its ends, whoever made it – in a checkout other sessions
# commit to, a peer's commit lands between two of a landing's moves and goes with them, while
# naming each moves those alone, together and in their history order, the rest staying put
_ST_SCENARIO "\e[1;96m[86] --move given more than once moves exactly the commits it names\e[0m"
local LS
for LS in anchor x mine1 peer mine2; do
	echo "$LS" > "ls_$LS.txt" && git add "ls_$LS.txt" && git commit -qm "LS $LS"
done
local LS_TREE=$(git rev-parse 'HEAD^{tree}')
local LS_MOVES=$(git reflog show --format=%H "$(git symbolic-ref HEAD)" | wc -l | tr -d ' ')
_ST_RUN --move="$(git rev-parse ':/LS mine1')" --move="$(git rev-parse ':/LS mine2')" --after="$(git rev-parse ':/LS anchor')"
_ST_EQ "two named commits move" "$RC" "0"
_ST_OUT_HAS "announced by name" 'Moving 2 commits – '
_ST_EQ "together after the anchor, the commit between them left behind" "$(git log --format=%s -5 | tr '\n' '|')" "LS peer|LS x|LS mine2|LS mine1|LS anchor|"
_ST_EQ "with the tip tree kept" "$(git rev-parse 'HEAD^{tree}')" "$LS_TREE"
_ST_EQ "in one ref move" "$(( $(git reflog show --format=%H "$(git symbolic-ref HEAD)" | wc -l) - LS_MOVES ))" "1"
_ST_RUN --move="$(git rev-parse ':/LS mine2')" --move="$(git rev-parse ':/LS mine1')" --after="$(git rev-parse ':/LS peer')"
_ST_EQ "named newest first" "$RC" "0"
_ST_EQ "they keep their history order" "$(git log --format=%s -5 | tr '\n' '|')" "LS mine2|LS mine1|LS peer|LS x|LS anchor|"
_ST_RUN --move="$(git rev-parse ':/LS x')" --move="$(git rev-parse ':/LS mine2')" --after="$(git rev-parse ':/LS peer')"
_ST_EQ "an anchor lying between them" "$RC" "0"
_ST_EQ "gathers them there" "$(git log --format=%s -5 | tr '\n' '|')" "LS mine1|LS mine2|LS x|LS peer|LS anchor|"
_ST_RUN --move="$(git rev-parse ':/LS x')" --move="$(git rev-parse ':/LS mine2')" --after="$(git rev-parse ':/LS peer')"
_ST_EQ "named commits in position are a no-op" "$RC" "0"
_ST_OUT_HAS "saying so" 'already sit directly after'
local LS_HEAD=$(git rev-parse HEAD)
_ST_RUN --move="$(git rev-parse ':/LS x')" --move="$(git rev-parse ':/LS peer')" --after="$(git rev-parse ':/LS peer')"
_ST_EQ "an anchor among them refuses" "$RC" "1"
_ST_OUT_HAS "naming it" 'is one of the commits being moved'
_ST_EQ "moving nothing" "$(git rev-parse HEAD)" "$LS_HEAD"
_ST_RUN --move="$(git rev-parse ':/LS peer')..$(git rev-parse ':/LS x')" --move="$(git rev-parse ':/LS mine1')" --before="$(git rev-parse ':/LS mine2')"
_ST_EQ "a run and a single commit together" "$RC" "0"
_ST_EQ "move as one block" "$(git log --format=%s -5 | tr '\n' '|')" "LS mine2|LS mine1|LS x|LS peer|LS anchor|"
