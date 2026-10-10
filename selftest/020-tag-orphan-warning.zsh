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
