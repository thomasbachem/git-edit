# Auto-target follows the edited lines, not the file
_ST_SCENARIO "\e[1;96m[28] blame-aware auto-target\e[0m"
printf 'bl1\nbl2\nbl3\nbl4\nbl5\nbl6\nbl7\nbl8\n' > bl.txt
git add bl.txt && git commit -qm "BL base"
printf 'bl1\nBL-A original\nbl2\nbl3\nbl4\nbl5\nbl6\nbl7\nbl8\n' > bl.txt
git add bl.txt && git commit -qm "BL add A"
printf 'bl1\nBL-A original\nbl2\nbl3\nbl4\nbl5\nbl6\nbl7\nbl8\nBL-B original\n' > bl.txt
git add bl.txt && git commit -qm "BL add B"
printf 'bl1\nBL-A original\nbl2\nbl3\nbl4\nbl5\nbl6\nbl7\nbl8\nBL-B refined\n' > bl.txt
git add bl.txt && git commit -qm "BL refine B"
# The newest commit touching bl.txt is "BL refine B", but the edited line
# belongs to "BL add A" – the file-level guess would fold into the wrong one
printf 'bl1\nBL-A EDITED\nbl2\nbl3\nbl4\nbl5\nbl6\nbl7\nbl8\nBL-B refined\n' > bl.txt
git add bl.txt
_ST_RUN --amend-into=auto
_ST_EQ "line-level auto exits 0" "$RC" "0"
_ST_OUT_HAS "reports the line-level basis" 'last touched the staged lines'
_ST_EQ "folded into the line's owner" "$(git log --format=%s -S 'BL-A EDITED' | head -1)" "BL add A"
_ST_EQ "later commit left alone" "$(git log --format=%s -1)" "BL refine B"
# Lines owned by two different commits – refuse rather than pick one
printf 'bl1\nBL-A TWICE\nbl2\nbl3\nbl4\nbl5\nbl6\nbl7\nbl8\nBL-B TWICE\n' > bl.txt
git add bl.txt
_ST_RUN --amend-into=auto
_ST_EQ "split line ownership refused" "$RC" "1"
_ST_OUT_HAS "names the competing commits" 'different commits'
git reset -q --hard HEAD
