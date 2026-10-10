# A placement lands what it built or nothing – a commit gone empty where it was placed, or a merge
# a peer landed meanwhile, refuses – and its pause reads as a placement, whose it is named
_ST_SCENARIO "\e[1;96m[139] a placement lands only what it built, its pause named as one\e[0m"
local PB_T PB_WT PB_A
_ST_PZ_NEW pb1
_ST_PZ_C f.txt a "PB A" && _ST_PZ_C f.txt b "PB R" && _ST_PZ_C g.txt g "PB S"
PB_A=$(git rev-parse HEAD~2)
PB_T=$(git rev-parse HEAD)
# Its change back to `a` already there at the anchor, the placed commit goes empty
print -r -- a > f.txt
_ST_RUN --commit --text "PB N" --after="$PB_A" -- f.txt
_ST_EQ "a placed commit going empty pauses, nothing landed" "${RC}:$(git rev-parse HEAD)" "2:$PB_T"
_ST_OUT_HAS "naming --abort rather than a skip, which would land another tree" 'so the placement cannot land'
PB_WT=$(_ST_PZ_WT)
git -C "${PB_WT:-$ST_NO_WT}" rebase --skip >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a resume without it refuses rather than land another tree under the placement" "${RC}:$(git rev-parse HEAD)" "1:$PB_T"
_ST_OUT_HAS "saying so" 'no longer ends as it was built'
_ST_RUN --status
_ST_OUT_HAS "--status names a placement as one" 'In-flight operation: placement – commit after'
_ST_RUN --abort
_ST_OUT_HAS "as does --abort" 'Placement aborted'
_ST_EQ "which leaves the branch and the checkout's file as they were" "${RC}:$(git rev-parse HEAD):$(<f.txt)" "0:${PB_T}:a"
git checkout -q -- f.txt
# Placed before an anchor, the anchor is named as it now stands
print -r -- n > n.txt
_ST_RUN --commit --text "PB before" --before=HEAD~1 -- n.txt
_ST_OUT_HAS "a placement below an anchor names it by its new SHA" "committed before $(git rev-parse --short=7 HEAD~1):"
# A pause on another branch is in the way of a placement, which can pause itself
git branch pb-other HEAD~1
git checkout -q pb-other
print -r -- x > x.txt && git add x.txt && git commit -qm "PB other x"
print -r -- y > x.txt && git add x.txt && git commit -qm "PB other y"
_ST_RUN --move=HEAD --before=HEAD~1
git checkout -q main 2>/dev/null
print -r -- p > p.txt
_ST_RUN --commit --text "PB placed" --after=HEAD~1 -- p.txt
_ST_EQ "a placement with a pause open on another branch refuses up front" "$RC" "1"
_ST_OUT_HAS "naming it and whose it is" "in flight on pb-other, paused for its resolution – an unlabeled caller's"
_ST_RUN --commit --text "PB plain" -- p.txt
_ST_EQ "while a plain commit, which never pauses, lands beside it" "${RC}:$(git log -1 --format=%s)" "0:PB plain"
git checkout -q pb-other 2>/dev/null
_ST_RUN --abort
git checkout -q main 2>/dev/null
# A merge a peer lands between resolving the anchor and the replay refuses before anything lands
_ST_PZ_NEW pb2
_ST_PZ_C a.txt a "PB2 A" && _ST_PZ_C b.txt b "PB2 B"
PB_A=$(git rev-parse HEAD~1)
git checkout -q -b side HEAD~1 && _ST_PZ_C s.txt s "PB2 side" && git checkout -q main
# The peer's merge lands while the run takes the files it commits, after the anchor was checked
mkdir -p "$TMP/pb2-bin"
cat > "$TMP/pb2-bin/git" <<EOF
#!/bin/sh
if [ "\$1 \$2 \$3" = "config --type=bool core.ignorecase" ] && [ ! -e "$TMP/pb2-merged" ]; then
	: > "$TMP/pb2-merged"
	command -p env PATH="$PATH" git -C "$TMP/pz-pb2" merge -q --no-ff -m "PB2 merge" side >/dev/null 2>&1
fi
exec env PATH="$PATH" git "\$@"
EOF
chmod +x "$TMP/pb2-bin/git"
print -r -- n > n.txt
PB_T=$(git rev-parse HEAD)
OUT=$(PATH="$TMP/pb2-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "PB2 N" --after="$PB_A" -- n.txt </dev/null 2>&1)
RC=$?
_ST_EQ "a merge landing mid-placement refuses it, the merge kept" "${RC}:$(git rev-list --merges --count HEAD):$(git log -1 --format=%s)" "1:1:PB2 merge"
_ST_OUT_HAS "naming the merge in its span" 'contains a merge commit'
# As does an anchor a peer dropped meanwhile, which the replay would bring back
_ST_PZ_NEW pb3
_ST_PZ_C a.txt a "PB3 A" && _ST_PZ_C b.txt b "PB3 B anchor" && _ST_PZ_C c.txt c "PB3 C"
PB_A=$(git rev-parse HEAD~1)
cat > "$TMP/pb2-bin/git" <<EOF
#!/bin/sh
if [ "\$1 \$2 \$3" = "config --type=bool core.ignorecase" ] && [ ! -e "$TMP/pb3-dropped" ]; then
	: > "$TMP/pb3-dropped"
	env PATH="$PATH" git -C "$TMP/pz-pb3" rebase -q --onto HEAD~2 HEAD~1 >/dev/null 2>&1
fi
exec env PATH="$PATH" git "\$@"
EOF
print -r -- n > n.txt
OUT=$(PATH="$TMP/pb2-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "PB3 N" --after="$PB_A" -- n.txt </dev/null 2>&1)
RC=$?
_ST_EQ "an anchor dropped mid-placement refuses, the drop kept" "${RC}:$(git log --format=%s | tr '\n' '|')" "1:PB3 C|PB3 A|"
_ST_OUT_HAS "naming it as gone" 'left the branch while this run built'
cd "$TMP/repo"
