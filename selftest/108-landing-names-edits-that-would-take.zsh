# A landing names the edits a whole-file commit would take it back with
# Edits on the pre-rewrite content revert the rewrite once committed whole, and a rename leaves
# them untracked at the old path, where a restore of the new one would strand them
_ST_SCENARIO "\e[1;96m[108] a landing names edits that would take it back, renames included\e[0m"
printf '1\n2\n3\n4\n5\n' > rh-a.txt && printf 'x\ny\nz\n' > rh-c.txt && printf 'k\nl\nm\n' > rh-f.txt
printf 'g1\ng2\ng3\n' > rh-g.txt && printf 'h1\nh2\nh3\n' > rh-h.txt
git add rh-a.txt rh-c.txt rh-f.txt rh-g.txt rh-h.txt && git commit -qm "RH base"
local RH_OLD=$(git rev-parse HEAD)
git worktree add -q --detach "$TMP/rh-side" HEAD
git -C "$TMP/rh-side" mv rh-a.txt rh-b.txt
printf 'ONE\n2\n3\n4\n5\n' > "$TMP/rh-side/rh-b.txt" && printf 'EX\ny\nz\n' > "$TMP/rh-side/rh-c.txt" && printf 'KAY\nl\nm\n' > "$TMP/rh-side/rh-f.txt"
printf 'G1\ng2\ng3\n' > "$TMP/rh-side/rh-g.txt" && printf 'H1\nh2\nh3\n' > "$TMP/rh-side/rh-h.txt"
git -C "$TMP/rh-side" commit -qam "RH rename and change"
local RH_NEW=$(git -C "$TMP/rh-side" rev-parse HEAD)
git worktree remove --force "$TMP/rh-side"
printf '1\n2\n3\n4\n5\n6\n' > rh-a.txt && printf 'x\ny\nz\nw\n' > rh-c.txt
# A change made in the checkout first and edited on there holds the rewrite already
printf 'KAY\nl\nm\nn\n' > rh-f.txt
# Edits on the line beside the rewrite's conflict whichever content they sit on – on the new one
# they hold the rewrite, on the old one they take it back
printf 'G1\nG2 beside\ng3\n' > rh-g.txt && printf 'h1\nH2 beside\nh3\n' > rh-h.txt
_ST_RUN --exec --base="$RH_OLD" --no-verify -- git reset -q --hard "$RH_NEW"
_ST_EQ "the landing lands" "$RC:$(git rev-parse HEAD)" "0:$RH_NEW"
_ST_OUT_HAS "naming edits a whole-file commit takes it back with" 'take the landing back there: rh-c.txt'
_ST_OUT_LACKS "a landing on top taking nothing out of history" 'out of history'
_ST_OUT_HAS "and a rename's edits left at the old path" 'the new one missing: rh-a.txt → rh-b.txt'
_ST_OUT_LACKS "with no restore that would strand them" 'worktree -- rh-b.txt'
_ST_OUT_HAS "while edits already on the new content are merely left alone" 'your own): rh-f.txt'
_ST_OUT_LACKS "and not called a revert" 'back there: rh-c.txt rh-f.txt'
_ST_OUT_HAS "nor are edits beside its line that conflict with it" 'your own): rh-f.txt rh-g.txt'
_ST_OUT_HAS "while such edits on the old content still take it back" 'back there: rh-c.txt rh-h.txt'
git reset -q --hard && rm -f rh-a.txt
