# Tag-orphan warning on rewrites beneath a tag
_ST_SCENARIO "\e[1;96m[20] tag-orphan warning\e[0m"
echo "t1" > t1.txt && git add t1.txt && git commit -qm "T1 commit"
echo "t2" > t2.txt && git add t2.txt && git commit -qm "T2 commit"
git tag marker
# Rewriting below the tag orphans it – expect the warning + exact re-point
_ST_RUN -M --text="T1 reworded" "$(git rev-parse HEAD~1)"
_ST_EQ "exits 0" "$RC" "0"
_ST_OUT_HAS "warns about the tag" 'points into the rewritten span'
_ST_OUT_HAS "suggests exact counterpart" 'Tag marker .*its counterpart, the same change'
_ST_OUT_HAS "with the command to re-point it" "git tag -f marker $(git rev-parse --short=12 HEAD)\$"
git tag -f marker >/dev/null 2>&1   # re-point to current `HEAD` for the next check
# Rewriting above the tag leaves it reachable – expect no warning
git tag -f marker "$(git rev-parse HEAD~1)" >/dev/null 2>&1
_ST_RUN -M --text="T2 reworded" "$(git rev-parse HEAD)"
_ST_EQ "exits 0" "$RC" "0"
_ST_OUT_LACKS "no warning for safe tag" 'points into the rewritten span'
git tag -d marker >/dev/null 2>&1
# Two tags in the span warn independently, and a tag on a non-commit
# object is neither flagged nor trips the --merged walks
git tag markerA "$(git rev-parse HEAD~1)"
git tag markerB
git tag blobmark "$(echo blob | git hash-object -w --stdin)"
_ST_RUN -M --text="T1 reworded again" "$(git rev-parse HEAD~1)"
_ST_EQ "exits 0 with a blob tag present" "$RC" "0"
_ST_OUT_HAS "warns about the lower tag" 'Tag markerA points into'
_ST_OUT_HAS "and the upper tag" 'Tag markerB points into'
_ST_OUT_LACKS "blob tag never flagged" 'blobmark'
git tag -d markerA markerB blobmark >/dev/null 2>&1
# A side branch's rewrite names neither the default branch nor a tag
# it still holds, its own rewrite one a side branch holds all the same
git tag markerS
git checkout -q -b tag-trial && echo t3 > t3.txt && git add t3.txt && git commit -qm "T3 commit" && git tag markerT && git branch tag-backup
_ST_RUN -M --text="T2 reworded on the trial" "$(git rev-parse HEAD~1)"
_ST_EQ "exits 0 on the side branch, the tag where it was" "$RC:$(git rev-parse markerS)" "0:$(git rev-parse main)"
_ST_OUT_LACKS "naming no tag main holds" 'Tag markerS'
_ST_OUT_HAS "naming one the side branch and its backup hold" 'Tag markerT points into'
_ST_OUT_LACKS "nor main itself" '^Branch main'
_ST_OUT_HAS "the backup still named" '^Branch tag-backup points into the rewritten span'
git checkout -q main
_ST_RUN -M --text="T2 reworded on main" "$(git rev-parse HEAD)"
_ST_OUT_HAS "the default branch's rewrite naming one the side holds" 'Tag markerS points into'
# A detached `HEAD`'s rewrite names none a branch holds either
git checkout -q --detach main && git tag markerD
_ST_RUN -M --text="T2 reworded detached" "$(git rev-parse HEAD)"
_ST_EQ "exits 0 detached, the tag where it was" "$RC:$(git rev-parse markerD)" "0:$(git rev-parse main)"
_ST_OUT_LACKS "naming no tag main holds, detached" 'Tag markerD'
git checkout -q main
git tag -d markerS markerT markerD >/dev/null 2>&1 && git branch -q -D tag-trial tag-backup
