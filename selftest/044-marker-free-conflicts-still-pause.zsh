# Marker-free conflicts must still pause, with history intact
_ST_SCENARIO "\e[1;96m[44] marker-free conflicts still pause\e[0m"
git reset -q --hard
# Neither of these carries conflict markers, so any attempt to decide a
# conflict by inspecting the file auto-resolves them the wrong way – which
# silently reverted a deletion and dropped the commit that made it
printf 'md one\n' > md2.txt && git add md2.txt && git commit -qm "MD2 base"
printf 'md two\n' > md2.txt && git add md2.txt && git commit -qm "MD2 middle"
local MD2_MID=$(git rev-parse HEAD)
git rm -q md2.txt && git commit -qm "MD2 deletes it"
_ST_RUN -d -y "$MD2_MID"
_ST_EQ "modify/delete pauses" "$RC" "2"
_ST_OUT_HAS "and the marker-free state is flagged" 'No conflict markers in md2.txt'
_ST_RUN --abort
_ST_CHECK "its deleting commit survives" sh -c "git log --format=%s | grep -qx 'MD2 deletes it'"
_ST_CHECK "and the file is still deleted at the tip" \
	sh -c "! git cat-file -e HEAD:md2.txt 2>/dev/null"
git reset -q --hard
# Binary: three stages, no markers, and rerere cannot resolve it either
printf 'bin\000\001 v1\n' > bin.dat && git add bin.dat && git commit -qm "BIN base"
printf 'bin\000\002 v2\n' > bin.dat && git add bin.dat && git commit -qm "BIN middle"
local BIN_MID=$(git rev-parse HEAD)
printf 'bin\000\003 v3\n' > bin.dat && git add bin.dat && git commit -qm "BIN top"
_ST_CHECK "the fixture really is binary to git" \
	sh -c "git diff --numstat HEAD~1 HEAD -- bin.dat | grep -q '^-'"
_ST_RUN -d -y "$BIN_MID"
_ST_EQ "binary conflict pauses" "$RC" "2"
_ST_OUT_HAS "the binary marker-free state is flagged too" 'No conflict markers in bin.dat'
_ST_RUN --abort
_ST_CHECK "no commit was dropped" sh -c "git log --format=%s | grep -qx 'BIN top'"
git reset -q --hard
