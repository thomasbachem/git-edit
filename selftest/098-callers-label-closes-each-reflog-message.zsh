# The undo journal keeps none, so an undo names whoever undid rather than nesting a second
# label – and a value that could break the quoted command it rides in is left out
_ST_SCENARIO "\e[1;96m[98] the caller's label closes each reflog message\e[0m"
echo s > sid.txt && git add sid.txt && git commit -qm "SID base"
local SID=local_0123abcd-0000-4000-8000-00000000abcd SID_REF=$(git symbolic-ref HEAD) SID_BASE=$(git rev-parse HEAD)
export GIT_EDIT_ACTOR=$SID
_ST_RUN -M --text="SID reworded" "$SID_BASE"
_ST_EQ "a reword ends in the id" "$(git reflog show -1 --format=%gs "$SID_REF")" "git edit: reword ${SID_BASE:0:7} [$SID]"
_ST_RUN --exec -- git commit -q --allow-empty -m "SID on top"
_ST_EQ "an exec too" "$(git reflog show -1 --format=%gs "$SID_REF")" "git edit: exec [$SID]"
_ST_RUN --undo
_ST_EQ "an undo names only its own caller" "$(git reflog show -1 --format=%gs "$SID_REF")" "git edit: undo exec [$SID]"
export GIT_EDIT_ACTOR="x' HEAD; touch '$TMP/sid-pwned' '"
_ST_RUN --exec -- git commit -q --allow-empty -m "SID unsafe"
_ST_EQ "an unsafe value is mapped to a label of its own" "$(git reflog show -1 --format=%gs "$SID_REF")" "git edit: exec [x__HEAD__touch__${TMP//[^A-Za-z0-9_-]/_}_sid-pwned___]"
_ST_CHECK "and runs nothing" test ! -e "$TMP/sid-pwned"
export GIT_EDIT_ACTOR=
