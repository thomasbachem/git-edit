# Reporting must survive the shapes that break naive derivation
_ST_SCENARIO "\e[1;96m[36] reporting under merges + scoped conflicts\e[0m"
git reset -q --hard
# (a) a merge in the reword span: commit count includes the side branch,
# but `~N` walks first parents – deriving the commit by offset misses
echo "rw1" > rw.txt && git add rw.txt && git commit -qm "RW target"
local RW_TARGET=$(git rev-parse HEAD)
git checkout -q -b rw-side "$RW_TARGET~1"
echo "rwside" > rw-side.txt && git add rw-side.txt && git commit -qm "RW side"
git checkout -q main
git merge -q --no-ff rw-side -m "RW merge" >/dev/null 2>&1
_ST_RUN -M --text="RW reworded" "$RW_TARGET"
_ST_EQ "reword across a merge succeeds" "$RC" "0"
_ST_OUT_HAS "echo names the reworded commit, not its parent" '[0-9a-f]\{7,\} RW reworded'
_ST_OUT_LACKS "result line does not name the wrong commit" '[0-9a-f]\{7,\} RW target'
_ST_CHECK "merge topology preserved" sh -c "test \$(git log --format=%P -1 HEAD | wc -w) -eq 2"
git branch -q -D rw-side 2>/dev/null
# (b) a scoped fold that conflicts: the scope must survive --continue, or
# its intended leftovers get reported as an anomaly
git reset -q --hard
printf 'sc1\nsc2\nsc3\n' > sf.txt && printf 'keep\n' > sf-other.txt
git add sf.txt sf-other.txt && git commit -qm "SF base"
printf 'sc1\nSFT\nsc3\n' > sf.txt && git add sf.txt && git commit -qm "SF target"
local SF_TARGET=$(git rev-parse HEAD)
printf 'sc1\nSFL\nsc3\n' > sf.txt && git add sf.txt && git commit -qm "SF later"
printf 'sc1\nSFS\nsc3\n' > sf.txt && git add sf.txt
printf 'parallel\n' > sf-other.txt && git add sf-other.txt
_ST_RUN --amend-into="$SF_TARGET" -- sf.txt
_ST_EQ "scoped fold conflicts as set up" "$RC" "2"
local SF_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
_ST_RESOLVE "$SF_WT" sf.txt $'sc1\nSFS\nsc3'
_ST_RUN --continue
# The final pick's staged-tree resolution would empty "SF later" – the
# auto-resolve must decline that and leave the call with the resolver
_ST_EQ "final step that would empty its commit still pauses" "$RC" "2"
_ST_OUT_LACKS "and is not auto-resolved" 'auto-resolved'
_ST_OUT_HAS "pauses on a conflict, not a wedge" 'Conflicted files:'
_ST_RESOLVE "$SF_WT" sf.txt $'sc1\nSFL\nsc3'
_ST_RUN --continue
_ST_OUT_HAS "scope survives the conflict pause" 'outside the pathspec'
_ST_OUT_LACKS "no bogus not-folded warning" 'not folded'
_ST_CHECK "out-of-scope file never folded" sh -c "test \"\$(git show \$(git log --format='%H %s' | grep 'SF target' | cut -d' ' -f1):sf-other.txt)\" = keep"
git reset -q --hard
