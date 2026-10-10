# --carry merges a landing's left-alone edits onto what it landed
_ST_SCENARIO "\e[1;96m[109] --carry merges uncommitted edits onto what a rewrite landed\e[0m"
printf '1\n2\n3\n4\n5\n' > cy-a.txt && printf 'x\ny\nz\n' > cy-c.txt && printf 'p\nq\nr\n' > cy-e.txt
printf 'k\nl\nm\n' > cy-f.txt && printf 'g\n' > cy-g.txt && printf 'a\nb\nc\nd\ne\n' > cy-h.txt && chmod +x cy-c.txt
ln -s cy-c.txt cy-l
git add cy-a.txt cy-c.txt cy-e.txt cy-f.txt cy-g.txt cy-h.txt cy-l && git commit -qm "CY base"
local CY_OLD=$(git rev-parse HEAD)
git worktree add -q --detach "$TMP/cy-side" HEAD
mkdir "$TMP/cy-side/cy-dir" && git -C "$TMP/cy-side" mv cy-a.txt cy-dir/cy-b.txt && git -C "$TMP/cy-side" rm -q cy-g.txt
printf 'ONE\n2\n3\n4\n5\n' > "$TMP/cy-side/cy-dir/cy-b.txt" && printf 'EX\ny\nz\n' > "$TMP/cy-side/cy-c.txt"
ln -sfn cy-e.txt "$TMP/cy-side/cy-l"
printf 'P\nq\nr\n' > "$TMP/cy-side/cy-e.txt" && printf 'KAY\nl\nm\n' > "$TMP/cy-side/cy-f.txt"
printf 'A\nb\nc\nd\ne\n' > "$TMP/cy-side/cy-h.txt"
git -C "$TMP/cy-side" commit -qam "CY rename and change"
local CY_NEW=$(git -C "$TMP/cy-side" rev-parse HEAD)
git worktree remove --force "$TMP/cy-side"
# Edits on the old content – beside the rewrite's line, on that very line, on a file it removes
printf '1\n2\n3\n4\n5\n6\n' > cy-a.txt && printf 'x\ny\nz\nw\n' > cy-c.txt
printf 'PEE\nq\nr\n' > cy-e.txt && printf 'g\nh\n' > cy-g.txt && printf 'a\nb\nc\nd\nE\n' > cy-h.txt
ln -sfn cy-f.txt cy-l
# And edits on the new content, a change made in the checkout first
printf 'KAY\nl\nm\nn\n' > cy-f.txt
_ST_RUN_UNSYNCED --exec --base="$CY_OLD" --no-verify -- git reset -q --hard "$CY_NEW"
_ST_OUT_HAS "the landing points at the bare --carry, from the checkout's mark" "edits merged onto it: git edit --carry$"
# A commit on top since brought content of its own, which carrying from the rewrite would revert
local CY_IDX=$TMP/cy-index
GIT_INDEX_FILE=$CY_IDX git read-tree HEAD
GIT_INDEX_FILE=$CY_IDX git update-index --cacheinfo "100644,$(printf 'A\nb\nC\nd\ne\n' | git hash-object -w --stdin),cy-h.txt"
git update-ref HEAD "$(git commit-tree "$(GIT_INDEX_FILE=$CY_IDX git write-tree)" -p HEAD -m "CY later")"
git reset -q -- cy-h.txt && rm -f "$CY_IDX"
_ST_RUN --carry
_ST_EQ "a conflict left fails the run" "$RC" "1"
_ST_EQ "edits beside the rewrite merge onto it" "$(cat cy-c.txt)" "$(printf 'EX\ny\nz\nw')"
_ST_CHECK "keeping the file's mode" test -x cy-c.txt
_ST_EQ "a rename's edits move to its new path, in a new directory" "$(cat cy-dir/cy-b.txt)" "$(printf 'ONE\n2\n3\n4\n5\n6')"
_ST_CHECK "the old one gone" test ! -e cy-a.txt
_ST_EQ "edits on the new content stay as they are" "$(cat cy-f.txt)" "$(printf 'KAY\nl\nm\nn')"
_ST_EQ "as does a conflicting file" "$(cat cy-e.txt)" "$(printf 'PEE\nq\nr')"
_ST_OUT_HAS "named with its conflict" 'cy-e.txt – 1 conflict(s)'
_ST_OUT_HAS "and a file the rewrite removed" 'cy-g.txt – removed by the rewrite'
_ST_EQ "a file committed again since is left too" "$(cat cy-h.txt)" "$(printf 'a\nb\nc\nd\nE')"
_ST_OUT_HAS "named as such" 'cy-h.txt – changed again since the rewrite'
_ST_EQ "a retargeted symlink stays one, as it was" "$(readlink cy-l)" "cy-f.txt"
_ST_OUT_HAS "named too" 'cy-l – a symlink'
_ST_RUN --carry
_ST_OUT_LACKS "a second run carries nothing twice" 'Carried onto'
# Named outright, the old tip carries onto `HEAD`, the commit since included
_ST_RUN --carry="$CY_OLD"
_ST_EQ "an old tip named outright carries onto HEAD" "$(cat cy-h.txt)" "$(printf 'A\nb\nC\nd\nE')"
_ST_RUN --carry=no-such-tip
_ST_OUT_HAS "and one naming nothing is refused" 'names no commit here'
git reset -q --hard && rm -f cy-g.txt
# A file checked out through `eol` merges as checked out – its raw blob differs on every line
echo 'cy-crlf.txt text eol=crlf' >> .git/info/attributes
printf 'u\r\nv\r\nw\r\n' > cy-crlf.txt && git add cy-crlf.txt && git commit -qm "CY crlf"
local CY_CR_OLD=$(git rev-parse HEAD)
GIT_INDEX_FILE=$CY_IDX git read-tree HEAD
GIT_INDEX_FILE=$CY_IDX git update-index --cacheinfo "100644,$(printf 'U\nv\nw\n' | git hash-object -w --stdin),cy-crlf.txt"
git update-ref HEAD "$(git commit-tree "$(GIT_INDEX_FILE=$CY_IDX git write-tree)" -p HEAD -m "CY crlf rewrite")"
rm -f "$CY_IDX"
printf 'u\r\nv\r\nW\r\n' > cy-crlf.txt
_ST_RUN --carry="$CY_CR_OLD"
_ST_EQ "a file checked out through eol carries" "$RC" "0"
_ST_EQ "in its checked-out form" "$(cat cy-crlf.txt)" "$(printf 'U\r\nv\r\nW\r\n')"
git reset -q --hard
